import 'package:flutter/material.dart';
import 'package:volley_stats/volley_stats.dart';

import 'campo_traiettorie.dart';
import 'menu_compatto.dart';

/// Le traiettorie di una stagione su un campo solo (passo 12).
///
/// **Non è il report di una partita rifatto sul web**: lì si guarda una gara,
/// qui si sovrappongono tutte le battute (o tutti gli attacchi) del periodo
/// scelto. È la vista che risponde a "da dove passa la nostra offesa" invece
/// che "com'è andato quel colpo".
///
/// Non calcola niente: riceve i tiri già filtrati, come tutti i widget di
/// questo package.
class SezioneTraiettorie extends StatelessWidget {
  const SezioneTraiettorie({
    super.key,
    required this.tiri,
    required this.fondamentale,
    required this.giocatrici,
    required this.giocatriceUid,
    required this.heatmap,
    required this.onFondamentale,
    required this.onGiocatrice,
    required this.onHeatmap,
  });

  final List<TiroScout> tiri;

  /// Solo battuta e attacco: gli altri fondamentali non hanno traiettoria.
  final Fondamentale fondamentale;
  final List<GiocatoreBackup> giocatrici;

  /// `null` = tutta la squadra.
  final String? giocatriceUid;

  /// Mostra i punti d'arrivo come macchie calde invece che le sole frecce.
  final bool heatmap;

  final ValueChanged<Fondamentale> onFondamentale;
  final ValueChanged<String?> onGiocatrice;
  final ValueChanged<bool> onHeatmap;

  static String etichettaFondamentale(Fondamentale f) => switch (f) {
        Fondamentale.battuta => 'Battuta',
        Fondamentale.attacco => 'Attacco',
        _ => '—',
      };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    // Le frecce si normalizzano tutte nel verso sinistra→destra, così venti
    // colpi di venti scambi diversi si confrontano fra loro invece di
    // annullarsi a vicenda.
    final frecce = [
      for (final t in tiri)
        if (normalizzaTiro(t) != null) trajDataDaTiro(t),
    ];
    final arrivi = [
      for (final t in tiri)
        if (normalizzaTiro(t) case final n?) Offset(n.x2, n.y2),
    ];
    final conta = contaTiri(tiri);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MenuCompatto<Fondamentale>(
              etichetta: 'Fondamentale',
              valore: fondamentale,
              voci: const [
                DropdownMenuItem(
                    value: Fondamentale.battuta, child: Text('Battuta')),
                DropdownMenuItem(
                    value: Fondamentale.attacco, child: Text('Attacco')),
              ],
              onCambia: (v) => v == null ? null : onFondamentale(v),
            ),
            MenuCompatto<String?>(
              etichetta: 'Giocatrice',
              valore: giocatriceUid,
              larghezza: 250,
              voci: [
                const DropdownMenuItem(value: null, child: Text('Tutte')),
                for (final g in giocatrici)
                  DropdownMenuItem(
                    value: g.uid,
                    child: Text('${g.numero}  ${g.cognome}',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onCambia: onGiocatrice,
            ),
            // Con poche frecce si leggono una a una; con duecento si legge solo
            // dove si addensano. Il toggle serve a passare da una domanda
            // all'altra senza cambiare schermata.
            FilterChip(
              avatar: const Icon(Icons.local_fire_department, size: 18),
              label: const Text('Zone di caduta'),
              selected: heatmap,
              onSelected: onHeatmap,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (tiri.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(
              'Nessuna traiettoria registrata per questa scelta.',
              style: tema.textTheme.titleMedium,
            ),
          )
        else ...[
          Text(
            '${conta.totali} ${conta.totali == 1 ? "colpo" : "colpi"} · '
            '${conta.vincenti} vincenti · ${conta.errori} errori',
            style: tema.textTheme.bodyMedium
                ?.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          // Pannello scuro, il blu dello scout live. Non è decorazione: le
          // frecce sono BIANCHE, e le battute partono da dietro la linea di
          // fondo, cioè FUORI dal rettangolo del campo. Su pagina chiara
          // quel tratto spariva e di un servizio si vedeva solo la punta.
          // Il ritaglio arrotondato tiene dentro anche le macchie della
          // heatmap, che sui palloni finiti fuori sbordano oltre il campo.
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ColoredBox(
              color: kSfondoCampo,
              // L'altezza NON può essere fissa: il campo si dimensiona sulla
              // larghezza disponibile (58% di essa, rapporto 2:1), quindi su
              // una finestra larga sfondava un riquadro fisso e veniva
              // tagliato in basso. Si calcola con la stessa formula del campo,
              // più il margine in cima e un po' d'aria sotto per le punte.
              child: LayoutBuilder(
                builder: (context, vincoli) => SizedBox(
                  width: double.infinity,
                  height: kCourtTopMargin +
                      vincoli.maxWidth * kCourtWidthFraction / 2 +
                      16,
                  child: CourtTrajectoriesView(
                    // Con la heatmap accesa le frecce sparirebbero sotto le
                    // macchie: meglio mostrare solo quelle.
                    trajectories: heatmap ? const [] : frecce,
                    heatmapPunti: heatmap ? arrivi : const [],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
