/// Dai dati del backup ai **tiri** da disegnare: l'adapter che mancava al capo
/// della dashboard (passo 12 del piano in docs/dati-stagionali.md).
///
/// `TiroScout` esiste apposta perché la geometria non dipenda né da drift né
/// dal DTO del file. L'app converte le righe (`tiroDaRiga` in
/// `logic/heatmap.dart`), qui si convertono le `AzioneBackup`: due adapter, un
/// solo disegno.
library;

import 'backup_model.dart';
import 'enums.dart';
import 'filtro.dart';
import 'tiro_scout.dart';

/// Un'azione del file ridotta ai campi che la geometria legge.
TiroScout tiroDaAzione(AzioneBackup a) => TiroScout(
      squadra: a.squadra,
      tipo: a.tipo,
      fondamentale: a.fondamentale,
      voto: a.voto,
      tipoEsecuzione: a.tipoEsecuzione,
      x1: a.traiettoriaX1,
      y1: a.traiettoriaY1,
      x2: a.traiettoriaX2,
      y2: a.traiettoriaY2,
      muroX: a.traiettoriaMuroX,
      muroY: a.traiettoriaMuroY,
    );

/// Se un'azione ha davvero una traiettoria da disegnare.
///
/// Le quattro coordinate o ci sono tutte o non c'è niente: mezza freccia non
/// si disegna, e chi la riceve dovrebbe controllarle una per una.
bool haTraiettoria(AzioneBackup a) =>
    a.traiettoriaX1 != null &&
    a.traiettoriaY1 != null &&
    a.traiettoriaX2 != null &&
    a.traiettoriaY2 != null;

/// I tiri di un fondamentale che passano il [filtro], pronti da disegnare.
///
/// Solo `battuta` e `attacco` hanno una traiettoria; per gli altri esce una
/// lista vuota invece di un errore, perché è un'interfaccia a scegliere il
/// fondamentale e un menu può contenere anche voci senza dati.
///
/// [giocatoreUid] `null` = tutta la squadra. [squadra] permette di chiedere i
/// tiri AVVERSARI, che sono quelli che alimentano la heatmap di ricezione.
List<TiroScout> tiriFiltrati(
  BackupCompleto backup, {
  required Fondamentale fondamentale,
  Filtro filtro = const Filtro(),
  String? giocatoreUid,
  Squadra squadra = Squadra.nostra,
}) {
  if (!fondamentale.richiedeTraiettoria) return const [];
  final tiri = <TiroScout>[];
  for (final selezione in partiteFiltrate(backup, filtro)) {
    for (final set in selezione.sets) {
      for (final a in set.azioni) {
        if (a.tipo != TipoAzione.scout) continue;
        if (a.fondamentale != fondamentale) continue;
        if (a.squadra != squadra) continue;
        // Il filtro per giocatrice vale solo dalla NOSTRA parte: le azioni
        // avversarie non hanno un uid, sono registrate per ruolo.
        if (giocatoreUid != null && a.giocatoreUid != giocatoreUid) continue;
        if (!haTraiettoria(a)) continue;
        tiri.add(tiroDaAzione(a));
      }
    }
  }
  return tiri;
}

/// Come sono finiti quei tiri: il conto che sta sotto al campo.
///
/// Senza, un campo pieno di frecce non dice se è andata bene o male — e con
/// venti frecce sovrapposte contarle a occhio non si può.
({int totali, int vincenti, int errori}) contaTiri(List<TiroScout> tiri) => (
      totali: tiri.length,
      vincenti: tiri.where((t) => t.voto == Voto.perfetto).length,
      errori: tiri.where((t) => t.voto == Voto.errore).length,
    );

/// Chi ha tirato di più in quel fondamentale: il default sensato quando una
/// vista si apre e nessuno ha ancora scelto.
///
/// **Non "la prima della lista"**: per numero di maglia potrebbe capitare il
/// libero, che non batte mai, e il campo si aprirebbe vuoto. Chi ha più colpi
/// è sempre la scheda con più da dire — la stessa regola del grafico di
/// tendenza.
///
/// `null` se in quel periodo non ha tirato nessuno.
String? giocatriceConPiuTiri(
  BackupCompleto backup, {
  required Fondamentale fondamentale,
  Filtro filtro = const Filtro(),
}) {
  if (!fondamentale.richiedeTraiettoria) return null;
  final quanti = <String, int>{};
  for (final selezione in partiteFiltrate(backup, filtro)) {
    for (final set in selezione.sets) {
      for (final a in set.azioni) {
        if (a.tipo != TipoAzione.scout) continue;
        if (a.fondamentale != fondamentale) continue;
        if (a.squadra != Squadra.nostra) continue;
        final uid = a.giocatoreUid;
        if (uid == null || !haTraiettoria(a)) continue;
        quanti[uid] = (quanti[uid] ?? 0) + 1;
      }
    }
  }
  if (quanti.isEmpty) return null;
  // A parità di colpi vince l'uid minore: un default che cambia da un'apertura
  // all'altra sarebbe peggio di uno arbitrario.
  final ordinati = quanti.entries.toList()
    ..sort((a, b) {
      final perColpi = b.value.compareTo(a.value);
      return perColpi != 0 ? perColpi : a.key.compareTo(b.key);
    });
  return ordinati.first.key;
}
