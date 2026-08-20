import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/volley_stats.dart';
import 'package:volley_web/main.dart';

/// La pagina riceve un backup già pronto e non sa da dove arriva: per questo si
/// può montare in un test senza asset, senza browser e senza database — ed è
/// la stessa proprietà che al passo 9b le permetterà di finire dentro l'app.
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

void main() {
  testWidgets('mostra nome squadra e riga KPI', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PaginaSquadra(backup: _backupDiProva()),
    ));

    expect(find.text('Nettunia'), findsOneWidget);
    expect(find.text('1 azioni in 1 partite'), findsOneWidget);
    // Le tessere della riga KPI, con le etichette in maiuscolo.
    expect(find.text('PARTITE'), findsOneWidget);
    expect(find.text('EFFICIENZA ATTACCO'), findsOneWidget);
    // Un attacco perfetto su uno: efficienza 100%, un punto.
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('il banner dei dati di esempio compare solo quando serve',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: PaginaSquadra(backup: _backupDiProva(), dimostrativo: true),
    ));

    expect(find.textContaining('Dati dimostrativi'), findsOneWidget);
  });
}
