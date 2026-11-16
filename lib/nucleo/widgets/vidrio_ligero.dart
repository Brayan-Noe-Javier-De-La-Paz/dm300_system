import 'package:flutter/material.dart';

import '../tema/colores.dart';

/// Vidrio sin blur para chips y tarjetas pequeñas.
/// Optimizado para alto rendimiento en Android sin sacrificar el acabado cristalino.
class VidrioLigero extends StatelessWidget {
  const VidrioLigero({
    super.key,
    required this.child,
    this.radio = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.seleccionado = false,
  });

  final Widget child;
  final double radio;
  final EdgeInsetsGeometry padding;
  final bool seleccionado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radio),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: seleccionado
              ? [
                  Colores.vidrioSuperior,
                  const Color(0xD92E2718),
                ]
              : const [
                  Colores.vidrioSuperior,
                  Colores.vidrioInferior,
                ],
        ),
        border: Border.all(
          color: seleccionado
              ? Colores.oro
              : Colores.bordeBrillo.withValues(alpha: 0.30),
          width: seleccionado ? 1.4 : 1.0,
        ),
        boxShadow: seleccionado
            ? [
                BoxShadow(
                  color: Colores.oro.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
                const BoxShadow(
                  color: Color(0x3D000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}
