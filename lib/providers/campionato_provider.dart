import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../logic/fipav_calendario.dart';
import '../models/enums.dart';
import 'database_provider.dart';

/// Riepilogo di un import, per dire all'utente cosa è successo invece di
/// mostrare solo "fatto".
class EsitoImport {
  const EsitoImport({
    required this.campionatoId,
    required this.nuove,
    required this.aggiornate,
    required this.scartate,
  });

  final int campionatoId;
  final int nuove;
  final int aggiornate;
  final int scartate;
}

/// Accesso alle tabelle `Campionati`/`Gare` (calendario importato dal file
/// FIPAV). Come tutti gli altri repository, è l'unico punto in cui la UI tocca
/// il DB (vedi convenzione n.1 in CLAUDE.md).
class CampionatoRepository {
  CampionatoRepository(this._db);
  final AppDatabase _db;

  Stream<List<Campionato>> watchCampionati() {
    return (_db.select(_db.campionati)
          ..orderBy([(c) => OrderingTerm.desc(c.dataImport)]))
        .watch();
  }

  Stream<List<GaraCampionato>> watchGare(int campionatoId) {
    return (_db.select(_db.gare)
          ..where((g) => g.campionatoId.equals(campionatoId))
          ..orderBy([(g) => OrderingTerm.asc(g.dataOra)]))
        .watch();
  }

  Future<Campionato?> caricaCampionato(int id) {
    return (_db.select(_db.campionati)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Il nome del campionato che verrebbe usato importando questo file (la
  /// colonna "Campionato", identica su tutte le righe).
  String nomeCampionatoDi(EsitoParsingFipav parsing) => parsing.gare
      .map((g) => g.campionato)
      .firstWhere((n) => n.trim().isNotEmpty, orElse: () => 'Campionato');

  /// I campionati già presenti con questo nome. La UI ci costruisce la domanda
  /// "aggiorno quello esistente o ne creo uno nuovo?" — lista vuota al primo
  /// import di un girone, quindi nessuna domanda da fare.
  ///
  /// La decisione NON si prende qui: due import dello stesso nome possono
  /// essere il ri-download settimanale (aggiorna) oppure la stagione nuova
  /// (crea), e solo l'utente lo sa.
  Future<List<Campionato>> campionatiConNome(String nome) {
    return (_db.select(_db.campionati)..where((c) => c.nome.equals(nome)))
        .get();
  }

  Future<int> contaGare(int campionatoId) async {
    final righe = await (_db.select(_db.gare)
          ..where((g) => g.campionatoId.equals(campionatoId)))
        .get();
    return righe.length;
  }

  /// Importa le gare di un file FIPAV.
  ///
  /// Con [campionatoEsistenteId] valorizzato si **aggiorna** quel campionato:
  /// le gare già presenti vengono riscritte (risultati e parziali appena
  /// giocati) invece di essere duplicate, e il collegamento a una partita già
  /// creata (`matchId`) **non si perde**. È il caso d'uso normale: si riscarica
  /// il file ogni settimana per aggiornare la classifica.
  ///
  /// Con `null` si crea un campionato nuovo, anche se ne esiste già uno con lo
  /// stesso nome — è così che convivono due stagioni dello stesso girone.
  ///
  /// Chiave di identità di una gara: `garaNumero` se presente (è il numero
  /// federale, stabile), altrimenti la terna data+squadre.
  Future<EsitoImport> importa(
    EsitoParsingFipav parsing, {
    int? campionatoEsistenteId,
  }) async {
    final gare = parsing.gare;
    if (gare.isEmpty) {
      throw const FormatException(
        'Il file non contiene gare importabili.',
      );
    }

    final nomeCampionato = nomeCampionatoDi(parsing);
    final stagione = stagioneDaGare(gare);

    return _db.transaction(() async {
      var campionato = campionatoEsistenteId == null
          ? null
          : await (_db.select(_db.campionati)
                ..where((c) => c.id.equals(campionatoEsistenteId)))
              .getSingleOrNull();

      if (campionato == null) {
        final id = await _db.into(_db.campionati).insert(
              CampionatiCompanion.insert(
                nome: nomeCampionato,
                stagione: Value(stagione),
                dataImport: DateTime.now(),
              ),
            );
        campionato = await (_db.select(_db.campionati)
              ..where((c) => c.id.equals(id)))
            .getSingle();
      } else {
        await (_db.update(_db.campionati)
              ..where((c) => c.id.equals(campionato!.id)))
            .write(CampionatiCompanion(
          dataImport: Value(DateTime.now()),
          // La stagione si aggiorna solo se mancava (campionati importati
          // prima della v18): riscriverla cambierebbe l'etichetta sotto i
          // piedi all'utente a ogni ri-import.
          stagione: campionato.stagione == null
              ? Value(stagione)
              : const Value.absent(),
        ));
      }

      final esistenti = await (_db.select(_db.gare)
            ..where((g) => g.campionatoId.equals(campionato!.id)))
          .get();
      final perChiave = {for (final g in esistenti) _chiaveRiga(g): g};

      var nuove = 0;
      var aggiornate = 0;

      for (final g in gare) {
        final chiave = _chiaveGara(g);
        final esistente = perChiave[chiave];
        final companion = GareCompanion(
          campionatoId: Value(campionato.id),
          garaNumero: Value(g.garaNumero),
          giornata: Value(g.giornata),
          dataOra: Value(g.dataOra),
          squadraCasa: Value(g.squadraCasa),
          squadraOspite: Value(g.squadraOspite),
          risultato: Value(g.risultato),
          parziali: Value(g.parziali),
          statoDescrizione: Value(g.statoDescrizione),
          impianto: Value(g.impianto),
          indirizzoImpianto: Value(g.indirizzoImpianto),
        );

        if (esistente == null) {
          await _db.into(_db.gare).insert(companion);
          nuove++;
        } else {
          // matchId volutamente NON toccato: il collegamento alla partita già
          // creata deve sopravvivere al ri-import.
          await (_db.update(_db.gare)..where((r) => r.id.equals(esistente.id)))
              .write(companion);
          aggiornate++;
        }
      }

      return EsitoImport(
        campionatoId: campionato.id,
        nuove: nuove,
        aggiornate: aggiornate,
        scartate: parsing.righeScartate,
      );
    });
  }

  String _chiaveGara(GaraFipav g) => g.garaNumero != null
      ? 'n${g.garaNumero}'
      : '${g.dataOra.toIso8601String()}|${g.squadraCasa}|${g.squadraOspite}';

  String _chiaveRiga(GaraCampionato g) => g.garaNumero != null
      ? 'n${g.garaNumero}'
      : '${g.dataOra.toIso8601String()}|${g.squadraCasa}|${g.squadraOspite}';

  /// Registra qual è la propria squadra nel campionato (nome com'è scritto nel
  /// file) e l'eventuale squadra locale abbinata. Senza questo dato non si può
  /// decidere `inCasa` creando una partita.
  Future<void> impostaSquadraPropria(
    int campionatoId,
    String? nomeSquadra,
    int? teamId,
  ) {
    return (_db.update(_db.campionati)
          ..where((c) => c.id.equals(campionatoId)))
        .write(
      CampionatiCompanion(
        squadraPropria: Value(nomeSquadra),
        teamId: Value(teamId),
      ),
    );
  }

  Future<int> eliminaCampionato(int id) {
    // Le gare vanno via in cascata (FK onDelete: cascade).
    return (_db.delete(_db.campionati)..where((c) => c.id.equals(id))).go();
  }

  /// Crea la partita in "Gestione partite" a partire da una gara di
  /// calendario, e la collega alla gara (`matchId`) così la lista non ne
  /// propone più la creazione. Ritorna l'id della partita creata.
  Future<int> creaPartitaDaGara(
    GaraCampionato gara,
    Campionato campionato,
  ) async {
    return _db.transaction(() async {
      final matchId = await _db.into(_db.volleyMatches).insert(
            VolleyMatchesCompanion.insert(
              nome: nomePartitaDaGara(gara),
              dataOra: gara.dataOra,
              inCasa: gara.squadraCasa == campionato.squadraPropria,
              palestra: Value(_palestra(gara)),
              avversario: Value(avversarioDiGara(gara, campionato)),
              teamId: Value(campionato.teamId),
              stato: StatoPartita.configurazione,
              setCorrente: 1,
            ),
          );
      await (_db.update(_db.gare)..where((g) => g.id.equals(gara.id)))
          .write(GareCompanion(matchId: Value(matchId)));
      return matchId;
    });
  }

  String? _palestra(GaraCampionato gara) {
    final impianto = gara.impianto?.trim();
    final indirizzo = gara.indirizzoImpianto?.trim();
    if (impianto == null || impianto.isEmpty) {
      return (indirizzo == null || indirizzo.isEmpty) ? null : indirizzo;
    }
    if (indirizzo == null || indirizzo.isEmpty) return impianto;
    return '$impianto, $indirizzo';
  }
}

/// L'avversario di una gara dal punto di vista della propria squadra. Se la
/// squadra propria non è impostata (o la gara non la riguarda) si ripiega
/// sull'ospite, che è la scelta più probabile.
String avversarioDiGara(GaraCampionato gara, Campionato campionato) {
  final propria = campionato.squadraPropria;
  if (propria != null && gara.squadraOspite == propria) return gara.squadraCasa;
  return gara.squadraOspite;
}

/// Nome della partita creata da una gara di calendario, nel formato chiesto:
/// `Gara N 386 G. 1 MASI VOLLEY PINK B - NETTUNIA` (casa sempre prima).
/// I pezzi `Gara N`/`G.` si omettono se il file non li riporta.
///
/// `VolleyMatches.nome` è limitato a 100 caratteri: se i nomi squadra sono
/// lunghi si troncano, invece di far fallire l'insert.
String nomePartitaDaGara(GaraCampionato gara) {
  final prefisso = [
    if (gara.garaNumero != null) 'Gara N ${gara.garaNumero}',
    if (gara.giornata != null) 'G. ${gara.giornata}',
  ].join(' ');
  final scontro = '${gara.squadraCasa} - ${gara.squadraOspite}';
  final completo = prefisso.isEmpty ? scontro : '$prefisso $scontro';
  return completo.length <= 100 ? completo : completo.substring(0, 100);
}

final campionatoRepositoryProvider = Provider<CampionatoRepository>((ref) {
  return CampionatoRepository(ref.watch(appDatabaseProvider));
});

final campionatiStreamProvider = StreamProvider<List<Campionato>>((ref) {
  return ref.watch(campionatoRepositoryProvider).watchCampionati();
});

final gareStreamProvider =
    StreamProvider.family<List<GaraCampionato>, int>((ref, campionatoId) {
  return ref.watch(campionatoRepositoryProvider).watchGare(campionatoId);
});
