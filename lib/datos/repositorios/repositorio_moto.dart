import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../dominio/modelos/estado_tarea.dart';
import '../../dominio/modelos/ficha_moto.dart';
import '../../dominio/modelos/lectura_odometro.dart';
import '../../dominio/modelos/modelos_mantenimiento.dart';
import '../../dominio/reglas/motor_mantenimiento.dart';
import '../../dominio/reglas/validador_odometro.dart';

/// Repositorio reactivo central de la Italika DM300.
///
/// Gestiona el expediente de la moto, validación de odómetro, registro de servicios,
/// cargas de gasolina, mediciones de desgaste y compatibilidad de refacciones.
/// Soporta carga desde semillas JSON, persistencia local en JSON y sincronización simulada con Supabase.
class RepositorioMoto extends ChangeNotifier {
  static final RepositorioMoto instancia = RepositorioMoto._interno();

  factory RepositorioMoto() => instancia;

  RepositorioMoto._interno();

  static const String _nombreArchivoLocal = 'dm300_system_state_v1.json';

  bool _inicializado = false;
  DateTime? _ultimaSincronizacion;

  Map<String, dynamic> _moto = {};
  List<CampoFicha> _camposFicha = [];
  List<LecturaOdometro> _lecturasOdometro = [];
  List<TareaMantenimiento> _tareasMantenimiento = [];
  List<RegistroServicio> _registrosServicio = [];
  List<CargaCombustible> _cargasCombustible = [];
  List<MedicionDesgaste> _medicionesDesgaste = [];
  List<RefaccionDm300> _catalogoRefacciones = [];

  // ==========================================
  // GETTERS DE ESTADO REACTIVO
  // ==========================================

  bool get inicializado => _inicializado;
  DateTime? get ultimaSincronizacion => _ultimaSincronizacion;

  Map<String, dynamic> get moto => Map.unmodifiable(_moto);
  List<CampoFicha> get camposFicha => List.unmodifiable(_camposFicha);
  List<LecturaOdometro> get lecturasOdometro =>
      List.unmodifiable(_lecturasOdometro);
  List<TareaMantenimiento> get tareasMantenimiento =>
      List.unmodifiable(_tareasMantenimiento);
  List<RegistroServicio> get registrosServicio =>
      List.unmodifiable(_registrosServicio);
  List<CargaCombustible> get cargasCombustible =>
      List.unmodifiable(_cargasCombustible);
  List<MedicionDesgaste> get medicionesDesgaste =>
      List.unmodifiable(_medicionesDesgaste);
  List<RefaccionDm300> get catalogoRefacciones =>
      List.unmodifiable(_catalogoRefacciones);

  /// Kilometraje más reciente confirmado en el odómetro.
  double get kmActual {
    if (_lecturasOdometro.isEmpty) return 23880.0;
    final ordenadas = List<LecturaOdometro>.from(_lecturasOdometro)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    return ordenadas.last.km;
  }

  /// Kilometraje estimado al día de hoy según proyección de uso diario.
  double get kmEstimadoHoy =>
      ValidadorOdometro.estimarKmHoy(lecturas: _lecturasOdometro);

  /// Promedio de kilómetros recorridos por día según historial.
  double get promedioDiarioKm =>
      ValidadorOdometro.calcularPromedioDiario(_lecturasOdometro);

  /// Cantidad de campos técnicos verificados físicamente.
  int get camposVerificadosCount =>
      _camposFicha.where((c) => c.estaVerificado).length;

  /// Total de campos técnicos en la ficha de la DM300.
  int get totalCamposFicha => _camposFicha.length;

  /// Porcentaje de salud general del sistema de mantenimiento.
  double get saludGeneral => MotorMantenimiento.saludGeneralPorcentaje(
        _tareasMantenimiento,
        kmActual,
        DateTime.now(),
      );

  /// Rendimiento promedio histórico en km/L.
  double? get rendimientoPromedioKmL =>
      MotorMantenimiento.calcularRendimientoPromedioKmL(_cargasCombustible);

  /// Alerta de caída de rendimiento (>15%) si aplica.
  String? get alertaRendimiento =>
      MotorMantenimiento.detectarCaidaRendimiento(_cargasCombustible);

  /// Días transcurridos desde la última toma de lectura del odómetro.
  int get diasSinLectura {
    if (_lecturasOdometro.isEmpty) return 0;
    final ordenadas = List<LecturaOdometro>.from(_lecturasOdometro)
      ..sort((a, b) => a.fecha.compareTo(b.fecha));
    final diferencia = DateTime.now().difference(ordenadas.last.fecha).inDays;
    return diferencia < 0 ? 0 : diferencia;
  }

  /// Kilómetros recorridos en cada uno de los últimos 12 meses.
  List<double> get kmUltimos12Meses =>
      MotorMantenimiento.calcularKmUltimos12Meses(
          _lecturasOdometro, DateTime.now());

  /// Catálogo de refacciones evaluado frente a la ficha técnica actual.
  List<RefaccionEvaluada> get refaccionesEvaluadas =>
      MotorMantenimiento.filtrarRefacciones(
        catalogo: _catalogoRefacciones,
        ficha: _camposFicha,
      );

  // ==========================================
  // INICIALIZACIÓN Y PERSISTENCIA
  // ==========================================

  /// Inicializa el repositorio desde el almacenamiento local o semillas JSON.
  Future<void> inicializar() async {
    if (_inicializado) return;

    Map<String, dynamic>? datosJson;

    // 1. Intentar leer estado persistido localmente
    if (!kIsWeb) {
      try {
        final archivo = File('${Directory.systemTemp.path}/$_nombreArchivoLocal');
        if (await archivo.exists()) {
          final contenido = await archivo.readAsString();
          datosJson = jsonDecode(contenido) as Map<String, dynamic>;
        }
      } catch (_) {
        // En caso de error de lectura, continuamos al fallback
      }
    }

    // 2. Si no hay persistencia previa, leer de rootBundle o fallback en memoria
    if (datosJson == null) {
      try {
        final contenidoAsset = await rootBundle
            .loadString('assets/semillas/catalogo_dm300.json');
        datosJson = jsonDecode(contenidoAsset) as Map<String, dynamic>;
      } catch (_) {
        datosJson = jsonDecode(_semillaEmbebidaDm300) as Map<String, dynamic>;
      }
    }

    _cargarDesdeMapa(datosJson!);
    _inicializado = true;
    await _guardarEstadoLocal();
    notifyListeners();
  }

  void _cargarDesdeMapa(Map<String, dynamic> datos) {
    _moto = (datos['moto'] as Map<String, dynamic>?) ?? {};

    final rawFicha = datos['ficha_campos'] as List? ?? [];
    _camposFicha = rawFicha
        .map((e) => CampoFicha.deJson(e as Map<String, dynamic>))
        .toList();

    final rawTareas = datos['tareas_mantenimiento'] as List? ?? [];
    _tareasMantenimiento = rawTareas
        .map((e) => TareaMantenimiento.deJson(e as Map<String, dynamic>))
        .toList();

    final rawRefacciones = datos['refacciones'] as List? ?? [];
    _catalogoRefacciones = rawRefacciones
        .map((e) => RefaccionDm300.deJson(e as Map<String, dynamic>))
        .toList();

    final rawLecturas = datos['lecturas_odometro'] as List? ?? [];
    _lecturasOdometro = rawLecturas
        .map((e) => LecturaOdometro.deJson(e as Map<String, dynamic>))
        .toList();

    final rawCargas = datos['cargas_combustible'] as List? ?? [];
    _cargasCombustible = rawCargas
        .map((e) => CargaCombustible.deJson(e as Map<String, dynamic>))
        .toList();

    final rawServicios = datos['registros_servicio'] as List? ?? [];
    _registrosServicio = rawServicios
        .map((e) => RegistroServicio.deJson(e as Map<String, dynamic>))
        .toList();

    final rawMediciones = datos['mediciones_desgaste'] as List? ?? [];
    _medicionesDesgaste = rawMediciones
        .map((e) => MedicionDesgaste.deJson(e as Map<String, dynamic>))
        .toList();

    if (datos['ultimaSincronizacion'] != null) {
      _ultimaSincronizacion =
          DateTime.tryParse(datos['ultimaSincronizacion'].toString());
    }
  }

  Future<void> _guardarEstadoLocal() async {
    if (kIsWeb) return;
    try {
      final archivo = File('${Directory.systemTemp.path}/$_nombreArchivoLocal');
      final mapa = {
        'moto': _moto,
        'ficha_campos': _camposFicha.map((c) => c.aJson()).toList(),
        'tareas_mantenimiento':
            _tareasMantenimiento.map((t) => t.aJson()).toList(),
        'refacciones': _catalogoRefacciones.map((r) => r.aJson()).toList(),
        'lecturas_odometro': _lecturasOdometro.map((o) => o.aJson()).toList(),
        'cargas_combustible':
            _cargasCombustible.map((c) => c.aJson()).toList(),
        'registros_servicio':
            _registrosServicio.map((s) => s.aJson()).toList(),
        'mediciones_desgaste':
            _medicionesDesgaste.map((m) => m.aJson()).toList(),
        'ultimaSincronizacion': _ultimaSincronizacion?.toIso8601String(),
      };
      await archivo.writeAsString(jsonEncode(mapa));
    } catch (_) {
      // Ignorar fallas silenciosas en persistencia temporal
    }
  }

  // ==========================================
  // OPERACIONES DE DOMINIO Y TRANSACCIONES
  // ==========================================

  /// Prevalida un valor de odómetro sin registrarlo.
  ResultadoValidacionOdometro prevalidarOdometro(
    double nuevoKm, {
    bool cambioTablero = false,
    DateTime? fecha,
  }) {
    final fechaNueva = fecha ?? DateTime.now();

    final fechaUltima = _lecturasOdometro.isNotEmpty
        ? (_lecturasOdometro..sort((a, b) => a.fecha.compareTo(b.fecha)))
            .last
            .fecha
        : DateTime(2024, 1, 1);

    return ValidadorOdometro.validar(
      nuevoKm: nuevoKm,
      ultimoKm: kmActual,
      fechaUltimaLectura: fechaUltima,
      fechaNueva: fechaNueva,
      cambioTablero: cambioTablero,
    );
  }

  /// Registra una nueva lectura en el odómetro aplicando las reglas de validación.
  Future<ResultadoValidacionOdometro> registrarLecturaOdometro(
    double nuevoKm, {
    OrigenOdometro origen = OrigenOdometro.rapido,
    bool cambioTablero = false,
    String? nota,
    DateTime? fecha,
  }) async {
    final dictamen = prevalidarOdometro(
      nuevoKm,
      cambioTablero: cambioTablero,
      fecha: fecha,
    );

    if (!dictamen.permiteGuardar) {
      return dictamen;
    }

    final nuevaLectura = LecturaOdometro(
      id: 'odo_${DateTime.now().millisecondsSinceEpoch}',
      km: nuevoKm,
      fecha: fecha ?? DateTime.now(),
      origen: origen,
      cambioTablero: cambioTablero,
      nota: nota,
    );

    _lecturasOdometro.add(nuevaLectura);
    await _guardarEstadoLocal();
    notifyListeners();
    return dictamen;
  }

  /// Actualiza el valor y estado de verificación de un campo de la Ficha Técnica.
  Future<void> actualizarCampoFicha(
    String clave,
    String valor, {
    EstadoCampoFicha? estado,
    String? notaFoto,
  }) async {
    final indice = _camposFicha.indexWhere(
      (c) => c.clave.toLowerCase() == clave.toLowerCase(),
    );

    final ahora = DateTime.now();
    final nuevoEstado = estado ?? EstadoCampoFicha.verificado;

    if (indice != -1) {
      _camposFicha[indice] = _camposFicha[indice].copiarCon(
        valor: valor,
        estado: nuevoEstado,
        notaFoto: notaFoto,
        actualizadoEn: ahora,
      );
    } else {
      _camposFicha.add(CampoFicha(
        clave: clave,
        seccion: SeccionFicha.identidad,
        titulo: clave,
        pregunta: '¿Cuál es el valor de $clave?',
        dondeVerlo: 'Manual o inspección visual',
        opciones: const [],
        valor: valor,
        estado: nuevoEstado,
        notaFoto: notaFoto,
        actualizadoEn: ahora,
      ));
    }

    await _guardarEstadoLocal();
    notifyListeners();
  }

  /// Registra una intervención de mantenimiento y actualiza la tarea correspondiente.
  Future<void> registrarServicioTarea({
    required String tareaId,
    required double km,
    required String realizadoPor,
    required double costo,
    String? notas,
    DateTime? fecha,
  }) async {
    final fechaServicio = fecha ?? DateTime.now();

    final indiceTarea =
        _tareasMantenimiento.indexWhere((t) => t.id == tareaId);
    String tituloTarea = tareaId;
    String zona = 'Motor y aceite';

    if (indiceTarea != -1) {
      final actual = _tareasMantenimiento[indiceTarea];
      tituloTarea = actual.titulo;
      zona = actual.zona;

      _tareasMantenimiento[indiceTarea] = actual.copiarCon(
        ultimoKm: km,
        ultimaFecha: fechaServicio,
        hechoPor: realizadoPor,
        ultimoCosto: costo,
      );
    }

    final nuevoRegistro = RegistroServicio(
      id: 'srv_${DateTime.now().millisecondsSinceEpoch}',
      tareaId: tareaId,
      tituloTarea: tituloTarea,
      zona: zona,
      km: km,
      fecha: fechaServicio,
      realizadoPor: realizadoPor,
      costo: costo,
      notas: notas,
    );

    _registrosServicio.add(nuevoRegistro);

    // Si el odómetro es menor al km de servicio, actualizamos la lectura
    if (km > kmActual) {
      _lecturasOdometro.add(LecturaOdometro(
        id: 'odo_${DateTime.now().millisecondsSinceEpoch}',
        km: km,
        fecha: fechaServicio,
        origen: OrigenOdometro.servicio,
        nota: 'Actualizado tras servicio: $tituloTarea',
      ));
    }

    await _guardarEstadoLocal();
    notifyListeners();
  }

  /// Registra una carga de combustible y calcula el rendimiento si hay una carga previa.
  Future<void> registrarCargaCombustible({
    required double km,
    required double litros,
    required double costo,
    DateTime? fecha,
  }) async {
    final fechaCarga = fecha ?? DateTime.now();
    double? kmPorLitro;

    if (_cargasCombustible.isNotEmpty && litros > 0) {
      final ordenadas = List<CargaCombustible>.from(_cargasCombustible)
        ..sort((a, b) => a.fecha.compareTo(b.fecha));
      final previa = ordenadas.last;
      final deltaKm = km - previa.km;
      if (deltaKm > 0) {
        kmPorLitro = double.parse((deltaKm / litros).toStringAsFixed(1));
      }
    }

    final nuevaCarga = CargaCombustible(
      id: 'cga_${DateTime.now().millisecondsSinceEpoch}',
      km: km,
      litros: litros,
      costo: costo,
      fecha: fechaCarga,
      kmPorLitro: kmPorLitro,
    );

    _cargasCombustible.add(nuevaCarga);

    if (km > kmActual) {
      _lecturasOdometro.add(LecturaOdometro(
        id: 'odo_${DateTime.now().millisecondsSinceEpoch}',
        km: km,
        fecha: fechaCarga,
        origen: OrigenOdometro.combustible,
        nota: 'Lectura en carga de gasolina',
      ));
    }

    await _guardarEstadoLocal();
    notifyListeners();
  }

  /// Registra una medición de desgaste físico (balatas, cadena, etc.).
  Future<void> registrarMedicionDesgaste({
    required String componente,
    required String unidad,
    required double valor,
    required double minimoSeguro,
    double? maximoSeguro,
    required double km,
    String? nota,
    DateTime? fecha,
  }) async {
    final nuevaMedicion = MedicionDesgaste(
      id: 'med_${DateTime.now().millisecondsSinceEpoch}',
      componente: componente,
      unidad: unidad,
      valor: valor,
      minimoSeguro: minimoSeguro,
      maximoSeguro: maximoSeguro,
      km: km,
      fecha: fecha ?? DateTime.now(),
      nota: nota,
    );

    _medicionesDesgaste.add(nuevaMedicion);
    await _guardarEstadoLocal();
    notifyListeners();
  }

  /// Simula la sincronización bidireccional con Supabase.
  Future<Map<String, dynamic>> simularSincronizacionSupabase() async {
    await Future.delayed(const Duration(milliseconds: 350));
    _ultimaSincronizacion = DateTime.now();

    final totalRegistros = _camposFicha.length +
        _lecturasOdometro.length +
        _tareasMantenimiento.length +
        _registrosServicio.length +
        _cargasCombustible.length +
        _medicionesDesgaste.length;

    await _guardarEstadoLocal();
    notifyListeners();

    return {
      'exito': true,
      'registrosSincronizados': totalRegistros,
      'ultimaSincronizacion': _ultimaSincronizacion!.toIso8601String(),
      'mensaje': 'Sincronización Supabase completada sin conflictos.',
    };
  }

  /// Obtiene el estado actual de una tarea por su identificador.
  EstadoTarea estadoDeTarea(String tareaId) {
    final tarea =
        _tareasMantenimiento.where((t) => t.id == tareaId).firstOrNull;
    if (tarea == null) return EstadoTarea.sinDatos;
    return MotorMantenimiento.evaluarTarea(tarea, kmActual, DateTime.now());
  }

  /// Obtiene el estado consolidado de una zona de la motocicleta.
  EstadoTarea estadoDeZona(String zona) {
    final tareas = tareasPorZona(zona);
    if (tareas.isEmpty) return EstadoTarea.sinDatos;

    final ahora = DateTime.now();
    bool tieneProximo = false;

    for (final t in tareas) {
      final estado = MotorMantenimiento.evaluarTarea(t, kmActual, ahora);
      if (estado == EstadoTarea.vencido) {
        return EstadoTarea.vencido;
      }
      if (estado == EstadoTarea.proximo) {
        tieneProximo = true;
      }
    }

    if (tieneProximo) {
      return EstadoTarea.proximo;
    }

    final todasAlDia = tareas.every(
      (t) =>
          MotorMantenimiento.evaluarTarea(t, kmActual, ahora) ==
          EstadoTarea.alDia,
    );

    return todasAlDia ? EstadoTarea.alDia : EstadoTarea.sinDatos;
  }

  /// Filtra las tareas pertenecientes a una zona visual de la moto.
  List<TareaMantenimiento> tareasPorZona(String zona) {
    return _tareasMantenimiento
        .where((t) => t.zona.trim().toLowerCase() == zona.trim().toLowerCase())
        .toList();
  }

  // ==========================================
  // RESPALDO EMBEBIDO DART (Offline / Fallback)
  // ==========================================
  static const String _semillaEmbebidaDm300 = '''
{
  "moto": {
    "modelo": "Italika DM300",
    "año": 2024,
    "ano": 2024,
    "cilindrada": "292 cc",
    "tanqueL": 12.0,
    "aceiteL": 1.3
  },
  "ficha_campos": [
    {"clave": "fecha_compra", "seccion": "identidad", "titulo": "Fecha de compra", "pregunta": "¿En qué fecha se adquirió la motocicleta?", "dondeVerlo": "Factura original de compra", "opciones": [], "valor": "2024-01-15", "estadoInicial": "verificado"},
    {"clave": "km_compra", "seccion": "identidad", "titulo": "Kilometraje inicial", "pregunta": "¿Con cuántos kilómetros salió de la agencia?", "dondeVerlo": "Odómetro de entrega", "opciones": [], "valor": "0", "estadoInicial": "verificado"},
    {"clave": "tipo_uso", "seccion": "identidad", "titulo": "Tipo de uso principal", "pregunta": "¿Qué tipo de terreno tiene la DM300?", "dondeVerlo": "Declarado por usuario", "opciones": ["Ciudad", "Terracería", "Mixto ciudad y terracería"], "valor": "Mixto ciudad y terracería", "estadoInicial": "verificado"},
    {"clave": "niv", "seccion": "identidad", "titulo": "NIV (Número de serie)", "pregunta": "¿Cuál es el número de serie de 17 dígitos?", "dondeVerlo": "Pág. 18, tubo del cabezal", "opciones": [], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "numero_motor", "seccion": "identidad", "titulo": "Número de motor", "pregunta": "¿Qué código tiene grabado el motor?", "dondeVerlo": "Pág. 18, cárter izquierdo", "opciones": [], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "paso_cadena", "seccion": "traccion", "titulo": "Paso de cadena", "pregunta": "¿Qué paso tiene la cadena actual?", "dondeVerlo": "Grabado en los eslabones", "opciones": ["428", "520"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "eslabones_cadena", "seccion": "traccion", "titulo": "Eslabones de cadena", "pregunta": "¿Cuántos eslabones tiene instalados?", "dondeVerlo": "Conteo o manual (132L)", "opciones": ["132", "136", "140"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "dientes_corona", "seccion": "traccion", "titulo": "Dientes de corona", "pregunta": "¿Cuántos dientes tiene la corona trasera?", "dondeVerlo": "Cara plana trasera (45T)", "opciones": ["43T", "45T", "48T"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "dientes_pinon", "seccion": "traccion", "titulo": "Dientes de piñón", "pregunta": "¿Cuántos dientes tiene el piñón delantero?", "dondeVerlo": "Piñón de salida (15T)", "opciones": ["14T", "15T", "16T"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "bateria_codigo_capacidad", "seccion": "electrico", "titulo": "Batería y capacidad", "pregunta": "¿Qué modelo de batería está montada?", "dondeVerlo": "Bajo el asiento (12V 9Ah)", "opciones": ["12V 9Ah", "12V 7Ah"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "modelo_bujia", "seccion": "electrico", "titulo": "Modelo de bujía", "pregunta": "¿Qué bujía tiene el motor?", "dondeVerlo": "Cuerpo de bujía (D8EA)", "opciones": ["D8EA", "DR8EA", "D9EA"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "llanta_delantera", "seccion": "llantas", "titulo": "Llanta delantera", "pregunta": "¿Qué medida tiene la llanta frontal?", "dondeVerlo": "Costado de llanta (80/100-21)", "opciones": ["80/100-21"], "valor": "80/100-21", "estadoInicial": "verificado"},
    {"clave": "llanta_trasera", "seccion": "llantas", "titulo": "Llanta trasera", "pregunta": "¿Qué medida tiene la llanta trasera?", "dondeVerlo": "Costado de llanta (120/80-18)", "opciones": ["120/80-18"], "valor": "120/80-18", "estadoInicial": "verificado"},
    {"clave": "presion_llantas", "seccion": "llantas", "titulo": "Presión de llantas", "pregunta": "¿A qué presión se calibran en frío?", "dondeVerlo": "Basculante (28/32 PSI)", "opciones": ["28 PSI / 32 PSI"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "aceite_especificacion", "seccion": "motor", "titulo": "Aceite motor", "pregunta": "¿Qué aceite usa el motor?", "dondeVerlo": "Pág. 24 del manual (1.3 L)", "opciones": ["20W-50 Mineral", "15W-50 Semisintético", "10W-40 Sintético"], "valor": "20W-50 Mineral", "estadoInicial": "verificado"},
    {"clave": "filtro_aire_tipo", "seccion": "motor", "titulo": "Filtro de aire", "pregunta": "¿De qué material es el filtro?", "dondeVerlo": "Bajo asiento (esponja)", "opciones": ["Esponja lavable", "Papel"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "liquido_frenos", "seccion": "frenosSuspension", "titulo": "Líquido de frenos", "pregunta": "¿Qué grado DOT indica la bomba?", "dondeVerlo": "Tapa de depósito bomba", "opciones": ["DOT 3", "DOT 4"], "valor": "DOT 4", "estadoInicial": "verificado"},
    {"clave": "espesor_balatas_actual", "seccion": "frenosSuspension", "titulo": "Espesor balatas", "pregunta": "¿Cuánto espesor de pasta queda?", "dondeVerlo": "Ranura cáliper delantero", "opciones": ["> 3.0 mm", "2.0 a 3.0 mm", "< 2.0 mm"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "medida_reten_suspension", "seccion": "frenosSuspension", "titulo": "Retén de suspensión", "pregunta": "¿Qué medida tienen los retenes?", "dondeVerlo": "Manual (37x50x11 mm)", "opciones": ["37x50x11 mm"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "protectores_puno", "seccion": "accesorios", "titulo": "Protectores de puños", "pregunta": "¿Tiene cubrepuños instalados?", "dondeVerlo": "Extremos del manillar", "opciones": ["Sí", "No"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "porta_celular", "seccion": "accesorios", "titulo": "Soporte celular", "pregunta": "¿Cuenta con soporte en manillar?", "dondeVerlo": "Centro del manillar", "opciones": ["Sí", "No"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "faros_auxiliares", "seccion": "accesorios", "titulo": "Faros auxiliares", "pregunta": "¿Tiene faros exploradores?", "dondeVerlo": "Defensas laterales", "opciones": ["Sí", "No"], "valor": "Sí", "estadoInicial": "verificado"},
    {"clave": "parachoques", "seccion": "accesorios", "titulo": "Defensas de motor", "pregunta": "¿Tiene defensas tubulares?", "dondeVerlo": "Lados del motor", "opciones": ["Sí", "No"], "valor": "", "estadoInicial": "pendiente"},
    {"clave": "cubrecarter", "seccion": "accesorios", "titulo": "Cubrecárter", "pregunta": "¿Tiene placa inferior?", "dondeVerlo": "Parte baja del cárter", "opciones": ["Sí", "No"], "valor": "No", "estadoInicial": "verificado"}
  ],
  "tareas_mantenimiento": [
    {"id": "tarea_cadena", "zona": "Cadena y transmisión", "titulo": "Cadena y transmisión", "descripcion": "Holgura 15 a 20 mm · lubricar cada mes", "intervaloKm": 1000.0, "intervaloDias": 30, "ultimoKm": 22700.0, "ultimaFecha": "2026-10-04T10:00:00Z", "hechoPor": "Mí", "ultimoCosto": 120.0},
    {"id": "tarea_aceite", "zona": "Motor y aceite", "titulo": "Motor y aceite", "descripcion": "Aceite 1.3 L · bujía 0.6 a 0.7 mm", "intervaloKm": 3000.0, "intervaloDias": 120, "ultimoKm": 21000.0, "ultimaFecha": "2026-09-15T15:00:00Z", "hechoPor": "Taller", "ultimoCosto": 350.0},
    {"id": "tarea_freno_delantero", "zona": "Freno delantero", "titulo": "Freno delantero", "descripcion": "Balatas: límite 2 mm · líquido DOT 3 o 4", "intervaloKm": 3000.0, "intervaloDias": 90, "ultimoKm": null, "ultimaFecha": null, "hechoPor": null, "ultimoCosto": null},
    {"id": "tarea_tanque", "zona": "Tanque y combustible", "titulo": "Tanque y combustible", "descripcion": "Capacidad 12 L · llave de paso", "intervaloKm": 6000.0, "intervaloDias": 180, "ultimoKm": 22500.0, "ultimaFecha": "2026-10-15T12:00:00Z", "hechoPor": "Mí", "ultimoCosto": 80.0},
    {"id": "tarea_escape", "zona": "Escape", "titulo": "Escape", "descripcion": "Gomas de soporte y empaque del tubo", "intervaloKm": 6000.0, "intervaloDias": 180, "ultimoKm": 23000.0, "ultimaFecha": "2026-10-25T17:00:00Z", "hechoPor": "Mí", "ultimoCosto": 0.0},
    {"id": "tarea_bujia", "zona": "Eléctrico y llantas", "titulo": "Bujía e instalación eléctrica", "descripcion": "Calibrar bujía a 0.6-0.7 mm", "intervaloKm": 6000.0, "intervaloDias": 180, "ultimoKm": 21000.0, "ultimaFecha": "2026-09-15T15:30:00Z", "hechoPor": "Mí", "ultimoCosto": 95.0},
    {"id": "tarea_llantas", "zona": "Eléctrico y llantas", "titulo": "Presión y rayos de llantas", "descripcion": "28 PSI delantera / 32 PSI trasera", "intervaloKm": 1000.0, "intervaloDias": 15, "ultimoKm": 23800.0, "ultimaFecha": "2026-11-10T09:00:00Z", "hechoPor": "Mí", "ultimoCosto": 0.0}
  ],
  "refacciones": [
    {"id": "ref_arrastre_428", "sku": "DM300-CAD-428", "nombre": "Kit de arrastre paso 428 reforzado", "categoria": "Transmisión", "zona": "Cadena y transmisión", "precioEstimado": 680.0, "dependeDeClaveFicha": "paso_cadena", "valorRequerido": "428"},
    {"id": "ref_arrastre_520", "sku": "DM300-CAD-520", "nombre": "Kit de arrastre paso 520 O-Ring", "categoria": "Transmisión", "zona": "Cadena y transmisión", "precioEstimado": 1150.0, "dependeDeClaveFicha": "paso_cadena", "valorRequerido": "520"},
    {"id": "ref_aceite_20w50", "sku": "DM300-MOT-OIL20W50", "nombre": "Aceite 4T 20W-50 1.3L + cedazo", "categoria": "Motor", "zona": "Motor y aceite", "precioEstimado": 240.0, "dependeDeClaveFicha": "aceite_especificacion", "valorRequerido": "20W-50 Mineral"},
    {"id": "ref_bujia", "sku": "DM300-ELE-D8EA", "nombre": "Bujía D8EA / DR8EA", "categoria": "Eléctrico", "zona": "Eléctrico y llantas", "precioEstimado": 95.0},
    {"id": "ref_balatas_del", "sku": "DM300-FRE-BALDEL", "nombre": "Balatas delanteras DM300", "categoria": "Frenos", "zona": "Freno delantero", "precioEstimado": 190.0},
    {"id": "ref_filtro_aire", "sku": "DM300-MOT-FAIRE", "nombre": "Filtro de aire esponja bajo asiento", "categoria": "Admisión", "zona": "Motor y aceite", "precioEstimado": 130.0},
    {"id": "ref_soporte_faros", "sku": "DM300-ACC-SOPFARO", "nombre": "Soporte antivibración para faros auxiliares", "categoria": "Accesorios", "zona": "Eléctrico y llantas", "precioEstimado": 220.0, "requiereAccesorio": "faros_auxiliares"},
    {"id": "ref_tornillo_cubrecarter", "sku": "DM300-ACC-TORNCC", "nombre": "Tornillería de cubrecárter", "categoria": "Accesorios", "zona": "Motor y aceite", "precioEstimado": 85.0, "requiereAccesorio": "cubrecarter"},
    {"id": "ref_camara_del", "sku": "DM300-LLA-CAM21", "nombre": "Cámara delantera 80/100-21", "categoria": "Llantas", "zona": "Eléctrico y llantas", "precioEstimado": 140.0},
    {"id": "ref_bateria_gel", "sku": "DM300-ELE-BAT12V", "nombre": "Batería 12V gel", "categoria": "Eléctrico", "zona": "Eléctrico y llantas", "precioEstimado": 650.0}
  ],
  "lecturas_odometro": [
    {"id": "odo_001", "km": 1500.0, "fecha": "2025-12-01T10:00:00Z", "origen": "fichaInicial", "cambioTablero": false},
    {"id": "odo_002", "km": 3500.0, "fecha": "2026-01-05T10:00:00Z", "origen": "servicio", "cambioTablero": false},
    {"id": "odo_003", "km": 5400.0, "fecha": "2026-02-08T10:00:00Z", "origen": "combustible", "cambioTablero": false},
    {"id": "odo_004", "km": 7200.0, "fecha": "2026-03-12T10:00:00Z", "origen": "servicio", "cambioTablero": false},
    {"id": "odo_005", "km": 9150.0, "fecha": "2026-04-15T10:00:00Z", "origen": "rapido", "cambioTablero": false},
    {"id": "odo_006", "km": 11300.0, "fecha": "2026-05-18T10:00:00Z", "origen": "rapido", "cambioTablero": false},
    {"id": "odo_007", "km": 13400.0, "fecha": "2026-06-20T10:00:00Z", "origen": "servicio", "cambioTablero": false},
    {"id": "odo_008", "km": 15600.0, "fecha": "2026-07-22T10:00:00Z", "origen": "combustible", "cambioTablero": false},
    {"id": "odo_009", "km": 17750.0, "fecha": "2026-08-25T10:00:00Z", "origen": "servicio", "cambioTablero": false},
    {"id": "odo_010", "km": 19900.0, "fecha": "2026-09-28T10:00:00Z", "origen": "combustible", "cambioTablero": false},
    {"id": "odo_011", "km": 21000.0, "fecha": "2026-09-15T15:00:00Z", "origen": "servicio", "cambioTablero": false},
    {"id": "odo_012", "km": 22700.0, "fecha": "2026-10-04T10:00:00Z", "origen": "servicio", "cambioTablero": false},
    {"id": "odo_013", "km": 23800.0, "fecha": "2026-11-10T09:00:00Z", "origen": "combustible", "cambioTablero": false},
    {"id": "odo_014", "km": 23880.0, "fecha": "2026-11-13T18:00:00Z", "origen": "rapido", "cambioTablero": false}
  ],
  "cargas_combustible": [
    {"id": "cga_001", "km": 21850.0, "litros": 10.5, "costo": 262.5, "fecha": "2026-09-22T08:00:00Z", "kmPorLitro": 28.6},
    {"id": "cga_002", "km": 22150.0, "litros": 10.2, "costo": 255.0, "fecha": "2026-09-29T08:30:00Z", "kmPorLitro": 29.4},
    {"id": "cga_003", "km": 22440.0, "litros": 10.1, "costo": 252.5, "fecha": "2026-10-06T09:00:00Z", "kmPorLitro": 28.7},
    {"id": "cga_004", "km": 22730.0, "litros": 10.4, "costo": 260.0, "fecha": "2026-10-14T08:15:00Z", "kmPorLitro": 27.9},
    {"id": "cga_005", "km": 23020.0, "litros": 10.3, "costo": 257.5, "fecha": "2026-10-22T08:45:00Z", "kmPorLitro": 28.2},
    {"id": "cga_006", "km": 23310.0, "litros": 10.2, "costo": 255.0, "fecha": "2026-10-30T09:10:00Z", "kmPorLitro": 28.4},
    {"id": "cga_007", "km": 23600.0, "litros": 10.5, "costo": 262.5, "fecha": "2026-11-06T08:20:00Z", "kmPorLitro": 27.6},
    {"id": "cga_008", "km": 23880.0, "litros": 10.0, "costo": 250.0, "fecha": "2026-11-13T17:30:00Z", "kmPorLitro": 28.0}
  ],
  "registros_servicio": [
    {"id": "srv_001", "tareaId": "tarea_aceite", "tituloTarea": "Motor y aceite", "zona": "Motor y aceite", "km": 21000.0, "fecha": "2026-09-15T15:00:00Z", "realizadoPor": "Taller", "costo": 350.0},
    {"id": "srv_002", "tareaId": "tarea_cadena", "tituloTarea": "Cadena y transmisión", "zona": "Cadena y transmisión", "km": 22700.0, "fecha": "2026-10-04T10:00:00Z", "realizadoPor": "Mí", "costo": 120.0}
  ],
  "mediciones_desgaste": [
    {"id": "med_001", "componente": "Balatas delanteras", "unidad": "mm", "valor": 2.4, "minimoSeguro": 2.0, "maximoSeguro": null, "km": 23880.0, "fecha": "2026-11-13T18:00:00Z"},
    {"id": "med_002", "componente": "Holgura de cadena", "unidad": "mm", "valor": 24.0, "minimoSeguro": 15.0, "maximoSeguro": 20.0, "km": 23880.0, "fecha": "2026-11-13T18:00:00Z"}
  ]
}
''';
}
