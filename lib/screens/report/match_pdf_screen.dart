import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/database.dart';
import '../../logic/role_labels.dart';
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

// Formazione di partenza di un set — stesso record di
// MatchSetRepository.caricaFormazione().
typedef _FormazionePdf = ({
  Map<String, Player> assignments,
  String palleggiatoreSlot,
  Ruolo? ruoloCambiLibero,
});

// Traiettoria pronta per il painter vettoriale del PDF (coordinate
// normalizzate 0-1 già specchiate sx→dx): colore per esito, tocco a muro
// opzionale (due segmenti con snodo) e pallonetto (arco) — equivalente
// PDF di TrajData in court_trajectories_view.dart.
class _TrajPdf {
  final double x1, y1, x2, y2;
  final PdfColor colore;
  final double? muroX, muroY;
  final bool isPallonetto;
  const _TrajPdf({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.colore,
    this.muroX,
    this.muroY,
    this.isPallonetto = false,
  });
}

// Contatori di un giocatore per la mega tabella statistiche (pagina 2,
// layout dal foglio "VOLLEY STATS PDF"): una mappa voto→conteggio per
// gruppo di colonne. `attaccoSuRicezione`/`attaccoSuDifesa` sono la
// partizione binaria di `attacco` (vedi idAttacchiSuRicezione in
// database_provider.dart); `murati` gli attacchi con muro punto subito
// (vedi attaccoMurato). Usata anche per la riga TOTALI (player null).
class _StatGiocatore {
  final Player? player;
  // Solo per le statistiche AVVERSARIE (per ruolo, niente roster): codice
  // ruolo P/O/S1/S2/C1/C2. Null per i nostri giocatori e per la riga TOTALI.
  final String? ruoloAvv;
  final battuta = <Voto, int>{};
  final attacco = <Voto, int>{};
  final attaccoSuRicezione = <Voto, int>{};
  final attaccoSuDifesa = <Voto, int>{};
  final ricezione = <Voto, int>{};
  final difesa = <Voto, int>{};
  final muro = <Voto, int>{};
  int murati = 0;

  _StatGiocatore(this.player) : ruoloAvv = null;
  _StatGiocatore.avversario(this.ruoloAvv) : player = null;

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
    // Fallback: se la generazione lancia un'eccezione, invece di lasciare
    // l'anteprima vuota/bloccata si rende un PDF con messaggio + stack, così
    // l'errore è visibile e diagnosticabile (successo un fallimento
    // transitorio non riprodotto, meglio non restare al buio se ricapita).
    try {
      return await _buildPdfInterno(format);
    } catch (e, st) {
      return _buildPdfErrore(format, e, st);
    }
  }

  Future<Uint8List> _buildPdfErrore(
      PdfPageFormat format, Object errore, StackTrace st) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        build: (context) => [
          pw.Text('ERRORE generazione PDF',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('$errore', style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
          pw.Text('$st', style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
    );
    return doc.save();
  }

  Future<Uint8List> _buildPdfInterno(PdfPageFormat format) async {
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
    final formazioni = <int, _FormazionePdf>{};
    for (final set in sets) {
      final stato = await setRepo.calcolaStatoFinale(set);
      final azioni = await azioniRepo.caricaAzioni(set.id);
      azioniPerSet[set.id] = azioni;
      final formazione = await setRepo.caricaFormazione(set.id);
      if (formazione != null) formazioni[set.id] = formazione;
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
    // riferimento "VOLLEY STATS PDF") + punti/errori generici sulla
    // partita intera; poi una pagina identica per OGNI set giocato (scope
    // ridotto alle azioni di quel set, intestazione "Set N").
    // Nomi per i titoli delle pagine statistiche (nostra squadra + avversario,
    // 'Avversari' se non impostato — stessa convenzione di ScoutScreen/report).
    final nomeNostro = team?.nome ?? 'Nostra squadra';
    final avv = match.avversario?.trim();
    final nomeAvv = (avv != null && avv.isNotEmpty) ? avv : 'Avversari';
    if (stats.isNotEmpty) {
      doc.addPage(_buildPaginaStatistiche(
        format: format,
        logo: logo,
        titolo: 'Statistiche giocatori $nomeNostro — Partita intera',
        stats: stats,
        azioniGenerici: azioniPerSet.values,
        team: team,
      ));
    }
    for (final set in sets) {
      final azioniSet = azioniPerSet[set.id] ?? const <ScoutAction>[];
      final statsSet = _calcolaStatGiocatori(players, {set.id: azioniSet});
      if (statsSet.isEmpty) continue; // set senza azioni scoutate
      doc.addPage(_buildPaginaStatistiche(
        format: format,
        logo: logo,
        titolo: 'Statistiche giocatori $nomeNostro — Set ${set.numero}',
        stats: statsSet,
        azioniGenerici: [azioniSet],
        team: team,
      ));
    }
    _aggiungiPagineBattute(doc, format, logo, team, players, azioniPerSet);
    final zonaPerAzione =
        await setRepo.zonaTatticaPerAzione(sets, azioniPerSet, players);
    _aggiungiPagineAttacchi(
        doc, format, logo, team, players, azioniPerSet, zonaPerAzione);
    _aggiungiPaginaFormazioni(doc, format, logo, sets, formazioni);
    _aggiungiPaginaDistribuzione(doc, format, logo, azioniPerSet, zonaPerAzione);

    // ── In coda: statistiche AVVERSARIO per ruolo (solo se la partita ha lo
    // scout avversario) — partita intera + una pagina per set. Niente
    // specchietto generici (già sulle nostre pagine, non è per ruolo).
    final statsAvv = _calcolaStatAvversari(azioniPerSet);
    if (statsAvv.isNotEmpty) {
      doc.addPage(_buildPaginaStatistiche(
        format: format,
        logo: logo,
        titolo: 'Statistiche giocatori $nomeAvv — Partita intera',
        stats: statsAvv,
        azioniGenerici: const [],
        team: team,
        mostraGenerici: false,
      ));
      for (final set in sets) {
        final azioniSet = azioniPerSet[set.id] ?? const <ScoutAction>[];
        final statsSet = _calcolaStatAvversari({set.id: azioniSet});
        if (statsSet.isEmpty) continue;
        doc.addPage(_buildPaginaStatistiche(
          format: format,
          logo: logo,
          titolo: 'Statistiche giocatori $nomeAvv — Set ${set.numero}',
          stats: statsSet,
          azioniGenerici: const [],
          team: team,
          mostraGenerici: false,
        ));
      }
    }
    return doc.save();
  }

  // ── Pagina "Distribuzione alzate": un campo per rotazione ──────────────

  // Partita intera, un campo per ROTAZIONE P1..P6 (posizione del
  // palleggiatore al momento dell'alzata). In ogni zona due righe: % e
  // conteggio delle alzate dopo RICEZIONE e dopo DIFESA (partizione via
  // idAttacchiSuRicezione, come ovunque) — percentuali sul totale della
  // rotazione PER FASE: le sei zone di "Ric" sommano a 100 dentro la
  // rotazione, idem "Dif" (lettura K1/K2 standard, così le due
  // distribuzioni sono confrontabili anche con conteggi diversi).
  void _aggiungiPaginaDistribuzione(
    pw.Document doc,
    PdfPageFormat format,
    pw.MemoryImage logo,
    Map<int, List<ScoutAction>> azioniPerSet,
    Map<int, ({int zona, int rotazione})> zonaPerAzione,
  ) {
    final suRicezione = idAttacchiSuRicezione(azioniPerSet.values);
    // rotazione → zona → conteggio, per fase.
    final ric = <int, Map<int, int>>{};
    final dif = <int, Map<int, int>>{};
    var totale = 0;
    for (final azioni in azioniPerSet.values) {
      for (final a in azioni) {
        final info = zonaPerAzione[a.id]; // solo attacchi ricostruiti
        if (info == null) continue;
        final target = suRicezione.contains(a.id) ? ric : dif;
        final perZona = target.putIfAbsent(info.rotazione, () => {});
        perZona[info.zona] = (perZona[info.zona] ?? 0) + 1;
        totale++;
      }
    }
    if (totale == 0) return;

    const lato = 200.0;
    const gap = 24.0;
    final righe = <pw.Widget>[];
    for (var r = 1; r <= 6; r += 3) {
      righe.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var rot = r; rot < r + 3; rot++) ...[
              if (rot > r) pw.SizedBox(width: gap),
              _cellaDistribuzione(
                  rot, ric[rot] ?? const {}, dif[rot] ?? const {}, lato),
            ],
          ],
        ),
      ));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => _buildHeaderPagina(context, logo),
        build: (context) => [
          pw.Text(
            'Distribuzione alzate — partita intera',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'In ogni zona: alzate dopo ricezione (Ric) e dopo difesa (Dif) — '
            'percentuali sul totale della rotazione per ciascuna fase.',
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.SizedBox(height: 8),
          ...righe,
        ],
      ),
    );
  }

  // Campo di una rotazione: titolo "Rotazione Pn" + totali per fase,
  // campo quadrato (stesso painter delle formazioni) con una card per
  // zona — riga "Ric" e riga "Dif" con % e conteggio.
  pw.Widget _cellaDistribuzione(
      int rotazione, Map<int, int> ric, Map<int, int> dif, double lato) {
    final cw = lato / 3;
    final ch = lato / 2;
    // zona → (colonna, riga) della griglia: rete in alto, zona 1 in basso
    // a destra (stessa disposizione della pagina formazioni).
    const posizioni = {
      4: (0, 0), 3: (1, 0), 2: (2, 0),
      5: (0, 1), 6: (1, 1), 1: (2, 1),
    };
    final totRic = ric.values.fold(0, (a, b) => a + b);
    final totDif = dif.values.fold(0, (a, b) => a + b);
    // "0%" anche a fase vuota (più visibile del "—", scelta dell'utente).
    String pct(int n, int tot) => tot == 0 ? '0%' : '${(n * 100 / tot).round()}%';

    // Chip di una fase con la sua etichetta SOPRA (fuori dalla chip, così
    // dentro c'è spazio per percentuale e conteggio grandi). Ric = testo
    // bianco su nero, Dif = nero su bianco (bordata) — proposta
    // dell'utente per distinguerle a colpo d'occhio.
    pw.Widget chip(String label, int n, int tot, {required bool nero}) {
      final testo = nero ? PdfColors.white : PdfColors.black;
      return pw.Column(
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 6.5)),
          pw.SizedBox(height: 1),
          pw.Container(
            width: cw - 8,
            padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            decoration: pw.BoxDecoration(
              color: nero ? PdfColors.black : PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
              border: nero ? null : pw.Border.all(width: 0.8),
            ),
            child: pw.RichText(
              textAlign: pw.TextAlign.center,
              maxLines: 1,
              overflow: pw.TextOverflow.clip,
              text: pw.TextSpan(
                style: pw.TextStyle(fontSize: 9, color: testo),
                children: [
                  pw.TextSpan(
                    text: pct(n, tot),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      color: testo,
                    ),
                  ),
                  pw.TextSpan(text: ' ($n)'),
                ],
              ),
            ),
          ),
        ],
      );
    }

    pw.Widget cardZona(int zona) {
      final (col, riga) = posizioni[zona]!;
      final r = ric[zona] ?? 0;
      final d = dif[zona] ?? 0;
      // Due blocchi etichetta+chip impilati, centrati nella cella.
      const altezzaCard = 52.0;
      return pw.Positioned(
        left: col * cw + 4,
        top: riga * ch + (ch - altezzaCard) / 2,
        child: pw.Column(
          children: [
            chip('Ric', r, totRic, nero: true),
            pw.SizedBox(height: 3),
            chip('Dif', d, totDif, nero: false),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: lato,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Rotazione P$rotazione',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Ric $totRic · Dif $totDif',
                style: const pw.TextStyle(fontSize: 8),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        pw.SizedBox(
          width: lato,
          height: lato,
          child: pw.Stack(
            children: [
              pw.Positioned.fill(child: _campoFormazionePdf(lato)),
              for (final zona in posizioni.keys) cardZona(zona),
            ],
          ),
        ),
      ],
    );
  }

  // Pagina statistiche (mega tabella + generici) per uno scope di azioni:
  // partita intera o singolo set — cambia solo titolo e dati. Margine
  // ridotto e fissato esplicitamente: le larghezze fisse delle colonne
  // (vedi _buildMegaTabella) sono calcolate su ~800pt utili.
  pw.MultiPage _buildPaginaStatistiche({
    required PdfPageFormat format,
    required pw.MemoryImage logo,
    required String titolo,
    required List<_StatGiocatore> stats,
    required Iterable<List<ScoutAction>> azioniGenerici,
    required Team? team,
    bool mostraGenerici = true,
  }) {
    return pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.all(20),
      header: (context) => _buildHeaderPagina(context, logo),
      build: (context) => [
        pw.Text(
          titolo,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        _buildMegaTabella(stats),
        // Specchietto generici solo sulle pagine NOSTRE (non è per ruolo, e
        // sarebbe ridondante ripeterlo sulle pagine avversarie).
        if (mostraGenerici) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            'Punti ed errori generici',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          _buildGenerici(team, azioniGenerici),
        ],
      ],
    );
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

  // Come _calcolaStatGiocatori ma per la squadra AVVERSARIA, raggruppando per
  // RUOLO placeholder (`ruoloAvversario`, niente roster). Ordina per l'ordine
  // canonico dei ruoli. Conta solo le azioni `squadra == avversari`.
  static const _ordineRuoliAvv = ['P', 'O', 'S1', 'S2', 'C1', 'C2'];
  List<_StatGiocatore> _calcolaStatAvversari(
      Map<int, List<ScoutAction>> azioniPerSet) {
    final suRicezione = idAttacchiSuRicezione(azioniPerSet.values);
    final perRuolo = <String, _StatGiocatore>{};
    for (final azioni in azioniPerSet.values) {
      for (final a in azioni) {
        if (a.tipo != TipoAzione.scout || a.squadra != Squadra.avversari) {
          continue;
        }
        final ruolo = a.ruoloAvversario;
        final voto = a.voto;
        if (ruolo == null || voto == null) continue;
        final stat =
            perRuolo.putIfAbsent(ruolo, () => _StatGiocatore.avversario(ruolo));
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
            break;
        }
      }
    }
    int ordine(String r) {
      final i = _ordineRuoliAvv.indexOf(r);
      return i < 0 ? 99 : i;
    }
    return perRuolo.values.where((s) => !s.vuota).toList()
      ..sort((a, b) => ordine(a.ruoloAvv!).compareTo(ordine(b.ruoloAvv!)));
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
    // Colonne identità (# / Nome / R): per l'avversario il codice ruolo va
    // nella colonna Nome (niente numero né roster); 'TOTALI' quando player e
    // ruoloAvv sono entrambi null (riga totali).
    final identita = s.ruoloAvv != null
        ? <String>['', kAliasRuoloAvversario[s.ruoloAvv!] ?? s.ruoloAvv!, s.ruoloAvv!]
        : <String>[
            p == null ? '' : '${p.numero}',
            p == null ? 'TOTALI' : p.cognome,
            p == null ? '' : _ruoloBreve(p.ruolo),
          ];
    return [
      ...identita,
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
    // Larghezze fisse in pt per TIPO di colonna — intestazioni compatte
    // (R/ER/EF%/POS%, ++ e nome troncato) per stringere dove si può e
    // reinvestire lo spazio nel font (8pt invece di 6.5): totale ~790,
    // dentro i ~802 utili di A4 landscape col margine 20 della pagina.
    const wTot = 22.0, wPt = 22.0, wEr = 20.0, wMuri = 24.0;
    const wEff = 26.0, wPos = 27.0, wPp = 20.0;

    // Gruppi di colonne: label gruppo, colonne (header, larghezza), colore
    // (palette del foglio Google Sheets di riferimento).
    final gruppi = <(String, List<(String, double)>, PdfColor)>[
      ('GIOCATORE', const [('#', 18.0), ('Nome', 56.0), ('R', 16.0)],
          const PdfColor.fromInt(0xFFDD7E6B)),
      (
        'BATTUTA',
        const [('TOT', wTot), ('PT', wPt), ('ER', wEr), ('EF%', wEff)],
        const PdfColor.fromInt(0xFFFCE5CD)
      ),
      (
        'ATTACCO',
        const [
          ('TOT', wTot),
          ('PT', wPt),
          ('ER', wEr),
          ('MURI', wMuri),
          ('EF%', wEff),
        ],
        const PdfColor.fromInt(0xFFD9EAD3)
      ),
      (
        'ATT. SU RIC.',
        const [('TOT', wTot), ('PT', wPt), ('ER', wEr), ('EF%', wEff)],
        const PdfColor.fromInt(0xFFEBF3E8)
      ),
      (
        'ATT. SU DIF.',
        const [('TOT', wTot), ('PT', wPt), ('ER', wEr), ('EF%', wEff)],
        const PdfColor.fromInt(0xFFEBF3E8)
      ),
      (
        'RICEZIONE',
        const [
          ('TOT', wTot),
          ('++', wPp),
          ('ER', wEr),
          ('EF%', wEff),
          ('POS%', wPos),
        ],
        const PdfColor.fromInt(0xFFC9DAF8)
      ),
      (
        'DIFESA',
        const [
          ('TOT', wTot),
          ('++', wPp),
          ('ER', wEr),
          ('EF%', wEff),
          ('POS%', wPos),
        ],
        const PdfColor.fromInt(0xFF9FC5E8)
      ),
      (
        'MURO',
        const [('TOT', wTot), ('PT', wPt)],
        const PdfColor.fromInt(0xFFEAD1DC)
      ),
      (
        'PT - ERR',
        const [('PT', wPt), ('ER', wEr)],
        const PdfColor.fromInt(0xFFD5A6BD)
      ),
    ];

    // Liste piatte per la Table: header, larghezza e colore per colonna.
    final headerColonne = [for (final g in gruppi) ...[for (final c in g.$2) c.$1]];
    final larghezze = [for (final g in gruppi) ...[for (final c in g.$2) c.$2]];
    final coloriColonna = [
      for (final g in gruppi) ...List.filled(g.$2.length, g.$3),
    ];

    pw.Widget cella(String testo,
        {PdfColor? bg, bool bold = false, pw.Alignment? align, int maxLines = 1}) {
      return pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 1),
        alignment: align ?? pw.Alignment.center,
        child: pw.Text(
          testo,
          maxLines: maxLines,
          overflow: pw.TextOverflow.clip,
          style: pw.TextStyle(
            fontSize: 8,
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
            width: g.$2.fold<double>(0.0, (a, b) => a + b.$2),
            height: 14,
            color: g.$3,
            alignment: pw.Alignment.center,
            child: pw.Text(
              g.$1,
              style:
                  pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
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
                        align: i == 1 ? pw.Alignment.centerLeft : null,
                        // Colonna Nome a 2 righe: gli alias ruolo avversari
                        // ("Schiacciatore 1") non stanno in 56pt su una riga.
                        maxLines: i == 1 ? 2 : 1),
                ],
              ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: coloreTotali),
              children: [
                for (final (i, v) in _valoriRiga(totali).indexed)
                  cella(v,
                      bold: true,
                      align: i == 1 ? pw.Alignment.centerLeft : null,
                      maxLines: i == 1 ? 2 : 1),
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

  // ── Pagine "Battute <squadra>": un campo per giocatore ─────────────────

  // Colori di stampa delle traiettorie: verde ace (AppColors.success, più
  // leggibile su carta del verde brillante usato a video), nero per
  // l'"in campo" (a video è bianco, invisibile su pagina bianca), rosso
  // errore come ovunque.
  static const _kPdfAce = PdfColor.fromInt(0xFF16A34A);
  static const _kPdfErrore = PdfColors.red;
  static const _kPdfInCampo = PdfColors.black;

  void _aggiungiPagineBattute(
    pw.Document doc,
    PdfPageFormat format,
    pw.MemoryImage logo,
    Team? team,
    List<Player> players,
    Map<int, List<ScoutAction>> azioniPerSet,
  ) {
    // Tutte le battute della partita, raggruppate per giocatore.
    final perGiocatore = <int, List<ScoutAction>>{};
    for (final azioni in azioniPerSet.values) {
      for (final a in azioni) {
        if (a.tipo != TipoAzione.scout ||
            a.fondamentale != Fondamentale.battuta ||
            a.giocatoreId == null) {
          continue;
        }
        perGiocatore.putIfAbsent(a.giocatoreId!, () => []).add(a);
      }
    }
    final battitori = [
      for (final p in players)
        if (perGiocatore.containsKey(p.id)) p,
    ]..sort((a, b) => a.numero.compareTo(b.numero));
    if (battitori.isEmpty) return;

    // 3 campi per riga; ogni riga è atomica, MultiPage spezza tra le righe.
    const gap = 12.0;
    const larghezzaCella = (802 - 2 * gap) / 3;
    final righe = <pw.Widget>[];
    for (var i = 0; i < battitori.length; i += 3) {
      righe.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var j = i; j < i + 3 && j < battitori.length; j++) ...[
              if (j > i) pw.SizedBox(width: gap),
              _cellaTraiettorie(
                titolo: '${battitori[j].numero}  ${battitori[j].cognome}',
                azioni: perGiocatore[battitori[j].id]!,
                larghezza: larghezzaCella,
                labelVincente: 'Ace',
              ),
            ],
          ],
        ),
      ));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => _buildHeaderPagina(context, logo),
        build: (context) => [
          pw.Text(
            'Battute ${_nomeNostro(team)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...righe,
        ],
      ),
    );
  }

  // Pagine "Attacchi <squadra>": un campo per OGNI COPPIA giocatore +
  // posizione di attacco (zona TATTICA in cui il giocatore era schierato
  // al momento dell'azione, da _zonaTatticaPerAzione — NON la sua zona di
  // rotazione) — se un giocatore ha attaccato da P2 e da P4, i campi sono
  // due. Gli attacchi senza zona ricostruibile (formazione mancante/dato
  // incoerente) finiscono in un campo senza etichetta di posizione.
  void _aggiungiPagineAttacchi(
    pw.Document doc,
    PdfPageFormat format,
    pw.MemoryImage logo,
    Team? team,
    List<Player> players,
    Map<int, List<ScoutAction>> azioniPerSet,
    Map<int, ({int zona, int rotazione})> zonaPerAzione,
  ) {
    // (giocatoreId, zona) → attacchi; zona 0 = non ricostruibile.
    final perChiave = <(int, int), List<ScoutAction>>{};
    for (final azioni in azioniPerSet.values) {
      for (final a in azioni) {
        if (a.tipo != TipoAzione.scout ||
            a.fondamentale != Fondamentale.attacco ||
            a.giocatoreId == null) {
          continue;
        }
        final chiave = (a.giocatoreId!, zonaPerAzione[a.id]?.zona ?? 0);
        perChiave.putIfAbsent(chiave, () => []).add(a);
      }
    }
    if (perChiave.isEmpty) return;

    // Ordina per numero di maglia, poi per zona (quella ignota in coda).
    final perId = {for (final p in players) p.id: p};
    final chiavi = perChiave.keys
        .where((c) => perId.containsKey(c.$1))
        .toList()
      ..sort((a, b) {
        final numeri =
            perId[a.$1]!.numero.compareTo(perId[b.$1]!.numero);
        if (numeri != 0) return numeri;
        if (a.$2 == 0) return 1;
        if (b.$2 == 0) return -1;
        return a.$2.compareTo(b.$2);
      });

    const gap = 12.0;
    const larghezzaCella = (802 - 2 * gap) / 3;
    final righe = <pw.Widget>[];
    for (var i = 0; i < chiavi.length; i += 3) {
      righe.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 14),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var j = i; j < i + 3 && j < chiavi.length; j++) ...[
              if (j > i) pw.SizedBox(width: gap),
              _cellaTraiettorie(
                titolo: '${perId[chiavi[j].$1]!.numero}  '
                    '${perId[chiavi[j].$1]!.cognome}'
                    '${chiavi[j].$2 == 0 ? '' : ' — P${chiavi[j].$2}'}',
                azioni: perChiave[chiavi[j]]!,
                larghezza: larghezzaCella,
                labelVincente: 'Pt',
              ),
            ],
          ],
        ),
      ));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => _buildHeaderPagina(context, logo),
        build: (context) => [
          pw.Text(
            'Attacchi ${_nomeNostro(team)}',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...righe,
        ],
      ),
    );
  }

  // Cella traiettorie condivisa tra pagine battute e attacchi: titolo
  // sopra, campo B/N con le traiettorie, legenda Vincente/In/Err sotto
  // (label vincente parametrica: 'Ace' per la battuta, 'Pt' per l'attacco).
  pw.Widget _cellaTraiettorie({
    required String titolo,
    required List<ScoutAction> azioni,
    required double larghezza,
    required String labelVincente,
  }) {
    final vincenti = azioni.where((a) => a.voto == Voto.perfetto).length;
    final errori = azioni.where((a) => a.voto == Voto.errore).length;
    final inCampo = azioni.length - vincenti - errori;

    // Traiettorie disegnabili (coordinate complete), normalizzate sx→dx
    // come a video (mirror attorno al centro se partono da destra) —
    // tocco a muro specchiato insieme al resto, pallonetto dal
    // tipoEsecuzione (solo attacco).
    final trajs = <_TrajPdf>[];
    for (final a in azioni) {
      var x1 = a.traiettoriaX1;
      var y1 = a.traiettoriaY1;
      var x2 = a.traiettoriaX2;
      var y2 = a.traiettoriaY2;
      if (x1 == null || y1 == null || x2 == null || y2 == null) continue;
      var muroX = a.traiettoriaMuroX;
      var muroY = a.traiettoriaMuroY;
      if (x1 > 0.5) {
        x1 = 1.0 - x1;
        y1 = 1.0 - y1;
        x2 = 1.0 - x2;
        y2 = 1.0 - y2;
        if (muroX != null && muroY != null) {
          muroX = 1.0 - muroX;
          muroY = 1.0 - muroY;
        }
      }
      final colore = a.voto == Voto.perfetto
          ? _kPdfAce
          : (a.voto == Voto.errore ? _kPdfErrore : _kPdfInCampo);
      trajs.add(_TrajPdf(
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        colore: colore,
        muroX: muroX,
        muroY: muroY,
        isPallonetto: a.tipoEsecuzione == TipoAttacco.pallonetto.name,
      ));
    }

    pw.Widget legenda(String label, int count, PdfColor colore) =>
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 5),
          decoration: pw.BoxDecoration(
            color: colore,
            borderRadius: pw.BorderRadius.circular(2),
          ),
          child: pw.Text(
            '$label $count',
            // 8pt come le celle della mega tabella statistiche.
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.white),
          ),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          titolo,
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 3),
        _campoTraiettoriePdf(trajs, larghezza),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            legenda(labelVincente, vincenti, _kPdfAce),
            pw.SizedBox(width: 6),
            legenda('In', inCampo, PdfColors.grey600),
            pw.SizedBox(width: 6),
            legenda('Err', errori, _kPdfErrore),
          ],
        ),
      ],
    );
  }

  // Campo doppio in bianco e nero disegnato in vettoriale (niente PNG:
  // nitido a ogni zoom e senza sfondo colorato, adatto alla stampa):
  // bordo, rete al centro (più marcata), linee dei 3m a 1/3 e 2/3.
  // Il padding attorno al campo lascia spazio alle traiettorie che partono
  // fuori (il battitore sta dietro la linea di fondo, x normalizzata < 0).
  pw.Widget _campoTraiettoriePdf(List<_TrajPdf> trajs, double larghezza) {
    const pad = 14.0;
    final courtW = larghezza - 2 * pad;
    final courtH = courtW / 2;
    final altezza = courtH + 2 * pad;
    return pw.CustomPaint(
      size: PdfPoint(larghezza, altezza),
      painter: (canvas, size) {
        // Coordinate normalizzate (origine in alto a sinistra) → punti PDF
        // (origine in basso a sinistra, y verso l'alto).
        double px(double nx) => pad + nx * courtW;
        double py(double ny) => altezza - (pad + ny * courtH);

        // Campo: bordo + linee dei 3m in grigio, rete più scura e spessa.
        canvas
          ..setStrokeColor(PdfColors.grey500)
          ..setLineWidth(0.8)
          ..drawRect(px(0), py(1), courtW, courtH)
          ..moveTo(px(1 / 3), py(0))
          ..lineTo(px(1 / 3), py(1))
          ..moveTo(px(2 / 3), py(0))
          ..lineTo(px(2 / 3), py(1))
          ..strokePath()
          ..setStrokeColor(PdfColors.grey700)
          ..setLineWidth(1.4)
          ..moveTo(px(0.5), py(0))
          ..lineTo(px(0.5), py(1))
          ..strokePath();

        for (final t in trajs) {
          final x1 = px(t.x1), y1 = py(t.y1), x2 = px(t.x2), y2 = py(t.y2);
          canvas
            ..setStrokeColor(t.colore)
            ..setLineWidth(1.0);

          // Direzione della punta: dallo snodo del muro, dalla tangente
          // dell'arco (fine−controllo) o dalla retta — stessi tre casi del
          // MultiTrajectoryPainter a video.
          final double dirX, dirY;
          if (t.muroX != null && t.muroY != null) {
            // Tocco a muro: due segmenti con pallino sullo snodo.
            final mx = px(t.muroX!), my = py(t.muroY!);
            canvas
              ..moveTo(x1, y1)
              ..lineTo(mx, my)
              ..lineTo(x2, y2)
              ..strokePath()
              ..setFillColor(t.colore)
              ..drawEllipse(mx, my, 1.8, 1.8)
              ..fillPath();
            dirX = x2 - mx;
            dirY = y2 - my;
          } else if (t.isPallonetto) {
            // Pallonetto: arco — bezier quadratica col punto di controllo
            // alzato (y PDF verso l'alto), convertita in cubica per
            // curveTo (cp = estremo + 2/3·(ctrl − estremo)).
            final ctrlX = (x1 + x2) / 2;
            final ctrlY = (y1 + y2) / 2 + courtH * 0.15;
            canvas
              ..moveTo(x1, y1)
              ..curveTo(
                  x1 + 2 / 3 * (ctrlX - x1),
                  y1 + 2 / 3 * (ctrlY - y1),
                  x2 + 2 / 3 * (ctrlX - x2),
                  y2 + 2 / 3 * (ctrlY - y2),
                  x2,
                  y2)
              ..strokePath();
            dirX = x2 - ctrlX;
            dirY = y2 - ctrlY;
          } else {
            canvas
              ..moveTo(x1, y1)
              ..lineTo(x2, y2)
              ..strokePath();
            dirX = x2 - x1;
            dirY = y2 - y1;
          }

          // Punta a "V" sulla direzione calcolata.
          final angolo = math.atan2(dirY, dirX);
          const lunghezza = 4.0, apertura = 0.45;
          canvas
            ..moveTo(x2, y2)
            ..lineTo(x2 - lunghezza * math.cos(angolo - apertura),
                y2 - lunghezza * math.sin(angolo - apertura))
            ..moveTo(x2, y2)
            ..lineTo(x2 - lunghezza * math.cos(angolo + apertura),
                y2 - lunghezza * math.sin(angolo + apertura))
            ..strokePath();
          // Pallino sul punto di partenza.
          canvas
            ..setFillColor(t.colore)
            ..drawEllipse(x1, y1, 1.5, 1.5)
            ..fillPath();
        }
      },
    );
  }

  // ── Pagina "Formazioni di partenza": un campo per set ──────────────────

  // Come la sezione del report a video, ma col campo disegnato in
  // vettoriale B/N: mezzo campo con la rete IN ALTO, griglia 3×2 —
  // P4|P3|P2 in prima linea, P5|P6|P1 in seconda (P1 in basso a destra).
  void _aggiungiPaginaFormazioni(
    pw.Document doc,
    PdfPageFormat format,
    pw.MemoryImage logo,
    List<MatchSet> sets,
    Map<int, _FormazionePdf> formazioni,
  ) {
    final conFormazione = [
      for (final s in sets)
        if (formazioni.containsKey(s.id)) s,
    ];
    if (conFormazione.isEmpty) return;

    // Campo QUADRATO (mezzo campo reale 9×9): lato tale che due righe da
    // 3 campi stiano in pagina (200 + titolo/didascalia ≈ 240 a riga).
    const lato = 200.0;
    const gap = 24.0;
    final righe = <pw.Widget>[];
    for (var i = 0; i < conFormazione.length; i += 3) {
      righe.add(pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (var j = i; j < i + 3 && j < conFormazione.length; j++) ...[
              if (j > i) pw.SizedBox(width: gap),
              _cellaFormazione(
                  conFormazione[j], formazioni[conFormazione[j].id]!, lato),
            ],
          ],
        ),
      ));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(20),
        header: (context) => _buildHeaderPagina(context, logo),
        build: (context) => [
          pw.Text(
            'Formazioni di partenza',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...righe,
        ],
      ),
    );
  }

  // Cella di un set: titolo "Set N - P<slot>" (+ pallone se la battuta
  // iniziale era nostra), campo con le card dei giocatori (palleggiatore
  // bordato di rosso), didascalia libero/i sotto.
  pw.Widget _cellaFormazione(MatchSet set, _FormazionePdf f, double lato) {
    final larghezza = lato;
    final altezzaCampo = lato; // campo quadrato (mezzo campo reale 9×9)
    final cw = larghezza / 3;
    final ch = altezzaCampo / 2;
    // slot → (colonna, riga) della griglia: rete in alto.
    const posizioni = {
      'P4': (0, 0), 'P3': (1, 0), 'P2': (2, 0),
      'P5': (0, 1), 'P6': (1, 1), 'P1': (2, 1),
    };
    final liberi = [f.assignments['L1'], f.assignments['L2']]
        .whereType<Player>()
        .toList();
    final cambi = f.ruoloCambiLibero;

    pw.Widget cardGiocatore(String slot) {
      final p = f.assignments[slot];
      if (p == null) return pw.SizedBox();
      final (col, riga) = posizioni[slot]!;
      final isSetter = slot == f.palleggiatoreSlot;
      return pw.Positioned(
        left: col * cw + 4,
        top: riga * ch + 8,
        child: pw.Container(
          width: cw - 8,
          height: ch - 28,
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(
              color: isSetter ? PdfColors.red : PdfColors.grey400,
              width: isSetter ? 1.4 : 0.7,
            ),
          ),
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Cognome e nome su DUE righe: su una sola il nome spariva
              // troncato appena il cognome era lungo.
              pw.Column(
                children: [
                  pw.Text(
                    p.cognome,
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                  if (p.nome.trim().isNotEmpty)
                    pw.Text(
                      p.nome,
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                ],
              ),
              pw.Text(
                '${p.numero}',
                style:
                    pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                p.ruolo.label,
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
                style: const pw.TextStyle(fontSize: 7.5),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Larghezza esplicita: la cella vive in una Row (larghezza
        // illimitata) e uno Spacer/flex senza vincolo lancia
        // "PdfException: flex children".
        pw.SizedBox(
          width: larghezza,
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Set ${set.numero} - ${f.palleggiatoreSlot}',
                style:
                    pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              if (set.squadraServizioIniziale == Squadra.nostra)
                _iconaPallone(10),
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        pw.SizedBox(
          width: larghezza,
          height: altezzaCampo,
          child: pw.Stack(
            children: [
              pw.Positioned.fill(child: _campoFormazionePdf(lato)),
              for (final slot in posizioni.keys) cardGiocatore(slot),
            ],
          ),
        ),
        pw.SizedBox(height: 3),
        if (liberi.isNotEmpty)
          pw.Text(
            'Libero: ${liberi.map((p) => '${p.numero} ${p.cognome}').join(' · ')}'
            '${cambi != null ? ' — cambi: ${cambi.label}' : ''}',
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            style: const pw.TextStyle(fontSize: 8),
          ),
      ],
    );
  }

  // Mezzo campo B/N QUADRATO con la rete in alto: bordo grigio, rete più
  // marcata sul lato superiore, linea di metà griglia orizzontale,
  // separatori verticali tratteggiati (come la sezione formazioni a video).
  pw.Widget _campoFormazionePdf(double lato) {
    return pw.CustomPaint(
      size: PdfPoint(lato, lato),
      painter: (canvas, size) {
        // y PDF verso l'alto: la rete (bordo superiore) è a y = lato.
        canvas
          ..setStrokeColor(PdfColors.grey500)
          ..setLineWidth(0.8)
          ..drawRect(0, 0, lato, lato)
          ..moveTo(0, lato / 2)
          ..lineTo(lato, lato / 2)
          ..strokePath()
          // Separatori verticali tratteggiati tra le colonne della griglia.
          ..setLineDashPattern(<int>[3, 3])
          ..moveTo(lato / 3, 0)
          ..lineTo(lato / 3, lato)
          ..moveTo(2 * lato / 3, 0)
          ..lineTo(2 * lato / 3, lato)
          ..strokePath()
          ..setLineDashPattern()
          // Rete: bordo superiore più scuro e spesso.
          ..setStrokeColor(PdfColors.grey700)
          ..setLineWidth(2.2)
          ..moveTo(0, lato)
          ..lineTo(lato, lato)
          ..strokePath();
      },
    );
  }

  // Pallone da volley minimale (cerchio + tre "cuciture" curve) — usato
  // accanto al titolo del set quando la battuta iniziale era nostra
  // (equivalente PDF dell'icona sports_volleyball del report a video).
  pw.Widget _iconaPallone(double lato) {
    return pw.CustomPaint(
      size: PdfPoint(lato, lato),
      painter: (canvas, size) {
        final c = lato / 2;
        final r = lato / 2 - 0.6;
        canvas
          ..setStrokeColor(PdfColors.grey800)
          ..setLineWidth(0.8)
          ..drawEllipse(c, c, r, r)
          ..strokePath()
          // Cucitura orizzontale curva + due verticali dal centro.
          ..moveTo(c - r, c)
          ..curveTo(c - r / 2, c + r / 2, c + r / 2, c + r / 2, c + r, c)
          ..moveTo(c, c + r * 0.5)
          ..curveTo(c - r * 0.5, c + r * 0.1, c - r * 0.6, c - r * 0.5,
              c - r * 0.3, c - r * 0.95)
          ..moveTo(c, c + r * 0.5)
          ..curveTo(c + r * 0.5, c + r * 0.1, c + r * 0.6, c - r * 0.5,
              c + r * 0.3, c - r * 0.95)
          ..strokePath();
      },
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
        // Render ad alta risoluzione: lo zoom (doppio tap → pinch, integrato
        // in PdfPreview, fino a 5×) mostra l'immagine già rasterizzata, quindi
        // un dpi più alto la tiene nitida anche ingrandita — utile per le
        // tabelle statistiche fitte. Le pagine si rasterizzano pigramente
        // (solo quelle visibili), quindi il costo è contenuto.
        dpi: 220,
        pdfFileName:
            'report_${widget.match.nome.replaceAll(RegExp(r'[^\w]+'), '_')}.pdf',
      ),
    );
  }
}
