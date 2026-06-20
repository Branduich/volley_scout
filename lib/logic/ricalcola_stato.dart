import '../models/enums.dart';

/// Azione minimale necessaria al ricalcolo: solo l'ordine (per il
/// sequenziamento) e l'esito che ha prodotto sul punteggio. Gli altri campi
/// della futura tabella ScoutAction (giocatore, fondamentale, voto,
/// traiettoria...) non servono a questa funzione, quindi non compaiono qui —
/// chi persiste le azioni a DB estrarrà solo questi due campi per il ricalcolo.
typedef AzioneScout = ({int ordine, EsitoPunto esitoPunto});

/// Stato di un set calcolato rigiocando la sequenza di azioni: punteggio e
/// rotazione corrente. La rotazione riguarda solo la nostra squadra — per gli
/// avversari (nome libero, senza roster) si traccia solo chi è al servizio.
class StatoSet {
  final int punteggioNostro;
  final int punteggioAvversario;
  final Squadra squadraAlServizio;
  final Map<int, int> rotazione; // posizione 1-6 -> giocatoreId (solo nostra)

  const StatoSet({
    required this.punteggioNostro,
    required this.punteggioAvversario,
    required this.squadraAlServizio,
    required this.rotazione,
  });

  @override
  bool operator ==(Object other) {
    if (other is! StatoSet) return false;
    if (other.punteggioNostro != punteggioNostro ||
        other.punteggioAvversario != punteggioAvversario ||
        other.squadraAlServizio != squadraAlServizio ||
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
        Object.hashAllUnordered(
          rotazione.entries.map((e) => Object.hash(e.key, e.value)),
        ),
      );

  @override
  String toString() =>
      'StatoSet(nostro: $punteggioNostro, avversario: $punteggioAvversario, '
      'al servizio: $squadraAlServizio, rotazione: $rotazione)';
}

/// Ricalcola punteggio e rotazione corrente di un set rigiocando, in ordine,
/// la sequenza di azioni registrate. Funzione pura (stesso input -> stesso
/// output, nessuna dipendenza da DB o UI): è il cuore logico dello scout.
/// Punteggio e rotazione non sono mai stato mutabile salvato, ma sempre
/// derivati da qui — undo = rimuovi l'ultima azione (per `ordine`) e richiama
/// questa funzione; riprendi partita = richiamala con le azioni salvate.
StatoSet ricalcolaStato({
  required List<AzioneScout> azioni,
  required Squadra servizioIniziale,
  required Map<int, int> rotazioneIniziale,
}) {
  var punteggioNostro = 0;
  var punteggioAvversario = 0;
  var alServizio = servizioIniziale;
  var rotazione = Map<int, int>.from(rotazioneIniziale);

  final ordinate = [...azioni]..sort((a, b) => a.ordine.compareTo(b.ordine));

  for (final azione in ordinate) {
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
