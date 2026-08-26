import 'package:flutter/material.dart';

/// Il menu a tendina della dashboard: etichetta sopra, bordo, larghezza fissa.
///
/// Vive in un file suo perché lo usano sia la barra filtri sia il grafico di
/// tendenza: due file di selettori che non si assomigliano *quasi* sarebbero
/// peggio di due identici.
class MenuCompatto<T> extends StatelessWidget {
  const MenuCompatto({
    super.key,
    required this.etichetta,
    required this.valore,
    required this.voci,
    required this.onCambia,
    this.larghezza = 210,
  });

  final String etichetta;
  final T valore;
  final List<DropdownMenuItem<T>> voci;
  final ValueChanged<T?> onCambia;
  final double larghezza;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: larghezza,
      child: DropdownButtonFormField<T>(
        initialValue: valore,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: etichetta,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: voci,
        onChanged: onCambia,
      ),
    );
  }
}
