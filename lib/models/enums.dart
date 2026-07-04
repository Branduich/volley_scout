enum Categoria {
  under11('Under 11'),
  under12('Under 12'),
  under13('Under 13'),
  under14('Under 14'),
  under16('Under 16'),
  under18('Under 18'),
  terzaDivisione('Terza Divisione'),
  secondaDivisione('Seconda Divisione'),
  primaDivisione('Prima Divisione'),
  serieD('Serie D'),
  serieC('Serie C'),
  serieB('Serie B'),
  serieB1('Serie B1'),
  serieB2('Serie B2'),
  serieA1('Serie A1'),
  serieA2('Serie A2'),
  serieA3('Serie A3');

  final String label;
  const Categoria(this.label);
}

enum Ruolo {
  // "Universale": può giocare al posto di qualsiasi ruolo tranne il libero
  // (assume l'etichetta tattica mancante nella composizione — vedi
  // roleLabelsFor in logic/role_labels.dart). Il nome Dart resta
  // `undefined` per compatibilità: RuoloConverter persiste `.name` a DB
  // (players.ruolo, match_sets.ruolo_cambi_libero,
  // scout_actions.nuovo_ruolo_cambi_libero) e rinominarlo romperebbe
  // byName() sulle righe esistenti.
  undefined('Universale'),
  palleggiatore('Palleggiatore'),
  opposto('Opposto'),
  schiacciatore('Schiacciatore'),
  centrale('Centrale'),
  libero('Libero');

  final String label;
  const Ruolo(this.label);
}

enum Voto {
  perfetto('#'),
  positivo('+'),
  mezzoPunto('/'),
  negativo('-'),
  errore('=');

  final String simbolo;
  const Voto(this.simbolo);
}

enum SistemaGioco {
  palleggiatoreUnico('Palleggiatore unico (5-1)'),
  doppioPalleggiatore('Doppio palleggiatore (6-2)');

  final String label;
  const SistemaGioco(this.label);
}

/// Stato di una partita. Flusso: configurazione → inCorso ↔ sospesa → terminata.
enum StatoPartita { configurazione, inCorso, sospesa, terminata }

/// Nostra squadra o avversari. La rotazione è tracciata solo per `nostra`
/// (l'avversario è un nome libero, senza roster in DB — vedi CLAUDE.md).
enum Squadra { nostra, avversari }

/// Esito di un'azione di scout rispetto al punteggio del set. `nessuno` per
/// le azioni interne a uno scambio che non chiudono il punto (es. ricezione).
enum EsitoPunto { nessuno, puntoNostro, puntoAvversario }

enum Fondamentale {
  battuta('Battuta'),
  ricezione('Ricezione'),
  alzata('Alzata'),
  attacco('Attacco'),
  muro('Muro'),
  difesa('Difesa'),
  errore('Errore');

  final String label;
  const Fondamentale(this.label);

  /// Solo battuta e attacco hanno una traiettoria da registrare.
  bool get richiedeTraiettoria =>
      this == Fondamentale.battuta || this == Fondamentale.attacco;
}

/// Tipo di un'azione registrata nello scout. `scout` = percorso normale
/// (giocatore + fondamentale + voto); `puntoManuale`/`erroreGenerico` sono i
/// bottoni rapidi. `cambioGiocatore` = sostituzione a set in corso
/// ("cambio", non "sostituzione": quel termine è già usato per la meccanica
/// del libero) — `giocatoreId` = chi entra, `esitoPunto = nessuno`, più le
/// colonne dedicate su ScoutActions (uscente + override di configurazione).
enum TipoAzione { scout, puntoManuale, erroreGenerico, cambioGiocatore }

/// Motivo di un `TipoAzione.erroreGenerico` dell'avversario — salvato nella
/// stessa colonna polimorfica `tipoEsecuzione` usata da TipoBattuta/
/// TipoAttacco (qui per `tipo == erroreGenerico` invece che per un
/// fondamentale). Tap singolo sul bottone "Errore avversario" registra
/// `generico` (percorso veloce, invariato); pressione prolungata apre un
/// menu con gli altri motivi — vedi ScoutScreen._buildBottoniAvversario().
enum MotivoErrore {
  generico('Generico'),
  battuta('Battuta'),
  falloDiPosizione('Fallo di posizione'),
  invasione('Invasione');

  final String label;
  const MotivoErrore(this.label);
}

/// Tipo di esecuzione di un attacco — contestuale, opzionale, default
/// `nonSpecificato` per non bloccare il flusso veloce.
enum TipoAttacco {
  nonSpecificato('Non specificato'),
  forte('Forte'),
  piazzata('Piazzata'),
  pallonetto('Pallonetto');

  final String label;
  const TipoAttacco(this.label);
}

/// Tipo di esecuzione di una battuta — stessa logica di TipoAttacco.
enum TipoBattuta {
  nonSpecificato('Non specificato'),
  dalBasso('Dal basso'),
  float('Float'),
  salto('Salto'),
  saltoFloat('Salto float');

  final String label;
  const TipoBattuta(this.label);
}
