import 'package:flutter/material.dart';

import 'colores.dart';

ThemeData crearTema() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Colores.fondo,
    colorScheme: ColorScheme.dark(
      primary: Colores.oro,
      onPrimary: Colores.oroOscuro,
      secondary: Colores.oroClaro,
      surface: Colores.fondo,
      onSurface: Colores.texto,
      error: Colores.vencido,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: Colores.texto,
      displayColor: Colores.texto,
    ),
    splashFactory: NoSplash.splashFactory,
  );
}
