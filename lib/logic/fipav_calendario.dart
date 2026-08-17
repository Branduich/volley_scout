/// Conversione della griglia grezza di un export FIPAV (`Gare*.xls`, letto da
/// `data/xls_reader.dart`) in gare tipizzate. Funzione **pura**: nessuna
/// dipendenza da Flutter, DB o UI — come `ricalcolaStato()` e
/// `righeCsvPartita()`, così è testabile sulla fixture `docs/samples/GareNettunia.xls`.
///
/// Il file esportato dal sito federale ha una riga di intestazione e una riga
/// per gara, tutte le celle come testo:
/// `Campionato | Gara N | Giornata | Data | Ora | SquadraCasa | SquadraOspite |
///  Risultato | Parziali | StatoDescrizione | Impianto | IndirizzoImpianto`
library;

/// Una gara del calendario di campionato.
class GaraFipav {
  const GaraFipav({
    required this.campionato,
    required this.dataOra,
    required this.squadraCasa,
    required this.squadraOspite,
    this.garaNumero,
    this.giornata,
    this.risultato,
    this.parziali,
    this.statoDescrizione,
    this.impianto,
    this.indirizzoImpianto,
  });

  final String campionato;
  final int? garaNumero;
  final int? giornata;
  final DateTime dataOra;
  final String squadraCasa;
  final String squadraOspite;

  /// Set vinti, es. `"3-1"` — `null` se la gara non è ancora stata giocata.
  final String? risultato;

  /// Punteggi dei set, es. `"25-17 20-25 25-14 25-6"`.
  final String? parziali;
  final String? statoDescrizione;
  final String? impianto;
  final String? indirizzoImpianto;

  /// Set vinti dalla squadra di casa, `null` se la gara non è giocata o il
  /// risultato non è nel formato atteso.
  int? get setCasa => _risultatoParsed?.$1;

  /// Set vinti dalla squadra ospite.
  int? get setOspite => _risultatoParsed?.$2;

  bool get giocata => _risultatoParsed != null;

  (int, int)? get _risultatoParsed {
    final r = risultato?.trim();
    if (r == null || r.isEmpty) return null;
    final m = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(r);
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(2)!));
  }

  /// I parziali come coppie (punti casa, punti ospite), lista vuota se
  /// assenti o illeggibili. Servono al quoziente punti della classifica.
  List<(int, int)> get parzialiParsed {
    final p = parziali?.trim();
    if (p == null || p.isEmpty) return const [];
    final out = <(int, int)>[];
    for (final pezzo in p.split(RegExp(r'[\s,;]+'))) {
      final m = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(pezzo.trim());
      if (m != null) {
        out.add((int.parse(m.group(1)!), int.parse(m.group(2)!)));
      }
    }
    return out;
  }

  /// Le due squadre della gara, per raccogliere i nomi presenti nel file.
  Iterable<String> get squadre => [squadraCasa, squadraOspite];
}

/// Esito della conversione: le gare lette più le righe scartate, così la UI
/// può dire all'utente quante ne ha ignorate invece di far sparire dati in
/// silenzio.
class EsitoParsingFipav {
  const EsitoParsingFipav({required this.gare, required this.righeScartate});

  final List<GaraFipav> gare;
  final int righeScartate;
}

/// Nomi di colonna attesi (normalizzati: minuscoli, senza spazi né punti).
const _kColonneRichieste = <String>{
  'campionato',
  'data',
  'squadracasa',
  'squadraospite',
};

String _normalizza(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[\s.\-_]'), '');

/// Converte la griglia grezza in gare. Lancia [FormatException] se la riga di
/// intestazione non contiene le colonne indispensabili — meglio un errore
/// esplicito che un import silenziosamente vuoto.
EsitoParsingFipav parseGareFipav(List<List<String>> righe) {
  if (righe.isEmpty) {
    throw const FormatException('Il file non contiene alcuna riga.');
  }

  final header = righe.first;
  final indici = <String, int>{};
  for (var i = 0; i < header.length; i++) {
    final nome = _normalizza(header[i]);
    if (nome.isNotEmpty) indici.putIfAbsent(nome, () => i);
  }

  final mancanti = _kColonneRichieste.where((c) => !indici.containsKey(c));
  if (mancanti.isNotEmpty) {
    throw FormatException(
      'Il file non sembra un calendario FIPAV: mancano le colonne '
      '${mancanti.join(", ")}. Colonne trovate: '
      '${header.where((h) => h.trim().isNotEmpty).join(", ")}.',
    );
  }

  String? cella(List<String> riga, String colonna) {
    final i = indici[colonna];
    if (i == null || i >= riga.length) return null;
    final v = riga[i].trim();
    return v.isEmpty ? null : v;
  }

  final gare = <GaraFipav>[];
  var scartate = 0;

  for (final riga in righe.skip(1)) {
    final casa = cella(riga, 'squadracasa');
    final ospite = cella(riga, 'squadraospite');
    final data = _parseData(cella(riga, 'data'), cella(riga, 'ora'));

    // Righe vuote in coda o senza i dati minimi: non sono un errore, ma non
    // sono nemmeno una gara.
    if (casa == null || ospite == null || data == null) {
      if (riga.any((c) => c.trim().isNotEmpty)) scartate++;
      continue;
    }

    gare.add(
      GaraFipav(
        campionato: cella(riga, 'campionato') ?? '',
        garaNumero: int.tryParse(cella(riga, 'garan') ?? ''),
        giornata: int.tryParse(cella(riga, 'giornata') ?? ''),
        dataOra: data,
        squadraCasa: casa,
        squadraOspite: ospite,
        risultato: cella(riga, 'risultato'),
        parziali: cella(riga, 'parziali'),
        statoDescrizione: cella(riga, 'statodescrizione'),
        impianto: cella(riga, 'impianto'),
        indirizzoImpianto: cella(riga, 'indirizzoimpianto'),
      ),
    );
  }

  gare.sort((a, b) => a.dataOra.compareTo(b.dataOra));
  return EsitoParsingFipav(gare: gare, righeScartate: scartate);
}

/// La stagione sportiva delle gare, es. `"2025/26"` — `null` se non ci sono
/// gare. Il file FIPAV non ha una colonna stagione, quindi si deduce dalla
/// PRIMA gara in calendario: l'anno sportivo parte in estate, quindi da luglio
/// in poi è `anno/anno+1`, prima è `anno-1/anno`.
///
/// Serve a distinguere in UI due import dello stesso girone in stagioni
/// diverse (vedi `Campionati.stagione`): senza, a settembre il calendario
/// nuovo sarebbe indistinguibile da quello dell'anno prima.
String? stagioneDaGare(Iterable<GaraFipav> gare) {
  DateTime? prima;
  for (final g in gare) {
    if (prima == null || g.dataOra.isBefore(prima)) prima = g.dataOra;
  }
  if (prima == null) return null;
  final inizio = prima.month >= 7 ? prima.year : prima.year - 1;
  final fine = (inizio + 1) % 100;
  return '$inizio/${fine.toString().padLeft(2, '0')}';
}

/// `dd/MM/yyyy` + `HH:mm` (l'ora può mancare → mezzanotte). Parsing a mano
/// invece che con `intl`: il formato è fisso e così la funzione resta pura e
/// senza inizializzazione delle locale.
///
/// Accetta anche il **seriale Excel** (`46672` = 12/10/2027) al posto del
/// testo: l'export federale scrive le date come testo, ma un file ri-salvato
/// da Excel/Google Sheets le converte in date vere, che i lettori rendono come
/// numero grezzo (vedi `data/xlsx_reader.dart`).
DateTime? _parseData(String? data, String? ora) {
  if (data == null) return null;

  final ore = _parseOra(ora);

  final d = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(data.trim());
  if (d != null) {
    return DateTime(
      int.parse(d.group(3)!),
      int.parse(d.group(2)!),
      int.parse(d.group(1)!),
      ore.$1,
      ore.$2,
    );
  }

  final giorno = _dataDaSeriale(data);
  if (giorno == null) return null;
  // Un seriale con parte decimale porta già l'orario; la colonna Ora, se c'è,
  // resta comunque la fonte più leggibile e vince.
  if (ora != null && (ore.$1 != 0 || ore.$2 != 0)) {
    return DateTime(giorno.year, giorno.month, giorno.day, ore.$1, ore.$2);
  }
  return giorno;
}

/// `HH:mm` → (ore, minuti); `(0, 0)` se assente o illeggibile. Accetta anche
/// la frazione di giorno (`0.458333` = 11:00), come la scrivono i fogli di
/// calcolo quando l'ora è una cella oraria vera invece che testo.
(int, int) _parseOra(String? ora) {
  if (ora == null) return (0, 0);
  final testo = ora.trim();

  // La frazione va tentata PRIMA: `0.875` combacerebbe anche con il formato
  // `H.mm` (leggendolo come 0h 87min), che è chiaramente non quello che è.
  final frazione = double.tryParse(testo);
  if (frazione != null) {
    if (frazione < 0 || frazione >= 1) return (0, 0);
    final minutiTotali = (frazione * 1440).round();
    return (minutiTotali ~/ 60 % 24, minutiTotali % 60);
  }

  final o = RegExp(r'^(\d{1,2})[:.](\d{2})').firstMatch(testo);
  if (o != null) return (int.parse(o.group(1)!), int.parse(o.group(2)!));
  return (0, 0);
}

/// Il seriale data dei fogli di calcolo: giorni dal 30/12/1899, parte decimale
/// = frazione di giorno. Fuori da un intervallo plausibile di date sportive si
/// rifiuta il valore, per non scambiare un numero qualsiasi per una data.
DateTime? _dataDaSeriale(String testo) {
  final seriale = double.tryParse(testo.trim());
  if (seriale == null || seriale < 20000 || seriale > 80000) return null;
  final giorni = seriale.floor();
  final secondi = ((seriale - giorni) * 86400).round();
  return DateTime(1899, 12, 30 + giorni).add(Duration(seconds: secondi));
}
