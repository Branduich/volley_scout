import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers/database_provider.dart';

// Punteggio finale di un set per la tabella del PDF — stesso calcolo di
// MatchReportScreen._carica (eventi + correzione manuale + durata).
typedef _RigaSetPdf = ({
  int numero,
  int nostro,
  int avversario,
  Duration? durata,
});

// Contatori di un giocatore per la mega tabella statistiche (pagina 2,
// layout dal foglio "VOLLEY STATS PDF"): una mappa voto→conteggio per
// gruppo di colonne. `attaccoSuRicezione`/`attaccoSuDifesa` sono la
// partizione binaria di `attacco` (vedi idAttacchiSuRicezione in
// database_provider.dart); `murati` gli attacchi con muro punto subito
// (vedi attaccoMurato). Usata anche per la riga TOTALI (player null).
class _StatGiocatore {
  final Player? player;
  final battuta = <Voto, int>{};
  final attacco = <Voto, int>{};
  final attaccoSuRicezione = <Voto, int>{};
  final attaccoSuDifesa = <Voto, int>{};
  final ricezione = <Voto, int>{};
  final difesa = <Voto, int>{};
  final muro = <Voto, int>{};
  int murati = 0;

  _StatGiocatore(this.player);

  bool get vuota =>
      battuta.isEmpty &&
      attacco.isEmpty &&
      ricezione.isEmpty &&
      difesa.isEmpty &&
      muro.isEmpty;

  // Punti totali (voto # nei fondamentali che vincono punti) ed errori
  // totali (voto = su tutti i gruppi della tabella; alzata esclusa perché
  // non ha un gruppo nel foglio) — colonne "PT - ERR".
  int get puntiTotali =>
      (battuta[Voto.perfetto] ?? 0) +
      (attacco[Voto.perfetto] ?? 0) +
      (muro[Voto.perfetto] ?? 0);
  int get erroriTotali =>
      (battuta[Voto.errore] ?? 0) +
      (attacco[Voto.errore] ?? 0) +
      (ricezione[Voto.errore] ?? 0) +
      (difesa[Voto.errore] ?? 0) +
      (muro[Voto.errore] ?? 0);
}

/// Anteprima + condivisione del report PDF di una partita terminata —
/// raggiunta dal bottone "PDF" sulla card di `MatchesScreen`. Il documento
/// si genera on-demand nella callback di `PdfPreview` (nessun file salvato
/// finché non si condivide/stampa): sempre aggiornato, anche dopo una
/// ripresa della partita per correzioni.
class MatchPdfScreen extends ConsumerStatefulWidget {
  final VolleyMatch match;
  const MatchPdfScreen({super.key, required this.match});

  @override
  ConsumerState<MatchPdfScreen> createState() => _MatchPdfScreenState();
}

class _MatchPdfScreenState extends ConsumerState<MatchPdfScreen> {
  String _pad(int n) => n.toString().padLeft(2, '0');

  // Durata di gioco di un set (prima→ultima azione) — stessa logica di
  // MatchReportScreen._durataSet.
  Duration? _durataSet(List<ScoutAction> azioni) {
    if (azioni.length < 2) return null;
    return azioni.last.timestamp.difference(azioni.first.timestamp);
  }

  String _formatDurata(Duration d) =>
      '${d.inMinutes}:${_pad(d.inSeconds % 60)}';

  // Genera l'intero documento. Richiamata da PdfPreview (anche al cambio di
  // formato pagina): carica dati e font ogni volta — costo trascurabile per
  // una partita, e niente stato da tenere sincronizzato.
  Future<Uint8List> _buildPdf(PdfPageFormat format) async {
    final match = widget.match;
    final setRepo = ref.read(matchSetRepositoryProvider);
    final azioniRepo = ref.read(scoutActionRepositoryProvider);

    // Squadra: lookup diretto + fallback per le partite pre-fix con teamId
    // perso — stesse convenzioni di MatchReportScreen._carica.
    final teamId = match.teamId;
    var team = teamId == null
        ? null
        : await ref.read(teamRepositoryProvider).getTeam(teamId);
    team ??= await setRepo.inferisciSquadraDaRotazioni(match.id);

    final sets = await setRepo.caricaSetsPartita(match.id);
    final righeSet = <_RigaSetPdf>[];
    final azioniPerSet = <int, List<ScoutAction>>{};
    for (final set in sets) {
      final stato = await setRepo.calcolaStatoFinale(set);
      final azioni = await azioniRepo.caricaAzioni(set.id);
      azioniPerSet[set.id] = azioni;
      righeSet.add((
        numero: set.numero,
        nostro: stato.punteggioNostro + set.correzionePuntiNostri,
        avversario: stato.punteggioAvversario + set.correzionePuntiAvversari,
        durata: _durataSet(azioni),
      ));
    }
    final players = team == null
        ? <Player>[]
        : await ref.read(teamRepositoryProvider).getPlayersForTeam(team.id);
    final stats = _calcolaStatGiocatori(players, azioniPerSet);

    // Font Barlow dagli asset già bundlati (stesso font dell'app): senza,
    // il pdf ricadrebbe su Helvetica non-Unicode.
    final regular = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Barlow/Barlow-Regular.ttf'));
    final bold = pw.Font.ttf(
        await rootBundle.load('assets/fonts/Barlow/Barlow-Bold.ttf'));
    // Logo app (variante trasparente, la stessa dell'icona adattiva).
    final logo = pw.MemoryImage(
      (await rootBundle.load('assets/icon/icon_foreground.png'))
          .buffer
          .asUint8List(),
    );

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        header: (context) => _buildHeaderPagina(context, logo),
        build: (context) => [
          ..._buildIntestazione(team),
          pw.SizedBox(height: 24),
          _buildPunteggioFinale(team, righeSet),
          pw.SizedBox(height: 24),
          _buildTabellaSet(righeSet),
        ],
      ),
    );
    // Pagina 2 — mega tabella statistiche giocatori (layout dal foglio di
    // riferimento "VOLLEY STATS PDF") + punti/errori generici. Margine
    // ridotto e fissato esplicitamente: le larghezze fisse delle colonne
    // (vedi _buildMegaTabella) sono calcolate su ~800pt utili.
    if (stats.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          pageFormat: format,
          margin: const pw.EdgeInsets.all(20),
          header: (context) => _buildHeaderPagina(context, logo),
          build: (context) => [
            pw.Text(
              'Statistiche giocatori — Partita intera',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            _buildMegaTabella(stats),
            pw.SizedBox(height: 16),
            pw.Text(
              'Punti ed errori generici',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            _buildGenerici(team, azioniPerSet.values),
          ],
        ),
      );
    }
    return doc.save();
  }

  // Header ripetuto su ogni pagina: logo + numero di pagina in alto a
  // destra.
  pw.Widget _buildHeaderPagina(pw.Context context, pw.MemoryImage logo) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Image(logo, height: 26),
          pw.SizedBox(width: 8),
          pw.Text(
            'Pag. ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  // Pallino esito 8pt: verde = vinto, rosso = perso, grigio = parità —
  // stessi colori semantici del report a video (AppColors.success/danger).
  pw.Widget _pallinoEsito(int mio, int altro) {
    final colore = mio > altro
        ? const PdfColor.fromInt(0xFF16A34A) // AppColors.success
        : (altro > mio
            ? const PdfColor.fromInt(0xFFDC2626) // AppColors.danger
            : PdfColors.grey500);
    return pw.Container(
      width: 8,
      height: 8,
      decoration: pw.BoxDecoration(color: colore, shape: pw.BoxShape.circle),
    );
  }

  // Nomi con le stesse convenzioni di MatchReportScreen (fallback
  // "Avversari"/"Nostra squadra").
  String get _nomeAvversario {
    final avversario = widget.match.avversario?.trim();
    return (avversario != null && avversario.isNotEmpty)
        ? avversario
        : 'Avversari';
  }

  String _nomeNostro(Team? team) => team?.nome ?? 'Nostra squadra';

  // ── Sezioni del documento (una funzione per sezione: i prossimi pezzi
  // aggiungono funzioni qui senza toccare l'impianto) ─────────────────────

  List<pw.Widget> _buildIntestazione(Team? team) {
    final match = widget.match;
    final dt = match.dataOra;
    final dataOraStr =
        '${_pad(dt.day)}/${_pad(dt.month)}/${dt.year} ${_pad(dt.hour)}:${_pad(dt.minute)}';
    final palestra = match.palestra?.trim();
    return [
      pw.Text(
        '${_nomeNostro(team)} - $_nomeAvversario',
        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 4),
      pw.Text(match.nome, style: const pw.TextStyle(fontSize: 14)),
      pw.SizedBox(height: 2),
      pw.Text(dataOraStr,
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
      if (palestra != null && palestra.isNotEmpty)
        pw.Text(palestra,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
    ];
  }

  pw.Widget _buildPunteggioFinale(Team? team, List<_RigaSetPdf> righeSet) {
    var setVintiNostri = 0;
    var setVintiAvversario = 0;
    for (final riga in righeSet) {
      if (riga.nostro > riga.avversario) setVintiNostri++;
      if (riga.avversario > riga.nostro) setVintiAvversario++;
    }
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Pallino esito accanto a ciascun nome (verde vinto/rosso perso),
          // sul lato interno — stessa convenzione del report a video.
          pw.Expanded(
            child: pw.Row(
              children: [
                pw.Flexible(
                  child: pw.Text(_nomeNostro(team),
                      style: const pw.TextStyle(fontSize: 14)),
                ),
                pw.SizedBox(width: 8),
                _pallinoEsito(setVintiNostri, setVintiAvversario),
              ],
            ),
          ),
          pw.Text(
            '$setVintiNostri - $setVintiAvversario',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Expanded(
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                _pallinoEsito(setVintiAvversario, setVintiNostri),
                pw.SizedBox(width: 8),
                pw.Flexible(
                  child: pw.Text(
                    _nomeAvversario,
                    textAlign: pw.TextAlign.right,
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTabellaSet(List<_RigaSetPdf> righeSet) {
    if (righeSet.isEmpty) {
      return pw.Text('Nessun set giocato.',
          style: const pw.TextStyle(fontSize: 12));
    }
    pw.Widget cella(String testo,
        {bool bold = false, pw.TextAlign align = pw.TextAlign.center}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
        child: pw.Text(
          testo,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    // Pallino esito centrato in cella (stessa altezza delle celle testo).
    pw.Widget cellaEsito(int mio, int altro) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Center(child: _pallinoEsito(mio, altro)),
        );

    var puntiNostri = 0;
    var puntiAvversari = 0;
    var setVintiNostri = 0;
    var setVintiAvversario = 0;
    var durataTotale = Duration.zero;
    for (final riga in righeSet) {
      puntiNostri += riga.nostro;
      puntiAvversari += riga.avversario;
      if (riga.nostro > riga.avversario) setVintiNostri++;
      if (riga.avversario > riga.nostro) setVintiAvversario++;
      if (riga.durata != null) durataTotale += riga.durata!;
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(1.4),
        2: pw.FlexColumnWidth(0.5),
        3: pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            cella('Set', bold: true, align: pw.TextAlign.left),
            cella('Punteggio', bold: true),
            cella('Esito', bold: true),
            cella('Durata', bold: true),
          ],
        ),
        for (final riga in righeSet)
          pw.TableRow(
            children: [
              cella('Set ${riga.numero}', align: pw.TextAlign.left),
              cella('${riga.nostro} - ${riga.avversario}'),
              cellaEsito(riga.nostro, riga.avversario),
              cella(riga.durata == null ? '—' : _formatDurata(riga.durata!)),
            ],
          ),
        // Riga Totale: il pallino segue i SET vinti, non i punti — stessa
        // convenzione del report a video.
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            cella('Totale', bold: true, align: pw.TextAlign.left),
            cella('$puntiNostri - $puntiAvversari', bold: true),
            cellaEsito(setVintiNostri, setVintiAvversario),
            cella(_formatDurata(durataTotale), bold: true),
          ],
        ),
      ],
    );
  }

  // ── Pagina 2: mega tabella statistiche + generici ───────────────────────

  List<_StatGiocatore> _calcolaStatGiocatori(
      List<Player> players, Map<int, List<ScoutAction>> azioniPerSet) {
    final suRicezione = idAttacchiSuRicezione(azioniPerSet.values);
    final perId = {for (final p in players) p.id: _StatGiocatore(p)};
    for (final azioni in azioniPerSet.values) {
      for (final a in azioni) {
        if (a.tipo != TipoAzione.scout) continue;
        final stat = perId[a.giocatoreId];
        final voto = a.voto;
        if (stat == null || voto == null) continue;
        void inc(Map<Voto, int> c) => c[voto] = (c[voto] ?? 0) + 1;
        switch (a.fondamentale) {
          case Fondamentale.battuta:
            inc(stat.battuta);
          case Fondamentale.attacco:
            inc(stat.attacco);
            inc(suRicezione.contains(a.id)
                ? stat.attaccoSuRicezione
                : stat.attaccoSuDifesa);
            if (attaccoMurato(a)) stat.murati++;
          case Fondamentale.ricezione:
            inc(stat.ricezione);
          case Fondamentale.difesa:
            inc(stat.difesa);
          case Fondamentale.muro:
            inc(stat.muro);
          default:
            break; // alzata: nessun gruppo nel foglio di riferimento
        }
      }
    }
    return perId.values.where((s) => !s.vuota).toList()
      ..sort((a, b) => a.player!.numero.compareTo(b.player!.numero));
  }

  int _tot(Map<Voto, int> c) => c.values.fold(0, (a, b) => a + b);
  int _nVoto(Map<Voto, int> c, Voto v) => c[v] ?? 0;

  // Percentuale arrotondata all'intero (anche negativa, per l'efficienza),
  // '—' senza azioni (mai divisione per zero) — interi per leggibilità
  // nelle celle strette della mega tabella.
  String _pctSu(int numeratore, int totale) =>
      totale == 0 ? '—' : '${(numeratore * 100 / totale).round()}';

  // Stesse formule delle card Efficienza/Positività del report a video.
  String _eff(Map<Voto, int> c) => _pctSu(
      _nVoto(c, Voto.perfetto) - _nVoto(c, Voto.errore), _tot(c));
  String _pos(Map<Voto, int> c) => _pctSu(
      _nVoto(c, Voto.perfetto) + _nVoto(c, Voto.positivo), _tot(c));

  String _ruoloBreve(Ruolo r) => switch (r) {
        Ruolo.palleggiatore => 'P',
        Ruolo.schiacciatore => 'S',
        Ruolo.centrale => 'C',
        Ruolo.opposto => 'O',
        Ruolo.libero => 'L',
        Ruolo.undefined => 'U',
      };

  // Valori di una riga della mega tabella, nello stesso ordine delle 34
  // colonne (vedi _buildMegaTabella). `player == null` = riga TOTALI.
  List<String> _valoriRiga(_StatGiocatore s) {
    final p = s.player;
    return [
      p == null ? '' : '${p.numero}',
      p == null ? 'TOTALI' : p.cognome,
      p == null ? '' : _ruoloBreve(p.ruolo),
      // BATTUTA
      '${_tot(s.battuta)}',
      '${_nVoto(s.battuta, Voto.perfetto)}',
      '${_nVoto(s.battuta, Voto.errore)}',
      _eff(s.battuta),
      // ATTACCO
      '${_tot(s.attacco)}',
      '${_nVoto(s.attacco, Voto.perfetto)}',
      '${_nVoto(s.attacco, Voto.errore)}',
      '${s.murati}',
      _eff(s.attacco),
      // ATT. SU RICEZIONE
      '${_tot(s.attaccoSuRicezione)}',
      '${_nVoto(s.attaccoSuRicezione, Voto.perfetto)}',
      '${_nVoto(s.attaccoSuRicezione, Voto.errore)}',
      _eff(s.attaccoSuRicezione),
      // ATT. SU DIFESA
      '${_tot(s.attaccoSuDifesa)}',
      '${_nVoto(s.attaccoSuDifesa, Voto.perfetto)}',
      '${_nVoto(s.attaccoSuDifesa, Voto.errore)}',
      _eff(s.attaccoSuDifesa),
      // RICEZIONE
      '${_tot(s.ricezione)}',
      '${_nVoto(s.ricezione, Voto.perfetto)}',
      '${_nVoto(s.ricezione, Voto.errore)}',
      _eff(s.ricezione),
      _pos(s.ricezione),
      // DIFESA
      '${_tot(s.difesa)}',
      '${_nVoto(s.difesa, Voto.perfetto)}',
      '${_nVoto(s.difesa, Voto.errore)}',
      _eff(s.difesa),
      _pos(s.difesa),
      // MURO
      '${_tot(s.muro)}',
      '${_nVoto(s.muro, Voto.perfetto)}',
      // PT - ERR
      '${s.puntiTotali}',
      '${s.erroriTotali}',
    ];
  }

  pw.Widget _buildMegaTabella(List<_StatGiocatore> stats) {
    // Larghezze fisse in pt: 3 colonne giocatore + 31 numeriche = ~784,
    // dentro i ~802 utili di A4 landscape col margine 20 della pagina.
    const wNum = 16.0, wNome = 66.0, wRuolo = 20.0, wCol = 22.0;

    // Gruppi di colonne: label, larghezze, colore (palette del foglio
    // Google Sheets di riferimento).
    final gruppi = <(String, List<double>, PdfColor)>[
      ('GIOCATORE', const [wNum, wNome, wRuolo],
          const PdfColor.fromInt(0xFFDD7E6B)),
      ('BATTUTA', List.filled(4, wCol), const PdfColor.fromInt(0xFFFCE5CD)),
      ('ATTACCO', List.filled(5, wCol), const PdfColor.fromInt(0xFFD9EAD3)),
      ('ATT. SU RIC.', List.filled(4, wCol),
          const PdfColor.fromInt(0xFFEBF3E8)),
      ('ATT. SU DIF.', List.filled(4, wCol),
          const PdfColor.fromInt(0xFFEBF3E8)),
      ('RICEZIONE', List.filled(5, wCol), const PdfColor.fromInt(0xFFC9DAF8)),
      ('DIFESA', List.filled(5, wCol), const PdfColor.fromInt(0xFF9FC5E8)),
      ('MURO', List.filled(2, wCol), const PdfColor.fromInt(0xFFEAD1DC)),
      ('PT - ERR', List.filled(2, wCol), const PdfColor.fromInt(0xFFD5A6BD)),
    ];
    const headerColonne = [
      '#', 'Nome', 'Ruolo',
      'TOT', 'PT', 'ERR', 'EFF %',
      'TOT', 'PT', 'ERR', 'MURI', 'EFF %',
      'TOT', 'PT', 'ERR', 'EFF %',
      'TOT', 'PT', 'ERR', 'EFF %',
      'TOT', '++', 'ERR', 'EFF %', 'POS %',
      'TOT', '++', 'ERR', 'EFF %', 'POS %',
      'TOT', 'PT',
      'PT', 'ERR',
    ];

    // Liste piatte per la Table: larghezza e colore di ciascuna colonna.
    final larghezze = [for (final g in gruppi) ...g.$2];
    final coloriColonna = [
      for (final g in gruppi) ...List.filled(g.$2.length, g.$3),
    ];

    pw.Widget cella(String testo,
        {PdfColor? bg, bool bold = false, pw.Alignment? align}) {
      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
        alignment: align ?? pw.Alignment.center,
        child: pw.Text(
          testo,
          maxLines: 1,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            fontSize: 6.5,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    // Riga dei gruppi: pw.Table non ha il colspan, quindi è una Row di
    // Container a parte, con larghezze = somma delle colonne del gruppo —
    // le stesse FixedColumnWidth della tabella, così restano allineate.
    final rigaGruppi = pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        for (final g in gruppi)
          pw.Container(
            width: g.$2.fold<double>(0.0, (a, b) => a + b),
            height: 12,
            color: g.$3,
            alignment: pw.Alignment.center,
            child: pw.Text(
              g.$1,
              style:
                  pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
            ),
          ),
      ],
    );

    final totali = _StatGiocatore(null);
    for (final s in stats) {
      void somma(Map<Voto, int> da, Map<Voto, int> a) =>
          da.forEach((v, n) => a[v] = (a[v] ?? 0) + n);
      somma(s.battuta, totali.battuta);
      somma(s.attacco, totali.attacco);
      somma(s.attaccoSuRicezione, totali.attaccoSuRicezione);
      somma(s.attaccoSuDifesa, totali.attaccoSuDifesa);
      somma(s.ricezione, totali.ricezione);
      somma(s.difesa, totali.difesa);
      somma(s.muro, totali.muro);
      totali.murati += s.murati;
    }
    const coloreTotali = PdfColor.fromInt(0xFFF6D368);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        rigaGruppi,
        pw.Table(
          // min: senza, la Table si stira alla larghezza disponibile
          // (default TableWidth.max) scalando le colonne oltre le
          // FixedColumnWidth — e la riga dei gruppi (Row a larghezze
          // fisse) si disallinea progressivamente verso destra.
          tableWidth: pw.TableWidth.min,
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.3),
          columnWidths: {
            for (var i = 0; i < larghezze.length; i++)
              i: pw.FixedColumnWidth(larghezze[i]),
          },
          children: [
            pw.TableRow(
              children: [
                for (var i = 0; i < headerColonne.length; i++)
                  cella(headerColonne[i], bg: coloriColonna[i], bold: true),
              ],
            ),
            for (var r = 0; r < stats.length; r++)
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: r.isEven ? PdfColors.white : PdfColors.grey100,
                ),
                children: [
                  for (final (i, v) in _valoriRiga(stats[r]).indexed)
                    cella(v,
                        align: i == 1 ? pw.Alignment.centerLeft : null),
                ],
              ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: coloreTotali),
              children: [
                for (final (i, v) in _valoriRiga(totali).indexed)
                  cella(v,
                      bold: true,
                      align: i == 1 ? pw.Alignment.centerLeft : null),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // Punti/errori generici (bottoni rapidi) + tipologia degli errori
  // avversari — stessa logica dello specchietto del report a video.
  pw.Widget _buildGenerici(
      Team? team, Iterable<List<ScoutAction>> azioniPerSet) {
    var puntiNostri = 0, erroriNostri = 0, puntiAvv = 0, erroriAvv = 0;
    final motivi = <MotivoErrore, int>{};
    for (final azioni in azioniPerSet) {
      for (final a in azioni) {
        if (a.tipo == TipoAzione.puntoManuale) {
          a.squadra == Squadra.nostra ? puntiNostri++ : puntiAvv++;
        } else if (a.tipo == TipoAzione.erroreGenerico) {
          if (a.squadra == Squadra.nostra) {
            erroriNostri++;
          } else {
            erroriAvv++;
            final m = MotivoErrore.values
                    .where((m) => m.name == a.tipoEsecuzione)
                    .firstOrNull ??
                MotivoErrore.generico;
            motivi[m] = (motivi[m] ?? 0) + 1;
          }
        }
      }
    }

    pw.Widget cella(String testo, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          child: pw.Text(
            testo,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 320,
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  cella(''),
                  cella(_nomeNostro(team), bold: true),
                  cella(_nomeAvversario, bold: true),
                ],
              ),
              pw.TableRow(children: [
                cella('Punti generici', bold: true),
                cella('$puntiNostri'),
                cella('$puntiAvv'),
              ]),
              pw.TableRow(children: [
                cella('Errori generici', bold: true),
                cella('$erroriNostri'),
                cella('$erroriAvv'),
              ]),
            ],
          ),
        ),
        if (erroriAvv > 0) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            'Tipologia errori $_nomeAvversario: ${[
              for (final m in MotivoErrore.values)
                if ((motivi[m] ?? 0) > 0) '${m.label} ${motivi[m]}',
            ].join(' · ')}',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report PDF')),
      body: PdfPreview(
        build: _buildPdf,
        // A4 orizzontale, fisso: i contenuti (campi traiettorie/formazioni,
        // tabelle larghe) sono tutti più larghi che alti.
        initialPageFormat: PdfPageFormat.a4.landscape,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName:
            'report_${widget.match.nome.replaceAll(RegExp(r'[^\w]+'), '_')}.pdf',
      ),
    );
  }
}
