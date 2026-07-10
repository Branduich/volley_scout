import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/data/match_csv_exporter.dart';
import 'package:volley_scout/models/enums.dart';

// Test della funzione pura righeCsvPartita() — nessun DB: le data class di
// drift si costruiscono direttamente.

VolleyMatch _match({String? avversario, bool inCasa = true}) => VolleyMatch(
      id: 1,
      nome: 'Partita test',
      dataOra: DateTime(2026, 7, 10, 18, 30),
      inCasa: inCasa,
      palestra: null,
      avversario: avversario,
      teamId: 10,
      lat: null,
      lon: null,
      stato: StatoPartita.terminata,
      setCorrente: 1,
    );

Team _team() => Team(
      id: 10,
      nome: 'Nettunia',
      categoria: Categoria.terzaDivisione,
      coloreDivisa: 0xFF0000FF,
    );

Player _player(int id, int numero, String cognome, Ruolo ruolo) => Player(
      id: id,
      teamId: 10,
      nome: 'Nome$numero',
      cognome: cognome,
      numero: numero,
      ruolo: ruolo,
      scadenzaCertificato: null,
    );

MatchSet _set(int id, int numero) => MatchSet(
      id: id,
      matchId: 1,
      numero: numero,
      aperto: false,
      squadraServizioIniziale: Squadra.nostra,
      liberoId: null,
      libero2Id: null,
      ruoloCambiLibero: null,
      correzionePuntiNostri: 0,
      correzionePuntiAvversari: 0,
    );

ScoutAction _azione({
  required int id,
  required int setId,
  required int ordine,
  int? rallyId,
  Squadra squadra = Squadra.nostra,
  TipoAzione tipo = TipoAzione.scout,
  int? giocatoreId,
  Fondamentale? fondamentale,
  Voto? voto,
  String tipoEsecuzione = 'nonSpecificato',
  EsitoPunto esitoPunto = EsitoPunto.nessuno,
  double? x1,
  double? y1,
  double? x2,
  double? y2,
  int? giocatoreUscenteId,
}) =>
    ScoutAction(
      id: id,
      setId: setId,
      rallyId: rallyId ?? ordine,
      ordine: ordine,
      timestamp: DateTime(2026, 7, 10, 18, 45, ordine),
      squadra: squadra,
      tipo: tipo,
      giocatoreId: giocatoreId,
      fondamentale: fondamentale,
      voto: voto,
      tipoEsecuzione: tipoEsecuzione,
      esitoPunto: esitoPunto,
      traiettoriaX1: x1,
      traiettoriaY1: y1,
      traiettoriaX2: x2,
      traiettoriaY2: y2,
      traiettoriaMuroX: null,
      traiettoriaMuroY: null,
      puntiCasaAlMomento: null,
      puntiOspitiAlMomento: null,
      giocatoreUscenteId: giocatoreUscenteId,
      nuovoPalleggiatoreId: null,
      nuovoRuoloCambiLibero: null,
      gruppoCambio: null,
    );

void main() {
  final players = {
    1: _player(1, 7, 'Rossi', Ruolo.schiacciatore),
    2: _player(2, 12, 'Bianchi', Ruolo.centrale),
  };

  group('righeCsvPartita', () {
    test('prima riga = header', () {
      final righe = righeCsvPartita(
        match: _match(),
        team: _team(),
        sets: const [],
        azioniPerSet: const {},
        playerById: const {},
      );
      expect(righe, [kCsvHeader]);
    });

    test('riga scout: nomi, voto, tipo esecuzione e traiettoria risolti', () {
      final righe = righeCsvPartita(
        match: _match(avversario: 'Clai'),
        team: _team(),
        sets: [_set(100, 1)],
        azioniPerSet: {
          100: [
            _azione(
              id: 1,
              setId: 100,
              ordine: 1,
              giocatoreId: 1,
              fondamentale: Fondamentale.battuta,
              voto: Voto.perfetto,
              tipoEsecuzione: 'saltoFloat',
              esitoPunto: EsitoPunto.puntoNostro,
              x1: 0.1,
              y1: 0.25,
              x2: 0.8,
              y2: 0.5,
            ),
          ],
        },
        playerById: players,
      );
      expect(righe.length, 2);
      final r = righe[1];
      expect(r[0], '1'); // set
      expect(r[3], '18:45:01'); // orario
      expect(r[4], 'Nettunia'); // squadra col nome reale
      expect(r[5], 'Scout');
      expect(r[6], '7');
      expect(r[7], 'Rossi Nome7');
      expect(r[8], 'Schiacciatore');
      expect(r[9], 'Battuta');
      expect(r[10], '#');
      expect(r[11], 'Salto float');
      expect(r[12], 'Punto casa'); // inCasa: noi = casa
      expect(r[13], '1'); // punti casa progressivi
      expect(r[14], '0');
      expect(r[15], '0,100'); // decimali con la virgola
      expect(r[18], '0,500');
      expect(r[21], ''); // nessun uscente
    });

    test('punteggio progressivo per set e azioni ordinate per ordine', () {
      final righe = righeCsvPartita(
        match: _match(),
        team: _team(),
        sets: [_set(101, 2), _set(100, 1)], // set fuori ordine
        azioniPerSet: {
          100: [
            // fuori ordine: la 2 prima della 1
            _azione(
                id: 2,
                setId: 100,
                ordine: 2,
                tipo: TipoAzione.puntoManuale,
                esitoPunto: EsitoPunto.puntoNostro),
            _azione(
                id: 1,
                setId: 100,
                ordine: 1,
                tipo: TipoAzione.erroreGenerico,
                squadra: Squadra.avversari,
                esitoPunto: EsitoPunto.puntoNostro),
          ],
          101: [
            _azione(
                id: 3,
                setId: 101,
                ordine: 1,
                tipo: TipoAzione.puntoManuale,
                squadra: Squadra.avversari,
                esitoPunto: EsitoPunto.puntoAvversario),
          ],
        },
        playerById: players,
      );
      // header + 2 (set 1) + 1 (set 2), set in ordine di numero
      expect(righe.length, 4);
      expect(righe[1][0], '1');
      expect(righe[1][1], '1'); // ordine 1 prima di ordine 2
      expect(righe[1][13], '1');
      expect(righe[2][13], '2'); // progressivo
      // il set 2 riparte da zero
      expect(righe[3][0], '2');
      expect(righe[3][13], '0');
      expect(righe[3][14], '1');
    });

    test('in trasferta: punteggio ed esito si specchiano su Casa/Trasferta',
        () {
      final righe = righeCsvPartita(
        match: _match(inCasa: false),
        team: _team(),
        sets: [_set(100, 1)],
        azioniPerSet: {
          100: [
            _azione(
                id: 1,
                setId: 100,
                ordine: 1,
                tipo: TipoAzione.puntoManuale,
                esitoPunto: EsitoPunto.puntoNostro),
          ],
        },
        playerById: players,
      );
      final r = righe[1];
      expect(r[12], 'Punto trasferta'); // punto nostro, ma siamo trasferta
      expect(r[13], '0'); // punti casa (avversari)
      expect(r[14], '1'); // punti trasferta (noi)
    });

    test('cambio giocatore: colonna Esce valorizzata', () {
      final righe = righeCsvPartita(
        match: _match(),
        team: _team(),
        sets: [_set(100, 1)],
        azioniPerSet: {
          100: [
            _azione(
              id: 1,
              setId: 100,
              ordine: 1,
              tipo: TipoAzione.cambioGiocatore,
              giocatoreId: 2, // entra Bianchi
              giocatoreUscenteId: 1, // esce Rossi
            ),
          ],
        },
        playerById: players,
      );
      final r = righe[1];
      expect(r[5], 'Cambio giocatore');
      expect(r[7], 'Bianchi Nome12'); // chi entra
      expect(r[21], 'Rossi Nome7'); // chi esce
    });

    test('motivo errore avversario risolto da tipoEsecuzione', () {
      final righe = righeCsvPartita(
        match: _match(),
        team: null, // nessuna squadra -> fallback "Noi"
        sets: [_set(100, 1)],
        azioniPerSet: {
          100: [
            _azione(
              id: 1,
              setId: 100,
              ordine: 1,
              tipo: TipoAzione.erroreGenerico,
              squadra: Squadra.avversari,
              tipoEsecuzione: 'falloDiPosizione',
              esitoPunto: EsitoPunto.puntoNostro,
            ),
          ],
        },
        playerById: const {},
      );
      final r = righe[1];
      expect(r[4], 'Avversari'); // avversario non impostato
      expect(r[11], 'Fallo di posizione');
    });

    test('null e default -> celle vuote', () {
      final righe = righeCsvPartita(
        match: _match(),
        team: _team(),
        sets: [_set(100, 1)],
        azioniPerSet: {
          100: [
            _azione(
              id: 1,
              setId: 100,
              ordine: 1,
              tipo: TipoAzione.timeout,
            ),
          ],
        },
        playerById: players,
      );
      final r = righe[1];
      expect(r[5], 'Timeout');
      for (final i in [6, 7, 8, 9, 10, 11, 12, 15, 16, 17, 18, 19, 20, 21]) {
        expect(r[i], '', reason: 'colonna $i (${kCsvHeader[i]})');
      }
    });
  });
}
