import '../modelos/lectura_odometro.dart';

/// Nivel de severidad o resultado de la validación del odómetro.
enum NivelValidacionOdometro {
  valido,
  advertenciaSalto,
  errorDigitoProbable,
  bloqueadoMenor,
}

/// Objeto de transferencia que describe el dictamen de validación de kilometraje.
class ResultadoValidacionOdometro {
  const ResultadoValidacionOdometro({
    required this.nivel,
    required this.mensaje,
    this.kmSugerido,
    this.requiereCambioTablero = false,
    this.requiereConfirmacionSalto = false,
  });

  final NivelValidacionOdometro nivel;
  final String mensaje;
  final double? kmSugerido;
  final bool requiereCambioTablero;
  final bool requiereConfirmacionSalto;

  /// Determina si la regla de negocio autoriza el guardado directo o tras confirmación.
  bool get permiteGuardar =>
      nivel == NivelValidacionOdometro.valido ||
      nivel == NivelValidacionOdometro.advertenciaSalto;
}

/// Reglas de validación y cálculo estadístico para el odómetro de la DM300.
class ValidadorOdometro {
  const ValidadorOdometro._();

  /// Valida una nueva lectura frente al último registro histórico.
  static ResultadoValidacionOdometro validar({
    required double nuevoKm,
    required double ultimoKm,
    required DateTime fechaUltimaLectura,
    required DateTime fechaNueva,
    bool cambioTablero = false,
  }) {
    if (nuevoKm < 0) {
      return const ResultadoValidacionOdometro(
        nivel: NivelValidacionOdometro.bloqueadoMenor,
        mensaje: 'El kilometraje no puede ser menor a cero.',
      );
    }

    if (nuevoKm < ultimoKm && !cambioTablero) {
      // Detección de error humano por omisión de un dígito final (ej: 2388 vs 23880)
      final valorMultiplicado = nuevoKm * 10;
      if (nuevoKm > 0 && (valorMultiplicado - ultimoKm).abs() <= 1500) {
        return ResultadoValidacionOdometro(
          nivel: NivelValidacionOdometro.errorDigitoProbable,
          kmSugerido: valorMultiplicado,
          mensaje:
              '¿Quisiste decir ${valorMultiplicado.round()} km? Parece faltar un dígito respecto a la lectura anterior (${ultimoKm.round()} km).',
        );
      }

      return ResultadoValidacionOdometro(
        nivel: NivelValidacionOdometro.bloqueadoMenor,
        requiereCambioTablero: true,
        mensaje:
            'No puede ser menor a la lectura anterior (${ultimoKm.round()} km). ¿Cambiaste el tablero?',
      );
    }

    // Si hubo cambio de tablero y es menor, o si es mayor regular, evaluamos el ritmo
    if (!cambioTablero) {
      final diferenciaDias = fechaNueva.difference(fechaUltimaLectura).inDays;
      final diasEfectivos = diferenciaDias <= 0 ? 1 : diferenciaDias;
      final ritmoDiario = (nuevoKm - ultimoKm) / diasEfectivos;

      if (ritmoDiario > 400) {
        return ResultadoValidacionOdometro(
          nivel: NivelValidacionOdometro.advertenciaSalto,
          requiereConfirmacionSalto: true,
          mensaje:
              'El incremento representa un promedio de ${ritmoDiario.toStringAsFixed(0)} km/día (> 400 km/día). Confirma si el dato es correcto.',
        );
      }
    }

    return const ResultadoValidacionOdometro(
      nivel: NivelValidacionOdometro.valido,
      mensaje: 'Lectura de kilometraje válida.',
    );
  }

  /// Calcula el promedio de kilómetros recorridos por día según el historial.
  /// Si hay menos de 2 lecturas, retorna el promedio de fábrica (~28.0 km/día).
  static double calcularPromedioDiario(List<LecturaOdometro> lecturas) {
    if (lecturas.length < 2) return 28.0;

    final ordenadas = List<LecturaOdometro>.from(lecturas)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    double acumuladoKm = 0.0;
    int acumuladoDias = 0;

    for (int i = 0; i < ordenadas.length - 1; i++) {
      final actual = ordenadas[i];
      final siguiente = ordenadas[i + 1];

      if (siguiente.cambioTablero) continue;

      final deltaKm = siguiente.km - actual.km;
      final deltaDias = siguiente.fecha.difference(actual.fecha).inDays;

      if (deltaKm >= 0 && deltaDias > 0) {
        acumuladoKm += deltaKm;
        acumuladoDias += deltaDias;
      }
    }

    if (acumuladoDias > 0 && acumuladoKm > 0) {
      final promedio = acumuladoKm / acumuladoDias;
      return promedio > 0 ? promedio : 28.0;
    }

    // Respaldo global con primer y último registro
    final deltaGlobalKm = ordenadas.last.km - ordenadas.first.km;
    final deltaGlobalDias =
        ordenadas.last.fecha.difference(ordenadas.first.fecha).inDays;

    if (deltaGlobalDias > 0 && deltaGlobalKm > 0) {
      return deltaGlobalKm / deltaGlobalDias;
    }

    return 28.0;
  }

  /// Estima el kilometraje a la fecha actual proyectando el ritmo diario.
  /// Redondea a la decena más cercana (ej. 24,310 km) para visualización limpia.
  static double estimarKmHoy({
    required List<LecturaOdometro> lecturas,
    DateTime? ahora,
  }) {
    if (lecturas.isEmpty) return 0.0;

    final fechaActual = ahora ?? DateTime.now();
    final ordenadas = List<LecturaOdometro>.from(lecturas)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final ultima = ordenadas.last;
    final dias = fechaActual.difference(ultima.fecha).inDays;

    if (dias <= 0) {
      return (ultima.km / 10.0).roundToDouble() * 10.0;
    }

    final ritmoDiario = calcularPromedioDiario(ordenadas);
    final proyectado = ultima.km + (dias * ritmoDiario);

    return (proyectado / 10.0).roundToDouble() * 10.0;
  }
}
