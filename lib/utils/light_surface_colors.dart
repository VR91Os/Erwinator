import 'package:flutter/material.dart';

// Textfarbe für Inhalte auf Flächen, die bewusst IMMER hell bleiben
// (weiße Karten, Pastell-Hintergründe für Aufgaben/Kalendertage),
// unabhängig vom App-weiten Dunkelmodus - ohne diese feste Farbe würde der
// Text im Dunkelmodus die helle Standard-Textfarbe des Themes erben und
// auf dem hellen Untergrund verschwinden. Ein zentraler Ort statt des
// bisher an jeder betroffenen Stelle wiederholten Einzel-Fixes, damit ein
// neues Widget auf einer solchen Fläche nicht erneut vergisst, die
// Textfarbe festzunageln.
const lightSurfaceTextColor = Colors.black87;
