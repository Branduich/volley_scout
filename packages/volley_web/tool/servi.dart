// Servitore statico per provare la dashboard come sarà una volta pubblicata.
//
// A cosa serve, e perché non basta `flutter run -d chrome`: quel comando
// costruisce una build di DEBUG, e il codice che vi viene iniettato pretende di
// riagganciarsi al servizio di debug della sessione che l'ha lanciata. Riaperta
// in una finestra nuova — o dopo aver chiuso il browser — quella pagina resta
// bianca, e la memoria del backup (IndexedDB) non si riesce a verificare.
//
// Qui invece si serve il pacchetto di release, che è esattamente ciò che finirà
// sull'host statico del passo 10: nessuna sessione, nessun aggancio, la pagina
// vive di suo finché gira questo comando.
//
// Uso, da `packages/volley_web`:
//
//     flutter build web --release
//     dart run tool/servi.dart          # poi apri http://localhost:8080
//
// La **porta va tenuta fissa**: per un browser l'origine è schema + host +
// porta, quindi cambiandola si finisce su un IndexedDB diverso e i dati salvati
// sembrano spariti. È lo stesso motivo per cui non si usa la porta a caso di
// `flutter run`.
//
// Zero dipendenze (solo `dart:io`) di proposito: è uno strumento di sviluppo e
// non deve pesare sul pubspec dell'applicazione.
import 'dart:io';

const int _portaPredefinita = 8080;
const String _radice = 'build/web';

/// Il tipo giusto conta più di quanto sembri: un `.js` servito come testo
/// semplice viene rifiutato dal browser, e un `.wasm` senza il suo tipo perde
/// la compilazione in streaming.
const Map<String, String> _tipi = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.wasm.map': 'application/json; charset=utf-8',
};

String _tipoDi(String percorso) {
  final punto = percorso.lastIndexOf('.');
  if (punto < 0) return 'application/octet-stream';
  return _tipi[percorso.substring(punto).toLowerCase()] ??
      'application/octet-stream';
}

Future<void> main(List<String> argomenti) async {
  final porta =
      argomenti.isEmpty ? _portaPredefinita : int.tryParse(argomenti.first);
  if (porta == null) {
    stderr.writeln('Porta non valida: ${argomenti.first}');
    exitCode = 2;
    return;
  }

  final radice = Directory(_radice);
  if (!radice.existsSync()) {
    stderr.writeln('Manca $_radice. Prima: flutter build web --release');
    exitCode = 1;
    return;
  }

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, porta);
  stdout.writeln('Dashboard su http://localhost:$porta  (Ctrl+C per fermare)');

  await for (final richiesta in server) {
    final relativo = Uri.decodeComponent(richiesta.uri.path)
        .replaceAll('\\', '/')
        .replaceFirst(RegExp(r'^/+'), '');
    // Nessun percorso può uscire dalla cartella servita: è un server di
    // sviluppo, ma "../../" verso il resto del disco non deve funzionare
    // nemmeno qui.
    if (relativo.split('/').contains('..')) {
      richiesta.response.statusCode = HttpStatus.forbidden;
      await richiesta.response.close();
      continue;
    }

    var file = File('$_radice/${relativo.isEmpty ? 'index.html' : relativo}');
    // Un indirizzo che non corrisponde a un file è una rotta dell'applicazione:
    // la gestisce lei, quindi si consegna comunque la pagina.
    if (!file.existsSync()) file = File('$_radice/index.html');

    richiesta.response.headers.contentType =
        ContentType.parse(_tipoDi(file.path));
    try {
      await richiesta.response.addStream(file.openRead());
    } catch (_) {
      // Il browser che chiude la connessione a metà (ricaricamento, scheda
      // chiusa) non è un errore da segnalare.
    }
    await richiesta.response.close();
  }
}
