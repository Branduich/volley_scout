import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/backup_model.dart';
import 'package:volley_stats/enums.dart';
import 'package:volley_stats/filtro.dart';
import 'package:volley_stats/tiri_partita.dart';

/// L'adapter fra i dati del file e il disegno del campo. Sbagliare qui non fa
/// crashare niente: fa sparire delle frecce, o ne fa comparire di sbagliate —
/// ed è il tipo di errore che si scopre solo guardando bene un campo pieno.
void main() {
  _default();

  AzioneBackup azione(
    int ordine, {
    required Fondamentale fondamentale,
    Squadra squadra = Squadra.nostra,
    Voto voto = Voto.positivo,
    String? giocatore = 'g1',
    bool conTraiettoria = true,
    TipoAzione tipo = TipoAzione.scout,
  }) =>
      AzioneBackup(
        ordine: ordine,
        rallyId: ordine,
        secondiDaInizioPartita: ordine * 20,
        squadra: squadra,
        tipo: tipo,
        esitoPunto: EsitoPunto.nessuno,
        fondamentale: fondamentale,
        voto: voto,
        giocatoreUid: giocatore,
        traiettoriaX1: conTraiettoria ? 0.1 : null,
        traiettoriaY1: conTraiettoria ? 0.2 : null,
        traiettoriaX2: conTraiettoria ? 0.8 : null,
        traiettoriaY2: conTraiettoria ? 0.7 : null,
      );

  BackupCompleto backupCon(List<AzioneBackup> azioni, {DateTime? quando}) =>
      BackupCompleto(
        formatoVersione: kFormatoVersioneBackup,
        schemaDb: 19,
        app: 'test',
        esportatoIl: DateTime(2026, 8, 28),
        partite: [
          PartitaBackup(
            uid: 'p1',
            nome: 'p1',
            dataOra: quando ?? DateTime(2026, 10, 5),
            inCasa: true,
            stato: StatoPartita.terminata,
            setCorrente: 1,
            squadraUid: 's1',
            sets: [
              SetBackup(
                numero: 1,
                aperto: false,
                squadraServizioIniziale: Squadra.nostra,
                azioni: azioni,
              ),
            ],
          ),
        ],
      );

  test('prende solo il fondamentale chiesto', () {
    final b = backupCon([
      azione(1, fondamentale: Fondamentale.battuta),
      azione(2, fondamentale: Fondamentale.attacco),
      azione(3, fondamentale: Fondamentale.battuta),
    ]);

    expect(tiriFiltrati(b, fondamentale: Fondamentale.battuta), hasLength(2));
    expect(tiriFiltrati(b, fondamentale: Fondamentale.attacco), hasLength(1));
  });

  test('i fondamentali senza traiettoria danno lista vuota, non errore', () {
    // Un menu può contenere anche voci che non hanno coordinate: chiederle non
    // deve far saltare la schermata.
    final b = backupCon([azione(1, fondamentale: Fondamentale.ricezione)]);

    expect(tiriFiltrati(b, fondamentale: Fondamentale.ricezione), isEmpty);
    expect(tiriFiltrati(b, fondamentale: Fondamentale.difesa), isEmpty);
  });

  test('un\'azione senza coordinate non entra', () {
    // È il caso di tutte le partite importate da "Volleyball Scout": voto sì,
    // traiettoria no. Devono sparire dal campo, non disegnare una freccia
    // degenere nell'angolo.
    final b = backupCon([
      azione(1, fondamentale: Fondamentale.battuta),
      azione(2, fondamentale: Fondamentale.battuta, conTraiettoria: false),
    ]);

    expect(tiriFiltrati(b, fondamentale: Fondamentale.battuta), hasLength(1));
  });

  test('si può chiedere una giocatrice sola', () {
    final b = backupCon([
      azione(1, fondamentale: Fondamentale.attacco, giocatore: 'g1'),
      azione(2, fondamentale: Fondamentale.attacco, giocatore: 'g2'),
    ]);

    final soloG2 = tiriFiltrati(b,
        fondamentale: Fondamentale.attacco, giocatoreUid: 'g2');

    expect(soloG2, hasLength(1));
  });

  test('le azioni avversarie restano fuori finché non si chiedono', () {
    // Sono quelle che alimentano la heatmap di ricezione: utilissime, ma
    // mescolate alle nostre direbbero che attacchiamo da entrambe le parti.
    final b = backupCon([
      azione(1, fondamentale: Fondamentale.battuta),
      azione(2, fondamentale: Fondamentale.battuta, squadra: Squadra.avversari, giocatore: null),
    ]);

    expect(tiriFiltrati(b, fondamentale: Fondamentale.battuta), hasLength(1));
    expect(
      tiriFiltrati(b,
          fondamentale: Fondamentale.battuta, squadra: Squadra.avversari),
      hasLength(1),
    );
  });

  test('i punti manuali non sono tiri', () {
    final b = backupCon([
      azione(1, fondamentale: Fondamentale.battuta, tipo: TipoAzione.puntoManuale),
    ]);

    expect(tiriFiltrati(b, fondamentale: Fondamentale.battuta), isEmpty);
  });

  test('segue il filtro del periodo come il resto della dashboard', () {
    final b = backupCon(
      [azione(1, fondamentale: Fondamentale.battuta)],
      quando: DateTime(2026, 10, 5),
    );

    final fuori = tiriFiltrati(
      b,
      fondamentale: Fondamentale.battuta,
      filtro: Filtro(
        periodo: PeriodoPreset.personalizzato,
        da: DateTime(2026, 11, 1),
        a: DateTime(2026, 11, 30),
      ),
    );

    expect(fuori, isEmpty);
  });

  test('il conto sotto al campo distingue vincenti ed errori', () {
    final b = backupCon([
      azione(1, fondamentale: Fondamentale.attacco, voto: Voto.perfetto),
      azione(2, fondamentale: Fondamentale.attacco, voto: Voto.errore),
      azione(3, fondamentale: Fondamentale.attacco, voto: Voto.positivo),
    ]);

    final conta = contaTiri(tiriFiltrati(b, fondamentale: Fondamentale.attacco));

    expect(conta.totali, 3);
    expect(conta.vincenti, 1);
    expect(conta.errori, 1);
  });
}

void _default() {
  // Il default della vista traiettorie. Conta perché è la prima cosa che si
  // vede: aprire su una giocatrice senza colpi mostrerebbe un campo vuoto.
  AzioneBackup tiro(int ordine, String uid, Fondamentale f) => AzioneBackup(
        ordine: ordine,
        rallyId: ordine,
        secondiDaInizioPartita: ordine * 20,
        squadra: Squadra.nostra,
        tipo: TipoAzione.scout,
        esitoPunto: EsitoPunto.nessuno,
        fondamentale: f,
        voto: Voto.positivo,
        giocatoreUid: uid,
        traiettoriaX1: 0.1,
        traiettoriaY1: 0.2,
        traiettoriaX2: 0.8,
        traiettoriaY2: 0.7,
      );

  BackupCompleto con(List<AzioneBackup> azioni) => BackupCompleto(
        formatoVersione: kFormatoVersioneBackup,
        schemaDb: 19,
        app: 'test',
        esportatoIl: DateTime(2026, 8, 28),
        partite: [
          PartitaBackup(
            uid: 'p1',
            nome: 'p1',
            dataOra: DateTime(2026, 10, 5),
            inCasa: true,
            stato: StatoPartita.terminata,
            setCorrente: 1,
            sets: [
              SetBackup(
                numero: 1,
                aperto: false,
                squadraServizioIniziale: Squadra.nostra,
                azioni: azioni,
              ),
            ],
          ),
        ],
      );

  group('chi si apre per prima nelle traiettorie', () {
    test('quella con più colpi di QUEL fondamentale', () {
      final b = con([
        tiro(1, 'g1', Fondamentale.battuta),
        tiro(2, 'g2', Fondamentale.battuta),
        tiro(3, 'g2', Fondamentale.battuta),
        // g1 attacca molto, ma stiamo guardando le battute.
        tiro(4, 'g1', Fondamentale.attacco),
        tiro(5, 'g1', Fondamentale.attacco),
        tiro(6, 'g1', Fondamentale.attacco),
      ]);

      expect(giocatriceConPiuTiri(b, fondamentale: Fondamentale.battuta), 'g2');
      expect(giocatriceConPiuTiri(b, fondamentale: Fondamentale.attacco), 'g1');
    });

    test('senza tiri non si sceglie nessuno', () {
      expect(giocatriceConPiuTiri(con([]), fondamentale: Fondamentale.battuta),
          isNull);
    });

    test('a parità di colpi la scelta è stabile', () {
      // Un default che cambia da un'apertura all'altra è peggio di uno
      // arbitrario: sembra che i dati si muovano da soli.
      final b = con([
        tiro(1, 'g2', Fondamentale.battuta),
        tiro(2, 'g1', Fondamentale.battuta),
      ]);

      expect(giocatriceConPiuTiri(b, fondamentale: Fondamentale.battuta), 'g1');
      expect(giocatriceConPiuTiri(b, fondamentale: Fondamentale.battuta), 'g1');
    });
  });
}
