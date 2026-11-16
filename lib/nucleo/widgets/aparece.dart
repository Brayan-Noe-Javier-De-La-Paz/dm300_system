import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Entrada escalonada: aparece con desvanecimiento y un ligero ascenso.
class Aparece extends StatelessWidget {
  const Aparece({super.key, required this.child, this.indice = 0});

  final Widget child;
  final int indice;

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: (80 * indice).ms)
        .fadeIn(duration: 450.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.06, end: 0, duration: 450.ms, curve: Curves.easeOutCubic);
  }
}
