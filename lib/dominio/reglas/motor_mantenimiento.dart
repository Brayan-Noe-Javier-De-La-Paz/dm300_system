import '../modelos/estado_tarea.dart';
import '../modelos/ficha_moto.dart';
import '../modelos/lectura_odometro.dart';
import '../modelos/modelos_mantenimiento.dart';

/// Motor determinista de reglas para mantenimiento preventivo, salud de la moto,
/// rendimiento de gasolina y compatibilidad de refacciones DM300.
class MotorMantenimiento {
  const MotorMantenimiento._();

  /// Evalúa el estado de una tarea respecto a sus intervalos de km y días.
  ///
  /// Reglas:
  /// - Si no hay `ultimoKm` ni `ultimaFecha`: [EstadoTarea.sinDatos].
  /// - Vencido si el km restante <= 0 o los días restantes <= 0.
  /// - Próximo si los km restantes o días restantes son <= al 15% del intervalo.
  /// - En otro caso: [EstadoTarea.alDia].
  static EstadoTarea evaluarTarea(
    TareaMantenimiento tarea,
    double kmActual,
    DateTime ahora,
  ) {
    if (tarea.ultimoKm == null && tarea.ultimaFecha == null) {
      return EstadoTarea.sinDatos;
    }

    final tieneKm = tarea.intervaloKm != null && tarea.ultimoKm != null;
    final tieneDias = tarea.intervaloDias != null && tarea.ultimaFecha != null;

    final kmRestante = tarea.kmRestantes(kmActual);
    final diasRestantes = tarea.diasRestantes(ahora);

    final kmVencido = tieneKm && (kmRestante != null && kmRestante <= 0);
    final diasVencido =
        tieneDias && (diasRestantes != null && diasRestantes <= 0);

    if (kmVencido || diasVencido) {
      return EstadoTarea.vencido;
    }

    final umbralKm =
        tieneKm ? (tarea.intervaloKm! * 0.15) : double.negativeInfinity;
    final umbralDias =
        tieneDias ? (tarea.intervaloDias! * 0.15) : double.negativeInfinity;

    final kmProximo = tieneKm &&
        kmRestante != null &&
        kmRestante > 0 &&
        kmRestante <= umbralKm;
    final diasProximo = tieneDias &&
        diasRestantes != null &&
        diasRestantes > 0 &&
        diasRestantes <= umbralDias;

    if (kmProximo || diasProximo) {
      return EstadoTarea.proximo;
    }

    return EstadoTarea.alDia;
  }

  /// Calcula el porcentaje de salud general (0.0 a 100.0) a partir de las tareas de mantenimiento.
  static double saludGeneralPorcentaje(
    List<TareaMantenimiento> tareas,
    double kmActual,
    DateTime ahora,
  ) {
    if (tareas.isEmpty) return 100.0;

    double acumulado = 0.0;
    for (final tarea in tareas) {
      final estado = evaluarTarea(tarea, kmActual, ahora);
      switch (estado) {
        case EstadoTarea.alDia:
          acumulado += 100.0;
          break;
        case EstadoTarea.proximo:
          acumulado += 60.0;
          break;
        case EstadoTarea.sinDatos:
          acumulado += 50.0;
          break;
        case EstadoTarea.vencido:
          acumulado += 0.0;
          break;
      }
    }

    final porcentaje = acumulado / tareas.length;
    return double.parse(porcentaje.clamp(0.0, 100.0).toStringAsFixed(1));
  }

  /// Calcula el rendimiento promedio histórico en km/L.
  static double? calcularRendimientoPromedioKmL(List<CargaCombustible> cargas) {
    final conRendimiento = cargas
        .where((c) => c.kmPorLitro != null && c.kmPorLitro! > 0)
        .toList();

    if (conRendimiento.isEmpty) return null;

    final suma =
        conRendimiento.map((c) => c.kmPorLitro!).reduce((a, b) => a + b);
    return double.parse((suma / conRendimiento.length).toStringAsFixed(1));
  }

  /// Detecta si la última carga de combustible sufrió una caída de rendimiento >= 15%
  /// respecto al promedio de las cargas anteriores.
  static String? detectarCaidaRendimiento(List<CargaCombustible> cargas) {
    final ordenadas = List<CargaCombustible>.from(cargas)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    final validas = ordenadas
        .where((c) => c.kmPorLitro != null && c.kmPorLitro! > 0)
        .toList();

    if (validas.length < 2) return null;

    final ultima = validas.last;
    final previas = validas.sublist(0, validas.length - 1);
    final promPrev =
        previas.map((c) => c.kmPorLitro!).reduce((a, b) => a + b) /
            previas.length;

    if (promPrev > 0 &&
        (promPrev - ultima.kmPorLitro!) / promPrev >= 0.15) {
      return 'Caída de rendimiento detectada (${ultima.kmPorLitro!.toStringAsFixed(1)} vs ${promPrev.toStringAsFixed(1)} km/L): revisa el filtro de aire bajo el asiento o la bujía.';
    }

    return null;
  }

  /// Evalúa el catálogo de refacciones frente al estado actual de la Ficha Técnica.
  ///
  /// Reglas:
  /// - Si `requiereAccesorio != null`: si el campo está pendiente -> `dudosaPendienteFicha`.
  ///   Si está verificado como distinto de 'Sí' -> `noAplicaAccesorio`.
  /// - Si `dependeDeClaveFicha != null`: si el campo no está verificado -> `dudosaPendienteFicha`.
  ///   Si está verificado y coincide con `valorRequerido` -> `sugerida`.
  ///   Si está verificado con otro valor -> `noAplicaAccesorio`.
  /// - Si no tiene dependencias -> `sugerida`.
  static List<RefaccionEvaluada> filtrarRefacciones({
    required List<RefaccionDm300> catalogo,
    required List<CampoFicha> ficha,
  }) {
    final mapaFicha = <String, CampoFicha>{
      for (final c in ficha) c.clave.toLowerCase(): c,
    };

    final resultado = <RefaccionEvaluada>[];

    for (final ref in catalogo) {
      // 1. Validación de accesorio condicional
      if (ref.requiereAccesorio != null) {
        final campoAcc = mapaFicha[ref.requiereAccesorio!.toLowerCase()];
        if (campoAcc == null || !campoAcc.estaVerificado) {
          resultado.add(RefaccionEvaluada(
            refaccion: ref,
            estado: EstadoCompatibilidadRefaccion.dudosaPendienteFicha,
            claveFichaPendiente: campoAcc?.clave ?? ref.requiereAccesorio,
            motivo:
                'Dato pendiente en Ficha (${campoAcc?.titulo ?? ref.requiereAccesorio}): no se sugiere para compra aún.',
          ));
          continue;
        }

        final valorAcc = campoAcc.valor.trim().toLowerCase();
        if (valorAcc != 'sí' && valorAcc != 'si') {
          resultado.add(RefaccionEvaluada(
            refaccion: ref,
            estado: EstadoCompatibilidadRefaccion.noAplicaAccesorio,
            claveFichaPendiente: null,
            motivo:
                'No aplica porque el accesorio está marcado como No en la Ficha.',
          ));
          continue;
        }
      }

      // 2. Validación de especificación técnica condicional
      if (ref.dependeDeClaveFicha != null) {
        final campoDep = mapaFicha[ref.dependeDeClaveFicha!.toLowerCase()];
        if (campoDep == null || !campoDep.estaVerificado) {
          resultado.add(RefaccionEvaluada(
            refaccion: ref,
            estado: EstadoCompatibilidadRefaccion.dudosaPendienteFicha,
            claveFichaPendiente: campoDep?.clave ?? ref.dependeDeClaveFicha,
            motivo:
                'Dato pendiente en Ficha (${campoDep?.titulo ?? ref.dependeDeClaveFicha}): no se sugiere para compra aún.',
          ));
          continue;
        }

        final valorFicha = campoDep.valor.trim().toLowerCase();
        final valorReq = (ref.valorRequerido ?? '').trim().toLowerCase();

        if (valorFicha == valorReq ||
            (valorReq.isNotEmpty && valorFicha.contains(valorReq))) {
          resultado.add(RefaccionEvaluada(
            refaccion: ref,
            estado: EstadoCompatibilidadRefaccion.sugerida,
            claveFichaPendiente: null,
            motivo:
                'Compatible con especificación verificada (${campoDep.valor}).',
          ));
        } else {
          resultado.add(RefaccionEvaluada(
            refaccion: ref,
            estado: EstadoCompatibilidadRefaccion.noAplicaAccesorio,
            claveFichaPendiente: null,
            motivo:
                'No aplica para la especificación verificada (${campoDep.valor} vs requerida ${ref.valorRequerido}).',
          ));
        }
        continue;
      }

      // 3. Refacción estándar sin dependencias condicionales
      resultado.add(RefaccionEvaluada(
        refaccion: ref,
        estado: EstadoCompatibilidadRefaccion.sugerida,
        claveFichaPendiente: null,
        motivo: 'Refacción estándar compatible con DM300.',
      ));
    }

    return resultado;
  }

  /// Calcula los kilómetros recorridos en cada uno de los últimos 12 meses.
  /// Siempre retorna una lista de exactamente 12 elementos `double` en orden cronológico
  /// (desde hace 11 meses hasta el mes actual).
  static List<double> calcularKmUltimos12Meses(
    List<LecturaOdometro> lecturas,
    DateTime ahora,
  ) {
    final resultado = List<double>.filled(12, 0.0);
    if (lecturas.isEmpty) return resultado;

    final ordenadas = List<LecturaOdometro>.from(lecturas)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));

    // Construcción de los 12 meses: mes 0 = hace 11 meses, mes 11 = mes actual
    for (int indice = 0; indice < 12; indice++) {
      final desfaseMeses = 11 - indice;
      final inicioMes = DateTime(ahora.year, ahora.month - desfaseMeses, 1);
      final finMes = DateTime(ahora.year, ahora.month - desfaseMeses + 1, 1);

      // Lecturas dentro del mes
      final lecturasMes = ordenadas
          .where((l) =>
              !l.fecha.isBefore(inicioMes) && l.fecha.isBefore(finMes))
          .toList();

      if (lecturasMes.isNotEmpty) {
        // Buscar la lectura previa más cercana al inicio de este mes
        final lecturasPrevias =
            ordenadas.where((l) => l.fecha.isBefore(inicioMes)).toList();

        final kmBase = lecturasPrevias.isNotEmpty
            ? lecturasPrevias.last.km
            : lecturasMes.first.km;

        final delta = lecturasMes.last.km - kmBase;
        resultado[indice] = delta > 0 ? double.parse(delta.toStringAsFixed(1)) : 0.0;
      } else {
        // Si no hubo lecturas ese mes exacto, pero hay lecturas antes y después, interpolar
        final lecturasPrevias =
            ordenadas.where((l) => l.fecha.isBefore(inicioMes)).toList();
        final lecturasPosteriores =
            ordenadas.where((l) => !l.fecha.isBefore(finMes)).toList();

        if (lecturasPrevias.isNotEmpty && lecturasPosteriores.isNotEmpty) {
          final lPre = lecturasPrevias.last;
          final lPost = lecturasPosteriores.first;
          final diasTotal = lPost.fecha.difference(lPre.fecha).inDays;
          final deltaKmTotal = lPost.km - lPre.km;

          if (diasTotal > 0 && deltaKmTotal > 0) {
            final diasMes = finMes.difference(inicioMes).inDays;
            final ritmoDiario = deltaKmTotal / diasTotal;
            final estimado = ritmoDiario * diasMes;
            resultado[indice] = double.parse(estimado.toStringAsFixed(1));
          }
        }
      }
    }

    return resultado;
  }
}
