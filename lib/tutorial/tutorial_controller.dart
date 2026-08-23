import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../l10n/app_localizations.dart';
import 'tutorial_steps.dart';
import 'tutorial_target.dart';

/// Eventi di `ScoutScreen` che non sono né un tap su un target né un'azione
/// scritta a DB. Volutamente pochissimi: ogni segnale è una riga in più dentro
/// `scout_screen.dart`, e l'obiettivo è tenerne il meno possibile.
/// `traiettoriaDisegnata`: il tratto è stato catturato al rilascio del dito.
/// Serve ai passi che insegnano il trascinamento — agganciarli al tocco sul
/// token non basta, perché la battuta si può far partire da tutta la linea di
/// fondo e in quel caso l'ancora del token non scatta mai (vedi
/// `_aperturaBattitore` in scout_screen).
enum SegnaleTutorial { drawerAperto, drawerChiuso, traiettoriaDisegnata }

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

  /// Passo a **campo libero**: l'overlay non disegna né velo né card.
  ///
  /// Serve dove l'azione da insegnare è un trascinamento sul campo: la card,
  /// piazzata accanto al bersaglio, finirebbe proprio sopra alla traiettoria
  /// che stai tracciando, e il velo lascerebbe in chiaro solo il buco. Qui non
  /// c'è un bersaglio da isolare — c'è tutto il campo da guardare.
  ///
  /// La spiegazione lunga va nella card del passo PRECEDENTE (informativo, con
  /// "Avanti"); qui [testo] diventa il promemoria di **una riga** mostrato da
  /// `ScoutScreen` nella fascia centrale fra i due tasti timeout, che è
  /// l'unico spazio orizzontale libero e non toglie altezza al campo.
  ///
  /// L'avanzamento non richiede niente di nuovo: `avanzaSuTap` scatta al
  /// RILASCIO del dito sul token (l'ancora usa `onPointerUp`), cioè alla fine
  /// del trascinamento.
  final bool campoLibero;

  /// Se in questo passo si può disegnare la traiettoria sul campo.
  ///
  /// **Spenta di default**, e girata così di proposito: durante il tutorial
  /// ogni passo deve essere deterministico, quindi il disegno si accende solo
  /// dove lo si insegna. Bloccare a mano i singoli passi vorrebbe dire
  /// ricordarsene a ogni card nuova, e prima o poi ne sfuggirebbe una.
  ///
  /// Non blocca il TRASCINAMENTO: il pezzo che apre il pannello partendo dal
  /// token vive prima di questo gate (vedi `_onPointerMoveCampo`), quindi chi
  /// trascina si ritrova la pulsantiera aperta come se avesse toccato,
  /// semplicemente senza freccia. Nessun gesto che non fa niente.
  ///
  /// Fuori dal tutorial non conta: lì decidono impostazioni e premium
  /// (`ScoutScreen._traiettorieInLineConsentite`).
  final bool traiettoriaConsentita;

  final bool avanzaSuTap;
  final TutorialTarget? avanzaSuComparsaDi;
  final SegnaleTutorial? avanzaSuSegnale;

  /// Riceve il log completo del set e la sua lunghezza all'ingresso nel passo
  /// (per riconoscere un undo: `log.length < lunghezzaIniziale`).
  final bool Function(List<ScoutAction> log, int lunghezzaIniziale)? avanzaSuLog;

  /// Rete di sicurezza per i passi a CAMPO LIBERO: se dopo questo tempo
  /// l'utente non ha fatto il gesto, l'app lo aiuta da sé — apre la
  /// pulsantiera come farebbe il tocco e manda avanti il passo.
  ///
  /// Serve perché lì non ci sono né velo né card: chi non capisce cosa fare
  /// resta davanti a uno schermo che non glielo ripete. Aiutare NON può
  /// limitarsi ad avanzare: il passo successivo ha il buco su un bottone della
  /// pulsantiera, e se quella non è aperta il bersaglio non esiste — un velo
  /// senza buco assorbe ogni tocco e il blocco diventa totale.
  ///
  /// `null` = nessun aiuto.
  final Duration? aiutoDopo;

  /// Passo condizionale: se torna false il passo viene saltato (es. la
  /// spiegazione delle traiettorie non ha senso se sono disattivate).
  final bool Function(Ref ref)? mostraSe;

  const PassoTutorial({
    required this.testo,
    this.titolo,
    this.bersaglio,
    this.bersaglioSecondario,
    this.lato = LatoCard.automatico,
    this.url,
    this.mail,
    this.avanzaConBottone = false,
    this.etichettaBottone,
    this.campoLibero = false,
    this.aiutoDopo,
    this.traiettoriaConsentita = false,
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

  /// Avanzamento forzato dalla rete di sicurezza (vedi PassoTutorial.aiutoDopo):
  /// non passa da nessun predicato, perché il gesto atteso non è avvenuto ed è
  /// l'app ad averlo surrogato.
  void avanzaPerAiuto() => _avanza();

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
