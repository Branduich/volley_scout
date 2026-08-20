/// Le formule delle statistiche per fondamentale, in un posto solo.
///
/// Prima vivevano in **tre copie**: le celle della mega tabella del PDF, le
/// card Efficienza/Positività del report a video e la percentuale generica.
/// A tenerle allineate c'era un commento — *"Stesse formule delle card del
/// report a video"* — che è esattamente il tipo di garanzia che salta la prima
/// volta che qualcuno cambia una definizione e dimentica l'altra copia.
///
/// Tutte tornano `null` quando non ci sono azioni, invece di 0: "nessun dato"
/// e "zero per cento" sono cose diverse, e chi disegna mostra `—` per il primo.
/// La **formattazione resta fuori** (il PDF scrive interi in celle strette, il
/// report a video ha una card colorata, il web avrà altro ancora).
library;

import 'enums.dart';

/// Quante azioni votate ci sono in tutto.
int totaleVoti(Map<Voto, int> conteggi) =>
    conteggi.values.fold(0, (a, b) => a + b);

int conteggioVoto(Map<Voto, int> conteggi, Voto voto) => conteggi[voto] ?? 0;

/// Percentuale, oppure `null` con totale zero (mai una divisione per zero).
/// Può essere negativa: l'efficienza lo è quando gli errori superano i punti.
double? percentuale(int numeratore, int totale) =>
    totale == 0 ? null : numeratore * 100 / totale;

/// Efficienza = (punti − errori) / totale × 100.
///
/// `punti` sono i voti `#`, `errori` i voti `=`, `totale` **tutte** le azioni
/// votate di quel fondamentale — comprese quelle di mezzo, che abbassano la
/// percentuale senza comparire al numeratore.
double? efficienza({
  required int punti,
  required int errori,
  required int totale,
}) =>
    percentuale(punti - errori, totale);

/// Come [efficienza] ma dai conteggi per voto.
double? efficienzaDaVoti(Map<Voto, int> conteggi) => efficienza(
      punti: conteggioVoto(conteggi, Voto.perfetto),
      errori: conteggioVoto(conteggi, Voto.errore),
      totale: totaleVoti(conteggi),
    );

/// Positività = (perfette + positive) / totale × 100 — per ricezione e difesa,
/// dove il `#` non porta punto ma dice quanto bene si è gestita la palla.
double? positivita({required int positive, required int totale}) =>
    percentuale(positive, totale);

/// Come [positivita] ma dai conteggi per voto: somma `#` e `+`.
double? positivitaDaVoti(Map<Voto, int> conteggi) => positivita(
      positive: conteggioVoto(conteggi, Voto.perfetto) +
          conteggioVoto(conteggi, Voto.positivo),
      totale: totaleVoti(conteggi),
    );
