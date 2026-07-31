import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/data/xls_reader.dart';
import 'package:volley_scout/logic/fipav_calendario.dart';
import 'package:volley_scout/providers/campionato_provider.dart';

/// Database in memoria: il repository si testa senza toccare il device.
AppDatabase _dbInMemoria() =>
    AppDatabase.perTest(NativeDatabase.memory());

EsitoParsingFipav _fixture() =>
    parseGareFipav(leggiXls(File('docs/samples/GareNettunia.xls').readAsBytesSync()));

void main() {
  late AppDatabase db;
  late CampionatoRepository repo;

  setUp(() {
    db = _dbInMemoria();
    repo = CampionatoRepository(db);
  });

  tearDown(() async => db.close());

  group('importa', () {
    test('crea campionato e gare al primo import', () async {
      final esito = await repo.importa(_fixture());

      expect(esito.nuove, 12);
      expect(esito.aggiornate, 0);
      expect(esito.scartate, 0);

      final gare = await repo.watchGare(esito.campionatoId).first;
      expect(gare.length, 12);
      expect(gare.first.squadraCasa, 'MASI VOLLEY PINK B');
      expect(gare.first.garaNumero, 386);
    });

    test('ri-importando lo stesso file non duplica nulla', () async {
      final primo = await repo.importa(_fixture());
      final secondo = await repo.importa(_fixture());

      expect(secondo.campionatoId, primo.campionatoId);
      expect(secondo.nuove, 0);
      expect(secondo.aggiornate, 12);

      final campionati = await repo.watchCampionati().first;
      expect(campionati.length, 1);
      final gare = await repo.watchGare(primo.campionatoId).first;
      expect(gare.length, 12);
    });

    test('il ri-import aggiorna il risultato senza perdere il matchId',
        () async {
      final esito = await repo.importa(_fixture());
      await repo.impostaSquadraPropria(esito.campionatoId, 'NETTUNIA', null);
      final campionato = (await repo.caricaCampionato(esito.campionatoId))!;

      final gare = await repo.watchGare(esito.campionatoId).first;
      final gara = gare.firstWhere((g) => g.garaNumero == 386);
      final matchId = await repo.creaPartitaDaGara(gara, campionato);

      // Nel frattempo la federazione pubblica un risultato diverso.
      final aggiornato = EsitoParsingFipav(
        righeScartate: 0,
        gare: [
          for (final g in _fixture().gare)
            if (g.garaNumero == 386)
              GaraFipav(
                campionato: g.campionato,
                dataOra: g.dataOra,
                squadraCasa: g.squadraCasa,
                squadraOspite: g.squadraOspite,
                garaNumero: g.garaNumero,
                giornata: g.giornata,
                risultato: '3-2',
                parziali: '26-24 25-15 20-25 20-25 15-13',
              )
            else
              g,
        ],
      );
      await repo.importa(aggiornato);

      final dopo = (await repo.watchGare(esito.campionatoId).first)
          .firstWhere((g) => g.garaNumero == 386);
      expect(dopo.risultato, '3-2');
      expect(dopo.matchId, matchId, reason: 'il collegamento non va perso');
    });

    test('un file senza gare viene rifiutato', () async {
      expect(
        () => repo.importa(
          const EsitoParsingFipav(gare: [], righeScartate: 0),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('creaPartitaDaGara', () {
    Future<(GaraCampionato, Campionato)> preparato(String squadraPropria) async {
      final esito = await repo.importa(_fixture());
      await repo.impostaSquadraPropria(
          esito.campionatoId, squadraPropria, null);
      final campionato = (await repo.caricaCampionato(esito.campionatoId))!;
      final gare = await repo.watchGare(esito.campionatoId).first;
      return (gare.firstWhere((g) => g.garaNumero == 386), campionato);
    }

    test('gara in trasferta: inCasa false e avversario = squadra di casa',
        () async {
      final (gara, campionato) = await preparato('NETTUNIA');
      final id = await repo.creaPartitaDaGara(gara, campionato);

      final partita = await (db.select(db.volleyMatches)
            ..where((m) => m.id.equals(id)))
          .getSingle();

      expect(partita.nome, 'Gara N 386 G. 1 MASI VOLLEY PINK B - NETTUNIA');
      expect(partita.inCasa, isFalse);
      expect(partita.avversario, 'MASI VOLLEY PINK B');
      expect(partita.dataOra, DateTime(2025, 10, 12, 11, 0));
      expect(
        partita.palestra,
        'Sc.Galilei 1 - CASALECCHIO DI RENO (BO), Via Porrettana 97',
      );
      expect(partita.stato.name, 'configurazione');
      expect(partita.setCorrente, 1);
    });

    test('gara in casa: inCasa true e avversario = squadra ospite', () async {
      final (gara, campionato) = await preparato('MASI VOLLEY PINK B');
      final id = await repo.creaPartitaDaGara(gara, campionato);

      final partita = await (db.select(db.volleyMatches)
            ..where((m) => m.id.equals(id)))
          .getSingle();

      expect(partita.inCasa, isTrue);
      expect(partita.avversario, 'NETTUNIA');
    });

    test('la gara resta collegata alla partita creata', () async {
      final (gara, campionato) = await preparato('NETTUNIA');
      final id = await repo.creaPartitaDaGara(gara, campionato);

      final dopo = await (db.select(db.gare)..where((g) => g.id.equals(gara.id)))
          .getSingle();
      expect(dopo.matchId, id);
    });
  });

  group('nomePartitaDaGara', () {
    GaraCampionato gara({
      int? numero,
      int? giornata,
      String casa = 'ALFA',
      String ospite = 'BETA',
    }) =>
        GaraCampionato(
          id: 1,
          campionatoId: 1,
          garaNumero: numero,
          giornata: giornata,
          dataOra: DateTime(2026),
          squadraCasa: casa,
          squadraOspite: ospite,
        );

    test('formato completo', () {
      expect(
        nomePartitaDaGara(gara(numero: 386, giornata: 1)),
        'Gara N 386 G. 1 ALFA - BETA',
      );
    });

    test('senza numero gara né giornata resta solo lo scontro', () {
      expect(nomePartitaDaGara(gara()), 'ALFA - BETA');
    });

    test('solo la giornata', () {
      expect(nomePartitaDaGara(gara(giornata: 4)), 'G. 4 ALFA - BETA');
    });

    test('nomi lunghissimi vengono troncati a 100 caratteri', () {
      final nome = nomePartitaDaGara(
        gara(numero: 1, giornata: 1, casa: 'A' * 80, ospite: 'B' * 80),
      );

      expect(nome.length, 100);
    });
  });
}
