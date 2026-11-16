import '../../dominio/modelos/estado_tarea.dart';
import 'vista_moto.dart';

/// Datos de ejemplo para ver el diseño. Se reemplazan por la base de datos.
const double kmActualEjemplo = 23880;

class DetalleZona {
  const DetalleZona({
    required this.titulo,
    required this.subtitulo,
    required this.estado,
    required this.metrica,
    required this.unidad,
    required this.delta,
    required this.lineaSecundaria,
  });

  final String titulo;
  final String subtitulo;
  final EstadoTarea estado;
  final double metrica;
  final String unidad;
  final String delta;
  final String lineaSecundaria;
}

final Map<String, DetalleZona> detallesEjemplo = {
  'Cadena y transmisión': const DetalleZona(
    titulo: 'Cadena y transmisión',
    subtitulo: 'Holgura 15 a 20 mm · lubricar cada mes',
    estado: EstadoTarea.vencido,
    metrica: 12,
    unidad: 'días de retraso',
    delta: 'Sin grasa',
    lineaSecundaria: 'Última vez: hace 42 días · usa lubricante para cadena',
  ),
  'Motor y aceite': const DetalleZona(
    titulo: 'Motor y aceite',
    subtitulo: 'Aceite 1.3 L · bujía 0.6 a 0.7 mm',
    estado: EstadoTarea.proximo,
    metrica: 120,
    unidad: 'km para el servicio',
    delta: 'a 24,000 km',
    lineaSecundaria: 'Aceite, cedazo y bujía · cada 3,000 km o 4 meses',
  ),
  'Freno delantero': const DetalleZona(
    titulo: 'Freno delantero',
    subtitulo: 'Balatas: límite 2 mm · líquido DOT 3 o 4',
    estado: EstadoTarea.proximo,
    metrica: 2,
    unidad: 'mm de límite',
    delta: 'Medir ahora',
    lineaSecundaria: 'Última medición: sin datos',
  ),
  'Tanque y combustible': const DetalleZona(
    titulo: 'Tanque y combustible',
    subtitulo: 'Capacidad 12 L · llave de paso',
    estado: EstadoTarea.alDia,
    metrica: 12,
    unidad: 'L de capacidad',
    delta: 'Sin pendientes',
    lineaSecundaria: 'Filtro de combustible: sin datos',
  ),
  'Escape': const DetalleZona(
    titulo: 'Escape',
    subtitulo: 'Gomas de soporte y empaque del tubo',
    estado: EstadoTarea.alDia,
    metrica: 0,
    unidad: 'pendientes',
    delta: 'Al día',
    lineaSecundaria: 'Revisar firmeza en cada servicio',
  ),
};

DetalleZona detalleDe(ZonaVista z) =>
    detallesEjemplo[z.nombre] ??
    DetalleZona(
      titulo: z.nombre,
      subtitulo: 'Sin datos todavía',
      estado: z.estado,
      metrica: 0,
      unidad: 'pendientes',
      delta: '—',
      lineaSecundaria: 'Aún no hay registros para esta zona',
    );
