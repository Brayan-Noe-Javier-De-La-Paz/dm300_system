/// Estado de verificación de un campo de la ficha técnica.
enum EstadoCampoFicha { pendiente, verificado }

/// Secciones del manual y ficha técnica de la DM300.
enum SeccionFicha {
  identidad('Identidad'),
  traccion('Tracción'),
  electrico('Eléctrico'),
  llantas('Llantas'),
  motor('Motor'),
  frenosSuspension('Frenos y suspensión'),
  accesorios('Accesorios');

  const SeccionFicha(this.etiqueta);
  final String etiqueta;
}

/// Representa un campo individual del expediente técnico de la motocicleta.
class CampoFicha {
  const CampoFicha({
    required this.clave,
    required this.seccion,
    required this.titulo,
    required this.pregunta,
    required this.dondeVerlo,
    required this.opciones,
    required this.valor,
    required this.estado,
    this.notaFoto,
    this.actualizadoEn,
  });

  final String clave;
  final SeccionFicha seccion;
  final String titulo;
  final String pregunta;
  final String dondeVerlo;
  final List<String> opciones;
  final String valor;
  final EstadoCampoFicha estado;
  final String? notaFoto;
  final DateTime? actualizadoEn;

  /// Indica si el dato fue verificado físicamente por el usuario.
  bool get estaVerificado => estado == EstadoCampoFicha.verificado;

  CampoFicha copiarCon({
    String? clave,
    SeccionFicha? seccion,
    String? titulo,
    String? pregunta,
    String? dondeVerlo,
    List<String>? opciones,
    String? valor,
    EstadoCampoFicha? estado,
    String? notaFoto,
    DateTime? actualizadoEn,
  }) {
    return CampoFicha(
      clave: clave ?? this.clave,
      seccion: seccion ?? this.seccion,
      titulo: titulo ?? this.titulo,
      pregunta: pregunta ?? this.pregunta,
      dondeVerlo: dondeVerlo ?? this.dondeVerlo,
      opciones: opciones ?? this.opciones,
      valor: valor ?? this.valor,
      estado: estado ?? this.estado,
      notaFoto: notaFoto ?? this.notaFoto,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  Map<String, dynamic> aJson() {
    return {
      'clave': clave,
      'seccion': seccion.name,
      'titulo': titulo,
      'pregunta': pregunta,
      'dondeVerlo': dondeVerlo,
      'opciones': opciones,
      'valor': valor,
      'estado': estado.name,
      'notaFoto': notaFoto,
      'actualizadoEn': actualizadoEn?.toIso8601String(),
    };
  }

  factory CampoFicha.deJson(Map<String, dynamic> json) {
    final seccionStr = json['seccion']?.toString() ?? '';
    final seccion = SeccionFicha.values.firstWhere(
      (s) =>
          s.name.toLowerCase() == seccionStr.toLowerCase() ||
          s.etiqueta.toLowerCase() == seccionStr.toLowerCase(),
      orElse: () => SeccionFicha.identidad,
    );

    final estadoRaw =
        (json['estado'] ?? json['estadoInicial'])?.toString() ?? '';
    final estado = estadoRaw.toLowerCase() == 'verificado'
        ? EstadoCampoFicha.verificado
        : EstadoCampoFicha.pendiente;

    final rawOpciones = json['opciones'];
    final List<String> opciones = rawOpciones is List
        ? rawOpciones.map((e) => e.toString()).toList()
        : const <String>[];

    final rawFecha = json['actualizadoEn'] ?? json['actualizado_en'];
    final actualizadoEn =
        rawFecha != null ? DateTime.tryParse(rawFecha.toString()) : null;

    return CampoFicha(
      clave: json['clave']?.toString() ?? '',
      seccion: seccion,
      titulo: json['titulo']?.toString() ?? '',
      pregunta: json['pregunta']?.toString() ?? '',
      dondeVerlo:
          (json['dondeVerlo'] ?? json['donde_verlo'])?.toString() ?? '',
      opciones: opciones,
      valor: json['valor']?.toString() ?? '',
      estado: estado,
      notaFoto: json['notaFoto']?.toString() ?? json['nota_foto']?.toString(),
      actualizadoEn: actualizadoEn,
    );
  }
}
