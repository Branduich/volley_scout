import '../models/enums.dart';

/// Cambio giocatore (sostituzione a set in corso, TipoAzione.cambioGiocatore
/// a DB — "cambio" e non "sostituzione" perché quel termine è già usato per
/// la meccanica del libero). Il subentrante prende ESATTAMENTE la posizione
/// di rotazione dell'uscente e ruota da lì in poi: il cambio non altera mai
/// la rotazione, solo chi occupa una posizione. Gli override di
/// configurazione (nuovo palleggiatore designato, nuova coppia cambi-libero)
/// viaggiano nello stesso evento — null = invariato.
class SostituzioneGiocatore {
  final int esceId;
  final int entraId;
  final int? nuovoPalleggiatoreId; // null = invariato
  final Ruolo? nuovoRuoloCambiLibero; // null = invariato

  const SostituzioneGiocatore({
    required this.esceId,
    required this.entraId,
    this.nuovoPalleggiatoreId,
    this.nuovoRuoloCambiLibero,
  });
}

/// Azione minimale necessaria al ricalcolo: solo l'ordine (per il
/// sequenziamento), l'esito che ha prodotto sul punteggio e l'eventuale
/// cambio giocatore. Gli altri campi della tabella ScoutAction (giocatore,
/// fondamentale, voto, traiettoria...) non servono a questa funzione, quindi
/// non compaiono qui — chi persiste le azioni a DB estrae solo questi campi
/// per il ricalcolo (vedi azioneScoutDaRiga in database_provider.dart).
class AzioneScout {
  final int ordine;
  final EsitoPunto esitoPunto;
  final SostituzioneGiocatore? sostituzione; // null per le azioni normali

  const AzioneScout({
    required this.ordine,
    required this.esitoPunto,
    this.sostituzione,
  });
}

/// Stato di un set calcolato rigiocando la sequenza di azioni: punteggio,
/// rotazione corrente e configurazione effettiva (palleggiatore designato,
/// coppia cambi-libero — possono cambiare a set in corso con un cambio
/// giocatore). La rotazione riguarda solo la nostra squadra — per gli
/// avversari (nome libero, senza roster) si traccia solo chi è al servizio.
class StatoSet {
  final int punteggioNostro;
  final int punteggioAvversario;
  final Squadra squadraAlServizio;
  final Map<int, int> rotazione; // posizione 1-6 -> giocatoreId (solo nostra)
  final int? palleggiatoreId; // palleggiatore designato effettivo
  final Ruolo? ruoloCambiLibero; // coppia cambi-libero effettiva
  final int? liberoId; // libero L1 effettivo (cambia solo libero-per-libero)
  final int? libero2Id; // libero L2 effettivo

  const StatoSet({
    required this.punteggioNostro,
    required this.punteggioAvversario,
    required this.squadraAlServizio,
    required this.rotazione,
    this.palleggiatoreId,
    this.ruoloCambiLibero,
    this.liberoId,
    this.libero2Id,
  });

  @override
  bool operator ==(Object other) {
    if (other is! StatoSet) return false;
    if (other.punteggioNostro != punteggioNostro ||
        other.punteggioAvversario != punteggioAvversario ||
        other.squadraAlServizio != squadraAlServizio ||
        other.palleggiatoreId != palleggiatoreId ||
        other.ruoloCambiLibero != ruoloCambiLibero ||
        other.liberoId != liberoId ||
        other.libero2Id != libero2Id ||
        other.rotazione.length != rotazione.length) {
      return false;
    }
    for (final entry in rotazione.entries) {
      if (other.rotazione[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        punteggioNostro,
        punteggioAvversario,
        squadraAlServizio,
        palleggiatoreId,
        ruoloCambiLibero,
        liberoId,
        libero2Id,
        Object.hashAllUnordered(
          rotazione.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  @override
  String toString() =>
      'StatoSet(nostro: $punteggioNostro, avversario: $punteggioAvversario, '
      'al servizio: $squadraAlServizio, rotazione: $rotazione, '
      'palleggiatore: $palleggiatoreId, cambiLibero: $ruoloCambiLibero, '
      'liberi: $liberoId/$libero2Id)';
}

/// Ricalcola punteggio e rotazione corrente di un set rigiocando, in ordine,
/// la sequenza di azioni registrate. Funzione pura (stesso input -> stesso
/// output, nessuna dipendenza da DB o UI): è il cuore logico dello scout.
/// Punteggio e rotazione non sono mai stato mutabile salvato, ma sempre
/// derivati da qui — undo = rimuovi l'ultima azione (per `ordine`) e richiama
/// questa funzione; riprendi partita = richiamala con le azioni salvate.
///
/// `palleggiatoreInizialeId`/`ruoloCambiLiberoIniziale` sono opzionali (i
/// chiamanti che non hanno bisogno della configurazione effettiva — es. il
/// solo punteggio nei report — possono ometterli): partono dal valore
/// iniziale del set e seguono gli override dei cambi giocatore.
StatoSet ricalcolaStato({
  required List<AzioneScout> azioni,
  required Squadra servizioIniziale,
  required Map<int, int> rotazioneIniziale,
  int? palleggiatoreInizialeId,
  Ruolo? ruoloCambiLiberoIniziale,
  int? liberoInizialeId,
  int? libero2InizialeId,
}) {
  var punteggioNostro = 0;
  var punteggioAvversario = 0;
  var alServizio = servizioIniziale;
  var rotazione = Map<int, int>.from(rotazioneIniziale);
  var palleggiatoreId = palleggiatoreInizialeId;
  var ruoloCambiLibero = ruoloCambiLiberoIniziale;
  var liberoId = liberoInizialeId;
  var libero2Id = libero2InizialeId;

  final ordinate = [...azioni]..sort((a, b) => a.ordine.compareTo(b.ordine));

  for (final azione in ordinate) {
    final sostituzione = azione.sostituzione;
    if (sostituzione != null) {
      // Se esce un LIBERO (mai in rotazione), il cambio aggiorna il libero
      // effettivo (solo libero-per-libero, vincolo di dominio); altrimenti
      // il subentrante prende la posizione di rotazione dell'uscente — la
      // rotazione non cambia mai. Righe incoerenti → no-op, mai lanciare
      // durante un replay: uscente non presente (né in rotazione né come
      // libero) o subentrante GIÀ presente (applicarla duplicherebbe lo
      // stesso giocatore — ValueKey duplicate in UI, dati corrotti).
      // Eccezione: esceId == entraId è la riga "no-op" legittima usata per
      // una riconfigurazione senza cambi (porta solo gli override).
      final esce = sostituzione.esceId;
      final entra = sostituzione.entraId;
      final duplicherebbe = esce != entra &&
          (rotazione.containsValue(entra) ||
              entra == liberoId ||
              entra == libero2Id);
      if (!duplicherebbe) {
        if (esce == liberoId) {
          liberoId = entra;
        } else if (esce == libero2Id) {
          libero2Id = entra;
        } else {
          rotazione = {
            for (final entry in rotazione.entries)
              entry.key: entry.value == esce ? entra : entry.value,
          };
        }
        palleggiatoreId =
            sostituzione.nuovoPalleggiatoreId ?? palleggiatoreId;
        ruoloCambiLibero =
            sostituzione.nuovoRuoloCambiLibero ?? ruoloCambiLibero;
      }
    }

    switch (azione.esitoPunto) {
      case EsitoPunto.nessuno:
        break;
      case EsitoPunto.puntoNostro:
        punteggioNostro++;
        // Sideout: se non eravamo già al servizio, ruotiamo.
        if (alServizio != Squadra.nostra) {
          rotazione = _ruotata(rotazione);
        }
        alServizio = Squadra.nostra;
      case EsitoPunto.puntoAvversario:
        punteggioAvversario++;
        // Il sideout è degli avversari: passano al servizio, ma non
        // tracciamo una loro rotazione (nessun roster avversario).
        alServizio = Squadra.avversari;
    }
  }

  return StatoSet(
    punteggioNostro: punteggioNostro,
    punteggioAvversario: punteggioAvversario,
    squadraAlServizio: alServizio,
    rotazione: rotazione,
    palleggiatoreId: palleggiatoreId,
    ruoloCambiLibero: ruoloCambiLibero,
    liberoId: liberoId,
    libero2Id: libero2Id,
  );
}

/// Rotazione oraria di un sideout: chi era in posizione p+1 si sposta in
/// posizione p (la posizione 1, il battitore, eredita chi era in posizione
/// 2; la posizione 6 eredita chi era in posizione 1).
Map<int, int> _ruotata(Map<int, int> rotazione) {
  return {
    for (var pos = 1; pos <= 6; pos++) pos: rotazione[(pos % 6) + 1]!,
  };
}
