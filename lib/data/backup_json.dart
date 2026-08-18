// Ponte fra le righe drift e i DTO puri di `backup_model.dart`, più la lettura
// difensiva di un file scelto dall'utente.
//
// Questo file **resta nell'app**: è l'unico punto che conosce sia drift sia il
// formato. Il modello e il suo JSON stanno in `backup_model.dart`, che al passo
// 5 del piano si sposta in `packages/volley_stats` senza toccare nulla.
//
// Nota rispetto al piano (docs/dati-stagionali.md): `toJson`/`fromJson` sono
// nel modello e non qui, perché sono codice puro e devono viaggiare col
// modello; qui restano la conversione da drift e le guardie sul file.
import 'dart:convert';
import 'dart:typed_data';

import 'database.dart';
import 'backup_model.dart';

/// Tutte le righe di un backup, come vengono dal database. Raggrupparle in un
/// oggetto evita una funzione con dodici parametri posizionali e rende
/// esplicito, a chi legge, che la conversione **non interroga il database**:
/// riceve righe e restituisce DTO, quindi è testabile senza DB.
class RigheBackup {
  const RigheBackup({
    required this.categorie,
    required this.squadre,
    required this.giocatori,
    required this.partite,
    required this.sets,
    required this.rotazioni,
    required this.azioni,
    required this.campionati,
    required this.gare,
  });

  final List<CategorieData> categorie;
  final List<Team> squadre;
  final List<Player> giocatori;
  final List<VolleyMatch> partite;
  final List<MatchSet> sets;
  final List<Rotation> rotazioni;
  final List<ScoutAction> azioni;
  final List<Campionato> campionati;
  final List<GaraCampionato> gare;
}

/// Costruisce il backup dalle righe. `app` è la versione dell'applicazione
/// (`package_info_plus` lato UI) e `schemaDb` la versione dello schema drift:
/// servono solo a diagnosticare un file, non a leggerlo.
BackupCompleto costruisciBackup(
  RigheBackup righe, {
  required String app,
  required int schemaDb,
  DateTime? esportatoIl,
}) {
  // Gli `id` autoincrement non finiscono nel file: si traducono negli uid, che
  // sono l'unica identità valida fuori da questo dispositivo.
  final uidGiocatore = {for (final g in righe.giocatori) g.id: g.uid};
  final uidSquadra = {for (final s in righe.squadre) s.id: s.uid};
  final uidPartita = {for (final p in righe.partite) p.id: p.uid};

  final setsPerPartita = <int, List<MatchSet>>{};
  for (final s in righe.sets) {
    (setsPerPartita[s.matchId] ??= []).add(s);
  }
  final rotazioniPerSet = <int, List<Rotation>>{};
  for (final r in righe.rotazioni) {
    (rotazioniPerSet[r.setId] ??= []).add(r);
  }
  final azioniPerSet = <int, List<ScoutAction>>{};
  for (final a in righe.azioni) {
    (azioniPerSet[a.setId] ??= []).add(a);
  }
  final garePerCampionato = <int, List<GaraCampionato>>{};
  for (final g in righe.gare) {
    (garePerCampionato[g.campionatoId] ??= []).add(g);
  }

  // Ordinamento una volta sola, qui: le liste dentro le mappe sono modificabili
  // (`sort` su una `const []` sarebbe un errore in attesa di succedere) e
  // l'ordine è parte del formato — le azioni di un set vanno lette per
  // `ordine`, che è ciò che rende il replay ripetibile.
  for (final l in setsPerPartita.values) {
    l.sort((a, b) => a.numero.compareTo(b.numero));
  }
  for (final l in azioniPerSet.values) {
    l.sort((a, b) => a.ordine.compareTo(b.ordine));
  }
  for (final l in rotazioniPerSet.values) {
    l.sort((a, b) => a.posizione.compareTo(b.posizione));
  }

  // Ancora dei tempi: la PRIMA azione di ciascuna partita. Si prende il minimo
  // dei timestamp e non "la prima per ordine", perché l'ordine è per set e
  // basta un orologio spostato o un set ripreso il giorno dopo perché le due
  // cose non coincidano; il minimo resta comunque l'istante da cui contare.
  final inizioAzioniPerPartita = <int, DateTime>{};
  for (final s in righe.sets) {
    for (final a in azioniPerSet[s.id] ?? const <ScoutAction>[]) {
      final corrente = inizioAzioniPerPartita[s.matchId];
      if (corrente == null || a.timestamp.isBefore(corrente)) {
        inizioAzioniPerPartita[s.matchId] = a.timestamp;
      }
    }
  }

  return BackupCompleto(
    formatoVersione: kFormatoVersioneBackup,
    schemaDb: schemaDb,
    app: app,
    esportatoIl: esportatoIl ?? DateTime.now(),
    categorie: [
      for (final c in righe.categorie)
        CategoriaBackup(nome: c.nome, ordine: c.ordine),
    ],
    squadre: [
      for (final s in righe.squadre)
        SquadraBackup(
          uid: s.uid,
          nome: s.nome,
          categoria: s.categoria,
          coloreDivisa: s.coloreDivisa,
        ),
    ],
    giocatori: [
      for (final g in righe.giocatori)
        if (uidSquadra[g.teamId] != null)
          GiocatoreBackup(
            uid: g.uid,
            squadraUid: uidSquadra[g.teamId]!,
            nome: g.nome,
            cognome: g.cognome,
            numero: g.numero,
            ruolo: g.ruolo,
            scadenzaCertificato: g.scadenzaCertificato,
          ),
    ],
    partite: [
      for (final p in righe.partite)
        PartitaBackup(
          uid: p.uid,
          nome: p.nome,
          dataOra: p.dataOra,
          inCasa: p.inCasa,
          stato: p.stato,
          setCorrente: p.setCorrente,
          palestra: p.palestra,
          avversario: p.avversario,
          squadraUid: p.teamId == null ? null : uidSquadra[p.teamId],
          lat: p.lat,
          lon: p.lon,
          inizioAzioni: inizioAzioniPerPartita[p.id],
          sets: [
            for (final s in setsPerPartita[p.id] ?? const <MatchSet>[])
              SetBackup(
                numero: s.numero,
                aperto: s.aperto,
                squadraServizioIniziale: s.squadraServizioIniziale,
                liberoUid:
                    s.liberoId == null ? null : uidGiocatore[s.liberoId],
                libero2Uid:
                    s.libero2Id == null ? null : uidGiocatore[s.libero2Id],
                ruoloCambiLibero: s.ruoloCambiLibero,
                correzionePuntiNostri: s.correzionePuntiNostri,
                correzionePuntiAvversari: s.correzionePuntiAvversari,
                palleggiatoreAvversarioSlot: s.palleggiatoreAvversarioSlot,
                sistemaGioco: s.sistemaGioco,
                rotazioni: [
                  for (final r in rotazioniPerSet[s.id] ?? const <Rotation>[])
                    if (uidGiocatore[r.giocatoreId] != null)
                      RotazioneBackup(
                        squadra: r.squadra,
                        posizione: r.posizione,
                        giocatoreUid: uidGiocatore[r.giocatoreId]!,
                      ),
                ],
                azioni: [
                  for (final a in azioniPerSet[s.id] ?? const <ScoutAction>[])
                    _azione(
                      a,
                      inizioAzioniPerPartita[p.id] ?? a.timestamp,
                      uidGiocatore,
                    ),
                ],
              ),
          ],
        ),
    ],
    campionati: [
      for (final c in righe.campionati)
        CampionatoBackup(
          nome: c.nome,
          dataImport: c.dataImport,
          stagione: c.stagione,
          squadraPropria: c.squadraPropria,
          squadraUid: c.teamId == null ? null : uidSquadra[c.teamId],
          gare: [
            for (final g
                in garePerCampionato[c.id] ?? const <GaraCampionato>[])
              GaraBackup(
                dataOra: g.dataOra,
                squadraCasa: g.squadraCasa,
                squadraOspite: g.squadraOspite,
                garaNumero: g.garaNumero,
                giornata: g.giornata,
                risultato: g.risultato,
                parziali: g.parziali,
                statoDescrizione: g.statoDescrizione,
                impianto: g.impianto,
                indirizzoImpianto: g.indirizzoImpianto,
                partitaUid:
                    g.matchId == null ? null : uidPartita[g.matchId],
              ),
          ],
        ),
    ],
  );
}

AzioneBackup _azione(
  ScoutAction a,
  DateTime inizioAzioni,
  Map<int, String> uidGiocatore,
) {
  // Il timestamp diventa un delta in secondi dalla PRIMA azione della partita:
  // le durate si ricavano per differenza (vedi `_durataSet` nel report) e il
  // file non porta dietro il fuso orario di chi ha scoutato. L'ancora non è
  // `VolleyMatch.dataOra`, che è la data di calendario: una partita creata dal
  // calendario FIPAV per il 31 agosto e scoutata il 17 produceva `t` negativi
  // di trenta giorni — corretti, ma illeggibili per chiunque aprisse il file.
  final secondi = a.timestamp.difference(inizioAzioni).inSeconds;
  return AzioneBackup(
    ordine: a.ordine,
    rallyId: a.rallyId,
    secondiDaInizioPartita: secondi,
    squadra: a.squadra,
    tipo: a.tipo,
    esitoPunto: a.esitoPunto,
    tipoEsecuzione: a.tipoEsecuzione,
    giocatoreUid:
        a.giocatoreId == null ? null : uidGiocatore[a.giocatoreId],
    fondamentale: a.fondamentale,
    voto: a.voto,
    traiettoriaX1: a.traiettoriaX1,
    traiettoriaY1: a.traiettoriaY1,
    traiettoriaX2: a.traiettoriaX2,
    traiettoriaY2: a.traiettoriaY2,
    traiettoriaMuroX: a.traiettoriaMuroX,
    traiettoriaMuroY: a.traiettoriaMuroY,
    puntiCasaAlMomento: a.puntiCasaAlMomento,
    puntiOspitiAlMomento: a.puntiOspitiAlMomento,
    giocatoreUscenteUid: a.giocatoreUscenteId == null
        ? null
        : uidGiocatore[a.giocatoreUscenteId],
    nuovoPalleggiatoreUid: a.nuovoPalleggiatoreId == null
        ? null
        : uidGiocatore[a.nuovoPalleggiatoreId],
    nuovoRuoloCambiLibero: a.nuovoRuoloCambiLibero,
    gruppoCambio: a.gruppoCambio,
    ruoloAvversario: a.ruoloAvversario,
  );
}

/// JSON compatto, senza indentazione: un backup non si legge a mano, e
/// l'indentazione su ~15.000 azioni costa più del contenuto. (La partita demo
/// pesa 109 KB per 456 azioni proprio perché è indentata e scrive i double per
/// intero.)
String codificaBackup(BackupCompleto backup) => jsonEncode(backup.toJson());

/// Legge un backup dai byte di un file scelto dall'utente. Ogni caso di
/// fallimento ha un messaggio che dice **cosa** è stato aperto, perché è un
/// file che l'utente ha pescato a mano da Download e può facilmente essere
/// quello sbagliato.
BackupCompleto leggiBackupDaByte(Uint8List byte) {
  if (byte.isEmpty) {
    throw const BackupFormatException('Il file è vuoto.');
  }
  // Guardia gzip: la v1 non comprime, ma se un domani lo farà (o se l'utente
  // apre un .json.gz), meglio dirlo che mostrare "carattere inatteso".
  if (byte.length >= 2 && byte[0] == 0x1f && byte[1] == 0x8b) {
    throw const BackupFormatException(
        'Il file è compresso (gzip): decomprimilo e riprova.');
  }
  // Un .zip/.xlsx scambiato per backup: capita, l'import del calendario usa
  // proprio quei formati.
  if (byte.length >= 2 && byte[0] == 0x50 && byte[1] == 0x4b) {
    throw const BackupFormatException(
        'Questo è un archivio zip (o un file Excel), non un backup.');
  }

  final String testo;
  try {
    // I nomi contengono accenti: il BOM UTF-8, se presente, va scartato prima
    // di jsonDecode, che altrimenti inciampa sul primo carattere.
    testo = utf8.decode(byte, allowMalformed: false).replaceFirst('﻿', '');
  } on FormatException {
    throw const BackupFormatException(
        'Il file non è un testo leggibile: probabilmente non è un backup.');
  }
  return leggiBackupDaStringa(testo);
}

BackupCompleto leggiBackupDaStringa(String testo) {
  final Object? decodificato;
  try {
    decodificato = jsonDecode(testo);
  } on FormatException catch (e) {
    throw BackupFormatException('Il file non è un JSON valido: ${e.message}');
  }
  if (decodificato is! Map<String, Object?>) {
    throw const BackupFormatException(
        'Il contenuto del file non ha la forma di un backup.');
  }
  return BackupCompleto.fromJson(decodificato);
}
