import '../models/enums.dart';
import 'app_localizations.dart';

/// Etichette localizzate degli enum, tenute FUORI da `enums.dart` (che resta
/// senza dipendenze da Flutter/AppLocalizations). `Voto.simbolo` NON è qui:
/// è un simbolo grafico, non testo da tradurre.
///
/// Sono **funzioni top-level** (non estensioni con metodo `label`) di
/// proposito: gli enum hanno ancora il campo `label` (usato dagli export non
/// ancora migrati), e un membro d'istanza vincerebbe su un metodo di
/// estensione omonimo. Una funzione non va mai in conflitto — quando tutti i
/// call site saranno migrati si potrà rimuovere il campo `label` dall'enum.

/// Nome localizzato del [TipoBattuta] (chip su TrajectoryScreen, CSV/PDF,
/// distribuzione tipi nel report). Il `.name` resta la chiave polimorfica
/// salvata a DB nella colonna `tipoEsecuzione`.
String tipoBattutaLabel(TipoBattuta t, AppLocalizations l) => switch (t) {
      TipoBattuta.nonSpecificato => l.tipoBattutaGenerico,
      TipoBattuta.dalBasso => l.tipoBattutaDalBasso,
      TipoBattuta.float => l.tipoBattutaFloat,
      TipoBattuta.salto => l.tipoBattutaSalto,
      TipoBattuta.saltoFloat => l.tipoBattutaSaltoFloat,
    };

/// Nome localizzato del [TipoAttacco] (chip su TrajectoryScreen, CSV/PDF,
/// distribuzione tipi nel report). Il `.name` resta la chiave polimorfica
/// salvata a DB nella colonna `tipoEsecuzione`.
String tipoAttaccoLabel(TipoAttacco t, AppLocalizations l) => switch (t) {
      TipoAttacco.nonSpecificato => l.tipoAttaccoGenerico,
      TipoAttacco.forte => l.tipoAttaccoForte,
      TipoAttacco.piazzata => l.tipoAttaccoPiazzata,
      TipoAttacco.pallonetto => l.tipoAttaccoPallonetto,
    };

/// Nome localizzato del [MotivoErrore] (popup/banner errore avversario nello
/// scout, chip report, riga PDF, CSV). Il `.name` resta la chiave polimorfica
/// salvata a DB nella colonna `tipoEsecuzione`.
String motivoErroreLabel(MotivoErrore m, AppLocalizations l) => switch (m) {
      MotivoErrore.generico => l.motivoErroreGenerico,
      MotivoErrore.battuta => l.motivoErroreBattuta,
      MotivoErrore.falloDiPosizione => l.motivoErroreFalloDiPosizione,
      MotivoErrore.invasione => l.motivoErroreInvasione,
    };

/// Nome localizzato del [SistemaGioco] (dropdown in FormationConfigScreen).
String sistemaGiocoLabel(SistemaGioco s, AppLocalizations l) => switch (s) {
      SistemaGioco.palleggiatoreUnico => l.sistemaGiocoPalleggiatoreUnico,
      SistemaGioco.doppioPalleggiatore => l.sistemaGiocoDoppioPalleggiatore,
    };

/// Nome localizzato del [Fondamentale] (banner scout, pannelli voto, dropdown
/// dei report, colonna CSV). Il `.name` resta la chiave persistita a DB
/// (FondamentaleConverter).
String fondamentaleLabel(Fondamentale f, AppLocalizations l) => switch (f) {
      Fondamentale.battuta => l.fondamentaleBattuta,
      Fondamentale.ricezione => l.fondamentaleRicezione,
      Fondamentale.alzata => l.fondamentaleAlzata,
      Fondamentale.attacco => l.fondamentaleAttacco,
      Fondamentale.muro => l.fondamentaleMuro,
      Fondamentale.difesa => l.fondamentaleDifesa,
      Fondamentale.errore => l.fondamentaleErrore,
    };

/// Nome completo del [Ruolo] nella lingua dell'app (dropdown, card, report).
String ruoloLabel(Ruolo r, AppLocalizations l) => switch (r) {
      Ruolo.palleggiatore => l.ruoloPalleggiatore,
      Ruolo.opposto => l.ruoloOpposto,
      Ruolo.schiacciatore => l.ruoloSchiacciatore,
      Ruolo.centrale => l.ruoloCentrale,
      Ruolo.libero => l.ruoloLibero,
      Ruolo.undefined => l.ruoloUniversale,
    };

/// Sigla localizzata a partire dal CODICE INTERNO STABILE
/// (`P`/`O`/`S1`/`S2`/`C1`/`C2`/`Libero`), usato come chiave nelle mappe
/// posizione (`attack_positions`/`defense_positions`) e salvato a DB
/// (`ScoutActions.ruoloAvversario`). I codici NON cambiano mai: qui si
/// traduce solo la resa a video (es. EN: `P`→`S`, `S1`→`OH1`, `C1`→`MB1`).
/// Fallback = il codice stesso (universali senza etichetta, dati inattesi).
String siglaRuolo(String code, AppLocalizations l) => switch (code) {
      'P' => l.siglaPalleggiatore,
      'O' => l.siglaOpposto,
      'S1' => '${l.siglaSchiacciatore}1',
      'S2' => '${l.siglaSchiacciatore}2',
      'C1' => '${l.siglaCentrale}1',
      'C2' => '${l.siglaCentrale}2',
      'Libero' => l.siglaLibero,
      'U' => l.siglaUniversale,
      _ => code,
    };

/// Sigla base localizzata di un [Ruolo] (senza numero di posizione), per la
/// colonna "R" della mega tabella PDF. Es. EN: Palleggiatore→`S`,
/// Schiacciatore→`OH`, Centrale→`MB`.
String siglaRuoloBreve(Ruolo r, AppLocalizations l) => switch (r) {
      Ruolo.palleggiatore => l.siglaPalleggiatore,
      Ruolo.opposto => l.siglaOpposto,
      Ruolo.schiacciatore => l.siglaSchiacciatore,
      Ruolo.centrale => l.siglaCentrale,
      Ruolo.libero => l.siglaLibero,
      Ruolo.undefined => l.siglaUniversale,
    };

/// Nome completo del codice ruolo avversario per i selettori/titoli del
/// report (sostituisce `kAliasRuoloAvversario`). Codice interno invariato.
String aliasRuoloAvversario(String code, AppLocalizations l) => switch (code) {
      'P' => l.ruoloPalleggiatore,
      'O' => l.ruoloOpposto,
      'S1' => '${l.ruoloSchiacciatore} 1',
      'S2' => '${l.ruoloSchiacciatore} 2',
      'C1' => '${l.ruoloCentrale} 1',
      'C2' => '${l.ruoloCentrale} 2',
      _ => code,
    };

/// Etichetta del formato CSV nella pagina Impostazioni. Il separatore mostrato
/// fra parentesi è quello reale del file (campi e decimali).
String formatoCsvLabel(FormatoCsv f, AppLocalizations l) => switch (f) {
      FormatoCsv.europeo => l.settingsCsvFormatoEuropeo,
      FormatoCsv.internazionale => l.settingsCsvFormatoInternazionale,
    };
