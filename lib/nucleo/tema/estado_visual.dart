import 'package:flutter/material.dart';

import '../../dominio/modelos/estado_tarea.dart';
import 'colores.dart';

extension EstadoTareaVisual on EstadoTarea {
  Color get color => switch (this) {
        EstadoTarea.alDia => Colores.ok,
        EstadoTarea.proximo => Colores.aviso,
        EstadoTarea.vencido => Colores.vencido,
        EstadoTarea.sinDatos => Colores.sinDatos,
      };

  String get etiqueta => switch (this) {
        EstadoTarea.alDia => 'Al día',
        EstadoTarea.proximo => 'Próximo',
        EstadoTarea.vencido => 'Vencido',
        EstadoTarea.sinDatos => 'Sin datos',
      };

  IconData get icono => switch (this) {
        EstadoTarea.alDia => Icons.check_circle_outline_rounded,
        EstadoTarea.proximo => Icons.schedule_rounded,
        EstadoTarea.vencido => Icons.error_outline_rounded,
        EstadoTarea.sinDatos => Icons.help_outline_rounded,
      };
}
