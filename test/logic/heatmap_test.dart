import 'package:flutter_test/flutter_test.dart';
import 'package:volley_scout/data/database.dart';
import 'package:volley_scout/logic/heatmap.dart';
import 'package:volley_scout/models/enums.dart';

// Test della funzione pura puntiArrivoAvversari (Blocco 1 heatmap): filtri +
// normalizzazione dell'arrivo sul campo singolo.

int _ord = 0;
ScoutAction _azione({
  Squadra squadra = Squadra.avversari,
  TipoAzione tipo = TipoAzione.scout,
  Fondamentale? fondamentale = Fondamentale.battuta,
  double? x1,
  double? y1,
  double? x2,
  double? y2,
}) =>
    ScoutAction(
      id: _ord,
      setId: 1,
      rallyId: _ord,
      ordine: _ord++,
      timestamp: DateTime(2026, 7, 28),
      squadra: squadra,
      tipo: tipo,
      giocatoreId: null,
      fondamentale: fondamentale,
      voto: Voto.positivo,
      tipoEsecuzione: 'nonSpecificato',
      esitoPunto: EsitoPunto.nessuno,
      traiettoriaX1: x1,
      traiettoriaY1: y1,
      traiettoriaX2: x2,
      traiettoriaY2: y2,
      traiettoriaMuroX: null,
      traiettoriaMuroY: null,
      puntiCasaAlMomento: null,
      puntiOspitiAlMomento: null,
      giocatoreUscenteId: null,
      nuovoPalleggiatoreId: null,
      nuovoRuoloCambiLibero: null,
      gruppoCambio: null,
      ruoloAvversario: 'S1',
    );

void main() {
  group('puntiArrivoAvversari', () {
    test('filtra: solo avversari, scout, quel fondamentale, con traiettoria',
        () {
      final azioni = [
        // OK: avversari, scout, battuta, traiettoria completa
        _azione(x1: 0.2, y1: 0.3, x2: 0.75, y2: 0.4),
        // escluso: squadra nostra
        _azione(squadra: Squadra.nostra, x1: 0.2, y1: 0.3, x2: 0.75, y2: 0.4),
        // escluso: fondamentale diverso (attacco)
        _azione(
            fondamentale: Fondamentale.attacco,
            x1: 0.2,
            y1: 0.3,
            x2: 0.75,
            y2: 0.4),
        // escluso: non scout
        _azione(tipo: TipoAzione.puntoManuale, x1: 0.2, x2: 0.75, y2: 0.4),
        // escluso: senza traiettoria d'arrivo
        _azione(x1: 0.2, y1: 0.3),
      ];
      final punti = puntiArrivoAvversari(azioni, Fondamentale.battuta);
      expect(punti.length, 1);
      expect(punti.first, const Offset(0.75, 0.4)); // arrivo nella metà destra
    });

    test('senza mirror (x1 < 0.5): arrivo (x2, y2) tale e quale', () {
      final punti = puntiArrivoAvversari(
        [_azione(x1: 0.2, y1: 0.3, x2: 0.75, y2: 0.4)],
        Fondamentale.battuta,
      );
      expect(punti, [const Offset(0.75, 0.4)]);
    });

    test('con mirror (x1 > 0.5): specchiato → stesso arrivo nella metà destra',
        () {
      // x1=0.8 → specchia: ex=1-0.25=0.75, ey=1-0.6=0.4.
      final punti = puntiArrivoAvversari(
        [_azione(x1: 0.8, y1: 0.7, x2: 0.25, y2: 0.6)],
        Fondamentale.battuta,
      );
      expect(punti, [const Offset(0.75, 0.4)]);
    });

    test('estremi: rete a x=0.5, fondo a x=1.0 (metà destra)', () {
      final punti = puntiArrivoAvversari(
        [
          _azione(x1: 0.1, y1: 0.5, x2: 0.5, y2: 0.2), // sulla rete → x=0.5
          _azione(x1: 0.1, y1: 0.5, x2: 1.0, y2: 0.9), // fondo campo → x=1.0
        ],
        Fondamentale.battuta,
      );
      expect(punti, [const Offset(0.5, 0.2), const Offset(1.0, 0.9)]);
    });

    test('filtro per attacco', () {
      final azioni = [
        _azione(fondamentale: Fondamentale.battuta, x1: 0.2, x2: 0.75, y2: 0.4),
        _azione(fondamentale: Fondamentale.attacco, x1: 0.2, x2: 0.6, y2: 0.5),
      ];
      final punti = puntiArrivoAvversari(azioni, Fondamentale.attacco);
      expect(punti, [const Offset(0.6, 0.5)]);
    });
  });
}
