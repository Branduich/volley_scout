/// Il filtro della dashboard: **un oggetto immutabile** che attraversa tutte
/// le funzioni di aggregazione (passo 7b del piano in docs/dati-stagionali.md).
///
/// Nessuna funzione di questo package guarda dentro un widget, e nessun widget
/// filtra per conto suo: chi disegna costruisce un [Filtro] e lo passa. È
/// quello che permette di verificare "solo in casa, set 1" con un test invece
/// che a occhio davanti al browser.
library;

import 'backup_model.dart';

/// Dove si è giocato.
enum CampoPartita { tutte, casa, trasferta }

/// I periodi preimpostati. `personalizzato` usa [Filtro.da]/[Filtro.a].
enum PeriodoPreset {
  tuttaStagione,
  andata,
  ritorno,
  ultimeCinque,
  ultimoMese,
  personalizzato,
}

/// Una partita con i soli set che passano il filtro.
typedef PartitaSelezionata = ({PartitaBackup partita, List<SetBackup> sets});

class Filtro {
  const Filtro({
    this.periodo = PeriodoPreset.tuttaStagione,
    this.da,
    this.a,
    this.campo = CampoPartita.tutte,
    this.set,
    this.squadraUid,
  });

  final PeriodoPreset periodo;

  /// Estremi del periodo personalizzato (inclusivi). Ignorati con gli altri
  /// preset.
  final DateTime? da, a;

  final CampoPartita campo;

  /// Numero del set (1-5); `null` = tutti.
  final int? set;

  /// `null` = tutte le squadre (chi ne ha una sola non vede nemmeno il
  /// selettore).
  final String? squadraUid;

  Filtro copiaCon({
    PeriodoPreset? periodo,
    DateTime? da,
    DateTime? a,
    CampoPartita? campo,
    int? set,
    String? squadraUid,
    bool azzeraSet = false,
    bool azzeraSquadra = false,
    bool azzeraIntervallo = false,
  }) =>
      Filtro(
        periodo: periodo ?? this.periodo,
        da: azzeraIntervallo ? null : (da ?? this.da),
        a: azzeraIntervallo ? null : (a ?? this.a),
        campo: campo ?? this.campo,
        set: azzeraSet ? null : (set ?? this.set),
        squadraUid: azzeraSquadra ? null : (squadraUid ?? this.squadraUid),
      );

  bool get attivo =>
      periodo != PeriodoPreset.tuttaStagione ||
      campo != CampoPartita.tutte ||
      set != null;
}

/// Le partite che passano il filtro, con i set già ristretti.
///
/// Ordine cronologico crescente: è quello che serve a "andata/ritorno" e
/// "ultime 5", ed è anche l'ordine con cui si guarda una stagione.
List<PartitaSelezionata> partiteFiltrate(BackupCompleto backup, Filtro filtro) {
  var partite = [
    for (final p in backup.partite)
      if (filtro.squadraUid == null || p.squadraUid == filtro.squadraUid) p,
  ]..sort((a, b) => a.dataOra.compareTo(b.dataOra));

  partite = switch (filtro.campo) {
    CampoPartita.tutte => partite,
    CampoPartita.casa => [
        for (final p in partite)
          if (p.inCasa) p
      ],
    CampoPartita.trasferta => [
        for (final p in partite)
          if (!p.inCasa) p
      ],
  };

  partite = _perPeriodo(partite, filtro);

  return [
    for (final p in partite)
      (
        partita: p,
        sets: [
          for (final s in p.sets)
            if (filtro.set == null || s.numero == filtro.set) s,
        ],
      ),
  ];
}

List<PartitaBackup> _perPeriodo(List<PartitaBackup> partite, Filtro filtro) {
  if (partite.isEmpty) return partite;

  switch (filtro.periodo) {
    case PeriodoPreset.tuttaStagione:
      return partite;

    // Metà e metà per NUMERO di partite, non per data: il calendario non è
    // regolare (soste, recuperi) e dividere sul calendario darebbe due metà
    // sbilanciate. Con un numero dispari l'andata prende la partita in più,
    // come nei gironi a squadre dispari.
    case PeriodoPreset.andata:
      return partite.take((partite.length + 1) ~/ 2).toList();
    case PeriodoPreset.ritorno:
      return partite.skip((partite.length + 1) ~/ 2).toList();

    case PeriodoPreset.ultimeCinque:
      return partite.length <= 5
          ? partite
          : partite.sublist(partite.length - 5);

    // Ancorato all'ULTIMA partita dei dati, non a oggi: un backup di una
    // stagione finita mostrerebbe altrimenti una schermata vuota, che sembra un
    // errore dell'app invece che una conseguenza del filtro.
    case PeriodoPreset.ultimoMese:
      final ultima = partite.last.dataOra;
      final limite = ultima.subtract(const Duration(days: 30));
      return [
        for (final p in partite)
          if (!p.dataOra.isBefore(limite)) p
      ];

    case PeriodoPreset.personalizzato:
      return [
        for (final p in partite)
          if ((filtro.da == null || !p.dataOra.isBefore(filtro.da!)) &&
              (filtro.a == null || !p.dataOra.isAfter(filtro.a!)))
            p
      ];
  }
}
