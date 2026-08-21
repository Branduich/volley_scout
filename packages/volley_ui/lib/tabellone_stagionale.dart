import 'package:flutter/material.dart';
import 'package:volley_stats/volley_stats.dart';

import 'kpi_riga.dart' show pct;

/// Una colonna del tabellone: come si chiama, come si legge il valore e come
/// si ordina.
///
/// Tenere insieme testo e criterio d'ordinamento evita il classico difetto
/// delle tabelle ordinabili: la colonna mostra `—` ma ordina su uno zero, e
/// chi non ha mai attaccato finisce in mezzo a chi attacca male.
class ColonnaTabellone {
  const ColonnaTabellone({
    required this.titolo,
    required this.valore,
    required this.ordina,
    this.numerica = true,
    this.descrizione,
  });

  final String titolo;
  final String Function(StatGiocatore) valore;

  /// Come si ordina. La funzione può tornare `null` (percentuale senza
  /// azioni): quelle righe finiscono **sempre in fondo**, in entrambi i versi,
  /// perché "non pervenuto" non è uno zero. `ordina` stessa è `null` per le
  /// colonne di testo, che si ordinano alfabeticamente.
  final num? Function(StatGiocatore)? ordina;

  final bool numerica;
  final String? descrizione;
}

/// Le colonne del tabellone stagionale, con le stesse definizioni della mega
/// tabella del PDF (vedi stat_giocatori.dart).
List<ColonnaTabellone> colonneTabellone() => [
      ColonnaTabellone(
        titolo: '#',
        valore: (s) => '${s.giocatore.numero}',
        ordina: (s) => s.giocatore.numero,
      ),
      ColonnaTabellone(
        titolo: 'Giocatrice',
        valore: (s) => '${s.giocatore.cognome} ${s.giocatore.nome}',
        ordina: null,
        numerica: false,
      ),
      ColonnaTabellone(
        titolo: 'Azioni',
        valore: (s) => '${s.azioni}',
        ordina: (s) => s.azioni,
        descrizione: 'Azioni votate: il denominatore di tutte le percentuali',
      ),
      ColonnaTabellone(
        titolo: 'Punti',
        valore: (s) => '${s.puntiTotali}',
        ordina: (s) => s.puntiTotali,
        descrizione: 'Voti # su battuta, attacco e muro',
      ),
      ColonnaTabellone(
        titolo: 'Errori',
        valore: (s) => '${s.erroriTotali}',
        ordina: (s) => s.erroriTotali,
        descrizione: 'Voti = su tutti i fondamentali',
      ),
      ColonnaTabellone(
        titolo: 'Att.',
        valore: (s) => '${totaleVoti(s.attacco)}',
        ordina: (s) => totaleVoti(s.attacco),
      ),
      ColonnaTabellone(
        titolo: 'Eff. att.',
        valore: (s) => pct(s.efficienzaAttacco),
        ordina: (s) => s.efficienzaAttacco,
        descrizione: '(punti − errori) / attacchi',
      ),
      ColonnaTabellone(
        titolo: 'Ric.',
        valore: (s) => '${totaleVoti(s.ricezione)}',
        ordina: (s) => totaleVoti(s.ricezione),
      ),
      ColonnaTabellone(
        titolo: 'Pos. ric.',
        valore: (s) => pct(s.positivitaRicezione),
        ordina: (s) => s.positivitaRicezione,
        descrizione: '(# + +) / ricezioni',
      ),
      ColonnaTabellone(
        titolo: 'Bat.',
        valore: (s) => '${totaleVoti(s.battuta)}',
        ordina: (s) => totaleVoti(s.battuta),
      ),
      ColonnaTabellone(
        titolo: 'Muro',
        valore: (s) => '${conteggioVoto(s.muro, Voto.perfetto)}',
        ordina: (s) => conteggioVoto(s.muro, Voto.perfetto),
        descrizione: 'Muri punto',
      ),
      ColonnaTabellone(
        titolo: 'Murati',
        valore: (s) => '${s.murati}',
        ordina: (s) => s.murati,
        descrizione: 'Attacchi finiti sul muro avversario',
      ),
    ];

/// Il tabellone stagionale: una riga per giocatrice, ordinabile per colonna.
///
/// Scorre in orizzontale invece di stringere le colonne: su una tabella di
/// numeri, testo troncato o mandato a capo è peggio di uno scorrimento.
class TabelloneStagionale extends StatefulWidget {
  const TabelloneStagionale({super.key, required this.stats});

  final List<StatGiocatore> stats;

  @override
  State<TabelloneStagionale> createState() => _TabelloneStagionaleState();
}

class _TabelloneStagionaleState extends State<TabelloneStagionale> {
  final _colonne = colonneTabellone();

  /// Di default per numero di maglia: è l'ordine con cui l'allenatore cerca
  /// una giocatrice quando non sta ancora confrontando nulla.
  int _indiceOrdine = 0;
  bool _crescente = true;

  List<StatGiocatore> get _righeOrdinate {
    final colonna = _colonne[_indiceOrdine];
    final ordina = colonna.ordina;
    final righe = [...widget.stats];
    if (ordina == null) {
      righe.sort((a, b) {
        final confronto = colonna.valore(a).compareTo(colonna.valore(b));
        return _crescente ? confronto : -confronto;
      });
      return righe;
    }
    righe.sort((a, b) {
      final va = ordina(a);
      final vb = ordina(b);
      // I valori assenti (percentuali senza azioni) restano in fondo in
      // ENTRAMBI i versi: non sono "zero", sono "non pervenuto". Per questo il
      // verso si applica dentro il confronto e NON rovesciando la lista alla
      // fine — rovesciandola, i `—` finirebbero in cima.
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;
      return _crescente ? va.compareTo(vb) : vb.compareTo(va);
    });
    return righe;
  }

  void _ordinaPer(int indice, bool crescente) {
    setState(() {
      _indiceOrdine = indice;
      _crescente = crescente;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stats.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('Nessuna azione registrata.'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: _indiceOrdine,
        sortAscending: _crescente,
        columnSpacing: 24,
        columns: [
          for (var i = 0; i < _colonne.length; i++)
            DataColumn(
              label: Tooltip(
                message: _colonne[i].descrizione ?? _colonne[i].titolo,
                child: Text(_colonne[i].titolo),
              ),
              numeric: _colonne[i].numerica,
              onSort: (indice, crescente) => _ordinaPer(indice, crescente),
            ),
        ],
        rows: [
          for (final s in _righeOrdinate)
            DataRow(
              cells: [
                for (final c in _colonne) DataCell(Text(c.valore(s))),
              ],
            ),
        ],
      ),
    );
  }
}
