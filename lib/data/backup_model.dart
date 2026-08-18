// Modello del file di backup: oggetti puri + (de)serializzazione JSON.
//
// **Nessun import di drift, riverpod, AppLocalizations o BuildContext**: questo
// file è destinato a `packages/volley_stats` (passo 5 del piano in
// docs/dati-stagionali.md) e deve compilare con il solo `flutter`, perché la
// dashboard web lo userà così com'è. La conversione da/verso le righe drift sta
// invece in `backup_json.dart`, che resta nell'app.
//
// Formato documentato in docs/backup-format.md. Le scelte non ovvie, in breve:
// enum salvati per `.name` (mai etichette localizzate, che cambiano con la
// lingua), `uid` come identità stabile al posto degli `id` autoincrement (che
// sono numeri di QUESTO dispositivo), chiavi corte solo nelle azioni — che sono
// il 95% del file — e tempi delle azioni come secondi dall'inizio partita
// invece di timestamp assoluti.
import '../models/enums.dart';

/// Marcatore del formato: un file che non ha questo valore in `formato` non è
/// un nostro backup e viene rifiutato prima di qualunque altro controllo.
const String kFormatoBackup = 'volley_stratego_backup';

/// Versione del formato. Sale **solo** per modifiche incompatibili: aggiungere
/// campi è additivo e non la muove (il lettore ignora le chiavi che non
/// conosce). Un file con una versione più recente di questa viene rifiutato con
/// un messaggio esplicito, mai letto a metà.
const int kFormatoVersioneBackup = 1;

/// Errore di lettura con messaggio già mostrabile all'utente.
class BackupFormatException implements Exception {
  const BackupFormatException(this.messaggio);
  final String messaggio;
  @override
  String toString() => messaggio;
}

// --- Helper di lettura/scrittura ---------------------------------------------

/// Coordinate a 4 decimali: sono normalizzate 0-1 su un campo di 1200×600, e
/// il quarto decimale vale già meno di un decimo di pixel. Un `double` scritto
/// per intero costa fino a 17 cifre — su ~15.000 azioni con 6 coordinate sono
/// centinaia di KB di rumore.
double? _coord(double? v) =>
    v == null ? null : double.parse(v.toStringAsFixed(4));

/// Aggiunge la coppia solo se il valore non è nullo: le chiavi assenti sono la
/// forma compatta del "null" e il lettore le tratta come tali.
void _metti(Map<String, Object?> m, String chiave, Object? valore) {
  if (valore != null) m[chiave] = valore;
}

T _enum<T>(List<T> valori, String? nome, String dove) {
  final trovato = _enumOpt(valori, nome, dove);
  if (trovato == null) {
    throw BackupFormatException('$dove: valore obbligatorio mancante');
  }
  return trovato;
}

/// Enum tollerante: un valore sconosciuto (file scritto da una versione più
/// nuova che ha aggiunto una voce) NON fa cadere l'import, torna `null` —
/// coerente con la regola "i campi nuovi sono additivi".
T? _enumOpt<T>(List<T> valori, String? nome, String dove) {
  if (nome == null) return null;
  for (final v in valori) {
    if ((v as Enum).name == nome) return v;
  }
  return null;
}

String _stringa(Map<String, Object?> m, String chiave, String dove) {
  final v = m[chiave];
  if (v is! String) throw BackupFormatException('$dove: manca "$chiave"');
  return v;
}

int _intero(Map<String, Object?> m, String chiave, String dove) {
  final v = m[chiave];
  if (v is! int) throw BackupFormatException('$dove: manca "$chiave"');
  return v;
}

DateTime _data(Map<String, Object?> m, String chiave, String dove) {
  final v = m[chiave];
  if (v is! String) throw BackupFormatException('$dove: manca "$chiave"');
  final d = DateTime.tryParse(v);
  if (d == null) throw BackupFormatException('$dove: "$chiave" illeggibile');
  return d;
}

DateTime? _dataOpt(Map<String, Object?> m, String chiave) {
  final v = m[chiave];
  return v is String ? DateTime.tryParse(v) : null;
}

double? _double(Map<String, Object?> m, String chiave) =>
    (m[chiave] as num?)?.toDouble();

List<Map<String, Object?>> _lista(Map<String, Object?> m, String chiave) {
  final v = m[chiave];
  if (v == null) return const [];
  if (v is! List) return const [];
  return v.whereType<Map<String, Object?>>().toList();
}

// --- Envelope ---------------------------------------------------------------

/// Il file intero. `campionati` serve solo al ripristino: la dashboard lo salta.
class BackupCompleto {
  const BackupCompleto({
    required this.formatoVersione,
    required this.schemaDb,
    required this.app,
    required this.esportatoIl,
    this.categorie = const [],
    this.squadre = const [],
    this.giocatori = const [],
    this.partite = const [],
    this.campionati = const [],
  });

  final int formatoVersione;

  /// Versione dello schema drift al momento dell'export. Non serve a leggere il
  /// file (il formato è indipendente dallo schema), ma dice a chi diagnostica un
  /// problema da quale versione dell'app arriva il backup.
  final int schemaDb;
  final String app;
  final DateTime esportatoIl;
  final List<CategoriaBackup> categorie;
  final List<SquadraBackup> squadre;
  final List<GiocatoreBackup> giocatori;
  final List<PartitaBackup> partite;
  final List<CampionatoBackup> campionati;

  Map<String, Object?> toJson() => {
        'formato': kFormatoBackup,
        'formatoVersione': formatoVersione,
        'schemaDb': schemaDb,
        'app': app,
        // Al secondo, in UTC: i microsecondi di `DateTime.now()` sono rumore
        // in un marcatore che serve solo a dire "di quando è questo file".
        'esportatoIl': esportatoIl
            .toUtc()
            .copyWith(millisecond: 0, microsecond: 0)
            .toIso8601String(),
        'categorie': [for (final c in categorie) c.toJson()],
        'squadre': [for (final s in squadre) s.toJson()],
        'giocatori': [for (final g in giocatori) g.toJson()],
        'partite': [for (final p in partite) p.toJson()],
        'campionati': [for (final c in campionati) c.toJson()],
      };

  factory BackupCompleto.fromJson(Map<String, Object?> json) {
    if (json['formato'] != kFormatoBackup) {
      throw const BackupFormatException(
          'Questo file non è un backup di Volley Stratego.');
    }
    final versione = json['formatoVersione'];
    if (versione is! int) {
      throw const BackupFormatException(
          'Backup senza numero di versione: file incompleto o corrotto.');
    }
    if (versione > kFormatoVersioneBackup) {
      throw BackupFormatException(
          'Questo backup è stato creato con una versione più recente '
          'dell\'app (formato $versione, questa app legge fino a '
          '$kFormatoVersioneBackup). Aggiorna l\'app e riprova.');
    }
    return BackupCompleto(
      formatoVersione: versione,
      schemaDb: (json['schemaDb'] as int?) ?? 0,
      app: (json['app'] as String?) ?? '',
      esportatoIl: _dataOpt(json, 'esportatoIl') ?? DateTime.now(),
      categorie: [
        for (final m in _lista(json, 'categorie')) CategoriaBackup.fromJson(m)
      ],
      squadre: [
        for (final m in _lista(json, 'squadre')) SquadraBackup.fromJson(m)
      ],
      giocatori: [
        for (final m in _lista(json, 'giocatori')) GiocatoreBackup.fromJson(m)
      ],
      partite: [
        for (final m in _lista(json, 'partite')) PartitaBackup.fromJson(m)
      ],
      campionati: [
        for (final m in _lista(json, 'campionati')) CampionatoBackup.fromJson(m)
      ],
    );
  }
}

// --- Anagrafica -------------------------------------------------------------

/// Le categorie non hanno `uid`: sono una lista di etichette, l'identità è il
/// nome (è già così nel DB, dove `Teams.categoria` salva il testo e non una FK).
class CategoriaBackup {
  const CategoriaBackup({required this.nome, required this.ordine});
  final String nome;
  final int ordine;

  Map<String, Object?> toJson() => {'nome': nome, 'ordine': ordine};

  factory CategoriaBackup.fromJson(Map<String, Object?> m) => CategoriaBackup(
        nome: _stringa(m, 'nome', 'categoria'),
        ordine: _intero(m, 'ordine', 'categoria "${m['nome']}"'),
      );
}

class SquadraBackup {
  const SquadraBackup({
    required this.uid,
    required this.nome,
    required this.categoria,
    required this.coloreDivisa,
  });

  final String uid;
  final String nome;
  final String categoria;
  final int coloreDivisa;

  Map<String, Object?> toJson() => {
        'uid': uid,
        'nome': nome,
        'categoria': categoria,
        'coloreDivisa': coloreDivisa,
      };

  factory SquadraBackup.fromJson(Map<String, Object?> m) => SquadraBackup(
        uid: _stringa(m, 'uid', 'squadra'),
        nome: _stringa(m, 'nome', 'squadra ${m['uid']}'),
        categoria: (m['categoria'] as String?) ?? '',
        coloreDivisa: _intero(m, 'coloreDivisa', 'squadra ${m['nome']}'),
      );
}

class GiocatoreBackup {
  const GiocatoreBackup({
    required this.uid,
    required this.squadraUid,
    required this.nome,
    required this.cognome,
    required this.numero,
    required this.ruolo,
    this.scadenzaCertificato,
  });

  final String uid;
  final String squadraUid;
  final String nome;
  final String cognome;
  final int numero;
  final Ruolo ruolo;
  final DateTime? scadenzaCertificato;

  Map<String, Object?> toJson() {
    final m = <String, Object?>{
      'uid': uid,
      'squadraUid': squadraUid,
      'nome': nome,
      'cognome': cognome,
      'numero': numero,
      'ruolo': ruolo.name,
    };
    _metti(m, 'scadenzaCertificato',
        scadenzaCertificato?.toIso8601String());
    return m;
  }

  factory GiocatoreBackup.fromJson(Map<String, Object?> m) {
    final dove = 'giocatore ${m['cognome'] ?? m['uid']}';
    return GiocatoreBackup(
      uid: _stringa(m, 'uid', dove),
      squadraUid: _stringa(m, 'squadraUid', dove),
      nome: (m['nome'] as String?) ?? '',
      cognome: (m['cognome'] as String?) ?? '',
      numero: _intero(m, 'numero', dove),
      // Un ruolo sconosciuto non deve far cadere l'import: diventa universale,
      // che è il valore "non specificato" del dominio.
      ruolo: _enumOpt(Ruolo.values, m['ruolo'] as String?, dove) ??
          Ruolo.undefined,
      scadenzaCertificato: _dataOpt(m, 'scadenzaCertificato'),
    );
  }
}

// --- Partita ----------------------------------------------------------------

class PartitaBackup {
  const PartitaBackup({
    required this.uid,
    required this.nome,
    required this.dataOra,
    required this.inCasa,
    required this.stato,
    required this.setCorrente,
    this.palestra,
    this.avversario,
    this.squadraUid,
    this.lat,
    this.lon,
    this.inizioAzioni,
    this.sets = const [],
  });

  final String uid;
  final String nome;
  final DateTime dataOra;
  final bool inCasa;
  final StatoPartita stato;
  final int setCorrente;
  final String? palestra;
  final String? avversario;
  final String? squadraUid;
  final double? lat;
  final double? lon;

  /// Istante della **prima azione** della partita: è l'ancora a cui si
  /// riferiscono i `t` delle azioni (secondi trascorsi da qui).
  ///
  /// Non si usa `dataOra` come ancora, che è la data di *calendario* e può
  /// distare settimane dal momento in cui si è scoutato davvero (una partita
  /// programmata al 31 agosto e provata il 17 dava `t` negativi di trenta
  /// giorni: esatti, ma illeggibili). Con questa ancora il primo tocco è sempre
  /// `t = 0`. `null` se la partita non ha ancora nessuna azione.
  final DateTime? inizioAzioni;
  final List<SetBackup> sets;

  Map<String, Object?> toJson() {
    final m = <String, Object?>{
      'uid': uid,
      'nome': nome,
      'dataOra': dataOra.toIso8601String(),
      'inCasa': inCasa,
      'stato': stato.name,
      'setCorrente': setCorrente,
      'sets': [for (final s in sets) s.toJson()],
    };
    _metti(m, 'palestra', palestra);
    _metti(m, 'avversario', avversario);
    _metti(m, 'squadraUid', squadraUid);
    _metti(m, 'lat', lat);
    _metti(m, 'lon', lon);
    _metti(m, 'inizioAzioni', inizioAzioni?.toIso8601String());
    return m;
  }

  factory PartitaBackup.fromJson(Map<String, Object?> m) {
    final dove = 'partita ${m['nome'] ?? m['uid']}';
    return PartitaBackup(
      uid: _stringa(m, 'uid', dove),
      nome: (m['nome'] as String?) ?? '',
      dataOra: _data(m, 'dataOra', dove),
      inCasa: (m['inCasa'] as bool?) ?? true,
      stato: _enumOpt(StatoPartita.values, m['stato'] as String?, dove) ??
          StatoPartita.configurazione,
      setCorrente: (m['setCorrente'] as int?) ?? 1,
      palestra: m['palestra'] as String?,
      avversario: m['avversario'] as String?,
      squadraUid: m['squadraUid'] as String?,
      lat: _double(m, 'lat'),
      lon: _double(m, 'lon'),
      inizioAzioni: _dataOpt(m, 'inizioAzioni'),
      sets: [for (final s in _lista(m, 'sets')) SetBackup.fromJson(s, dove)],
    );
  }
}

class SetBackup {
  const SetBackup({
    required this.numero,
    required this.aperto,
    required this.squadraServizioIniziale,
    this.liberoUid,
    this.libero2Uid,
    this.ruoloCambiLibero,
    this.correzionePuntiNostri = 0,
    this.correzionePuntiAvversari = 0,
    this.palleggiatoreAvversarioSlot,
    this.sistemaGioco,
    this.rotazioni = const [],
    this.azioni = const [],
  });

  final int numero;
  final bool aperto;
  final Squadra squadraServizioIniziale;
  final String? liberoUid;
  final String? libero2Uid;
  final Ruolo? ruoloCambiLibero;
  final int correzionePuntiNostri;
  final int correzionePuntiAvversari;
  final int? palleggiatoreAvversarioSlot;
  final SistemaGioco? sistemaGioco;
  final List<RotazioneBackup> rotazioni;
  final List<AzioneBackup> azioni;

  Map<String, Object?> toJson() {
    final m = <String, Object?>{
      'numero': numero,
      'aperto': aperto,
      'servizioIniziale': squadraServizioIniziale.name,
      'correzionePuntiNostri': correzionePuntiNostri,
      'correzionePuntiAvversari': correzionePuntiAvversari,
      'rotazioni': [for (final r in rotazioni) r.toJson()],
      'azioni': [for (final a in azioni) a.toJson()],
    };
    _metti(m, 'liberoUid', liberoUid);
    _metti(m, 'libero2Uid', libero2Uid);
    _metti(m, 'ruoloCambiLibero', ruoloCambiLibero?.name);
    _metti(m, 'palleggiatoreAvversarioSlot', palleggiatoreAvversarioSlot);
    _metti(m, 'sistemaGioco', sistemaGioco?.name);
    return m;
  }

  factory SetBackup.fromJson(Map<String, Object?> m, String contesto) {
    final dove = '$contesto, set ${m['numero']}';
    return SetBackup(
      numero: _intero(m, 'numero', dove),
      aperto: (m['aperto'] as bool?) ?? false,
      squadraServizioIniziale: _enumOpt(
              Squadra.values, m['servizioIniziale'] as String?, dove) ??
          Squadra.nostra,
      liberoUid: m['liberoUid'] as String?,
      libero2Uid: m['libero2Uid'] as String?,
      ruoloCambiLibero:
          _enumOpt(Ruolo.values, m['ruoloCambiLibero'] as String?, dove),
      correzionePuntiNostri: (m['correzionePuntiNostri'] as int?) ?? 0,
      correzionePuntiAvversari: (m['correzionePuntiAvversari'] as int?) ?? 0,
      palleggiatoreAvversarioSlot: m['palleggiatoreAvversarioSlot'] as int?,
      sistemaGioco:
          _enumOpt(SistemaGioco.values, m['sistemaGioco'] as String?, dove),
      rotazioni: [
        for (final r in _lista(m, 'rotazioni'))
          RotazioneBackup.fromJson(r, dove)
      ],
      azioni: [
        for (final a in _lista(m, 'azioni')) AzioneBackup.fromJson(a, dove)
      ],
    );
  }
}

class RotazioneBackup {
  const RotazioneBackup({
    required this.squadra,
    required this.posizione,
    required this.giocatoreUid,
  });

  final Squadra squadra;
  final int posizione;
  final String giocatoreUid;

  Map<String, Object?> toJson() => {
        'squadra': squadra.name,
        'posizione': posizione,
        'giocatoreUid': giocatoreUid,
      };

  factory RotazioneBackup.fromJson(Map<String, Object?> m, String contesto) =>
      RotazioneBackup(
        squadra:
            _enumOpt(Squadra.values, m['squadra'] as String?, contesto) ??
                Squadra.nostra,
        posizione: _intero(m, 'posizione', '$contesto, rotazione'),
        giocatoreUid:
            _stringa(m, 'giocatoreUid', '$contesto, rotazione'),
      );
}

/// Un'azione di scout. **Chiavi corte** (`o`, `r`, `f`, `v`, …): sono il 95%
/// del file, e `"fondamentale"` scritto 15.000 volte costa 200 KB di sole
/// chiavi. Le chiavi lunghe restano dove le righe sono poche e la leggibilità
/// a occhio conta più dei byte.
///
/// Le azioni **non hanno `uid`**: si importano a blocchi e la loro identità è
/// `(partita, set, ordine)`. L'`id` interno lo assegna il lettore.
class AzioneBackup {
  const AzioneBackup({
    required this.ordine,
    required this.rallyId,
    required this.secondiDaInizioPartita,
    required this.squadra,
    required this.tipo,
    required this.esitoPunto,
    this.tipoEsecuzione = 'nonSpecificato',
    this.giocatoreUid,
    this.fondamentale,
    this.voto,
    this.traiettoriaX1,
    this.traiettoriaY1,
    this.traiettoriaX2,
    this.traiettoriaY2,
    this.traiettoriaMuroX,
    this.traiettoriaMuroY,
    this.puntiCasaAlMomento,
    this.puntiOspitiAlMomento,
    this.giocatoreUscenteUid,
    this.nuovoPalleggiatoreUid,
    this.nuovoRuoloCambiLibero,
    this.gruppoCambio,
    this.ruoloAvversario,
  });

  final int ordine;
  final int rallyId;

  /// Secondi trascorsi dalla **prima azione della partita**
  /// (`PartitaBackup.inizioAzioni`), non un timestamp assoluto: le durate si
  /// calcolano per differenza, il file è immune al fuso orario di chi lo
  /// rilegge, e il primo tocco è sempre `0`.
  final int secondiDaInizioPartita;
  final Squadra squadra;
  final TipoAzione tipo;
  final EsitoPunto esitoPunto;
  final String tipoEsecuzione;
  final String? giocatoreUid;
  final Fondamentale? fondamentale;
  final Voto? voto;
  final double? traiettoriaX1;
  final double? traiettoriaY1;
  final double? traiettoriaX2;
  final double? traiettoriaY2;
  final double? traiettoriaMuroX;
  final double? traiettoriaMuroY;
  final int? puntiCasaAlMomento;
  final int? puntiOspitiAlMomento;
  final String? giocatoreUscenteUid;
  final String? nuovoPalleggiatoreUid;
  final Ruolo? nuovoRuoloCambiLibero;
  final int? gruppoCambio;
  final String? ruoloAvversario;

  Map<String, Object?> toJson() {
    final m = <String, Object?>{
      'o': ordine,
      'r': rallyId,
      't': secondiDaInizioPartita,
      's': squadra.name,
      'ti': tipo.name,
      'e': esitoPunto.name,
    };
    // 'nonSpecificato' è il default: ometterlo risparmia una chiave su quasi
    // tutte le azioni.
    if (tipoEsecuzione != 'nonSpecificato') m['te'] = tipoEsecuzione;
    _metti(m, 'g', giocatoreUid);
    _metti(m, 'f', fondamentale?.name);
    _metti(m, 'v', voto?.name);
    _metti(m, 'x1', _coord(traiettoriaX1));
    _metti(m, 'y1', _coord(traiettoriaY1));
    _metti(m, 'x2', _coord(traiettoriaX2));
    _metti(m, 'y2', _coord(traiettoriaY2));
    _metti(m, 'mx', _coord(traiettoriaMuroX));
    _metti(m, 'my', _coord(traiettoriaMuroY));
    _metti(m, 'pc', puntiCasaAlMomento);
    _metti(m, 'po', puntiOspitiAlMomento);
    _metti(m, 'gu', giocatoreUscenteUid);
    _metti(m, 'np', nuovoPalleggiatoreUid);
    _metti(m, 'nr', nuovoRuoloCambiLibero?.name);
    _metti(m, 'gc', gruppoCambio);
    _metti(m, 'ra', ruoloAvversario);
    return m;
  }

  factory AzioneBackup.fromJson(Map<String, Object?> m, String contesto) {
    final dove = '$contesto, azione ${m['o']}';
    return AzioneBackup(
      ordine: _intero(m, 'o', dove),
      rallyId: (m['r'] as int?) ?? _intero(m, 'o', dove),
      secondiDaInizioPartita: (m['t'] as int?) ?? 0,
      squadra: _enum(Squadra.values, m['s'] as String?, dove),
      tipo: _enum(TipoAzione.values, m['ti'] as String?, dove),
      esitoPunto: _enum(EsitoPunto.values, m['e'] as String?, dove),
      tipoEsecuzione: (m['te'] as String?) ?? 'nonSpecificato',
      giocatoreUid: m['g'] as String?,
      fondamentale:
          _enumOpt(Fondamentale.values, m['f'] as String?, dove),
      voto: _enumOpt(Voto.values, m['v'] as String?, dove),
      traiettoriaX1: _double(m, 'x1'),
      traiettoriaY1: _double(m, 'y1'),
      traiettoriaX2: _double(m, 'x2'),
      traiettoriaY2: _double(m, 'y2'),
      traiettoriaMuroX: _double(m, 'mx'),
      traiettoriaMuroY: _double(m, 'my'),
      puntiCasaAlMomento: m['pc'] as int?,
      puntiOspitiAlMomento: m['po'] as int?,
      giocatoreUscenteUid: m['gu'] as String?,
      nuovoPalleggiatoreUid: m['np'] as String?,
      nuovoRuoloCambiLibero:
          _enumOpt(Ruolo.values, m['nr'] as String?, dove),
      gruppoCambio: m['gc'] as int?,
      ruoloAvversario: m['ra'] as String?,
    );
  }
}

// --- Campionato (solo ripristino, la dashboard lo salta) --------------------

class CampionatoBackup {
  const CampionatoBackup({
    required this.nome,
    required this.dataImport,
    this.stagione,
    this.squadraPropria,
    this.squadraUid,
    this.gare = const [],
  });

  final String nome;
  final DateTime dataImport;
  final String? stagione;
  final String? squadraPropria;
  final String? squadraUid;
  final List<GaraBackup> gare;

  Map<String, Object?> toJson() {
    final m = <String, Object?>{
      'nome': nome,
      'dataImport': dataImport.toIso8601String(),
      'gare': [for (final g in gare) g.toJson()],
    };
    _metti(m, 'stagione', stagione);
    _metti(m, 'squadraPropria', squadraPropria);
    _metti(m, 'squadraUid', squadraUid);
    return m;
  }

  factory CampionatoBackup.fromJson(Map<String, Object?> m) {
    final dove = 'campionato ${m['nome']}';
    return CampionatoBackup(
      nome: _stringa(m, 'nome', dove),
      dataImport: _dataOpt(m, 'dataImport') ?? DateTime.now(),
      stagione: m['stagione'] as String?,
      squadraPropria: m['squadraPropria'] as String?,
      squadraUid: m['squadraUid'] as String?,
      gare: [for (final g in _lista(m, 'gare')) GaraBackup.fromJson(g, dove)],
    );
  }
}

class GaraBackup {
  const GaraBackup({
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
    this.partitaUid,
  });

  final DateTime dataOra;
  final String squadraCasa;
  final String squadraOspite;
  final int? garaNumero;
  final int? giornata;
  final String? risultato;
  final String? parziali;
  final String? statoDescrizione;
  final String? impianto;
  final String? indirizzoImpianto;

  /// Partita creata da questa gara, se c'è: si esporta l'uid e non l'id, così
  /// il collegamento sopravvive al ripristino su un altro dispositivo.
  final String? partitaUid;

  Map<String, Object?> toJson() {
    final m = <String, Object?>{
      'dataOra': dataOra.toIso8601String(),
      'squadraCasa': squadraCasa,
      'squadraOspite': squadraOspite,
    };
    _metti(m, 'garaNumero', garaNumero);
    _metti(m, 'giornata', giornata);
    _metti(m, 'risultato', risultato);
    _metti(m, 'parziali', parziali);
    _metti(m, 'statoDescrizione', statoDescrizione);
    _metti(m, 'impianto', impianto);
    _metti(m, 'indirizzoImpianto', indirizzoImpianto);
    _metti(m, 'partitaUid', partitaUid);
    return m;
  }

  factory GaraBackup.fromJson(Map<String, Object?> m, String contesto) =>
      GaraBackup(
        dataOra: _data(m, 'dataOra', '$contesto, gara ${m['garaNumero']}'),
        squadraCasa: (m['squadraCasa'] as String?) ?? '',
        squadraOspite: (m['squadraOspite'] as String?) ?? '',
        garaNumero: m['garaNumero'] as int?,
        giornata: m['giornata'] as int?,
        risultato: m['risultato'] as String?,
        parziali: m['parziali'] as String?,
        statoDescrizione: m['statoDescrizione'] as String?,
        impianto: m['impianto'] as String?,
        indirizzoImpianto: m['indirizzoImpianto'] as String?,
        partitaUid: m['partitaUid'] as String?,
      );
}
