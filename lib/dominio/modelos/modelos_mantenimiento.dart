/// Definición de una tarea preventiva y su estado de ejecución.
class TareaMantenimiento {
  const TareaMantenimiento({
    required this.id,
    required this.zona,
    required this.titulo,
    required this.descripcion,
    this.intervaloKm,
    this.intervaloDias,
    this.ultimoKm,
    this.ultimaFecha,
    this.hechoPor,
    this.ultimoCosto,
  });

  final String id;
  final String zona;
  final String titulo;
  final String descripcion;
  final double? intervaloKm;
  final int? intervaloDias;
  final double? ultimoKm;
  final DateTime? ultimaFecha;
  final String? hechoPor;
  final double? ultimoCosto;

  /// Retorna los kilómetros restantes para el próximo servicio,
  /// o null si no se tiene intervalo o registro previo de kilometraje.
  double? kmRestantes(double kmActual) {
    if (intervaloKm == null || ultimoKm == null) return null;
    return (ultimoKm! + intervaloKm!) - kmActual;
  }

  /// Retorna los días restantes para el próximo servicio,
  /// o null si no se tiene intervalo o registro previo de fecha.
  int? diasRestantes(DateTime ahora) {
    if (intervaloDias == null || ultimaFecha == null) return null;
    final diasPasados = ahora.difference(ultimaFecha!).inDays;
    return intervaloDias! - diasPasados;
  }

  TareaMantenimiento copiarCon({
    String? id,
    String? zona,
    String? titulo,
    String? descripcion,
    double? intervaloKm,
    int? intervaloDias,
    double? ultimoKm,
    DateTime? ultimaFecha,
    String? hechoPor,
    double? ultimoCosto,
  }) {
    return TareaMantenimiento(
      id: id ?? this.id,
      zona: zona ?? this.zona,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      intervaloKm: intervaloKm ?? this.intervaloKm,
      intervaloDias: intervaloDias ?? this.intervaloDias,
      ultimoKm: ultimoKm ?? this.ultimoKm,
      ultimaFecha: ultimaFecha ?? this.ultimaFecha,
      hechoPor: hechoPor ?? this.hechoPor,
      ultimoCosto: ultimoCosto ?? this.ultimoCosto,
    );
  }

  Map<String, dynamic> aJson() {
    return {
      'id': id,
      'zona': zona,
      'titulo': titulo,
      'descripcion': descripcion,
      'intervaloKm': intervaloKm,
      'intervaloDias': intervaloDias,
      'ultimoKm': ultimoKm,
      'ultimaFecha': ultimaFecha?.toIso8601String(),
      'hechoPor': hechoPor,
      'ultimoCosto': ultimoCosto,
    };
  }

  factory TareaMantenimiento.deJson(Map<String, dynamic> json) {
    final rawFecha = json['ultimaFecha'] ?? json['ultima_fecha'];
    final ultimaFecha =
        rawFecha != null ? DateTime.tryParse(rawFecha.toString()) : null;

    return TareaMantenimiento(
      id: json['id']?.toString() ?? '',
      zona: json['zona']?.toString() ?? '',
      titulo: json['titulo']?.toString() ?? '',
      descripcion: json['descripcion']?.toString() ?? '',
      intervaloKm: (json['intervaloKm'] ?? json['intervalo_km'] as num?)
          ?.toDouble(),
      intervaloDias: (json['intervaloDias'] ?? json['intervalo_dias'] as num?)
          ?.toInt(),
      ultimoKm: (json['ultimoKm'] ?? json['ultimo_km'] as num?)?.toDouble(),
      ultimaFecha: ultimaFecha,
      hechoPor: (json['hechoPor'] ?? json['hecho_por'])?.toString(),
      ultimoCosto:
          (json['ultimoCosto'] ?? json['ultimo_costo'] as num?)?.toDouble(),
    );
  }
}

/// Bitácora histórica de intervenciones mecánicas ejecutadas.
class RegistroServicio {
  const RegistroServicio({
    required this.id,
    required this.tareaId,
    required this.tituloTarea,
    required this.zona,
    required this.km,
    required this.fecha,
    required this.realizadoPor,
    required this.costo,
    this.notas,
  });

  final String id;
  final String tareaId;
  final String tituloTarea;
  final String zona;
  final double km;
  final DateTime fecha;
  final String realizadoPor; // 'Mí' o 'Taller'
  final double costo;
  final String? notas;

  RegistroServicio copiarCon({
    String? id,
    String? tareaId,
    String? tituloTarea,
    String? zona,
    double? km,
    DateTime? fecha,
    String? realizadoPor,
    double? costo,
    String? notas,
  }) {
    return RegistroServicio(
      id: id ?? this.id,
      tareaId: tareaId ?? this.tareaId,
      tituloTarea: tituloTarea ?? this.tituloTarea,
      zona: zona ?? this.zona,
      km: km ?? this.km,
      fecha: fecha ?? this.fecha,
      realizadoPor: realizadoPor ?? this.realizadoPor,
      costo: costo ?? this.costo,
      notas: notas ?? this.notas,
    );
  }

  Map<String, dynamic> aJson() {
    return {
      'id': id,
      'tareaId': tareaId,
      'tituloTarea': tituloTarea,
      'zona': zona,
      'km': km,
      'fecha': fecha.toIso8601String(),
      'realizadoPor': realizadoPor,
      'costo': costo,
      'notas': notas,
    };
  }

  factory RegistroServicio.deJson(Map<String, dynamic> json) {
    final rawFecha = json['fecha'];
    final fecha = rawFecha != null
        ? (DateTime.tryParse(rawFecha.toString()) ?? DateTime.now())
        : DateTime.now();

    return RegistroServicio(
      id: json['id']?.toString() ?? '',
      tareaId: (json['tareaId'] ?? json['tarea_id'])?.toString() ?? '',
      tituloTarea:
          (json['tituloTarea'] ?? json['titulo_tarea'])?.toString() ?? '',
      zona: json['zona']?.toString() ?? '',
      km: (json['km'] as num?)?.toDouble() ?? 0.0,
      fecha: fecha,
      realizadoPor:
          (json['realizadoPor'] ?? json['realizado_por'])?.toString() ?? 'Mí',
      costo: (json['costo'] as num?)?.toDouble() ?? 0.0,
      notas: json['notas']?.toString(),
    );
  }
}

/// Registro de carga de gasolina y cálculo de rendimiento.
class CargaCombustible {
  const CargaCombustible({
    required this.id,
    required this.km,
    required this.litros,
    required this.costo,
    required this.fecha,
    this.kmPorLitro,
  });

  final String id;
  final double km;
  final double litros;
  final double costo;
  final DateTime fecha;
  final double? kmPorLitro;

  CargaCombustible copiarCon({
    String? id,
    double? km,
    double? litros,
    double? costo,
    DateTime? fecha,
    double? kmPorLitro,
  }) {
    return CargaCombustible(
      id: id ?? this.id,
      km: km ?? this.km,
      litros: litros ?? this.litros,
      costo: costo ?? this.costo,
      fecha: fecha ?? this.fecha,
      kmPorLitro: kmPorLitro ?? this.kmPorLitro,
    );
  }

  Map<String, dynamic> aJson() {
    return {
      'id': id,
      'km': km,
      'litros': litros,
      'costo': costo,
      'fecha': fecha.toIso8601String(),
      'kmPorLitro': kmPorLitro,
    };
  }

  factory CargaCombustible.deJson(Map<String, dynamic> json) {
    final rawFecha = json['fecha'];
    final fecha = rawFecha != null
        ? (DateTime.tryParse(rawFecha.toString()) ?? DateTime.now())
        : DateTime.now();

    return CargaCombustible(
      id: json['id']?.toString() ?? '',
      km: (json['km'] as num?)?.toDouble() ?? 0.0,
      litros: (json['litros'] as num?)?.toDouble() ?? 0.0,
      costo: (json['costo'] as num?)?.toDouble() ?? 0.0,
      fecha: fecha,
      kmPorLitro:
          (json['kmPorLitro'] ?? json['km_por_litro'] as num?)?.toDouble(),
    );
  }
}

/// Registro dimensional o físico de desgaste de componentes (balatas, cadena, etc.).
class MedicionDesgaste {
  const MedicionDesgaste({
    required this.id,
    required this.componente,
    required this.unidad,
    required this.valor,
    required this.minimoSeguro,
    this.maximoSeguro,
    required this.km,
    required this.fecha,
    this.nota,
  });

  final String id;
  final String componente;
  final String unidad;
  final double valor;
  final double minimoSeguro;
  final double? maximoSeguro;
  final double km;
  final DateTime fecha;
  final String? nota;

  /// Retorna true si la medición está por debajo del mínimo seguro
  /// o por encima del máximo seguro (por ejemplo holgura de cadena excesiva).
  bool get enAlerta =>
      valor < minimoSeguro || (maximoSeguro != null && valor > maximoSeguro!);

  MedicionDesgaste copiarCon({
    String? id,
    String? componente,
    String? unidad,
    double? valor,
    double? minimoSeguro,
    double? maximoSeguro,
    double? km,
    DateTime? fecha,
    String? nota,
  }) {
    return MedicionDesgaste(
      id: id ?? this.id,
      componente: componente ?? this.componente,
      unidad: unidad ?? this.unidad,
      valor: valor ?? this.valor,
      minimoSeguro: minimoSeguro ?? this.minimoSeguro,
      maximoSeguro: maximoSeguro ?? this.maximoSeguro,
      km: km ?? this.km,
      fecha: fecha ?? this.fecha,
      nota: nota ?? this.nota,
    );
  }

  Map<String, dynamic> aJson() {
    return {
      'id': id,
      'componente': componente,
      'unidad': unidad,
      'valor': valor,
      'minimoSeguro': minimoSeguro,
      'maximoSeguro': maximoSeguro,
      'km': km,
      'fecha': fecha.toIso8601String(),
      'nota': nota,
    };
  }

  factory MedicionDesgaste.deJson(Map<String, dynamic> json) {
    final rawFecha = json['fecha'];
    final fecha = rawFecha != null
        ? (DateTime.tryParse(rawFecha.toString()) ?? DateTime.now())
        : DateTime.now();

    return MedicionDesgaste(
      id: json['id']?.toString() ?? '',
      componente: json['componente']?.toString() ?? '',
      unidad: json['unidad']?.toString() ?? 'mm',
      valor: (json['valor'] as num?)?.toDouble() ?? 0.0,
      minimoSeguro: (json['minimoSeguro'] ?? json['minimo_seguro'] as num?)
              ?.toDouble() ??
          0.0,
      maximoSeguro:
          (json['maximoSeguro'] ?? json['maximo_seguro'] as num?)?.toDouble(),
      km: (json['km'] as num?)?.toDouble() ?? 0.0,
      fecha: fecha,
      nota: json['nota']?.toString(),
    );
  }
}

/// Refacción del catálogo oficial DM300 con condiciones de compatibilidad.
class RefaccionDm300 {
  const RefaccionDm300({
    required this.id,
    required this.sku,
    required this.nombre,
    required this.categoria,
    required this.zona,
    required this.precioEstimado,
    this.dependeDeClaveFicha,
    this.valorRequerido,
    this.requiereAccesorio,
    this.notas,
  });

  final String id;
  final String sku;
  final String nombre;
  final String categoria;
  final String zona;
  final double precioEstimado;
  final String? dependeDeClaveFicha;
  final String? valorRequerido;
  final String? requiereAccesorio;
  final String? notas;

  RefaccionDm300 copiarCon({
    String? id,
    String? sku,
    String? nombre,
    String? categoria,
    String? zona,
    double? precioEstimado,
    String? dependeDeClaveFicha,
    String? valorRequerido,
    String? requiereAccesorio,
    String? notas,
  }) {
    return RefaccionDm300(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      nombre: nombre ?? this.nombre,
      categoria: categoria ?? this.categoria,
      zona: zona ?? this.zona,
      precioEstimado: precioEstimado ?? this.precioEstimado,
      dependeDeClaveFicha: dependeDeClaveFicha ?? this.dependeDeClaveFicha,
      valorRequerido: valorRequerido ?? this.valorRequerido,
      requiereAccesorio: requiereAccesorio ?? this.requiereAccesorio,
      notas: notas ?? this.notas,
    );
  }

  Map<String, dynamic> aJson() {
    return {
      'id': id,
      'sku': sku,
      'nombre': nombre,
      'categoria': categoria,
      'zona': zona,
      'precioEstimado': precioEstimado,
      'dependeDeClaveFicha': dependeDeClaveFicha,
      'valorRequerido': valorRequerido,
      'requiereAccesorio': requiereAccesorio,
      'notas': notas,
    };
  }

  factory RefaccionDm300.deJson(Map<String, dynamic> json) {
    return RefaccionDm300(
      id: json['id']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      nombre: json['nombre']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? '',
      zona: json['zona']?.toString() ?? '',
      precioEstimado: (json['precioEstimado'] ?? json['precio_estimado'] as num?)
              ?.toDouble() ??
          0.0,
      dependeDeClaveFicha: (json['dependeDeClaveFicha'] ??
              json['depende_de_clave_ficha'])
          ?.toString(),
      valorRequerido:
          (json['valorRequerido'] ?? json['valor_requerido'])?.toString(),
      requiereAccesorio:
          (json['requiereAccesorio'] ?? json['requiere_accesorio'])?.toString(),
      notas: json['notas']?.toString(),
    );
  }
}

/// Estado de compatibilidad de una refacción frente a la Ficha Técnica de la moto.
enum EstadoCompatibilidadRefaccion {
  sugerida,
  dudosaPendienteFicha,
  noAplicaAccesorio,
}

/// Resultado de la evaluación inteligente de una refacción según la ficha técnica.
class RefaccionEvaluada {
  const RefaccionEvaluada({
    required this.refaccion,
    required this.estado,
    required this.motivo,
    this.claveFichaPendiente,
  });

  final RefaccionDm300 refaccion;
  final EstadoCompatibilidadRefaccion estado;
  final String motivo;
  final String? claveFichaPendiente;
}
