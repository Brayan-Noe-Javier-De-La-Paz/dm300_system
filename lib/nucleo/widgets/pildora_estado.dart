import 'package:flutter/material.dart';

import '../../dominio/modelos/estado_tarea.dart';
import '../tema/estado_visual.dart';

class PildoraEstado extends StatelessWidget {
  const PildoraEstado({super.key, required this.estado, this.texto});

  final EstadoTarea estado;
  final String? texto;

  @override
  Widget build(BuildContext context) {
    final color = estado.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(estado.icono, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            texto ?? estado.etiqueta,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
