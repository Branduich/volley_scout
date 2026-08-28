import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/backup_json.dart';
import 'package:volley_scout/data/backup_model.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/data/demo_match_importer.dart';
import 'package:volley_scout/logic/ricalcola_stato.dart';
import 'package:volley_scout/models/enums.dart';

/// Il formato di backup non deve perdere niente: è il ponte verso la dashboard
/// stagionale e, insieme, l'unica copia di sicurezza di una stagione di scout
/// (vedi docs/dati-stagionali.md, passo 2).
///
/// La prova che conta non è "il JSON contiene N azioni", ma che **rigiocando le
/// azioni ri-parsate con `ricalcolaStato()` si riottengano i punteggi del
/// referto reale** — gli stessi cinque set di `demo_match_test.dart`. Se un
/// campo che governa il punteggio si perdesse per strada, qui si vedrebbe.
void main() {
  // Punteggi reali di Clai Imola - Nettunia (avversario, nostro), persa 2-3.
  const attesi = [(25, 16), (15, 25), (21, 25), (25, 16), (25, 23)];

  // La stagione di esempio ha cinque partite, ma di UNA sola conosciamo il
  // referto: quella del 30 aprile, l'unica scoutata dal vivo. È quindi
  // l'unica su cui si può pretendere che il replay dia i punteggi giusti.
  PartitaBackup laGara(BackupCompleto b) => b.partite
      .firstWhere((p) => p.dataOra.month == 4 && p.dataOra.day == 30);

  late AppDatabase db;
  late String demoJson;

  setUpAll(() {
    demoJson = File('packages/volley_stats/assets/backup_demo.json').readAsStringSync();
  });

  setUp(() async {
    db = AppDatabase.perTest(NativeDatabase.memory());
    await DemoMatchImporter(db).importaDaJson(demoJson);
  });

  tearDown(() async => db.close());

  /// Legge tutte le tabelle e costruisce il backup, come farà
  /// `BackupRepository.esportaTutto()` al passo 3.
  Future<BackupCompleto> esporta() async => costruisciBackup(
        RigheBackup(
          categorie: await db.select(db.categorie).get(),
          squadre: await db.select(db.teams).get(),
          giocatori: await db.select(db.players).get(),
          partite: await db.select(db.volleyMatches).get(),
          sets: await db.select(db.matchSets).get(),
          rotazioni: await db.select(db.rotations).get(),
          azioni: await db.select(db.scoutActions).get(),
          campionati: await db.select(db.campionati).get(),
          gare: await db.select(db.gare).get(),
        ),
        app: '1.0.0+11',
        schemaDb: db.schemaVersion,
      );

  /// Il giro completo: DB -> DTO -> testo JSON -> DTO.
  Future<BackupCompleto> giroCompleto() async =>
      leggiBackupDaStringa(codificaBackup(await esporta()));

  group('round-trip', () {
    test('conteggi identici dopo esportazione e rilettura', () async {
      final prima = await esporta();
      final dopo = await giroCompleto();

      expect(dopo.squadre.length, prima.squadre.length);
      expect(dopo.giocatori.length, prima.giocatori.length);
      expect(dopo.partite.length, prima.partite.length);

      final setPrima = prima.partite.expand((p) => p.sets).toList();
      final setDopo = dopo.partite.expand((p) => p.sets).toList();
      expect(setDopo.length, setPrima.length);
      // La stagione di esempio: 5 partite, 18 set. Il numero esatto conta
      // poco, ma un crollo direbbe che si sta girando su un file quasi vuoto,
      // e tutto il round-trip passerebbe senza provare niente.
      expect(setDopo.length, 18);

      final azioniPrima = setPrima.expand((s) => s.azioni).length;
      final azioniDopo = setDopo.expand((s) => s.azioni).length;
      expect(azioniDopo, azioniPrima);
      // La demo ha ~460 azioni: se questo numero crollasse, il resto dei test
      // potrebbe passare su un file quasi vuoto.
      expect(azioniDopo, greaterThan(400));
    });

    test('replay delle azioni ri-parsate: punteggi del referto', () async {
      final backup = await giroCompleto();
      final partita = laGara(backup);

      for (final set in partita.sets) {
        final rotazione = {
          for (final r in set.rotazioni)
            // Nel replay conta solo l'identità del giocatore, non il suo id
            // numerico: l'uid come chiave va benissimo, mappato su un intero
            // stabile per la firma di ricalcolaStato().
            r.posizione: r.giocatoreUid.hashCode,
        };
        final azioni = [
          for (final a in set.azioni)
            AzioneScout(ordine: a.ordine, esitoPunto: a.esitoPunto),
        ];

        final stato = ricalcolaStato(
          azioni: azioni,
          servizioIniziale: set.squadraServizioIniziale,
          rotazioneIniziale: rotazione,
        );

        final (avversario, nostro) = attesi[set.numero - 1];
        expect((stato.punteggioAvversario, stato.punteggioNostro),
            (avversario, nostro),
            reason: 'set ${set.numero}: punteggio diverso dal referto');
      }
    });

    test('i riferimenti fra righe restano validi (uid, non id)', () async {
      final backup = await giroCompleto();
      final uidSquadre = backup.squadre.map((s) => s.uid).toSet();
      final uidGiocatori = backup.giocatori.map((g) => g.uid).toSet();

      for (final g in backup.giocatori) {
        expect(uidSquadre, contains(g.squadraUid));
      }
      for (final p in backup.partite) {
        if (p.squadraUid != null) expect(uidSquadre, contains(p.squadraUid));
        for (final s in p.sets) {
          // Solo 5 set su 18 hanno la formazione di partenza: le altre
          // partite vengono da un export che non la registra. Dove c'è,
          // dev'essere completa.
          if (s.rotazioni.isNotEmpty) expect(s.rotazioni, hasLength(6));
          for (final r in s.rotazioni) {
            expect(uidGiocatori, contains(r.giocatoreUid));
          }
          if (s.liberoUid != null) {
            expect(uidGiocatori, contains(s.liberoUid));
          }
          for (final a in s.azioni) {
            if (a.giocatoreUid != null) {
              expect(uidGiocatori, contains(a.giocatoreUid));
            }
          }
        }
      }
    });

    test('voti, fondamentali e traiettorie sopravvivono al giro', () async {
      final backup = await giroCompleto();
      final azioni = backup.partite
          .expand((p) => p.sets)
          .expand((s) => s.azioni)
          .where((a) => a.tipo == TipoAzione.scout)
          .toList();

      expect(azioni, isNotEmpty);
      // Ogni azione di scout della demo ha giocatore, fondamentale e voto.
      for (final a in azioni) {
        expect(a.giocatoreUid, isNotNull);
        expect(a.fondamentale, isNotNull);
        expect(a.voto, isNotNull);
      }
      // Battute e attacchi portano la traiettoria (sintetica nella demo).
      final conTraiettoria = azioni.where((a) =>
          a.fondamentale == Fondamentale.battuta ||
          a.fondamentale == Fondamentale.attacco);
      expect(conTraiettoria, isNotEmpty);
      for (final a in conTraiettoria) {
        expect(a.traiettoriaX1, isNotNull);
        expect(a.traiettoriaX2, isNotNull);
      }
      // Tutti e cinque i voti compaiono almeno una volta: se il converter
      // perdesse un valore, il conteggio scenderebbe senza rompere nulla.
      expect(azioni.map((a) => a.voto).toSet().length, Voto.values.length);
    });

    test('i tempi sono ancorati alla prima azione, non alla data di '
        'calendario', () async {
      final backup = await giroCompleto();
      final partita = laGara(backup);
      final azioni = partita.sets.expand((s) => s.azioni).toList();

      // L'ancora c'è ed è un istante reale di gioco.
      expect(partita.inizioAzioni, isNotNull);
      // Il primo tocco della partita è lo zero: è ciò che rende il file
      // leggibile a occhio. Prima l'ancora era `dataOra` (data di calendario),
      // e una partita programmata settimane dopo lo scout dava `t` negativi.
      expect(azioni.first.secondiDaInizioPartita, 0);
      expect(azioni.map((a) => a.secondiDaInizioPartita),
          everyElement(greaterThanOrEqualTo(0)));
      // Cresce nel corso della partita: è ciò che permette di calcolare la
      // durata di un set per differenza.
      expect(azioni.last.secondiDaInizioPartita,
          greaterThan(azioni.first.secondiDaInizioPartita));
    });

    test('dall\'ancora si ricostruisce l\'orario assoluto di ogni azione',
        () async {
      // È la garanzia che il delta non perde informazione: `inizioAzioni + t`
      // deve riportare al timestamp originale a DB (al secondo).
      final backup = await giroCompleto();
      final partita = laGara(backup);
      // Le righe di QUELLA partita: il database ne contiene cinque, e la
      // più vecchia in assoluto appartiene a un'altra gara.
      final riga = await (db.select(db.volleyMatches)
            ..where((m) => m.uid.equals(partita.uid)))
          .getSingle();
      final suoiSet = await (db.select(db.matchSets)
            ..where((s) => s.matchId.equals(riga.id)))
          .get();
      final idSet = suoiSet.map((s) => s.id).toSet();
      final sue = (await db.select(db.scoutActions).get())
          .where((a) => idSet.contains(a.setId))
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // L'ancora È il timestamp della prima azione, non la data di
      // calendario della partita.
      expect(partita.inizioAzioni!.difference(sue.first.timestamp).inSeconds,
          0);

      // E il delta più grande riporta esattamente all'ultima azione: è
      // questo che dimostra che `t` non perde informazione lungo il giro
      // database -> file -> database.
      final ultimoDelta = partita.sets
          .expand((s) => s.azioni)
          .map((a) => a.secondiDaInizioPartita)
          .reduce((a, b) => a > b ? a : b);
      expect(
        partita.inizioAzioni!.add(Duration(seconds: ultimoDelta)),
        sue.last.timestamp,
      );
    });

    test('le coordinate sono troncate a 4 decimali', () async {
      final json = codificaBackup(await esporta());
      // Nessun numero con più di 4 cifre decimali in tutto il file: è la
      // scelta che tiene il peso sotto controllo (~40-50 KB per partita).
      // La regex guarda solo i numeri in posizione di VALORE JSON (dopo `:`,
      // `,` o `[`, quindi non fra apici): senza questo, catturava i decimali
      // dentro le date ISO, che sono stringhe e non pesano allo stesso modo.
      final troppePrecise = RegExp(r'[:,\[]\s*-?\d+\.\d{5,}');
      final trovato = troppePrecise.firstMatch(json)?.group(0);
      expect(trovato, isNull,
          reason: 'numero con più di 4 decimali: $trovato');
    });
  });

  group('guardie in lettura', () {
    test('un file gzip viene rifiutato con un messaggio chiaro', () {
      final gzip = Uint8List.fromList([0x1f, 0x8b, 0x08, 0x00]);
      expect(
        () => leggiBackupDaByte(gzip),
        throwsA(isA<BackupFormatException>().having(
            (e) => e.messaggio, 'messaggio', contains('compresso'))),
      );
    });

    test('uno zip/xlsx viene riconosciuto come tale', () {
      final zip = Uint8List.fromList([0x50, 0x4b, 0x03, 0x04]);
      expect(
        () => leggiBackupDaByte(zip),
        throwsA(isA<BackupFormatException>()
            .having((e) => e.messaggio, 'messaggio', contains('zip'))),
      );
    });

    test('un file vuoto viene rifiutato', () {
      expect(() => leggiBackupDaByte(Uint8List(0)),
          throwsA(isA<BackupFormatException>()));
    });

    test('un JSON che non è un nostro backup viene rifiutato', () {
      expect(
        () => leggiBackupDaStringa('{"pippo": 1}'),
        throwsA(isA<BackupFormatException>().having((e) => e.messaggio,
            'messaggio', contains('non è un backup'))),
      );
    });

    test('una versione futura del formato viene rifiutata, non letta a metà',
        () async {
      final json =
          jsonDecode(codificaBackup(await esporta())) as Map<String, Object?>;
      json['formatoVersione'] = kFormatoVersioneBackup + 1;

      expect(
        () => leggiBackupDaStringa(jsonEncode(json)),
        throwsA(isA<BackupFormatException>().having((e) => e.messaggio,
            'messaggio', contains('versione più recente'))),
      );
    });

    test('un campo nuovo e sconosciuto NON fa cadere la lettura', () async {
      // Regola di versionamento: i campi aggiuntivi sono additivi e chi legge
      // ignora quelli che non conosce, senza alzare la versione del formato.
      final json =
          jsonDecode(codificaBackup(await esporta())) as Map<String, Object?>;
      json['campoDelFuturo'] = {'qualcosa': 42};
      (json['squadre'] as List).cast<Map<String, Object?>>().first['extra'] =
          'ignorami';

      final backup = leggiBackupDaStringa(jsonEncode(json));
      expect(backup.squadre, isNotEmpty);
      expect(backup.partite, hasLength(5));
    });

    test('un BOM UTF-8 in testa non impedisce la lettura', () async {
      final testo = '\u{FEFF}${codificaBackup(await esporta())}';
      final byte = Uint8List.fromList(utf8.encode(testo));
      expect(leggiBackupDaByte(byte).partite, hasLength(5));
    });
  });
}
