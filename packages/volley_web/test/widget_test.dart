import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/volley_stats.dart';
import 'package:volley_web/pagina_squadra.dart';

/// La pagina riceve un backup già pronto e non sa da dove arriva: per questo si
/// può montare in un test senza asset, senza browser e senza database — ed è
/// la stessa proprietà che al passo 9b le permetterà di finire dentro l'app.
/// Il guscio (`main.dart`) resta fuori da questi test proprio perché importa i
/// plugin del browser, che sulla VM non esistono.
BackupCompleto _backupDiProva() => BackupCompleto(
      formatoVersione: kFormatoVersioneBackup,
      schemaDb: 19,
      app: 'test',
      esportatoIl: DateTime(2026, 8, 20),
      squadre: const [
        SquadraBackup(
          uid: 's1',
          nome: 'Nettunia',
          categoria: 'Under 18',
          coloreDivisa: 0xFF1E3A8A,
        ),
      ],
      partite: [
        PartitaBackup(
          uid: 'p1',
          nome: 'Amichevole',
          dataOra: DateTime(2026, 9, 28),
          inCasa: true,
          stato: StatoPartita.terminata,
          setCorrente: 1,
          squadraUid: 's1',
          sets: const [
            SetBackup(
              numero: 1,
              aperto: false,
              squadraServizioIniziale: Squadra.nostra,
              azioni: [
                AzioneBackup(
                  ordine: 1,
                  rallyId: 1,
                  secondiDaInizioPartita: 0,
                  squadra: Squadra.nostra,
                  tipo: TipoAzione.scout,
                  esitoPunto: EsitoPunto.puntoNostro,
                  fondamentale: Fondamentale.attacco,
                  voto: Voto.perfetto,
                ),
              ],
            ),
          ],
        ),
      ],
    );

/// La dashboard vive su uno schermo da scrivania: montarla nei 800×600 di
/// default farebbe fallire per un ingombro che nella realtà non si presenta.
Future<void> _monta(WidgetTester tester, Widget schermata) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: schermata));
}

void main() {
  testWidgets('mostra nome squadra e riga KPI', (tester) async {
    await _monta(tester, PaginaSquadra(backup: _backupDiProva()));

    expect(find.text('Nettunia'), findsOneWidget);
    // Accordo al singolare: è il caso più comune della vetrina.
    expect(find.text('1 azione in 1 partita'), findsOneWidget);
    // Le tessere della riga KPI, con le etichette in maiuscolo.
    expect(find.text('PARTITE'), findsOneWidget);
    expect(find.text('EFFICIENZA ATTACCO'), findsOneWidget);
    // Un attacco perfetto su uno: efficienza 100%, un punto.
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('coi dati di esempio invita a caricare il proprio backup',
      (tester) async {
    await _monta(
      tester,
      PaginaSquadra(backup: _backupDiProva(), onApriFile: () {}),
    );

    expect(find.textContaining('partita di esempio'), findsOneWidget);
    // La promessa sulla privacy sta nel momento in cui si carica il file.
    expect(find.textContaining('non vengono inviati a noi'), findsOneWidget);
    expect(find.text('Apri un backup'), findsOneWidget);
    // Non si torna a dove si è già.
    expect(find.text('Torna ai dati di esempio'), findsNothing);
  });

  testWidgets('con un file caricato mostra il nome e come rimuoverlo',
      (tester) async {
    await _monta(
      tester,
      PaginaSquadra(
        backup: _backupDiProva(),
        nomeFile: 'nettunia_2026.json',
        salvatoLocalmente: true,
        onApriFile: () {},
        onRimuoviDati: () {},
      ),
    );

    expect(find.text('nettunia_2026.json'), findsOneWidget);
    expect(find.textContaining('lo ritrovi anche alla prossima visita'),
        findsOneWidget);
    expect(find.text('Rimuovi i miei dati'), findsOneWidget);
    expect(find.textContaining('partita di esempio'), findsNothing);
  });

  testWidgets('senza memoria del browser non promette che i dati restino',
      (tester) async {
    // Navigazione in incognito o archiviazione disattivata: la pagina funziona
    // lo stesso, ma dire "lo ritrovi alla prossima visita" sarebbe una bugia
    // che si scopre solo ricaricando.
    await _monta(
      tester,
      PaginaSquadra(
        backup: _backupDiProva(),
        nomeFile: 'nettunia_2026.json',
        onApriFile: () {},
        onRimuoviDati: () {},
      ),
    );

    expect(find.textContaining('lo ritrovi anche alla prossima visita'),
        findsNothing);
    expect(find.textContaining('bisognerà ricaricare il file'), findsOneWidget);
  });

  testWidgets('il bottone consegna la richiesta al guscio', (tester) async {
    var richieste = 0;
    await _monta(
      tester,
      PaginaSquadra(backup: _backupDiProva(), onApriFile: () => richieste++),
    );

    await tester.tap(find.text('Apri un backup'));
    expect(richieste, 1);
  });

  testWidgets('cambiando backup i filtri ripartono da zero', (tester) async {
    // Un filtro scelto sul documento di prima non descrive più niente sul
    // nuovo, e lascerebbe la pagina vuota: sembrerebbe un file letto male
    // invece che un filtro rimasto appeso. Succede davvero, perché il backup
    // si riesporta ogni settimana con lo stesso nome — stessa chiave, quindi
    // la pagina non si rimonta e tocca a `didUpdateWidget`.
    await _monta(tester,
        PaginaSquadra(backup: _backupDiProva(), nomeFile: 'stagione.json'));

    // La partita di prova è in casa: chiedendo le trasferte non resta niente.
    await tester.tap(find.text('Casa e trasferta'));
    await tester.pumpAndSettle();
    // Il testo compare sia nel bottone sia nel menu aperto.
    await tester.tap(find.text('Solo in trasferta').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Nessuna partita'), findsOneWidget);

    // Stesso nome file, contenuto nuovo: il filtro deve essere caduto.
    await tester.pumpWidget(MaterialApp(
      home: PaginaSquadra(backup: _backupDiProva(), nomeFile: 'stagione.json'),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nessuna partita'), findsNothing);
    expect(find.text('1 azione in 1 partita'), findsOneWidget);
  });
}
