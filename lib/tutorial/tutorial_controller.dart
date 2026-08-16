import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import 'tutorial_steps.dart';
import 'tutorial_target.dart';

/// Eventi di `ScoutScreen` che non sono né un tap su un target né un'azione
/// scritta a DB. Volutamente pochissimi: ogni segnale è una riga in più dentro
/// `scout_screen.dart`, e l'obiettivo è tenerne il meno possibile.
enum SegnaleTutorial { drawerAperto, drawerChiuso }

/// Dove mettere la card rispetto all'elemento evidenziato.
///
/// [automatico] sceglie tra sopra e sotto in base allo spazio — va bene quasi
/// sempre. Serve indicarlo a mano quando il bersaglio fa parte di un gruppo
/// che non va coperto: sul pulsante di un voto, per esempio, una card sopra o
/// sotto nasconde gli altri quattro voti della colonna, e va spostata di lato.
enum LatoCard { automatico, sopra, sotto, sinistra, destra }

/// Un passo del tutorial: cosa mostrare e **quando considerarlo superato**.
///
/// I quattro meccanismi di avanzamento sono mutuamente alternativi (se ne
/// valorizza uno solo):
/// - [avanzaConBottone]: passo informativo, l'utente preme "Avanti";
/// - [avanzaSuTap]: si preme il [bersaglio] (segnale dal `Listener` di
///   `_anchor`, che intercetta il tocco senza rubarlo al bottone vero);
/// - [avanzaSuComparsaDi]: compare a schermo un ALTRO target — è così che si
///   riconosce un cambio di stato della UI (pannello voto aperto, scelta del
///   fondamentale) senza far esporre stato interno a `ScoutScreen`;
/// - [avanzaSuLog]: predicato sul log di `ScoutAction` persistito, l'unico
///   modo davvero affidabile per dire "l'azione è stata registrata" (ed è
///   anche l'unico che intercetta un undo, dove il log si accorcia).
@immutable
class PassoTutorial {
  /// Testo della spiegazione (per ora hardcoded in italiano: la lista dei
  /// passi non è ancora stabile, si sposta in ARB quando lo sarà).
  final String testo;
  final String? titolo;

  /// Nota da mostrare su `TrajectoryScreen`, se questo passo ci passa (voto di
  /// battuta o attacco con le traiettorie attive). Lì l'azione è un
  /// trascinamento sul campo, non un pulsante: niente buco nel velo, solo un
  /// riquadro che non intercetta il tocco. `null` = nessuna nota.
  final String? testoTraiettoria;

  /// Elemento da evidenziare col buco nello scrim. `null` = card centrale e
  /// scrim pieno (nulla è premibile a parte i bottoni della card).
  final TutorialTarget? bersaglio;

  /// Secondo elemento da includere nel buco: il ritaglio diventa il rettangolo
  /// che contiene entrambi. Serve quando una stessa funzione è composta da due
  /// widget distinti e vicini — la mini-mappa e i suoi bottoni di correzione.
  /// Da non usare per bersagli lontani: il buco inghiottirebbe tutto quello
  /// che sta in mezzo.
  final TutorialTarget? bersaglioSecondario;

  final LatoCard lato;

  /// Pagina web da offrire con un pulsante in fondo alla card, e indirizzo a
  /// cui scrivere. Pulsanti e non link nel testo: bersagli molto più comodi da
  /// centrare col dito di una riga di testo, e niente `TapGestureRecognizer`
  /// da creare e liberare a mano.
  final String? url;
  final String? mail;

  final bool avanzaConBottone;

  /// Etichetta del bottone quando [avanzaConBottone] è true. `null` = quella
  /// di default ("Avanti"), che la card risolve da `AppLocalizations`: qui non
  /// può stare, il default di un parametro deve essere const.
  final String? etichettaBottone;

  final bool avanzaSuTap;
  final TutorialTarget? avanzaSuComparsaDi;
  final SegnaleTutorial? avanzaSuSegnale;

  /// Riceve il log completo del set e la sua lunghezza all'ingresso nel passo
  /// (per riconoscere un undo: `log.length < lunghezzaIniziale`).
  final bool Function(List<ScoutAction> log, int lunghezzaIniziale)? avanzaSuLog;

  /// Passo condizionale: se torna false il passo viene saltato (es. la
  /// spiegazione delle traiettorie non ha senso se sono disattivate).
  final bool Function(Ref ref)? mostraSe;

  const PassoTutorial({
    required this.testo,
    this.titolo,
    this.testoTraiettoria,
    this.bersaglio,
    this.bersaglioSecondario,
    this.lato = LatoCard.automatico,
    this.url,
    this.mail,
    this.avanzaConBottone = false,
    this.etichettaBottone,
    this.avanzaSuTap = false,
    this.avanzaSuComparsaDi,
    this.avanzaSuSegnale,
    this.avanzaSuLog,
    this.mostraSe,
  });
}

@immutable
class StatoTutorial {
  final bool attivo;
  final int indice;

  /// Lunghezza del log all'ingresso nel passo corrente — riferimento per i
  /// predicati di [PassoTutorial.avanzaSuLog].
  final int logIniziale;

  /// True quando l'ultimo passo è stato superato: l'overlay mostra la card di
  /// chiusura e poi esce.
  final bool completato;

  const StatoTutorial({
    this.attivo = false,
    this.indice = 0,
    this.logIniziale = 0,
    this.completato = false,
  });
}

class TutorialController extends Notifier<StatoTutorial> {
  /// Registro delle GlobalKey dei target. Vive qui (e non in `ScoutScreen`)
  /// perché deve sopravvivere ai rebuild della schermata.
  final RegistroTarget registro = RegistroTarget();

  List<PassoTutorial> _passi = const [];

  @override
  StatoTutorial build() => const StatoTutorial();

  List<PassoTutorial> get passi => _passi;

  PassoTutorial? get passo => state.attivo && state.indice < _passi.length
      ? _passi[state.indice]
      : null;

  /// [l] serve a costruire i passi già tradotti: la sequenza si compone una
  /// volta sola all'avvio, quindi le stringhe si risolvono qui e non a ogni
  /// build della card.
  void inizia(AppLocalizations l) {
    registro.clear();
    _passi = [
      for (final p in passiTutorial(l)) if (p.mostraSe?.call(ref) ?? true) p,
    ];
    state = const StatoTutorial(attivo: true);
  }

  void termina() {
    _passi = const [];
    state = const StatoTutorial();
  }

  void tapSuTarget(TutorialTarget target) {
    final corrente = passo;
    if (corrente == null) return;
    if (corrente.avanzaSuTap && corrente.bersaglio == target) _avanza();
  }

  void segnale(SegnaleTutorial segnale) {
    if (passo?.avanzaSuSegnale == segnale) _avanza();
  }

  /// Chiamata dall'overlay quando compare a schermo il rect di [target].
  void rectComparso(TutorialTarget target) {
    if (passo?.avanzaSuComparsaDi == target) _avanza();
  }

  /// Chiamata dall'overlay a ogni emissione dello stream delle azioni del set.
  void logAggiornato(List<ScoutAction> log) {
    final corrente = passo;
    final predicato = corrente?.avanzaSuLog;
    if (predicato == null) return;
    if (predicato(log, state.logIniziale)) _avanza(lunghezzaLog: log.length);
  }

  void avantiManuale() {
    if (passo?.avanzaConBottone ?? false) _avanza();
  }

  /// Salta al passo successivo. Sempre **differito di un frame**: viene
  /// invocata da `onPointerUp`, da un `ref.listen` o da un callback di layout,
  /// cioè da posti dove mutare lo stato subito significherebbe rebuildare
  /// durante il dispatch di un evento o durante un build.
  void _avanza({int? lunghezzaLog}) {
    final prossimo = state.indice + 1;
    final logIniziale = lunghezzaLog ?? state.logIniziale;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!state.attivo || state.indice != prossimo - 1) return; // già avanzato
      state = StatoTutorial(
        attivo: true,
        indice: prossimo,
        logIniziale: logIniziale,
        completato: prossimo >= _passi.length,
      );
    });
  }
}

final tutorialControllerProvider =
    NotifierProvider<TutorialController, StatoTutorial>(TutorialController.new);
