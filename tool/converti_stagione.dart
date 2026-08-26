// Converte le partite scoutate con "Volleyball Scout" (.xlsx, un foglio, dieci
// colonne) in un unico backup nel NOSTRO formato — la stagione dimostrativa
// della dashboard (passo 11 del piano in docs/dati-stagionali.md).
//
// **Lo script sta nel repo, non solo il suo risultato.** È la risposta
// all'obiezione che il piano muove all'export manuale: un file convertito una
// volta sola smette di aprirsi al primo cambio di formato, un convertitore no.
//
//   dart run tool/converti_stagione.dart <cartella con le partite> [-- opzioni]
//
//     --reale <file.json>    scrive anche la versione coi cognomi VERI
//     --demo  <file.json>    dove scrivere quella anonimizzata
//
// I cognomi veri non entrano MAI nel repo: sono di ragazze minorenni e la
// cartella degli asset della dashboard è destinata alla pubblicazione. La
// versione anonima usa nomi di COLORI perché si veda a colpo d'occhio che sono
// inventati — evitando Rossi/Bianchi/Verdi/Neri, che sono sì colori ma anche i
// cognomi italiani più diffusi, e otterrebbero l'effetto opposto.
import 'dart:convert';
import 'dart:io';

import 'package:volley_scout/data/xlsx_reader.dart';
// Import mirati e non il barile `volley_stats.dart`: quello espone anche le
// tabelle delle posizioni, che usano `Offset` di `dart:ui` — c'è in Flutter ma
// non in un `dart run` puro, e ne farebbe fallire la compilazione.
import 'package:volley_stats/backup_model.dart';
import 'package:volley_stats/enums.dart';
import 'package:volley_stats/ricalcola_stato.dart';

// --- Cosa sappiamo della squadra, e che il foglio non dice ------------------

const String _nostraSquadra = 'Nettunia';
const String _categoria = 'Terza Divisione';
const int _coloreDivisa = 0xFF1E3A8A;

/// Il foglio non ha una colonna "ruolo": arriva da qui, ed è l'unica cosa che
/// va aggiornata a mano se cambia la rosa.
const Map<String, (int, Ruolo)> _rosa = {
  'Ravaglia': (2, Ruolo.opposto),
  'Treccioni': (3, Ruolo.schiacciatore),
  'Mohamed': (5, Ruolo.centrale),
  'Zannoli': (7, Ruolo.schiacciatore),
  'Sartini': (8, Ruolo.centrale),
  'Fergacich': (9, Ruolo.schiacciatore),
  'Affuso': (10, Ruolo.centrale),
  'Camprini': (11, Ruolo.palleggiatore),
  'Guerrini': (14, Ruolo.schiacciatore),
  'Roncarati': (16, Ruolo.schiacciatore),
  'Millo': (21, Ruolo.palleggiatore),
  'Corradi': (44, Ruolo.libero),
  'Cerrè': (55, Ruolo.libero),
};

/// Colori, non cognomi: la stessa atleta prende sempre lo stesso, altrimenti le
/// tendenze per giocatrice si spezzerebbero da una partita all'altra.
const List<String> _colori = [
  'Amaranto', 'Azzurro', 'Cobalto', 'Cremisi', 'Fucsia', 'Indaco', 'Lilla',
  'Magenta', 'Ocra', 'Porpora', 'Smeraldo', 'Turchese', 'Vermiglio',
];

/// Anche le **società avversarie** vanno travestite: non sono dati personali,
/// ma restano club veri coi loro risultati su una pagina pubblica, e nel file
/// anonimo stonerebbero accanto a una squadra chiamata "Volley Demo".
/// Metalli e non colori, per non confonderle con le atlete.
const List<String> _metalli = [
  'Volley Argento', 'Volley Bronzo', 'Volley Ottone', 'Volley Peltro',
  'Volley Rame', 'Volley Zinco',
];

// --- Traduzione delle righe -------------------------------------------------

/// Colonna "Tipo" → cosa diventa da noi. `null` = riga da ignorare.
const Map<String, Fondamentale> _fondamentali = {
  'battuta': Fondamentale.battuta,
  'ricezione': Fondamentale.ricezione,
  'alzata': Fondamentale.alzata,
  'attacco': Fondamentale.attacco,
  'muro': Fondamentale.muro,
  'difesa': Fondamentale.difesa,
};

const Map<String, Voto> _voti = {
  '#': Voto.perfetto,
  '+': Voto.positivo,
  '/': Voto.mezzoPunto,
  '-': Voto.negativo,
  '=': Voto.errore,
};

void main(List<String> argomenti) {
  if (argomenti.isEmpty) {
    stderr.writeln('Uso: dart run tool/converti_stagione.dart <cartella> '
        '[--reale file.json] [--demo file.json]');
    exitCode = 2;
    return;
  }
  final cartella = argomenti.first;
  final reale = _opzione(argomenti, '--reale');
  final demo = _opzione(argomenti, '--demo') ??
      'packages/volley_web/assets/backup_demo.json';

  final file = Directory(cartella)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('.xlsx'))
      .toList();
  if (file.isEmpty) {
    stderr.writeln('Nessun .xlsx in $cartella');
    exitCode = 1;
    return;
  }

  final partite = <_PartitaLetta>[];
  for (final f in file) {
    try {
      partite.add(_leggiPartita(f));
    } catch (e) {
      stderr.writeln('!! ${f.path}: $e');
      exitCode = 1;
      return;
    }
  }
  // In ordine di calendario: la dashboard mostra una stagione, e una stagione
  // ha un verso.
  partite.sort((a, b) => a.dataOra.compareTo(b.dataOra));

  _riepiloga(partite);

  final vere = _componi(partite, anonimo: false);
  if (!_verifica(vere, partite)) {
    exitCode = 1;
    return;
  }
  if (reale != null) {
    _scrivi(reale, vere);
    stdout.writeln('\nCognomi veri  -> $reale');
  }
  _scrivi(demo, _componi(partite, anonimo: true));
  stdout.writeln('Anonimizzato  -> $demo');
}

String? _opzione(List<String> argomenti, String nome) {
  final i = argomenti.indexOf(nome);
  return i >= 0 && i + 1 < argomenti.length ? argomenti[i + 1] : null;
}

// --- Lettura ----------------------------------------------------------------

class _AzioneLetta {
  _AzioneLetta({
    required this.set,
    required this.tipo,
    required this.voto,
    required this.cognome,
    required this.puntiNostri,
    required this.puntiLoro,
  });
  final int set;
  final String tipo;
  final String voto;
  final String cognome;
  final int puntiNostri;
  final int puntiLoro;
}

class _PartitaLetta {
  _PartitaLetta({
    required this.nomeFile,
    required this.dataOra,
    required this.inCasa,
    required this.avversario,
    required this.azioni,
  });
  final String nomeFile;
  final DateTime dataOra;
  final bool inCasa;
  final String avversario;
  final List<_AzioneLetta> azioni;

  List<int> get numeriSet =>
      azioni.map((a) => a.set).toSet().toList()..sort();
}

_PartitaLetta _leggiPartita(File f) {
  final griglia = leggiXlsx(f.readAsBytesSync());
  if (griglia.length < 3) throw 'foglio troppo corto';

  // Riga 0: "Locali: Nettunia" oppure "Ospiti: Nettunia". È l'unico punto in
  // cui il foglio dice da che parte stiamo, e da lì dipende quale delle due
  // colonne del punteggio è la nostra.
  final prima = griglia.first.join(' ');
  final bool inCasa;
  if (prima.contains('Locali') && prima.contains(_nostraSquadra)) {
    inCasa = true;
  } else if (prima.contains('Ospiti') && prima.contains(_nostraSquadra)) {
    inCasa = false;
  } else {
    throw 'riga 0 non dice se $_nostraSquadra è in casa: "$prima"';
  }

  final testata = griglia[1].map((c) => c.trim()).toList();
  int col(String nome) {
    final i = testata.indexOf(nome);
    if (i < 0) throw 'manca la colonna "$nome"';
    return i;
  }

  final iTipo = col('Tipo');
  final iVoto = col('Voto');
  final iCognome = col('Cognome');
  final iSet = col('Numero Set');
  final iLocali = col('Punti Locali');
  final iOspiti = col('Punti Ospiti');

  final azioni = <_AzioneLetta>[];
  for (var r = 2; r < griglia.length; r++) {
    final riga = griglia[r];
    String cella(int i) => i < riga.length ? riga[i].trim() : '';
    final tipo = cella(iTipo).toLowerCase();
    if (tipo.isEmpty) continue;
    final set = int.tryParse(cella(iSet));
    if (set == null) continue;
    final locali = int.tryParse(cella(iLocali)) ?? 0;
    final ospiti = int.tryParse(cella(iOspiti)) ?? 0;
    azioni.add(_AzioneLetta(
      set: set,
      tipo: tipo,
      voto: cella(iVoto),
      cognome: cella(iCognome),
      puntiNostri: inCasa ? locali : ospiti,
      puntiLoro: inCasa ? ospiti : locali,
    ));
  }

  return _PartitaLetta(
    nomeFile: f.path.split(RegExp(r'[\\/]')).last,
    dataOra: _dataDaPercorso(f.path),
    inCasa: inCasa,
    avversario: _avversarioDaNomeFile(f.path),
    azioni: azioni,
  );
}

/// La data sta nel nome della cartella (`2026_04_30_Clai_Nettunia`): il foglio
/// non ce l'ha da nessuna parte.
DateTime _dataDaPercorso(String percorso) {
  final pezzi = percorso.split(RegExp(r'[\\/]'));
  for (final p in pezzi.reversed) {
    final m = RegExp(r'^(\d{4})[_-](\d{1,2})[_-](\d{1,2})').firstMatch(p);
    if (m != null) {
      return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), 20, 30);
    }
  }
  throw 'nessuna data nel percorso: $percorso';
}

/// Il nome file è "Casa - Ospiti.xlsx": l'avversario è il lato che non siamo
/// noi.
String _avversarioDaNomeFile(String percorso) {
  var nome = percorso.split(RegExp(r'[\\/]')).last;
  nome = nome.replaceAll(RegExp(r'\.xlsx$', caseSensitive: false), '');
  final lati = nome.split('-').map((s) => s.trim()).toList();
  for (final lato in lati) {
    if (!lato.toLowerCase().contains(_nostraSquadra.toLowerCase())) {
      return lato;
    }
  }
  return 'Avversari';
}

// --- Composizione del backup ------------------------------------------------

BackupCompleto _componi(List<_PartitaLetta> partite, {required bool anonimo}) {
  // Azzerato a ogni composizione: lo script ne fa due (vera e anonima) e senza
  // questo i rattoppi risulterebbero il doppio di quelli veri.
  _rattoppi
    ..puntiNonAttribuiti = 0
    ..correzioniNostre = 0
    ..correzioniLoro = 0;
  final cognomi = _rosa.keys.toList()..sort();
  final travestimento = <String, String>{
    for (var i = 0; i < cognomi.length; i++)
      cognomi[i]: anonimo ? _colori[i % _colori.length] : cognomi[i],
  };

  final squadraUid = _uid('squadra/$_nostraSquadra');
  final uidGiocatore = <String, String>{
    for (final c in cognomi) c: _uid('giocatore/$c'),
  };

  final avversarie = partite.map((p) => p.avversario).toSet().toList()..sort();
  final nostroNome = anonimo ? 'Volley Demo' : _nostraSquadra;
  final travestimentoSquadre = <String, String>{
    for (var i = 0; i < avversarie.length; i++)
      avversarie[i]: anonimo ? _metalli[i % _metalli.length] : avversarie[i],
  };

  return BackupCompleto(
    formatoVersione: kFormatoVersioneBackup,
    schemaDb: 19,
    app: 'converti_stagione',
    // Data fissa, non `DateTime.now()`: rilanciare lo script non deve produrre
    // un file diverso, altrimenti ogni rigenerazione sporca il diff in git.
    esportatoIl: DateTime.utc(2026, 5, 1),
    categorie: const [CategoriaBackup(nome: _categoria, ordine: 0)],
    squadre: [
      SquadraBackup(
        uid: squadraUid,
        nome: nostroNome,
        categoria: _categoria,
        coloreDivisa: _coloreDivisa,
      ),
    ],
    giocatori: [
      for (final c in cognomi)
        GiocatoreBackup(
          uid: uidGiocatore[c]!,
          squadraUid: squadraUid,
          nome: '-',
          cognome: travestimento[c]!,
          numero: _rosa[c]!.$1,
          ruolo: _rosa[c]!.$2,
        ),
    ],
    partite: [
      for (final p in partite)
        _componiPartita(
          p,
          squadraUid: squadraUid,
          uidGiocatore: uidGiocatore,
          nostroNome: nostroNome,
          avversario: travestimentoSquadre[p.avversario] ?? p.avversario,
        ),
    ],
  );
}

PartitaBackup _componiPartita(
  _PartitaLetta p, {
  required String squadraUid,
  required Map<String, String> uidGiocatore,
  required String nostroNome,
  required String avversario,
}) {
  final sets = <SetBackup>[];
  for (final numero in p.numeriSet) {
    final delSet = p.azioni.where((a) => a.set == numero).toList();
    sets.add(_componiSet(numero, delSet, uidGiocatore));
  }

  return PartitaBackup(
    uid: _uid('partita/${p.nomeFile}'),
    nome: p.inCasa
        ? '$nostroNome - $avversario'
        : '$avversario - $nostroNome',
    dataOra: p.dataOra,
    inCasa: p.inCasa,
    stato: StatoPartita.terminata,
    setCorrente: sets.length,
    avversario: avversario,
    squadraUid: squadraUid,
    inizioAzioni: p.dataOra,
    sets: sets,
  );
}

/// Quante volte la conversione ha dovuto rattoppare il foglio, per poterlo
/// dire invece di nasconderlo.
class _Rattoppi {
  int puntiNonAttribuiti = 0;
  int correzioniNostre = 0;
  int correzioniLoro = 0;
}

final _rattoppi = _Rattoppi();

SetBackup _componiSet(
  int numero,
  List<_AzioneLetta> lette,
  Map<String, String> uidGiocatore,
) {
  final azioni = <AzioneBackup>[];
  var ordine = 0;
  var rally = 1;
  var correzioneNostri = 0;
  var correzioneLoro = 0;

  void aggiungi({
    required TipoAzione tipo,
    required Squadra squadra,
    required EsitoPunto esito,
    Fondamentale? fondamentale,
    Voto? voto,
    String? giocatoreUid,
    int? puntiNostri,
    int? puntiLoro,
  }) {
    azioni.add(AzioneBackup(
      ordine: ++ordine,
      rallyId: rally,
      // Il foglio non registra gli orari. Zero significa "non rilevato": è
      // preferibile a una progressione inventata, che sembrerebbe un dato.
      secondiDaInizioPartita: 0,
      squadra: squadra,
      tipo: tipo,
      esitoPunto: esito,
      giocatoreUid: giocatoreUid,
      fondamentale: fondamentale,
      voto: voto,
      puntiCasaAlMomento: puntiNostri,
      puntiOspitiAlMomento: puntiLoro,
    ));
    if (esito != EsitoPunto.nessuno) rally++;
  }

  for (var i = 0; i < lette.length; i++) {
    final a = lette[i];

    // Quanti punti sono cambiati fra questa riga e la prossima. Il punteggio
    // scritto su una riga è quello PRIMA che l'azione avvenga, quindi è lì che
    // si legge l'effetto. Per l'ultima riga del set il confronto non c'è e si
    // ricade sulla regola voto→esito.
    var dNostri = 0;
    var dLoro = 0;
    if (i + 1 < lette.length) {
      dNostri = lette[i + 1].puntiNostri - a.puntiNostri;
      dLoro = lette[i + 1].puntiLoro - a.puntiLoro;
    } else {
      final esito = _esitoDalVoto(a);
      if (esito == EsitoPunto.puntoNostro) dNostri = 1;
      if (esito == EsitoPunto.puntoAvversario) dLoro = 1;
    }

    // Punteggio che ARRETRA: chi scoutava ha corretto a mano il tabellone. Non
    // è un evento — è esattamente ciò per cui il nostro modello ha
    // `correzionePuntiNostri`/`correzionePuntiAvversari`, che si sommano al
    // punteggio derivato senza essere loggati.
    if (dNostri < 0) {
      correzioneNostri += dNostri;
      _rattoppi.correzioniNostre -= dNostri;
      dNostri = 0;
    }
    if (dLoro < 0) {
      correzioneLoro += dLoro;
      _rattoppi.correzioniLoro -= dLoro;
      dLoro = 0;
    }

    final fondamentale = _fondamentali[a.tipo];
    TipoAzione? tipo;
    Squadra squadra = Squadra.nostra;

    if (fondamentale != null &&
        a.cognome.isNotEmpty &&
        uidGiocatore.containsKey(a.cognome)) {
      tipo = TipoAzione.scout;
    } else if (a.tipo == 'errore generico') {
      tipo = TipoAzione.erroreGenerico;
    } else if (a.tipo == 'errore generico avversario') {
      tipo = TipoAzione.erroreGenerico;
      squadra = Squadra.avversari;
    } else if (a.tipo.startsWith('punto generico')) {
      tipo = TipoAzione.puntoManuale;
      if (a.tipo.contains('avversario')) squadra = Squadra.avversari;
    }
    // `tipo == null` = riga che non diventa un'azione ("cambio
    // configurazione": il foglio non dice CHI entra e chi esce, e una
    // sostituzione inventata sposterebbe le rotazioni). I punti che quella
    // transizione porta con sé NON vanno però persi: finiscono fra quelli non
    // attribuiti, qui sotto.

    if (tipo != null) {
      // Con un punto per parte nella stessa transizione, questa riga si prende
      // quello coerente col proprio voto e l'altro resta da attribuire.
      final preferito = _esitoDalVoto(a);
      var esito = EsitoPunto.nessuno;
      if (dNostri > 0 && (preferito == EsitoPunto.puntoNostro || dLoro == 0)) {
        esito = EsitoPunto.puntoNostro;
        dNostri--;
      } else if (dLoro > 0) {
        esito = EsitoPunto.puntoAvversario;
        dLoro--;
      }

      aggiungi(
        tipo: tipo,
        squadra: squadra,
        esito: esito,
        fondamentale: tipo == TipoAzione.scout ? fondamentale : null,
        voto: tipo == TipoAzione.scout ? _voti[a.voto] : null,
        giocatoreUid: tipo == TipoAzione.scout ? uidGiocatore[a.cognome] : null,
        puntiNostri: a.puntiNostri,
        puntiLoro: a.puntiLoro,
      );
    }

    // Punti che il tabellone registra ma che nessuna riga spiega: chi scoutava
    // non li ha battuti. Diventano punti manuali — è la stessa cosa che farebbe
    // la nostra app col bottone "+1", e tenerli è meglio che avere un
    // punteggio finale sbagliato.
    for (var n = 0; n < dNostri; n++) {
      _rattoppi.puntiNonAttribuiti++;
      aggiungi(
        tipo: TipoAzione.puntoManuale,
        squadra: Squadra.nostra,
        esito: EsitoPunto.puntoNostro,
      );
    }
    for (var n = 0; n < dLoro; n++) {
      _rattoppi.puntiNonAttribuiti++;
      aggiungi(
        tipo: TipoAzione.puntoManuale,
        squadra: Squadra.avversari,
        esito: EsitoPunto.puntoAvversario,
      );
    }
  }

  return SetBackup(
    numero: numero,
    aperto: false,
    squadraServizioIniziale: _servizioIniziale(lette),
    correzionePuntiNostri: correzioneNostri,
    correzionePuntiAvversari: correzioneLoro,
    azioni: azioni,
  );
}

EsitoPunto _esitoDalVoto(_AzioneLetta a) {
  final f = _fondamentali[a.tipo];
  if (a.tipo == 'errore generico') return EsitoPunto.puntoAvversario;
  if (a.tipo == 'errore generico avversario') return EsitoPunto.puntoNostro;
  if (a.tipo.startsWith('punto generico')) {
    return a.tipo.contains('avversario')
        ? EsitoPunto.puntoAvversario
        : EsitoPunto.puntoNostro;
  }
  if (f == null) return EsitoPunto.nessuno;
  if (a.voto == '=') return EsitoPunto.puntoAvversario;
  if (a.voto == '#' &&
      (f == Fondamentale.battuta ||
          f == Fondamentale.attacco ||
          f == Fondamentale.muro)) {
    return EsitoPunto.puntoNostro;
  }
  return EsitoPunto.nessuno;
}

/// Chi serviva a inizio set: se la prima azione nostra è una ricezione,
/// servivano loro; se è una battuta, servivamo noi.
Squadra _servizioIniziale(List<_AzioneLetta> lette) {
  for (final a in lette) {
    if (a.tipo == 'ricezione') return Squadra.avversari;
    if (a.tipo == 'battuta') return Squadra.nostra;
  }
  return Squadra.nostra;
}

// --- Verifica ---------------------------------------------------------------

/// Rigioca le azioni convertite con la stessa funzione che l'app usa dal vivo e
/// pretende i punteggi del foglio. È la prova che la conversione non ha perso
/// né inventato punti.
bool _verifica(BackupCompleto backup, List<_PartitaLetta> lette) {
  stdout.writeln('\n=== verifica: replay contro il punteggio del foglio ===');
  var tutto = true;

  for (var i = 0; i < backup.partite.length; i++) {
    final partita = backup.partite[i];
    final originale = lette[i];

    for (final set in partita.sets) {
      final azioni = [
        for (final a in set.azioni)
          AzioneScout(ordine: a.ordine, esitoPunto: a.esitoPunto),
      ];
      final stato = ricalcolaStato(
        azioni: azioni,
        servizioIniziale: set.squadraServizioIniziale,
        rotazioneIniziale: const {},
      );

      // Il punteggio atteso è l'ultima riga del set più l'esito di quella riga:
      // le colonne riportano lo stato PRIMA dell'azione.
      final delSet = originale.azioni.where((a) => a.set == set.numero).toList();
      final ultima = delSet.last;
      final esitoUltima = _esitoDalVoto(ultima);
      final attesiNostri = ultima.puntiNostri +
          (esitoUltima == EsitoPunto.puntoNostro ? 1 : 0);
      final attesiLoro = ultima.puntiLoro +
          (esitoUltima == EsitoPunto.puntoAvversario ? 1 : 0);

      // Le correzioni manuali NON sono eventi e non entrano nel replay: si
      // sommano dopo, esattamente come fa l'app dal vivo.
      final replayNostri = stato.punteggioNostro + set.correzionePuntiNostri;
      final replayLoro =
          stato.punteggioAvversario + set.correzionePuntiAvversari;

      final ok = replayNostri == attesiNostri && replayLoro == attesiLoro;
      if (!ok) tutto = false;
      stdout.writeln('  ${ok ? "ok " : "NO "} ${partita.nome.padRight(28)} '
          'set ${set.numero}: replay $replayNostri-$replayLoro'
          '   foglio $attesiNostri-$attesiLoro');
    }
  }

  stdout.writeln('\nrattoppi: ${_rattoppi.puntiNonAttribuiti} punti che il '
      'tabellone segna ma che nessuna riga spiega (diventano punti manuali), '
      'correzioni manuali del punteggio ${_rattoppi.correzioniNostre} nostre / '
      '${_rattoppi.correzioniLoro} loro');
  return tutto;
}

/// Quanto la convenzione di chi ha scoutato somiglia alla nostra: quante volte
/// l'esito letto dal punteggio NON coincide con quello che dedurremmo dal voto.
/// Va guardato prima di fidarsi delle statistiche — un numero alto vorrebbe
/// dire che i due sistemi chiamano le cose in modo diverso.
void _riepiloga(List<_PartitaLetta> partite) {
  var discordi = 0;
  var confrontate = 0;
  for (final p in partite) {
    for (final numero in p.numeriSet) {
      final delSet = p.azioni.where((a) => a.set == numero).toList();
      for (var i = 0; i < delSet.length - 1; i++) {
        final dN = delSet[i + 1].puntiNostri - delSet[i].puntiNostri;
        final dL = delSet[i + 1].puntiLoro - delSet[i].puntiLoro;
        final dalPunteggio = dN > 0
            ? EsitoPunto.puntoNostro
            : dL > 0
                ? EsitoPunto.puntoAvversario
                : EsitoPunto.nessuno;
        confrontate++;
        if (dalPunteggio != _esitoDalVoto(delSet[i])) discordi++;
      }
    }
  }
  stdout.writeln('partite: ${partite.length}   '
      'azioni lette: ${partite.fold<int>(0, (s, p) => s + p.azioni.length)}');
  stdout.writeln('esito dal punteggio diverso da quello dedotto dal voto: '
      '$discordi su $confrontate');
}

// --- Utilità ----------------------------------------------------------------

/// Uid **deterministici**: rigenerando il file gli stessi soggetti devono
/// ricevere gli stessi identificativi, altrimenti ogni rigenerazione sarebbe un
/// diff totale e un ripristino creerebbe doppioni.
String _uid(String seme) {
  var h1 = 0xcbf29ce484222325;
  var h2 = 0x100000001b3;
  for (final c in seme.codeUnits) {
    h1 = (h1 ^ c) * 0x100000001b3;
    h2 = (h2 ^ (c * 31)) * 0xcbf29ce4;
    h1 &= 0xFFFFFFFFFFFFFFFF;
    h2 &= 0xFFFFFFFFFFFFFFFF;
  }
  return (h1.toRadixString(16).padLeft(16, '0') +
          h2.toRadixString(16).padLeft(16, '0'))
      .substring(0, 32);
}

void _scrivi(String percorso, BackupCompleto backup) {
  final file = File(percorso);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(backup.toJson()));
}
