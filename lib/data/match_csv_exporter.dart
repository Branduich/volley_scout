import 'dart:convert' show utf8;

import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

import '../models/enums.dart';
import 'database.dart';

// Export CSV di tutte le ScoutAction di una partita (bottone "CSV" sulla
// card delle partite terminate — futura feature premium, per ora sempre
// disponibile). Colonne "parlanti": join sui nomi (giocatori, squadre,
// label degli enum), mai ID. Separatore `;` + decimali con la virgola +
// BOM UTF-8: il formato che Excel in locale italiano apre correttamente
// senza import guidato.

/// Header del CSV, esposto per i test.
const List<String> kCsvHeader = [
  'Set',
  'Ordine',
  'Rally',
  'Orario',
  'Squadra',
  'Tipo azione',
  'Numero',
  'Giocatore',
  'Ruolo',
  'Fondamentale',
  'Voto',
  'Tipo esecuzione',
  'Esito',
  'Punti casa',
  'Punti trasferta',
  'Traiettoria X1',
  'Traiettoria Y1',
  'Traiettoria X2',
  'Traiettoria Y2',
  'Muro X',
  'Muro Y',
  'Esce',
];

String _pad(int n) => n.toString().padLeft(2, '0');

// Decimali con la virgola (3 cifre): con separatore `;`, Excel italiano li
// riconosce come numeri — col punto diventerebbero testo (o peggio, date).
String _dec(double? v) => v == null ? '' : v.toStringAsFixed(3).replaceAll('.', ',');

String _nomeGiocatore(Player? giocatore) =>
    giocatore == null ? '' : '${giocatore.cognome} ${giocatore.nome}';

String _labelTipoAzione(TipoAzione tipo) => switch (tipo) {
      TipoAzione.scout => 'Scout',
      TipoAzione.puntoManuale => 'Punto manuale',
      TipoAzione.erroreGenerico => 'Errore generico',
      TipoAzione.cambioGiocatore => 'Cambio giocatore',
      TipoAzione.timeout => 'Timeout',
    };

// La colonna `tipoEsecuzione` è polimorfica (vedi CLAUDE.md): il .name che
// contiene va interpretato con l'enum giusto in base al contesto —
// TipoBattuta per le battute, TipoAttacco per gli attacchi, MotivoErrore
// per gli errori generici. `nonSpecificato`/`generico` (i default) e i
// contesti senza tipo di esecuzione → cella vuota; un nome sconosciuto
// (dati futuri) resta com'è invece di rompere l'export.
String _labelTipoEsecuzione(ScoutAction a) {
  final nome = a.tipoEsecuzione;
  if (nome == 'nonSpecificato') return '';
  if (a.tipo == TipoAzione.erroreGenerico) {
    final motivo =
        MotivoErrore.values.where((m) => m.name == nome).firstOrNull;
    if (motivo == MotivoErrore.generico) return '';
    return motivo?.label ?? nome;
  }
  return switch (a.fondamentale) {
    Fondamentale.battuta =>
      TipoBattuta.values.where((t) => t.name == nome).firstOrNull?.label ??
          nome,
    Fondamentale.attacco =>
      TipoAttacco.values.where((t) => t.name == nome).firstOrNull?.label ??
          nome,
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
  required VolleyMatch match,
  required Team? team,
  required List<MatchSet> sets,
  required Map<int, List<ScoutAction>> azioniPerSet,
  required Map<int, Player> playerById,
}) {
  final nomeNoi = team?.nome ?? 'Noi';
  final nomeLoro = match.avversario ?? 'Avversari';
  final righe = <List<String>>[List.of(kCsvHeader)];

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
        _labelTipoAzione(a.tipo),
        giocatore == null ? '' : '${giocatore.numero}',
        _nomeGiocatore(giocatore),
        giocatore?.ruolo.label ?? '',
        a.fondamentale?.label ?? '',
        a.voto?.simbolo ?? '',
        _labelTipoEsecuzione(a),
        switch (a.esitoPunto) {
          EsitoPunto.puntoNostro =>
            match.inCasa ? 'Punto casa' : 'Punto trasferta',
          EsitoPunto.puntoAvversario =>
            match.inCasa ? 'Punto trasferta' : 'Punto casa',
          EsitoPunto.nessuno => '',
        },
        '${match.inCasa ? puntiNoi : puntiLoro}',
        '${match.inCasa ? puntiLoro : puntiNoi}',
        _dec(a.traiettoriaX1),
        _dec(a.traiettoriaY1),
        _dec(a.traiettoriaX2),
        _dec(a.traiettoriaY2),
        _dec(a.traiettoriaMuroX),
        _dec(a.traiettoriaMuroY),
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
  required VolleyMatch match,
  required Team? team,
  required List<MatchSet> sets,
  required Map<int, List<ScoutAction>> azioniPerSet,
  required Map<int, Player> playerById,
}) async {
  final righe = righeCsvPartita(
    match: match,
    team: team,
    sets: sets,
    azioniPerSet: azioniPerSet,
    playerById: playerById,
  );
  final csv = const ListToCsvConverter(fieldDelimiter: ';').convert(righe);

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
