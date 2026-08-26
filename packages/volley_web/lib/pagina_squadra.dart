import 'package:flutter/material.dart';
import 'package:volley_stats/volley_stats.dart';
import 'package:volley_ui/barra_filtri.dart';
import 'package:volley_ui/grafico_tendenza.dart';
import 'package:volley_ui/kpi_riga.dart';
import 'package:volley_ui/tabellone_stagionale.dart';

/// La vista di squadra. **Non sa da dove arrivano i dati**: riceve un backup
/// già pronto e due callback per cambiarne la sorgente. È la proprietà che al
/// passo 9b le permetterà di finire dentro l'app senza modifiche — lì i dati
/// arriveranno dal database, qui da un file trascinato o dall'esempio.
///
/// Sta in un file suo, e non dentro `main.dart`, per una ragione pratica: il
/// guscio importa i plugin del browser (trascinamento, scelta file) mentre i
/// test girano sulla VM. Separandoli, la pagina si monta senza browser.
class PaginaSquadra extends StatefulWidget {
  const PaginaSquadra({
    super.key,
    required this.backup,
    this.nomeFile,
    this.salvatoLocalmente = false,
    this.onApriFile,
    this.onRimuoviDati,
  });

  final BackupCompleto backup;

  /// Nome del file caricato dall'utente. `null` = dati di esempio: chi arriva
  /// dalla vetrina deve capire subito che i numeri non sono i suoi.
  final String? nomeFile;

  /// Se il documento è conservato nel browser e sarà ancora qui alla prossima
  /// visita. `false` quando il browser nega lo spazio: il banner non deve
  /// promettere una memoria che non c'è.
  final bool salvatoLocalmente;

  /// Apre il selettore di file. `null` dove non ha senso (dentro l'app).
  final VoidCallback? onApriFile;

  /// Cancella il documento dal browser e torna all'esempio. `null` quando
  /// l'esempio è già in mostra e non c'è niente da rimuovere.
  final VoidCallback? onRimuoviDati;

  @override
  State<PaginaSquadra> createState() => _PaginaSquadraState();
}

class _PaginaSquadraState extends State<PaginaSquadra> {
  /// Lo stato dei filtri è dell'interfaccia; il *significato* dei filtri sta in
  /// `volley_stats`. Qui si tiene solo qual è quello scelto.
  Filtro _filtro = const Filtro();

  /// Chi si sta guardando nel grafico di tendenza. `null` = nessuna scelta
  /// ancora fatta, e vale la predefinita (vedi `_giocatricePredefinita`).
  String? _giocatriceUid;
  MisuraTendenza _misura = MisuraTendenza.efficienzaAttacco;

  @override
  void didUpdateWidget(PaginaSquadra vecchio) {
    super.didUpdateWidget(vecchio);
    // Cambiato backup, i filtri di prima non descrivono più niente: un
    // intervallo di date della stagione scorsa lascerebbe la pagina vuota e
    // sembrerebbe un file letto male. Si riparte da "tutto".
    if (!identical(vecchio.backup, widget.backup)) {
      _filtro = const Filtro();
      // E la giocatrice scelta non esiste più: il suo uid verrebbe cercato
      // fra le voci di un altro documento e non si troverebbe.
      _giocatriceUid = null;
    }
  }

  /// Le giocatrici del menu: **tutte quelle in rosa**, non solo chi ha giocato
  /// nel periodo. Se la lista si restringesse coi filtri, chi è selezionata
  /// potrebbe sparirne mentre è ancora il valore del menu — e un menu il cui
  /// valore non è fra le sue voci non si disegna affatto.
  List<GiocatoreBackup> _giocatrici(BackupCompleto backup) => [
        for (final g in backup.giocatori)
          if (_filtro.squadraUid == null || g.squadraUid == _filtro.squadraUid)
            g,
      ]..sort((a, b) => a.numero.compareTo(b.numero));

  /// Chi mostrare senza che nessuno abbia scelto: quella con più azioni nel
  /// periodo. Su una vetrina è la scheda che ha più da dire.
  String? _giocatricePredefinita(
    List<StatGiocatore> stats,
    List<GiocatoreBackup> rosa,
  ) {
    if (stats.isEmpty) return rosa.isEmpty ? null : rosa.first.uid;
    var migliore = stats.first;
    for (final s in stats) {
      if (s.azioni > migliore.azioni) migliore = s;
    }
    return migliore.giocatore.uid;
  }

  @override
  Widget build(BuildContext context) {
    final backup = widget.backup;
    final riepilogo = riepilogoStagione(backup, filtro: _filtro);
    final stats = statGiocatori(backup, filtro: _filtro);
    final rosa = _giocatrici(backup);
    final giocatriceUid = _giocatriceUid ?? _giocatricePredefinita(stats, rosa);
    final squadra = backup.squadre.isEmpty ? '—' : backup.squadre.first.nome;
    final tema = Theme.of(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(squadra, style: tema.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${_plurale(riepilogo.azioni, 'azione', 'azioni')} '
              'in ${_plurale(riepilogo.partite, 'partita', 'partite')}',
              style: tema.textTheme.bodyMedium
                  ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            BannerSorgente(
              nomeFile: widget.nomeFile,
              salvatoLocalmente: widget.salvatoLocalmente,
              onApriFile: widget.onApriFile,
              onRimuoviDati: widget.onRimuoviDati,
            ),
            const SizedBox(height: 20),
            BarraFiltri(
              filtro: _filtro,
              squadre: backup.squadre,
              // Tutte le partite, non quelle già filtrate: i due menu del
              // periodo devono elencare la stagione intera, altrimenti
              // scegliendo un periodo stretto non si potrebbe più allargarlo.
              partite: backup.partite,
              onCambia: (f) => setState(() => _filtro = f),
            ),
            const SizedBox(height: 24),
            if (riepilogo.partite == 0)
              // Un filtro che non lascia passare niente deve dirlo: altrimenti
              // sembra che i dati siano spariti.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  'Nessuna partita nel periodo selezionato.',
                  style: tema.textTheme.titleMedium,
                ),
              )
            else ...[
              KpiRiga(kpi: kpiDaRiepilogo(riepilogo)),
              const SizedBox(height: 32),
              Text('Giocatrici', style: tema.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Tocca l\'intestazione di una colonna per ordinare.',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              TabelloneStagionale(stats: stats),
              const SizedBox(height: 40),
              Text('Tendenza', style: tema.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Come va nel tempo, una partita per punto. '
                'La riga tratteggiata è la tendenza del periodo.',
                style: tema.textTheme.bodySmall
                    ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              GraficoTendenza(
                punti: giocatriceUid == null
                    ? const []
                    : serieTendenza(
                        backup,
                        giocatoreUid: giocatriceUid,
                        misura: _misura,
                        filtro: _filtro,
                      ),
                giocatrici: rosa,
                giocatriceUid: giocatriceUid,
                misura: _misura,
                onGiocatrice: (uid) => setState(() => _giocatriceUid = uid),
                onMisura: (m) => setState(() => _misura = m),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dice di chi sono i numeri sullo schermo, e come cambiarli. Con l'esempio in
/// mostra è anche l'invito a caricare il proprio backup: è la prima cosa che
/// legge chi arriva dalla vetrina senza sapere cosa sia questa pagina.
class BannerSorgente extends StatelessWidget {
  const BannerSorgente({
    super.key,
    this.nomeFile,
    this.salvatoLocalmente = false,
    this.onApriFile,
    this.onRimuoviDati,
  });

  final String? nomeFile;
  final bool salvatoLocalmente;
  final VoidCallback? onApriFile;
  final VoidCallback? onRimuoviDati;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esempio = nomeFile == null;
    // L'esempio si veste da avviso, il file dell'utente da conferma tranquilla:
    // il colore fa metà del lavoro prima che si legga il testo.
    final sfondo = esempio
        ? tema.colorScheme.tertiaryContainer
        : tema.colorScheme.surfaceContainerHighest;
    final testo = esempio
        ? tema.colorScheme.onTertiaryContainer
        : tema.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: sfondo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Icon(esempio ? Icons.science_outlined : Icons.description_outlined,
              color: testo),
          ConstrainedBox(
            // Senza un tetto, una riga lunga dentro a un Wrap resta su una riga
            // sola e sfonda in orizzontale su schermi stretti.
            constraints: const BoxConstraints(maxWidth: 560),
            child: esempio
                ? Text(
                    _invito,
                    style: tema.textTheme.bodyMedium?.copyWith(color: testo),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        nomeFile!,
                        style: tema.textTheme.bodyMedium?.copyWith(
                          color: testo,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        salvatoLocalmente ? _conservato : _nonConservato,
                        style: tema.textTheme.bodySmall
                            ?.copyWith(color: testo.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
          ),
          if (esempio && onApriFile != null)
            FilledButton.icon(
              onPressed: onApriFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Apri un backup'),
            ),
          if (!esempio && onApriFile != null)
            TextButton.icon(
              onPressed: onApriFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Apri un altro backup'),
            ),
          if (!esempio && onRimuoviDati != null)
            TextButton.icon(
              onPressed: onRimuoviDati,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Rimuovi i miei dati'),
            ),
        ],
      ),
    );
  }
}

/// La promessa sulla privacy sta qui, accanto all'invito a caricare il file, e
/// non in una pagina "note legali" che nessuno apre: è nel momento in cui si
/// trascina un file che una persona si chiede dove sta andando a finire.
const String _invito =
    'Stai guardando una partita di esempio. Trascina qui il file di backup '
    'esportato dall\'app per vedere i tuoi dati: restano su questo computer, '
    'non vengono inviati a noi.';

/// Detto al passato ("non sono mai stati inviati") perché è il momento in cui
/// la promessa del banner d'ingresso viene mantenuta: chi ha appena caricato un
/// file vuole sapere che è andata come gli era stato detto.
const String _conservato = 'Salvato in questo browser: lo ritrovi anche alla '
    'prossima visita. Non è mai stato inviato a noi.';

/// Il browser ha negato lo spazio (navigazione in incognito, archiviazione
/// disattivata). I dati si vedono lo stesso, ma prometterne la memoria sarebbe
/// una bugia che si scopre solo ricaricando la pagina.
const String _nonConservato = 'Questo browser non conserva i dati: chiudendo '
    'la pagina bisognerà ricaricare il file.';

/// "1 partita", non "1 partite": il conteggio si legge in cima alla pagina e
/// l'errore di accordo salta all'occhio proprio nel caso più comune della
/// vetrina, che di partite ne ha una sola.
String _plurale(int n, String singolare, String plurale) =>
    n == 1 ? '$n $singolare' : '$n $plurale';
