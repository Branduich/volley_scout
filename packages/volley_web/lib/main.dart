import 'dart:async';
import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:idb_shim/idb_browser.dart';
import 'package:volley_stats/volley_stats.dart';

import 'archivio.dart';
import 'pagina_squadra.dart';

/// Dashboard stagionale (piano in docs/dati-stagionali.md).
///
/// Passi fatti: 6 (riga KPI), 7 (tabellone), 7b (filtri), 8 (caricamento di un
/// backup dell'utente e memoria fra una visita e l'altra). Mancano i grafici
/// (9).
void main() => runApp(const DashboardApp());

class DashboardApp extends StatelessWidget {
  const DashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Volley Scout Stratego — Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E3A8A),
        useMaterial3: true,
      ),
      home: const Dashboard(),
    );
  }
}

/// Il **guscio**: l'unico che sa da dove arrivano i dati — qui l'asset di
/// esempio o un file scelto dall'utente, al passo 8b anche IndexedDB, e nella
/// pagina dentro l'app (9b) il database drift. La pagina sotto riceve dati già
/// pronti e non sa niente di tutto questo.
class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  /// L'esempio si tiene da parte una volta letto: tornarci dopo aver rimosso i
  /// propri dati dev'essere immediato, non una seconda lettura dell'asset.
  BackupCompleto? _esempio;
  BackupCompleto? _backup;
  String? _nomeFile;
  String? _errore;
  bool _trascinamentoInCorso = false;

  /// `null` finché non si prova ad aprirlo, e **resta null se il browser nega
  /// lo spazio**: da lì in poi la pagina funziona identica, solo senza memoria.
  ArchivioBackup? _archivio;
  bool get _memoriaDisponibile => _archivio != null;

  @override
  void initState() {
    super.initState();
    _avvia();
  }

  /// All'apertura: prima si guarda se c'è un documento di una visita
  /// precedente, e solo se non c'è si mostra l'esempio. L'ordine conta — chi
  /// torna sulla pagina si aspetta i suoi dati, non la vetrina.
  Future<void> _avvia() async {
    await _caricaEsempio();
    await _riprendiDallArchivio();
  }

  Future<void> _caricaEsempio() async {
    try {
      final testo = await rootBundle.loadString('assets/backup_demo.json');
      // `BackupCompleto.fromJson` è nel package condiviso e fa già i controlli
      // su formato e versione: la dashboard legge gli stessi file che l'app
      // esporta, con lo stesso codice.
      final esempio =
          BackupCompleto.fromJson(jsonDecode(testo) as Map<String, Object?>);
      if (!mounted) return;
      setState(() {
        _esempio = esempio;
        _backup = esempio;
        _nomeFile = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errore = 'Dati di esempio non leggibili: $e');
    }
  }

  Future<void> _riprendiDallArchivio() async {
    final archivio = ArchivioBackup(idbFactoryBrowser);
    final DocumentoSalvato? salvato;
    try {
      salvato = await archivio.leggi();
    } catch (_) {
      // Spazio negato: si prosegue senza memoria. Non è un errore da mostrare
      // — chi apre la pagina in incognito non ha sbagliato niente — ma il
      // banner smetterà di promettere che i dati restano.
      return;
    }
    if (!mounted) return;
    setState(() => _archivio = archivio);
    if (salvato == null) return;

    try {
      final backup = BackupCompleto.fromJson(
          jsonDecode(salvato.json) as Map<String, Object?>);
      if (!mounted) return;
      setState(() {
        _backup = backup;
        _nomeFile = salvato!.nomeFile;
      });
    } catch (e) {
      // Un documento salvato che non si legge più (formato cambiato, record
      // troncato) resterebbe illeggibile a ogni visita: si toglie di mezzo e
      // lo si dice, invece di far ripartire ogni volta dalla vetrina senza
      // spiegare perché.
      unawaited(archivio.azzera());
      _segnala('Il backup salvato in questo browser non è più leggibile '
          '($e). È stato rimosso: ricarica il file.');
    }
  }

  /// Legge un file scelto o trascinato. Gli errori arrivano già scritti per una
  /// persona: `BackupFormatException` porta il proprio messaggio, e un file che
  /// non è nemmeno JSON va distinto da uno che è JSON ma non è un backup —
  /// sono due sbagli diversi e portano a due rimedi diversi.
  Future<void> _leggi(XFile file) async {
    try {
      final testo = await file.readAsString();
      final json = jsonDecode(testo);
      if (json is! Map<String, Object?>) {
        throw const BackupFormatException(
            'Il file contiene JSON, ma non un backup.');
      }
      final backup = BackupCompleto.fromJson(json);
      if (!mounted) return;
      setState(() {
        _backup = backup;
        _nomeFile = file.name;
      });
      // Si salva **dopo** aver letto il file, mai prima: un documento rifiutato
      // non deve prendere il posto di quello buono già in archivio.
      await _conserva(nomeFile: file.name, json: testo);
    } on BackupFormatException catch (e) {
      _segnala(e.messaggio);
    } on FormatException {
      _segnala('"${file.name}" non è un file JSON. Il backup si esporta '
          'dall\'app con Impostazioni → Backup e ripristino.');
    } catch (e) {
      _segnala('Non sono riuscito a leggere "${file.name}": $e');
    }
  }

  void _segnala(String messaggio) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messaggio),
        behavior: SnackBarBehavior.floating,
        // Un messaggio d'errore lungo va letto, non intravisto: il default di
        // quattro secondi non basta a leggere due righe e capire cosa fare.
        duration: const Duration(seconds: 8),
        width: 600,
      ),
    );
  }

  Future<void> _apriConSelettore() async {
    const tipi = XTypeGroup(
      label: 'Backup Volley Scout Stratego',
      extensions: ['json'],
      mimeTypes: ['application/json'],
    );
    final file = await openFile(acceptedTypeGroups: const [tipi]);
    if (file != null) await _leggi(file);
  }

  /// Conserva il documento per la prossima visita. Un fallimento qui non è
  /// grave — i dati sullo schermo restano — ma va detto, perché altrimenti si
  /// scopre solo ricaricando la pagina e sembra che siano andati persi.
  Future<void> _conserva(
      {required String nomeFile, required String json}) async {
    final archivio = _archivio;
    if (archivio == null) return;
    try {
      await archivio.salva(nomeFile: nomeFile, json: json);
    } catch (_) {
      if (!mounted) return;
      setState(() => _archivio = null);
    }
  }

  /// Un solo gesto per due cose che nella pratica coincidono: togliere i propri
  /// dati da questo computer e tornare alla vetrina. Tenerli separati avrebbe
  /// creato uno stato — "guardo l'esempio ma i miei dati sono ancora salvati" —
  /// in cui il banner non sa più cosa dire.
  Future<void> _rimuoviDati() async {
    setState(() {
      _backup = _esempio;
      _nomeFile = null;
    });
    try {
      await _archivio?.azzera();
    } catch (_) {
      // Già tornati all'esempio: insistere su un archivio che non risponde non
      // cambierebbe niente di quello che si vede.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errore != null) {
      return Scaffold(body: Center(child: Text(_errore!)));
    }
    final backup = _backup;
    if (backup == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DropTarget(
      onDragEntered: (_) => setState(() => _trascinamentoInCorso = true),
      onDragExited: (_) => setState(() => _trascinamentoInCorso = false),
      onDragDone: (dettagli) {
        setState(() => _trascinamentoInCorso = false);
        // Più file insieme: si legge il primo invece di non fare niente. Un
        // solo documento per volta è il modello della pagina, e chiedere quale
        // dei tre volesse sarebbe una domanda su un gesto già fatto.
        if (dettagli.files.isNotEmpty) _leggi(dettagli.files.first);
      },
      child: Stack(
        children: [
          PaginaSquadra(
            // La chiave lega lo stato dei filtri al documento: cambiando file
            // la pagina si rimonta pulita invece di trascinarsi dietro un
            // intervallo di date che non esiste più.
            key: ValueKey(_nomeFile ?? '#esempio'),
            backup: backup,
            nomeFile: _nomeFile,
            salvatoLocalmente: _memoriaDisponibile,
            onApriFile: _apriConSelettore,
            onRimuoviDati: _nomeFile == null ? null : _rimuoviDati,
          ),
          if (_trascinamentoInCorso) const _VeloTrascinamento(),
        ],
      ),
    );
  }
}

/// Conferma che la pagina accetta il file: senza, trascinare un documento su
/// una tela che non reagisce sembra non funzionare, e si lascia perdere prima
/// di provare a rilasciare.
class _VeloTrascinamento extends StatelessWidget {
  const _VeloTrascinamento();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Positioned.fill(
      // Il velo è decorativo: se intercettasse il puntatore non cambierebbe
      // nulla per il trascinamento (che passa dal browser) ma coprirebbe la
      // pagina a ogni sfioramento.
      child: IgnorePointer(
        child: Container(
          color: tema.colorScheme.primary.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: tema.colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_download_outlined,
                    color: tema.colorScheme.onInverseSurface),
                const SizedBox(width: 12),
                Text(
                  'Rilascia qui il backup',
                  style: tema.textTheme.titleMedium
                      ?.copyWith(color: tema.colorScheme.onInverseSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
