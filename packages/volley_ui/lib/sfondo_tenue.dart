import 'package:flutter/material.dart';

/// Quanto è accennato lo sfondo tenue: appena percettibile.
///
/// Sei per cento è poco di proposito. Serve a *raggruppare* — a dire "questo è
/// un blocco", "questa è la stessa riga" — non a colorare: appena si alza, la
/// banda comincia a competere coi numeri che deve aiutare a leggere.
const double kOpacitaSfondoTenue = 0.06;

/// Lo sfondo tenue condiviso dalle tessere KPI e dalle righe alternate del
/// tabellone.
///
/// Viene dal **tema** e non è un azzurro fisso: la primaria è lo stesso blu del
/// brand tanto nel guscio web quanto nella pagina dentro l'app, quindi la tinta
/// è quella voluta in entrambi e resta corretta se il tema cambia. È la
/// differenza con i colori dei gruppi del PDF (vedi `tabellone_stagionale`),
/// che invece sono un dato del documento e restano identici ovunque.
///
/// Sta in un file suo perché lo usano due schermate diverse: due `withValues`
/// scritti a mano finirebbero per divergere alla prima ritoccata.
Color sfondoTenue(ColorScheme colori) =>
    colori.primary.withValues(alpha: kOpacitaSfondoTenue);
