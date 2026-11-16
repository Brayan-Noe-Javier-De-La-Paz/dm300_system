import 'package:flutter/material.dart';

import '../tema/colores.dart';

enum EstadoBoton { normal, cargando, listo }

/// Botón dorado que cambia de forma: normal -> cargando -> listo.
class BotonOro extends StatelessWidget {
  const BotonOro({
    super.key,
    required this.etiqueta,
    required this.alPresionar,
    this.etiquetaListo = 'Listo',
    this.icono,
    this.estado = EstadoBoton.normal,
  });

  final String etiqueta;
  final String etiquetaListo;
  final IconData? icono;
  final EstadoBoton estado;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final listo = estado == EstadoBoton.listo;
    final radio = BorderRadius.circular(14);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: 48,
      decoration: BoxDecoration(
        gradient: listo ? null : Colores.degradadoOro,
        color: listo ? const Color(0x333DDC97) : null,
        borderRadius: radio,
        border: listo ? Border.all(color: const Color(0x993DDC97)) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radio,
          onTap: estado == EstadoBoton.normal ? alPresionar : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (hijo, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(anim),
                  child: hijo,
                ),
              ),
              child: _contenido(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    switch (estado) {
      case EstadoBoton.cargando:
        return const SizedBox(
          key: ValueKey('cargando'),
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Colores.oroOscuro,
          ),
        );
      case EstadoBoton.listo:
        return Row(
          key: const ValueKey('listo'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded, size: 18, color: Colores.ok),
            const SizedBox(width: 8),
            Text(
              etiquetaListo,
              style: const TextStyle(
                color: Colores.ok,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
      case EstadoBoton.normal:
        return Row(
          key: const ValueKey('normal'),
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 18, color: Colores.oroOscuro),
              const SizedBox(width: 8),
            ],
            Text(
              etiqueta,
              style: const TextStyle(
                color: Colores.oroOscuro,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );
    }
  }
}
