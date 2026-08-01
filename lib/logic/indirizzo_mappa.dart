/// Costruzione della query da passare a un'app di mappe partendo dal testo
/// libero di `VolleyMatches.palestra`. Funzione **pura**, senza dipendenze da
/// Flutter o dal launcher: l'apertura vera vive in `utils/mappe.dart`.
library;

/// Riconosce la forma prodotta dall'import FIPAV
/// (`campionato_provider.dart`, `_palestra()`):
///
/// ```
/// Sc.Galilei 1 - CASALECCHIO DI RENO (BO), Via Porrettana 97
/// └── impianto ──┘   └──── comune ────┘   └─── indirizzo ──┘
/// ```
///
/// Il nome dell'impianto in testa manda fuori strada la ricerca (spesso è
/// un'abbreviazione che non esiste nelle mappe, tipo "Sc.Mezzacasa"), quindi la
/// query utile è `"<indirizzo>, <comune>"`.
final _kFormatoFipav = RegExp(
  r'^\s*.+?\s+-\s+(.+?)\s*,\s*(.+?)\s*$',
);

/// Il testo da dare a un'app di mappe per raggiungere questa palestra.
///
/// Se [palestra] non ha la forma dell'import FIPAV viene restituita **tale e
/// quale**: un indirizzo scritto a mano dall'utente non va mai riscritto da
/// noi, meglio passarlo grezzo e lasciare che sia la mappa a interpretarlo.
String queryMappaDaPalestra(String palestra) {
  final testo = palestra.trim();
  if (testo.isEmpty) return testo;

  final m = _kFormatoFipav.firstMatch(testo);
  if (m == null) return testo;

  final comune = m.group(1)!.trim();
  final indirizzo = m.group(2)!.trim();
  if (comune.isEmpty || indirizzo.isEmpty) return testo;

  return '$indirizzo, $comune';
}
