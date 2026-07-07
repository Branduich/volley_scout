import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../data/database.dart';
import '../../providers/database_provider.dart';

// Punteggio finale di un set per la tabella del PDF — stesso calcolo di
// MatchReportScreen._carica (eventi + correzione manuale + durata).
typedef _RigaSetPdf = ({
  int numero,
  int nostro,
  int avversario,
  Duration? durata,
});

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
    for (final set in sets) {
      final stato = await setRepo.calcolaStatoFinale(set);
      final azioni = await azioniRepo.caricaAzioni(set.id);
      righeSet.add((
        numero: set.numero,
        nostro: stato.punteggioNostro + set.correzionePuntiNostri,
        avversario: stato.punteggioAvversario + set.correzionePuntiAvversari,
        durata: _durataSet(azioni),
      ));
    }

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
