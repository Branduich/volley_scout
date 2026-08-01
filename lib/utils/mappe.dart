/// Apertura della destinazione nell'app di mappe del dispositivo.
///
/// Non serve nessuna dipendenza nuova né una API key: la destinazione si
/// **cede** a un'altra app come testo, ed è quella a fare geocodifica, mappa e
/// navigazione. Per lo stesso motivo non serve il permesso `INTERNET`.
library;

import 'package:url_launcher/url_launcher.dart';

/// Apre l'app di mappe su [query] (un indirizzo, vedi
/// `logic/indirizzo_mappa.dart`). Ritorna `false` se non c'è modo di aprirla.
///
/// Due tentativi in cascata, perché nessuno dei due copre tutti i casi:
/// 1. `geo:` — l'URI standard Android: apre l'app di navigazione predefinita,
///    o il selettore se ce n'è più d'una (Maps, Waze, Organic Maps…);
/// 2. l'URL di Google Maps — ripiego quando nessuna app gestisce `geo:`
///    (device senza app di mappe, o un eventuale porting iOS): apre il browser.
///
/// **Niente `canLaunchUrl` sullo schema `geo:`**: da Android 11 risponde
/// `false` se il pacchetto non è dichiarato in `<queries>` nel manifest, e
/// darebbe un falso negativo anche con Maps installato. Si tenta e si guarda
/// l'esito.
Future<bool> apriInMappe(String query) async {
  final testo = query.trim();
  if (testo.isEmpty) return false;
  final codificata = Uri.encodeComponent(testo);

  // `geo:0,0?q=<indirizzo>` è la forma "cerca questo testo": le coordinate 0,0
  // sono il segnaposto previsto dallo schema quando non le si conosce.
  final tentativi = <Uri>[
    Uri.parse('geo:0,0?q=$codificata'),
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$codificata'),
  ];

  for (final uri in tentativi) {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // Nessuna app per questo schema: si passa al tentativo successivo.
    }
  }
  return false;
}
