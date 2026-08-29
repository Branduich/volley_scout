import 'package:flutter/material.dart';
import 'package:volley_stats/volley_stats.dart';

import 'kpi_riga.dart' show pct;

/// Cosa mostra il tabellone: il riepilogo di tutta la squadra oppure **un
/// fondamentale solo**, con le stesse colonne della mega tabella del PDF.
///
/// Il riepilogo risponde a "chi sta giocando bene"; le viste per fondamentale
/// a "come attacca la mia banda", che è la domanda per cui l'allenatore
/// stampava il PDF. Sono due letture diverse, e tenerle insieme voleva dire
/// trenta colonne di cui ventidue di troppo.
enum VistaTabellone {
  riepilogo('Riepilogo'),
  battuta('Battuta'),
  attacco('Attacco'),
  ricezione('Ricezione'),
  difesa('Difesa'),
  muro('Muro');

  const VistaTabellone(this.etichetta);

  final String etichetta;
}

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

/// Chi è la riga: le due colonne che ogni vista si porta dietro.
List<ColonnaTabellone> _identita() => [
      ColonnaTabellone(
        titolo: '#',
        valore: (s) => '${s.giocatore.numero}',
        ordina: (s) => s.giocatore.numero,
      ),
      ColonnaTabellone(
        titolo: 'Atleta',
        valore: (s) => '${s.giocatore.cognome} ${s.giocatore.nome}',
        ordina: null,
        numerica: false,
      ),
    ];

/// Un gruppo di colonne per un fondamentale, nell'ordine della mega tabella del
/// PDF: totale, perfette, errori, efficienza — più murati e positività dove il
/// PDF le prevede.
///
/// **Chi non ha toccato quel fondamentale mostra `0` nel totale e celle vuote
/// nel resto**: la riga resta al suo posto, così si vede a colpo d'occhio chi
/// non riceve mai, ma non si riempie di zeri e trattini che sembrano dati.
List<ColonnaTabellone> _gruppo({
  required Map<Voto, int> Function(StatGiocatore) conteggi,
  required String gruppo,
  required String titoloTotale,
  required String titoloPerfette,
  required String descrizionePerfette,
  String suffisso = '',
  bool murati = false,
  bool positivita = false,
}) {
  bool nessuna(StatGiocatore s) => totaleVoti(conteggi(s)) == 0;

  return [
    ColonnaTabellone(
      titolo: titoloTotale,
      valore: (s) => '${totaleVoti(conteggi(s))}',
      ordina: (s) => totaleVoti(conteggi(s)),
      descrizione: '$gruppo: azioni votate',
    ),
    ColonnaTabellone(
      titolo: titoloPerfette,
      valore: (s) =>
          nessuna(s) ? '' : '${conteggioVoto(conteggi(s), Voto.perfetto)}',
      ordina: (s) => conteggioVoto(conteggi(s), Voto.perfetto),
      descrizione: '$gruppo: $descrizionePerfette',
    ),
    if (murati)
      ColonnaTabellone(
        titolo: 'Murati',
        valore: (s) => nessuna(s) ? '' : '${s.murati}',
        ordina: (s) => s.murati,
        descrizione: 'Attacchi finiti sul muro avversario',
      ),
    ColonnaTabellone(
      titolo: 'Errori$suffisso',
      valore: (s) =>
          nessuna(s) ? '' : '${conteggioVoto(conteggi(s), Voto.errore)}',
      ordina: (s) => conteggioVoto(conteggi(s), Voto.errore),
      descrizione: '$gruppo: voti =',
    ),
    ColonnaTabellone(
      titolo: 'Eff.%$suffisso',
      valore: (s) => nessuna(s) ? '' : pct(efficienzaDaVoti(conteggi(s))),
      ordina: (s) => efficienzaDaVoti(conteggi(s)),
      descrizione: '$gruppo: (# − =) / totale',
    ),
    if (positivita)
      ColonnaTabellone(
        titolo: 'Pos.%',
        valore: (s) => nessuna(s) ? '' : pct(positivitaDaVoti(conteggi(s))),
        ordina: (s) => positivitaDaVoti(conteggi(s)),
        descrizione: '$gruppo: (# + +) / totale',
      ),
  ];
}

/// Le colonne del tabellone per la [vista] scelta, con le stesse definizioni
/// della mega tabella del PDF (vedi stat_giocatori.dart).
List<ColonnaTabellone> colonneTabellone(VistaTabellone vista) =>
    switch (vista) {
      VistaTabellone.riepilogo => [
          ..._identita(),
          ColonnaTabellone(
            titolo: 'Azioni',
            valore: (s) => '${s.azioni}',
            ordina: (s) => s.azioni,
            descrizione:
                'Azioni votate: il denominatore di tutte le percentuali',
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
            titolo: 'Battute',
            valore: (s) => '${totaleVoti(s.battuta)}',
            ordina: (s) => totaleVoti(s.battuta),
          ),
          ColonnaTabellone(
            titolo: 'Ace',
            valore: (s) => '${conteggioVoto(s.battuta, Voto.perfetto)}',
            ordina: (s) => conteggioVoto(s.battuta, Voto.perfetto),
            descrizione: 'Battute con voto #',
          ),
          ColonnaTabellone(
            titolo: 'Attacchi',
            valore: (s) => '${totaleVoti(s.attacco)}',
            ordina: (s) => totaleVoti(s.attacco),
          ),
          ColonnaTabellone(
            titolo: 'Punti att.',
            valore: (s) => '${conteggioVoto(s.attacco, Voto.perfetto)}',
            ordina: (s) => conteggioVoto(s.attacco, Voto.perfetto),
            descrizione: 'Attacchi con voto #',
          ),
          ColonnaTabellone(
            titolo: 'Ricezioni',
            valore: (s) => '${totaleVoti(s.ricezione)}',
            ordina: (s) => totaleVoti(s.ricezione),
          ),
          ColonnaTabellone(
            titolo: 'Pos. ric.',
            valore: (s) => pct(s.positivitaRicezione),
            ordina: (s) => s.positivitaRicezione,
            descrizione: '(# + +) / ricezioni',
          ),
        ],
      VistaTabellone.battuta => [
          ..._identita(),
          ..._gruppo(
            conteggi: (s) => s.battuta,
            gruppo: 'Battuta',
            titoloTotale: 'Battute',
            titoloPerfette: 'Ace',
            descrizionePerfette: 'voti # (ace)',
          ),
        ],
      // Le tre fette dell'attacco, come nel PDF: il totale, e poi la partizione
      // fra chi attacca dopo una ricezione e chi dopo una difesa — due
      // situazioni che non si giudicano con lo stesso metro.
      VistaTabellone.attacco => [
          ..._identita(),
          ..._gruppo(
            conteggi: (s) => s.attacco,
            gruppo: 'Attacco',
            titoloTotale: 'Attacchi',
            titoloPerfette: 'Punti',
            descrizionePerfette: 'voti # (punto)',
            murati: true,
          ),
          ..._gruppo(
            conteggi: (s) => s.attaccoSuRicezione,
            gruppo: 'Attacco su ricezione',
            titoloTotale: 'Su ric.',
            titoloPerfette: 'PT ric.',
            descrizionePerfette: 'voti # (punto)',
            suffisso: ' ric.',
          ),
          ..._gruppo(
            conteggi: (s) => s.attaccoSuDifesa,
            gruppo: 'Attacco su difesa',
            titoloTotale: 'Su dif.',
            titoloPerfette: 'PT dif.',
            descrizionePerfette: 'voti # (punto)',
            suffisso: ' dif.',
          ),
        ],
      VistaTabellone.ricezione => [
          ..._identita(),
          ..._gruppo(
            conteggi: (s) => s.ricezione,
            gruppo: 'Ricezione',
            titoloTotale: 'Ricezioni',
            titoloPerfette: 'Perfette',
            descrizionePerfette: 'voti #',
            positivita: true,
          ),
        ],
      VistaTabellone.difesa => [
          ..._identita(),
          ..._gruppo(
            conteggi: (s) => s.difesa,
            gruppo: 'Difesa',
            titoloTotale: 'Difese',
            titoloPerfette: 'Perfette',
            descrizionePerfette: 'voti #',
            positivita: true,
          ),
        ],
      VistaTabellone.muro => [
          ..._identita(),
          ..._gruppo(
            conteggi: (s) => s.muro,
            gruppo: 'Muro',
            titoloTotale: 'Muri',
            titoloPerfette: 'Muri punto',
            descrizionePerfette: 'voti # (punto)',
          ),
        ],
    };

/// Il tabellone stagionale: una riga per atleta, ordinabile per colonna, col
/// selettore del fondamentale sopra.
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
  VistaTabellone _vista = VistaTabellone.riepilogo;
  late List<ColonnaTabellone> _colonne = colonneTabellone(_vista);

  /// Di default per numero di maglia: è l'ordine con cui l'allenatore cerca
  /// un'atleta quando non sta ancora confrontando nulla.
  int _indiceOrdine = 0;
  bool _crescente = true;

  void _cambiaVista(VistaTabellone vista) {
    setState(() {
      _vista = vista;
      _colonne = colonneTabellone(vista);
      // L'ordinamento riparte dal numero di maglia: le colonne sono altre, e
      // un indice tenuto da prima punterebbe a una colonna che non c'entra
      // niente — o, dove le colonne sono meno, fuori dalla lista.
      _indiceOrdine = 0;
      _crescente = true;
    });
  }

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in VistaTabellone.values)
              ChoiceChip(
                label: Text(v.etichetta),
                selected: _vista == v,
                onSelected: (_) => _cambiaVista(v),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
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
        ),
      ],
    );
  }
}
