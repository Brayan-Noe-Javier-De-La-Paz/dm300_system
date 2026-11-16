import 'package:flutter/material.dart';

/// Paleta: gris oscuro, dorado y blanco. Los estados usan verde, naranja y
/// rojo para que el dorado de marca no se confunda con un aviso.
class Colores {
  Colores._();

  static const Color fondo = Color(0xFF0E0F12);
  static const Color vidrio = Color(0xCC26292E); // gris oscuro al 80 %
  static const Color vidrioSuave = Color(0xB3181A1E); // tarjetas sin blur
  static const Color borde = Color(0x26FFFFFF); // blanco al 15 %

  static const Color oro = Color(0xFFD4AF37);
  static const Color oroClaro = Color(0xFFF2D27A);
  static const Color oroOscuro = Color(0xFF1A1405); // texto sobre dorado

  static const Color texto = Color(0xFFF5F5F2);
  static const Color textoSecundario = Color(0xFFA9ADB5);

  static const Color ok = Color(0xFF3DDC97);
  static const Color aviso = Color(0xFFFF9F43);
  static const Color vencido = Color(0xFFFF5A5F);
  static const Color sinDatos = Color(0xFF8A8F98);

  // Acentos para fondo cristalino, biseles y glassmorphism
  static const Color cianHuella = Color(0xFF18A999);
  static const Color ambarCalido = Color(0xFFFF8C42);
  static const Color azulProfundo = Color(0xFF1E3A5F);
  static const Color bordeBrillo = Color(0x59FFFFFF);
  static const Color bordeSombra = Color(0x0DFFFFFF);
  static const Color vidrioSuperior = Color(0xBD262B34);
  static const Color vidrioInferior = Color(0x9416191F);

  static const LinearGradient degradadoOro = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [oro, oroClaro],
  );
}
