import 'dart:ui';

import 'package:flutter/material.dart';

import '../tema/colores.dart';

/// Dark glassmorphism: blur alto (sigma 27), gradiente de cristal oscuro,
/// sombra exterior suave, bisel luminoso superior y borde sutil.
/// Úsalo en paneles grandes; en chips pequeños usa [VidrioLigero] (sin blur)
/// para cuidar el rendimiento en Android.
class PanelVidrio extends StatelessWidget {
  const PanelVidrio({
    super.key,
    required this.child,
    this.radio = 24,
    this.padding = const EdgeInsets.all(20),
    this.desenfoque = 27,
  });

  final Widget child;
  final double radio;
  final EdgeInsetsGeometry padding;
  final double desenfoque;

  @override
  Widget build(BuildContext context) {
    final bordeRadius = BorderRadius.circular(radio);
    return Container(
      decoration: BoxDecoration(
        borderRadius: bordeRadius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x73000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: bordeRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: desenfoque, sigmaY: desenfoque),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: bordeRadius,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colores.vidrioSuperior, Colores.vidrioInferior],
              ),
              border: Border.all(color: Colores.borde),
            ),
            child: Stack(
              children: [
                // Brillo especular superior sutil de 1 px
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1,
                  child: const IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colores.bordeBrillo,
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: padding,
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
