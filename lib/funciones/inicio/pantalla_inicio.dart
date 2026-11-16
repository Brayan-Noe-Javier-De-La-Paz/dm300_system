import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../datos/repositorios/repositorio_moto.dart';
import '../../dominio/modelos/estado_tarea.dart';
import '../../nucleo/tema/colores.dart';
import '../../nucleo/widgets/aparece.dart';
import '../../nucleo/widgets/fondo_escena.dart';
import '../../nucleo/widgets/panel_vidrio.dart';
import '../../nucleo/widgets/pildora_estado.dart';
import '../../nucleo/widgets/riel_navegacion.dart';
import '../../nucleo/widgets/vidrio_ligero.dart';
import '../desgaste/pantalla_desgaste.dart';
import '../historial/pantalla_historial.dart';
import '../mantenimiento/pantalla_mantenimiento.dart';
import '../refacciones/pantalla_refacciones.dart';
import 'asistente_ficha_moto.dart';
import 'modal_odometro_rapido.dart';
import 'tarjeta_zona.dart';
import 'tarjetas.dart';
import 'vista_moto.dart';

const _elementos = [
  ElementoRiel(Icons.dashboard_rounded, 'Inicio'),
  ElementoRiel(Icons.build_rounded, 'Mantenimiento'),
  ElementoRiel(Icons.inventory_2_rounded, 'Refacciones'),
  ElementoRiel(Icons.speed_rounded, 'Desgaste'),
  ElementoRiel(Icons.history_rounded, 'Historial'),
  ElementoRiel(Icons.payments_rounded, 'Gastos'),
];

class PantallaInicio extends StatefulWidget {
  const PantallaInicio({super.key});

  @override
  State<PantallaInicio> createState() => _EstadoPantallaInicio();
}

class _EstadoPantallaInicio extends State<PantallaInicio> {
  final RepositorioMoto _repo = RepositorioMoto.instancia;
  int _seccion = 0;
  ZonaVista? _zona;
  String? _zonaMantenimiento;

  @override
  void initState() {
    super.initState();
    _repo.inicializar();
  }

  void _elegirZona(ZonaVista? z) => setState(() => _zona = z);

  void _irASeccion(int index, {String? zonaMantenimiento}) {
    setState(() {
      _seccion = index;
      _zonaMantenimiento = zonaMantenimiento;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        return Scaffold(
          body: FondoEscena(
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, c) =>
                    c.maxWidth >= 1000 ? _escritorio() : _movil(),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- Escritorio (Windows / tablet horizontal) ----------

  Widget _escritorio() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 96),
            child: _seccion == 0
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _barraSuperior(esAmplio: true),
                            const SizedBox(height: 8),
                            Expanded(child: _escenaEscritorio()),
                            const SizedBox(height: 12),
                            const SizedBox(
                              height: 200,
                              child: Aparece(indice: 4, child: TarjetaBarras()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      SizedBox(width: 340, child: _columnaDerecha()),
                    ],
                  )
                : _contenidoSeccion(),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
              child: RielNavegacion(
                elementos: _elementos,
                seleccionado: _seccion,
                alSeleccionar: (i) => _irASeccion(i),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _escenaEscritorio() {
    return LayoutBuilder(
      builder: (context, c) {
        final disponible = math.max(c.maxHeight - 96, 180.0);
        final ancho = math.min(c.maxWidth, disponible * (1600 / 1120));
        return Stack(
          children: [
            Center(
              child: SizedBox(
                width: ancho,
                child: VistaMoto(
                  alSeleccionarZona: _elegirZona,
                  zonaSeleccionada: _zona?.nombre,
                  estadoDeZona: _repo.estadoDeZona,
                ),
              ),
            ),
            Positioned(top: 8, left: 8, width: 320, child: _tarjetaFlotante()),
          ],
        );
      },
    );
  }

  Widget _tarjetaFlotante() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (hijo, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(anim),
          child: hijo,
        ),
      ),
      child: _zona == null
          ? const SizedBox.shrink(key: ValueKey('sin-zona'))
          : TarjetaZona(
              key: ValueKey(_zona!.nombre),
              zona: _zona!,
              alCerrar: () => _elegirZona(null),
              alVerMantenimiento: () =>
                  _irASeccion(1, zonaMantenimiento: _zona!.nombre),
            ),
    );
  }

  Widget _columnaDerecha() {
    final diasSinLectura = _repo.diasSinLectura;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        if (diasSinLectura >= 7) ...[
          Aparece(
            indice: 0,
            child: TarjetaRecordatorioKm(
              diasSinLectura: diasSinLectura,
              kmEstimado: _repo.kmEstimadoHoy,
              alActualizar: () =>
                  mostrarModalOdometroRapido(context, repo: _repo),
            ),
          ),
          const SizedBox(height: 12),
        ],
        const Aparece(indice: 1, child: TarjetaSalud()),
        const SizedBox(height: 12),
        Aparece(
          indice: 2,
          child: TarjetaFichaResumen(
            verificados: _repo.camposVerificadosCount,
            total: _repo.totalCamposFicha,
            alAbrir: () => mostrarAsistenteFichaMoto(context, repo: _repo),
          ),
        ),
        const SizedBox(height: 12),
        Aparece(indice: 3, child: _filaKpi()),
        const SizedBox(height: 12),
        Aparece(
          indice: 4,
          child: TarjetaServicio(
            alVerMantenimiento: () => _irASeccion(1),
          ),
        ),
        const SizedBox(height: 12),
        Aparece(
          indice: 5,
          child: TarjetaActividad(
            alVerTodo: () => _irASeccion(4),
          ),
        ),
      ],
    );
  }

  Widget _filaKpi() {
    final vencidas = _repo.tareasMantenimiento
        .where((t) => _repo.estadoDeTarea(t.id) == EstadoTarea.vencido)
        .length;
    final proximas = _repo.tareasMantenimiento
        .where((t) => _repo.estadoDeTarea(t.id) == EstadoTarea.proximo)
        .length;
    final alertas = vencidas + proximas;
    final kmMes = _repo.kmUltimos12Meses.isNotEmpty
        ? _repo.kmUltimos12Meses.last
        : 860.0;
    final etiquetaAlertas = vencidas > 0
        ? '$vencidas vencida${vencidas > 1 ? 's' : ''}'
        : (proximas > 0 ? '$proximas próxima${proximas > 1 ? 's' : ''}' : 'Al día');
    final estadoAlertas = vencidas > 0
        ? EstadoTarea.vencido
        : (proximas > 0 ? EstadoTarea.proximo : EstadoTarea.alDia);

    return SizedBox(
      height: 126,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: TarjetaKpi(
              titulo: 'Alertas activas',
              valor: alertas.toDouble(),
              etiqueta: etiquetaAlertas,
              estado: estadoAlertas,
              icono: Icons.notifications_active_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TarjetaKpi(
              titulo: 'Km este mes',
              valor: kmMes,
              etiqueta: '${_repo.promedioDiarioKm.round()} km/día',
              estado: EstadoTarea.alDia,
              icono: Icons.route_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraSuperior({required bool esAmplio}) {
    final alertas = _contarAlertas();
    return Row(
      children: [
        Expanded(
          child: _Buscador(
            alPresionar: _mostrarBuscadorRapido,
          ),
        ),
        if (esAmplio) ...[
          const SizedBox(width: 10),
          _ChipFicha(
            verificados: _repo.camposVerificadosCount,
            total: _repo.totalCamposFicha,
            alPresionar: () => mostrarAsistenteFichaMoto(context, repo: _repo),
          ),
        ],
        const SizedBox(width: 10),
        _Campana(
          hayAlertas: alertas > 0,
          alPresionar: _mostrarPanelAlertas,
        ),
        const SizedBox(width: 8),
        _ChipOdometro(
          km: _repo.kmActual,
          recordatorioPendiente: _repo.diasSinLectura >= 7,
          alPresionar: () => mostrarModalOdometroRapido(context, repo: _repo),
        ),
      ],
    );
  }

  int _contarAlertas() {
    var total = _repo.tareasMantenimiento
        .where((t) {
          final e = _repo.estadoDeTarea(t.id);
          return e == EstadoTarea.vencido || e == EstadoTarea.proximo;
        })
        .length;
    if (_repo.alertaRendimiento != null) total++;
    if (_repo.diasSinLectura >= 7) total++;
    return total;
  }

  // ---------- Móvil (Android < 1000 px) ----------

  Widget _movil() {
    final diasSinLectura = _repo.diasSinLectura;
    return Stack(
      children: [
        _seccion == 0
            ? ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                children: [
                  _barraSuperior(esAmplio: false),
                  if (diasSinLectura >= 7) ...[
                    const SizedBox(height: 12),
                    TarjetaRecordatorioKm(
                      diasSinLectura: diasSinLectura,
                      kmEstimado: _repo.kmEstimadoHoy,
                      alActualizar: () =>
                          mostrarModalOdometroRapido(context, repo: _repo),
                    ),
                  ],
                  const SizedBox(height: 12),
                  VistaMoto(
                    alSeleccionarZona: _elegirZona,
                    zonaSeleccionada: _zona?.nombre,
                    estadoDeZona: _repo.estadoDeZona,
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _zona == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TarjetaZona(
                              key: ValueKey(_zona!.nombre),
                              zona: _zona!,
                              alCerrar: () => _elegirZona(null),
                              alVerMantenimiento: () => _irASeccion(
                                1,
                                zonaMantenimiento: _zona!.nombre,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  TarjetaFichaResumen(
                    verificados: _repo.camposVerificadosCount,
                    total: _repo.totalCamposFicha,
                    alAbrir: () =>
                        mostrarAsistenteFichaMoto(context, repo: _repo),
                  ),
                  const SizedBox(height: 12),
                  const Aparece(indice: 1, child: TarjetaSalud()),
                  const SizedBox(height: 12),
                  Aparece(indice: 2, child: _filaKpi()),
                  const SizedBox(height: 12),
                  const SizedBox(height: 210, child: TarjetaBarras()),
                  const SizedBox(height: 12),
                  TarjetaServicio(alVerMantenimiento: () => _irASeccion(1)),
                  const SizedBox(height: 12),
                  TarjetaActividad(alVerTodo: () => _irASeccion(4)),
                ],
              )
            : _contenidoSeccion(),
        Positioned(
          left: 16,
          right: 16,
          bottom: 12,
          child: _BarraInferior(
            elementos: _elementos.take(5).toList(),
            seleccionado: _seccion.clamp(0, 4),
            alSeleccionar: (i) => _irASeccion(i),
          ),
        ),
      ],
    );
  }

  Widget _contenidoSeccion() {
    return switch (_seccion) {
      1 => PantallaMantenimiento(
          repo: _repo,
          zonaInicial: _zonaMantenimiento,
        ),
      2 => PantallaRefacciones(
          repo: _repo,
          alAbrirFicha: (clave) => mostrarAsistenteFichaMoto(
            context,
            repo: _repo,
            claveInicial: clave,
          ),
        ),
      3 => PantallaDesgaste(repo: _repo),
      4 => PantallaHistorial(repo: _repo, soloGastos: false),
      5 => PantallaHistorial(repo: _repo, soloGastos: true),
      _ => const SizedBox.shrink(),
    };
  }

  void _mostrarPanelAlertas() {
    final tareasAlerta = _repo.tareasMantenimiento.where((t) {
      final e = _repo.estadoDeTarea(t.id);
      return e == EstadoTarea.vencido || e == EstadoTarea.proximo;
    }).toList();

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: PanelVidrio(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: Colores.oroClaro,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Alertas activas · DM300',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colores.textoSecundario,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_repo.diasSinLectura >= 7)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: VidrioLigero(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.speed_rounded, color: Colores.aviso),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Pasaron ${_repo.diasSinLectura} días sin lectura de odómetro.',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              mostrarModalOdometroRapido(context, repo: _repo);
                            },
                            child: const Text('Capturar'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_repo.alertaRendimiento != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: VidrioLigero(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_gas_station_rounded,
                            color: Colores.aviso,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _repo.alertaRendimiento!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                for (final t in tareasAlerta)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: VidrioLigero(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          PildoraEstado(estado: _repo.estadoDeTarea(t.id)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.titulo,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  t.descripcion,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colores.textoSecundario,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _irASeccion(1, zonaMantenimiento: t.zona);
                            },
                            child: const Text('Ver'),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (tareasAlerta.isEmpty &&
                    _repo.alertaRendimiento == null &&
                    _repo.diasSinLectura < 7)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Tu DM300 está al día. Sin alertas pendientes.',
                      style: TextStyle(color: Colores.ok),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarBuscadorRapido() {
    String consulta = '';
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) {
          final q = consulta.trim().toLowerCase();
          final tareas = _repo.tareasMantenimiento
              .where((t) =>
                  q.isEmpty ||
                  t.titulo.toLowerCase().contains(q) ||
                  t.zona.toLowerCase().contains(q))
              .take(3)
              .toList();
          final refacciones = _repo.catalogoRefacciones
              .where((r) =>
                  q.isEmpty ||
                  r.nombre.toLowerCase().contains(q) ||
                  r.sku.toLowerCase().contains(q))
              .take(4)
              .toList();
          final campos = _repo.camposFicha
              .where((c) =>
                  q.isEmpty ||
                  c.titulo.toLowerCase().contains(q) ||
                  c.seccion.etiqueta.toLowerCase().contains(q))
              .take(3)
              .toList();

          return Dialog(
            backgroundColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: PanelVidrio(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      autofocus: true,
                      onChanged: (v) => setModal(() => consulta = v),
                      style: const TextStyle(color: Colores.texto),
                      decoration: InputDecoration(
                        hintText: 'Buscar pieza, SKU, tarea o campo de ficha…',
                        hintStyle: const TextStyle(color: Colores.textoSecundario),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Colores.oroClaro,
                        ),
                        filled: true,
                        fillColor: const Color(0x26FFFFFF),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Colores.borde),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (tareas.isNotEmpty) ...[
                              const Text(
                                'Mantenimiento',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colores.oroClaro,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final t in tareas)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.build_rounded,
                                    size: 18,
                                    color: Colores.textoSecundario,
                                  ),
                                  title: Text(t.titulo),
                                  subtitle: Text(t.zona),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _irASeccion(1, zonaMantenimiento: t.zona);
                                  },
                                ),
                            ],
                            if (refacciones.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Refacciones y SKU',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colores.oroClaro,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final r in refacciones)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.inventory_2_rounded,
                                    size: 18,
                                    color: Colores.textoSecundario,
                                  ),
                                  title: Text(r.nombre),
                                  subtitle: Text(r.sku),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _irASeccion(2);
                                  },
                                ),
                            ],
                            if (campos.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Ficha de mi moto',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colores.oroClaro,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final c in campos)
                                ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.fact_check_rounded,
                                    size: 18,
                                    color: Colores.textoSecundario,
                                  ),
                                  title: Text(c.titulo),
                                  subtitle: Text(c.seccion.etiqueta),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    mostrarAsistenteFichaMoto(
                                      context,
                                      repo: _repo,
                                      claveInicial: c.clave,
                                    );
                                  },
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Buscador extends StatelessWidget {
  const _Buscador({required this.alPresionar});

  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alPresionar,
      child: const VidrioLigero(
        radio: 999,
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 18, color: Colores.textoSecundario),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Buscar piezas, tareas, SKU…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colores.textoSecundario, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipFicha extends StatelessWidget {
  const _ChipFicha({
    required this.verificados,
    required this.total,
    required this.alPresionar,
  });

  final int verificados;
  final int total;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alPresionar,
      child: VidrioLigero(
        radio: 999,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        seleccionado: verificados < total,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fact_check_rounded,
              size: 16,
              color: Colores.oroClaro,
            ),
            const SizedBox(width: 8),
            Text(
              'Ficha $verificados/$total',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colores.texto,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Campana extends StatelessWidget {
  const _Campana({required this.hayAlertas, required this.alPresionar});

  final bool hayAlertas;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: alPresionar,
      child: VidrioLigero(
        radio: 999,
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            const Icon(Icons.notifications_none_rounded, size: 20),
            if (hayAlertas)
              const Positioned(
                right: 1,
                top: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colores.vencido,
                  ),
                  child: SizedBox(width: 8, height: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChipOdometro extends StatelessWidget {
  const _ChipOdometro({
    required this.km,
    required this.recordatorioPendiente,
    required this.alPresionar,
  });

  final double km;
  final bool recordatorioPendiente;
  final VoidCallback alPresionar;

  @override
  Widget build(BuildContext context) {
    final kmFormateado = NumberFormat('#,##0').format(km);
    return GestureDetector(
      onTap: alPresionar,
      child: VidrioLigero(
        radio: 999,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        seleccionado: recordatorioPendiente,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: Colores.degradadoOro,
              ),
              child: const Icon(
                Icons.two_wheeler_rounded,
                size: 17,
                color: Colores.oroOscuro,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DM300',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '$kmFormateado km',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colores.oroClaro,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.edit_rounded,
              size: 14,
              color: Colores.textoSecundario,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarraInferior extends StatelessWidget {
  const _BarraInferior({
    required this.elementos,
    required this.seleccionado,
    required this.alSeleccionar,
  });

  final List<ElementoRiel> elementos;
  final int seleccionado;
  final ValueChanged<int> alSeleccionar;

  @override
  Widget build(BuildContext context) {
    return PanelVidrio(
      radio: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < elementos.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => alSeleccionar(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: i == seleccionado ? Colores.degradadoOro : null,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  elementos[i].icono,
                  color: i == seleccionado
                      ? Colores.oroOscuro
                      : Colores.textoSecundario,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
