import 'package:flutter_test/flutter_test.dart';
import 'package:volley_stats/backup_model.dart';
import 'package:volley_stats/enums.dart';
import 'package:volley_stats/filtro.dart';

/// La selezione delle partite è tutta qui dentro, e le funzioni di aggregazione
/// non guardano più date né flag casa/trasferta: per questo basta testare
/// questa funzione per sapere cosa finisce nei numeri della dashboard.
PartitaBackup _partita(
  String uid, {
  required DateTime data,
  bool inCasa = true,
  int sets = 3,
  String squadra = 's1',
}) =>
    PartitaBackup(
      uid: uid,
      nome: uid,
      dataOra: data,
      inCasa: inCasa,
      stato: StatoPartita.terminata,
      setCorrente: sets,
      squadraUid: squadra,
      sets: [
        for (var n = 1; n <= sets; n++)
          SetBackup(
            numero: n,
            aperto: false,
            squadraServizioIniziale: Squadra.nostra,
          ),
      ],
    );

BackupCompleto _backup(List<PartitaBackup> partite) => BackupCompleto(
      formatoVersione: kFormatoVersioneBackup,
      schemaDb: 19,
      app: 'test',
      esportatoIl: DateTime(2026, 8, 21),
      partite: partite,
    );

List<String> _uid(List<PartitaSelezionata> selezione) =>
    [for (final s in selezione) s.partita.uid];

void main() {
  // Dieci partite, una a settimana, alternate casa/trasferta.
  final stagione = _backup([
    for (var i = 0; i < 10; i++)
      _partita('p$i',
          data: DateTime(2026, 10, 4).add(Duration(days: 7 * i)),
          inCasa: i.isEven),
  ]);

  test('senza filtro escono tutte, in ordine cronologico', () {
    final r = partiteFiltrate(stagione, const Filtro());

    expect(_uid(r), [for (var i = 0; i < 10; i++) 'p$i']);
  });

  test('l\'ordine è cronologico anche se il file non lo è', () {
    final disordinato = _backup([
      _partita('tardi', data: DateTime(2026, 12, 1)),
      _partita('presto', data: DateTime(2026, 10, 1)),
    ]);

    expect(_uid(partiteFiltrate(disordinato, const Filtro())),
        ['presto', 'tardi']);
  });

  group('periodo', () {
    test('andata e ritorno dividono per NUMERO di partite', () {
      // Non per data: il calendario ha soste e recuperi, e dividere sul
      // calendario darebbe due metà sbilanciate.
      expect(
        _uid(partiteFiltrate(
            stagione, const Filtro(periodo: PeriodoPreset.andata))),
        ['p0', 'p1', 'p2', 'p3', 'p4'],
      );
      expect(
        _uid(partiteFiltrate(
            stagione, const Filtro(periodo: PeriodoPreset.ritorno))),
        ['p5', 'p6', 'p7', 'p8', 'p9'],
      );
    });

    test('con un numero dispari l\'andata prende quella in più', () {
      final cinque = _backup([
        for (var i = 0; i < 5; i++)
          _partita('p$i', data: DateTime(2026, 10, 4).add(Duration(days: i))),
      ]);

      expect(
          _uid(partiteFiltrate(
                  cinque, const Filtro(periodo: PeriodoPreset.andata)))
              .length,
          3);
      expect(
          _uid(partiteFiltrate(
                  cinque, const Filtro(periodo: PeriodoPreset.ritorno)))
              .length,
          2);
    });

    test('ultime cinque: le più recenti, e con meno di cinque le prende tutte',
        () {
      expect(
        _uid(partiteFiltrate(
            stagione, const Filtro(periodo: PeriodoPreset.ultimeCinque))),
        ['p5', 'p6', 'p7', 'p8', 'p9'],
      );

      final tre = _backup([
        for (var i = 0; i < 3; i++)
          _partita('p$i', data: DateTime(2026, 10, 4).add(Duration(days: i))),
      ]);
      expect(
          _uid(partiteFiltrate(
                  tre, const Filtro(periodo: PeriodoPreset.ultimeCinque)))
              .length,
          3);
    });

    test('ultimo mese è ancorato all\'ULTIMA partita, non a oggi', () {
      // Un backup di una stagione finita mostrerebbe altrimenti una schermata
      // vuota, che sembra un difetto dell'app invece che l'effetto del filtro.
      final r = partiteFiltrate(
          stagione, const Filtro(periodo: PeriodoPreset.ultimoMese));

      // Ultima partita: p9. Trenta giorni prima ⇒ restano p5..p9 (7 giorni
      // l'una dall'altra).
      expect(_uid(r), ['p5', 'p6', 'p7', 'p8', 'p9']);
    });

    test('periodo personalizzato: estremi inclusivi', () {
      final r = partiteFiltrate(
        stagione,
        Filtro(
          periodo: PeriodoPreset.personalizzato,
          da: DateTime(2026, 10, 11),
          a: DateTime(2026, 10, 25),
        ),
      );

      expect(_uid(r), ['p1', 'p2', 'p3']);
    });
  });

  test('campo: casa e trasferta', () {
    expect(
      _uid(partiteFiltrate(stagione, const Filtro(campo: CampoPartita.casa))),
      ['p0', 'p2', 'p4', 'p6', 'p8'],
    );
    expect(
      _uid(partiteFiltrate(
          stagione, const Filtro(campo: CampoPartita.trasferta))),
      ['p1', 'p3', 'p5', 'p7', 'p9'],
    );
  });

  test('il filtro sul set restringe i SET, non le partite', () {
    final r = partiteFiltrate(stagione, const Filtro(set: 2));

    // Le partite restano tutte: quello che si riduce è cosa si guarda dentro.
    expect(r, hasLength(10));
    for (final s in r) {
      expect(s.sets, hasLength(1));
      expect(s.sets.single.numero, 2);
    }
  });

  test('un set che non esiste lascia la partita senza set', () {
    // Non è un errore: una partita finita 3-0 non ha il quarto set, e la
    // dashboard deve mostrare zero azioni invece di inventarsele.
    final r = partiteFiltrate(stagione, const Filtro(set: 5));

    expect(r, hasLength(10));
    expect(r.every((s) => s.sets.isEmpty), isTrue);
  });

  test('i filtri si combinano', () {
    final r = partiteFiltrate(
      stagione,
      const Filtro(
        periodo: PeriodoPreset.ritorno,
        campo: CampoPartita.casa,
        set: 1,
      ),
    );

    expect(_uid(r), ['p6', 'p8']);
    expect(r.every((s) => s.sets.single.numero == 1), isTrue);
  });

  test('la squadra filtra prima di tutto il resto', () {
    final due = _backup([
      _partita('a', data: DateTime(2026, 10, 4), squadra: 's1'),
      _partita('b', data: DateTime(2026, 10, 5), squadra: 's2'),
    ]);

    expect(_uid(partiteFiltrate(due, const Filtro(squadraUid: 's2'))), ['b']);
  });

  test('`attivo` distingue "sto guardando tutto" da "ho filtrato"', () {
    // Serve alla UI per mostrare un "azzera filtri" solo quando ha senso.
    expect(const Filtro().attivo, isFalse);
    expect(const Filtro(squadraUid: 's1').attivo, isFalse); // non è un filtro
    expect(const Filtro(set: 3).attivo, isTrue);
    expect(const Filtro(campo: CampoPartita.casa).attivo, isTrue);
  });
}
