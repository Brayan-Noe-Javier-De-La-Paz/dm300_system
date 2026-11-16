/// Origen que disparó el registro del odómetro.
enum OrigenOdometro { rapido, servicio, combustible, medicion, fichaInicial }

/// Registro inmutable de una lectura de odómetro.
class LecturaOdometro {
  const LecturaOdometro({
    required this.id,
    required this.km,
    required this.fecha,
    required this.origen,
    this.cambioTablero = false,
    this.nota,
  });

  final String id;
  final double km;
  final DateTime fecha;
  final OrigenOdometro origen;
  final bool cambioTablero;
  final String? nota;

  LecturaOdometro copiarCon({
    String? id,
    double? km,
    DateTime? fecha,
    OrigenOdometro? origen,
    bool? cambioTablero,
    String? nota,
  }) {
    return LecturaOdometro(
      id: id ?? this.id,
      km: km ?? this.km,
      fecha: fecha ?? this.fecha,
      origen: origen ?? this.origen,
      cambioTablero: cambioTablero ?? this.cambioTablero,
      nota: nota ?? this.nota,
    );
  }

  Map<String, dynamic> aJson() {
    return {
      'id': id,
      'km': km,
      'fecha': fecha.toIso8601String(),
      'origen': origen.name,
      'cambioTablero': cambioTablero,
      'nota': nota,
    };
  }

  factory LecturaOdometro.deJson(Map<String, dynamic> json) {
    final origenStr = json['origen']?.toString() ?? 'rapido';
    final origen = OrigenOdometro.values.firstWhere(
      (o) => o.name.toLowerCase() == origenStr.toLowerCase(),
      orElse: () => OrigenOdometro.rapido,
    );

    final rawFecha = json['fecha'];
    final fecha = rawFecha != null
        ? (DateTime.tryParse(rawFecha.toString()) ?? DateTime.now())
        : DateTime.now();

    final cambio = json['cambioTablero'] == true ||
        json['cambio_tablero'] == 1 ||
        json['cambio_tablero'] == true;

    return LecturaOdometro(
      id: json['id']?.toString() ?? '',
      km: (json['km'] as num?)?.toDouble() ?? 0.0,
      fecha: fecha,
      origen: origen,
      cambioTablero: cambio,
      nota: json['nota']?.toString(),
    );
  }
}
