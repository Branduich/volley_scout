import 'dart:convert' show utf8;

import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_localizations.dart';
import '../l10n/enum_l10n.dart';
import '../models/enums.dart';
import 'database.dart';

// Export CSV di tutte le ScoutAction di una partita (bottone "CSV" sulla
// card delle partite terminate — futura feature premium, per ora sempre
// disponibile). Colonne "parlanti": join sui nomi (giocatori, squadre,
// label degli enum), mai ID.
//
// Separatore di campo e decimale seguono l'impostazione `FormatoCsv`
// (Impostazioni → Export), NON la lingua dell'app: a decidere come si legge
// un CSV è il locale del computer su cui lo si apre. `europeo` (default,
// formato storico) = `;` + decimali con la virgola, quello che Excel
// italiano apre al doppio clic; `internazionale` = `,` + punto.
// Il BOM UTF-8 in testa c'è sempre: serve a far riconoscere la codifica
// (accenti nei cognomi), a prescindere dal separatore.

/// Header del CSV, esposto per i test. Funzione e non più costante: segue la
/// lingua dell'app come il resto del file (i VALORI passavano già da
/// `enum_l10n`). L'ORDINE delle colonne non cambia mai — i test indicizzano
/// per posizione, e chi si è fatto un foglio-modello si aspetta le stesse
/// colonne allo stesso posto in ogni lingua.
List<String> csvHeader(AppLocalizations l) => [
      l.csvColSet,
      l.csvColOrdine,
      l.csvColRally,
      l.csvColOrario,
      l.csvColSquadra,
      l.csvColTipoAzione,
      l.csvColNumero,
      l.csvColGiocatore,
      l.csvColRuolo,
      l.csvColFondamentale,
      l.csvColVoto,
      l.csvColTipoEsecuzione,
      l.csvColEsito,
      l.csvColPuntiCasa,
      l.csvColPuntiTrasferta,
      l.csvColTraiettoriaX1,
      l.csvColTraiettoriaY1,
      l.csvColTraiettoriaX2,
      l.csvColTraiettoriaY2,
      l.csvColMuroX,
      l.csvColMuroY,
      l.csvColEsce,
    ];

String _pad(int n) => n.toString().padLeft(2, '0');

// Decimali a 3 cifre. Col formato `europeo` la virgola: con separatore `;`,
// Excel italiano li riconosce come numeri — col punto diventerebbero testo
// (o peggio, date). Col formato `internazionale` restano col punto.
String _dec(double? v, FormatoCsv formato) {
  if (v == null) return '';
  final s = v.toStringAsFixed(3);
  return formato == FormatoCsv.europeo ? s.replaceAll('.', ',') : s;
}

String _nomeGiocatore(Player? giocatore) =>
    giocatore == null ? '' : '${giocatore.cognome} ${giocatore.nome}';

String _labelTipoAzione(TipoAzione tipo, AppLocalizations l) => switch (tipo) {
      TipoAzione.scout => l.csvTipoScout,
      TipoAzione.puntoManuale => l.csvTipoPuntoManuale,
      TipoAzione.erroreGenerico => l.csvTipoErroreGenerico,
      TipoAzione.cambioGiocatore => l.csvTipoCambioGiocatore,
      TipoAzione.timeout => l.csvTipoTimeout,
      TipoAzione.correzioneRotazione => l.csvTipoCorrezioneRotazione,
    };

// La colonna `tipoEsecuzione` è polimorfica (vedi CLAUDE.md): il .name che
// contiene va interpretato con l'enum giusto in base al contesto —
// TipoBattuta per le battute, TipoAttacco per gli attacchi, MotivoErrore
// per gli errori generici. `nonSpecificato`/`generico` (i default) e i
// contesti senza tipo di esecuzione → cella vuota; un nome sconosciuto
// (dati futuri) resta com'è invece di rompere l'export.
String _labelTipoEsecuzione(ScoutAction a, AppLocalizations l) {
  final nome = a.tipoEsecuzione;
  if (nome == 'nonSpecificato') return '';
  if (a.tipo == TipoAzione.erroreGenerico) {
    final motivo =
        MotivoErrore.values.where((m) => m.name == nome).firstOrNull;
    if (motivo == MotivoErrore.generico) return '';
    return motivo == null ? nome : motivoErroreLabel(motivo, l);
  }
  // Correzione rotazione: la colonna porta il verso (DirezioneRotazione).
  if (a.tipo == TipoAzione.correzioneRotazione) {
    return switch (
        DirezioneRotazione.values.where((d) => d.name == nome).firstOrNull) {
      DirezioneRotazione.avanti => l.csvRotazioneAvanti,
      DirezioneRotazione.indietro => l.csvRotazioneIndietro,
      null => nome,
    };
  }
  return switch (a.fondamentale) {
    Fondamentale.battuta => switch (
          TipoBattuta.values.where((t) => t.name == nome).firstOrNull) {
        final TipoBattuta t => tipoBattutaLabel(t, l),
        null => nome,
      },
    Fondamentale.attacco => switch (
          TipoAttacco.values.where((t) => t.name == nome).firstOrNull) {
        final TipoAttacco t => tipoAttaccoLabel(t, l),
        null => nome,
      },
    _ => '',
  };
}

/// Righe del CSV (header compreso), una per `ScoutAction`, set per set in
/// ordine di `numero` e azioni in ordine di `ordine`. Funzione pura (nessun
/// DB/UI), testata in `test/logic/match_csv_test.dart`.
///
/// [azioniPerSet] è indicizzata per **setId** (azioni già ordinate per
/// `ordine`, come le ritorna `ScoutActionRepository.caricaAzioni`);
/// [playerById] risolve i giocatoreId in nomi (roster completo della
/// squadra, `TeamRepository.getPlayersForTeam`).
///
/// "Punti casa"/"Punti trasferta" sono il punteggio progressivo del set
/// DOPO l'azione, derivato contando gli `esitoPunto` (stessa logica di
/// `ricalcolaStato()`); le correzioni manuali del punteggio non compaiono
/// (vivono su MatchSet, fuori dal log eventi). Punteggio ed esito usano la
/// convenzione del referto ufficiale Casa/Trasferta (intestazioni fisse
/// tra un file e l'altro, comode per fogli-modello): `match.inCasa` dice
/// da che parte sta la nostra squadra.
List<List<String>> righeCsvPartita({
  required AppLocalizations l,
  required VolleyMatch match,
  required Team? team,
  required List<MatchSet> sets,
  required Map<int, List<ScoutAction>> azioniPerSet,
  required Map<int, Player> playerById,
  FormatoCsv formato = FormatoCsv.europeo,
}) {
  final nomeNoi = team?.nome ?? l.csvNoi;
  final nomeLoro = match.avversario ?? l.scoutAvversariGenerico;
  final righe = <List<String>>[csvHeader(l)];

  final setsOrdinati = List.of(sets)
    ..sort((a, b) => a.numero.compareTo(b.numero));
  for (final set in setsOrdinati) {
    var puntiNoi = 0;
    var puntiLoro = 0;
    final azioni = List.of(azioniPerSet[set.id] ?? const <ScoutAction>[])
      ..sort((a, b) => a.ordine.compareTo(b.ordine));
    for (final a in azioni) {
      if (a.esitoPunto == EsitoPunto.puntoNostro) puntiNoi++;
      if (a.esitoPunto == EsitoPunto.puntoAvversario) puntiLoro++;
      final giocatore = a.giocatoreId == null ? null : playerById[a.giocatoreId];
      final uscente =
          a.giocatoreUscenteId == null ? null : playerById[a.giocatoreUscenteId];
      final ts = a.timestamp;
      righe.add([
        '${set.numero}',
        '${a.ordine}',
        '${a.rallyId}',
        '${_pad(ts.hour)}:${_pad(ts.minute)}:${_pad(ts.second)}',
        a.squadra == Squadra.nostra ? nomeNoi : nomeLoro,
        _labelTipoAzione(a.tipo, l),
        giocatore == null ? '' : '${giocatore.numero}',
        _nomeGiocatore(giocatore),
        giocatore == null ? '' : ruoloLabel(giocatore.ruolo, l),
        a.fondamentale == null ? '' : fondamentaleLabel(a.fondamentale!, l),
        a.voto?.simbolo ?? '',
        _labelTipoEsecuzione(a, l),
        switch (a.esitoPunto) {
          EsitoPunto.puntoNostro =>
            match.inCasa ? l.csvEsitoPuntoCasa : l.csvEsitoPuntoTrasferta,
          EsitoPunto.puntoAvversario =>
            match.inCasa ? l.csvEsitoPuntoTrasferta : l.csvEsitoPuntoCasa,
          EsitoPunto.nessuno => '',
        },
        '${match.inCasa ? puntiNoi : puntiLoro}',
        '${match.inCasa ? puntiLoro : puntiNoi}',
        _dec(a.traiettoriaX1, formato),
        _dec(a.traiettoriaY1, formato),
        _dec(a.traiettoriaX2, formato),
        _dec(a.traiettoriaY2, formato),
        _dec(a.traiettoriaMuroX, formato),
        _dec(a.traiettoriaMuroY, formato),
        _nomeGiocatore(uscente),
      ]);
    }
  }
  return righe;
}

/// Genera il CSV, lo scrive in un file temporaneo e apre lo share sheet di
/// sistema. Il file nasce solo alla condivisione (stesso principio
/// on-demand del PDF: niente file persistiti da gestire).
Future<void> condividiCsvPartita({
  required AppLocalizations l,
  required VolleyMatch match,
  required Team? team,
  required List<MatchSet> sets,
  required Map<int, List<ScoutAction>> azioniPerSet,
  required Map<int, Player> playerById,
  FormatoCsv formato = FormatoCsv.europeo,
}) async {
  final righe = righeCsvPartita(
    l: l,
    match: match,
    team: team,
    sets: sets,
    azioniPerSet: azioniPerSet,
    playerById: playerById,
    formato: formato,
  );
  // Il separatore di campo va d'accordo col decimale scelto in _dec: con la
  // virgola decimale il delimitatore DEVE essere `;`, altrimenti ogni numero
  // spaccherebbe la riga in due colonne.
  final csv = ListToCsvConverter(
    fieldDelimiter: formato == FormatoCsv.europeo ? ';' : ',',
  ).convert(righe);

  final dt = match.dataOra;
  final nomeSano = match.nome
      .replaceAll(RegExp(r'[^\w\-]+', unicode: true), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final nomeFile =
      '${nomeSano.isEmpty ? 'partita' : nomeSano}_${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}.csv';

  // BOM UTF-8 in testa: senza, Excel assume la codepage locale e storpia
  // gli accenti.
  final bytes = utf8.encode('﻿$csv');

  // XFile.fromData + fileNameOverrides: è l'UNICA combinazione in cui
  // share_plus applica davvero il nome file — con un XFile creato da path
  // l'override viene ignorato (`if (file.path.isNotEmpty) return file;` in
  // method_channel_share.dart) e il file può arrivare all'app ricevente
  // senza nome/estensione (visto con Google Sheets, che poi rifiuta
  // l'import). Così è share_plus stesso a scrivere il file temporaneo col
  // nome giusto: niente più File/path_provider qui.
  // subject = nome file COMPLETO DI ESTENSIONE, non un titolo libero:
  // "Salva su Drive" usa EXTRA_SUBJECT come titolo del documento al posto
  // del display name del file — con un subject senza ".csv" il file
  // arrivava su Drive senza estensione e Sheets rifiutava l'import (il
  // nome via fileNameOverrides era corretto, ma il subject lo scavalcava).
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(bytes, mimeType: 'text/csv')],
    fileNameOverrides: [nomeFile],
    subject: nomeFile,
  ));
}
