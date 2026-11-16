import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../datos/repositorios/repositorio_moto.dart';
import '../../dominio/modelos/lectura_odometro.dart';
import '../../nucleo/tema/colores.dart';
import '../../nucleo/widgets/boton_oro.dart';
import '../../nucleo/widgets/panel_vidrio.dart';
import '../../nucleo/widgets/vidrio_ligero.dart';

enum _FiltroHistorial { todo, servicios, odometro, combustible, gastos }

/// Evento unificado para la línea temporal cronológica.
class _EventoHistorial {
  _EventoHistorial({
    required this.fecha,
    required this.km,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.tipo,
    this.costo,
    this.badge,
    this.colorBadge,
  });

  final DateTime fecha;
  final double km;
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final _FiltroHistorial tipo;
  final double? costo;
  final String? badge;
  final Color? colorBadge;
}

/// Pantalla de bitácora cronológica, gastos totales y sincronización remota para DM300.
class PantallaHistorial extends StatefulWidget {
  const PantallaHistorial({
    super.key,
    this.repo,
    this.soloGastos = false,
  });

  final RepositorioMoto? repo;
  final bool soloGastos;

  @override
  State<PantallaHistorial> createState() => _EstadoPantallaHistorial();
}

class _EstadoPantallaHistorial extends State<PantallaHistorial> {
  late final RepositorioMoto _repo;
  final NumberFormat _fmtKm = NumberFormat('#,##0');
  final NumberFormat _fmtMoneda = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  late _FiltroHistorial _filtroActivo;
  EstadoBoton _estadoSync = EstadoBoton.normal;

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? RepositorioMoto.instancia;
    _filtroActivo = widget.soloGastos ? _FiltroHistorial.gastos : _FiltroHistorial.todo;
  }

  double get _gastoMes {
    final ahora = DateTime.now();
    final servicios = _repo.registrosServicio
        .where((s) => s.fecha.year == ahora.year && s.fecha.month == ahora.month)
        .fold<double>(0.0, (sum, s) => sum + s.costo);
    final cargas = _repo.cargasCombustible
        .where((c) => c.fecha.year == ahora.year && c.fecha.month == ahora.month)
        .fold<double>(0.0, (sum, c) => sum + c.costo);
    return servicios + cargas;
  }

  double get _gastoAcumulado {
    final servicios = _repo.registrosServicio.fold<double>(0.0, (sum, s) => sum + s.costo);
    final cargas = _repo.cargasCombustible.fold<double>(0.0, (sum, c) => sum + c.costo);
    return servicios + cargas;
  }

  Future<void> _sincronizarSupabase() async {
    if (_estadoSync == EstadoBoton.cargando) return;
    setState(() => _estadoSync = EstadoBoton.cargando);

    await _repo.simularSincronizacionSupabase();

    if (!mounted) return;
    setState(() => _estadoSync = EstadoBoton.listo);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _estadoSync = EstadoBoton.normal);
  }

  List<_EventoHistorial> _construirEventos() {
    final lista = <_EventoHistorial>[];

    // 1. Servicios de mantenimiento
    for (final s in _repo.registrosServicio) {
      lista.add(
        _EventoHistorial(
          fecha: s.fecha,
          km: s.km,
          titulo: s.tituloTarea,
          subtitulo: 'Zona ${s.zona} · Por ${s.realizadoPor}${s.notas != null ? ' · ${s.notas}' : ''}',
          icono: Icons.build_circle_rounded,
          tipo: _FiltroHistorial.servicios,
          costo: s.costo > 0 ? s.costo : null,
          badge: 'Servicio',
          colorBadge: Colores.oro,
        ),
      );
    }

    // 2. Lecturas de odómetro
    for (final o in _repo.lecturasOdometro) {
      final origenTxt = switch (o.origen) {
        OrigenOdometro.rapido => 'Captura rápida',
        OrigenOdometro.servicio => 'En servicio',
        OrigenOdometro.combustible => 'Carga de gasolina',
        OrigenOdometro.medicion => 'En medición física',
        OrigenOdometro.fichaInicial => 'Ficha inicial',
      };
      lista.add(
        _EventoHistorial(
          fecha: o.fecha,
          km: o.km,
          titulo: 'Odómetro: ${_fmtKm.format(o.km)} km',
          subtitulo: '$origenTxt${o.cambioTablero ? ' · Cambio de tablero' : ''}${o.nota != null ? ' · ${o.nota}' : ''}',
          icono: Icons.speed_rounded,
          tipo: _FiltroHistorial.odometro,
          badge: o.cambioTablero ? 'Tablero Nuevo' : 'Odómetro',
          colorBadge: o.cambioTablero ? Colores.aviso : Colores.textoSecundario,
        ),
      );
    }

    // 3. Cargas de combustible
    for (final c in _repo.cargasCombustible) {
      final kml = c.kmPorLitro != null ? '${c.kmPorLitro!.toStringAsFixed(1)} km/L' : null;
      lista.add(
        _EventoHistorial(
          fecha: c.fecha,
          km: c.km,
          titulo: 'Carga de Gasolina: ${c.litros.toStringAsFixed(1)} L',
          subtitulo: '${_fmtKm.format(c.km)} km${kml != null ? ' · Rendimiento: $kml' : ''}',
          icono: Icons.local_gas_station_rounded,
          tipo: _FiltroHistorial.combustible,
          costo: c.costo > 0 ? c.costo : null,
          badge: kml ?? 'Combustible',
          colorBadge: Colores.ok,
        ),
      );
    }

    // 4. Mediciones de desgaste
    for (final m in _repo.medicionesDesgaste) {
      lista.add(
        _EventoHistorial(
          fecha: m.fecha,
          km: m.km,
          titulo: 'Medición: ${m.componente}',
          subtitulo: 'Valor: ${m.valor} ${m.unidad} (límite: ${m.minimoSeguro} ${m.unidad})${m.nota != null ? ' · ${m.nota}' : ''}',
          icono: Icons.straighten_rounded,
          tipo: _FiltroHistorial.todo,
          badge: m.enAlerta ? 'Alerta Límite' : 'Tolerancia OK',
          colorBadge: m.enAlerta ? Colores.vencido : Colores.ok,
        ),
      );
    }

    // Ordenar de más reciente a más antiguo
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));

    // Filtrar según pestaña activa
    return lista.where((e) {
      return switch (_filtroActivo) {
        _FiltroHistorial.todo => true,
        _FiltroHistorial.servicios => e.tipo == _FiltroHistorial.servicios,
        _FiltroHistorial.odometro => e.tipo == _FiltroHistorial.odometro,
        _FiltroHistorial.combustible => e.tipo == _FiltroHistorial.combustible,
        _FiltroHistorial.gastos => e.costo != null && e.costo! > 0,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final ancho = MediaQuery.of(context).size.width;
        final esEscritorio = ancho >= 1000;

        final eventos = _construirEventos();

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            esEscritorio ? 24 : 16,
            16,
            esEscritorio ? 24 : 16,
            esEscritorio ? 24 : 120, // espacio para barra flotante móvil
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarjeta Superior: Resumen de Gastos + Sincronización Supabase
              _tarjetaResumenGastosYSync(),
              const SizedBox(height: 16),

              // Pestañas / Filtros de historial
              _barraPestanas(),
              const SizedBox(height: 16),

              // Línea Temporal Cronológica
              if (eventos.isEmpty)
                _tarjetaVacia()
              else
                _lineaTemporal(eventos),
            ],
          ),
        );
      },
    );
  }

  Widget _tarjetaResumenGastosYSync() {
    final costoPorKm = _repo.kmActual > 0
        ? (_gastoAcumulado / _repo.kmActual)
        : 0.0;
    final sincro = _repo.ultimaSincronizacion != null;
    final fechaSincro = _repo.ultimaSincronizacion != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(_repo.ultimaSincronizacion!)
        : 'Sin sincronizar aún';

    return PanelVidrio(
      radio: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila superior: Título y Sincronización Supabase
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Colores.degradadoOro,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 24,
                  color: Colores.oroOscuro,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Historial & Gastos',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colores.texto,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          sincro ? Icons.cloud_done_rounded : Icons.cloud_queue_rounded,
                          size: 14,
                          color: sincro ? Colores.ok : Colores.aviso,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            sincro
                                ? 'Nube sincronizada · $fechaSincro'
                                : 'Cambios locales pendientes · $fechaSincro',
                            style: const TextStyle(fontSize: 12, color: Colores.textoSecundario),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 140,
                child: BotonOro(
                  etiqueta: 'Sincronizar',
                  etiquetaListo: '¡Al día!',
                  icono: Icons.sync_rounded,
                  estado: _estadoSync,
                  alPresionar: _sincronizarSupabase,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // KPIs de Gasto
          LayoutBuilder(
            builder: (context, c) {
              final horizontal = c.maxWidth >= 540;
              if (horizontal) {
                return Row(
                  children: [
                    Expanded(child: _kpiGasto('Gasto del mes', _gastoMes, Colores.oroClaro)),
                    const SizedBox(width: 12),
                    Expanded(child: _kpiGasto('Gasto acumulado', _gastoAcumulado, Colores.texto)),
                    const SizedBox(width: 12),
                    Expanded(child: _kpiGasto('Costo por km', costoPorKm, Colores.ok, esPorKm: true)),
                  ],
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _kpiGasto('Gasto del mes', _gastoMes, Colores.oroClaro)),
                      const SizedBox(width: 10),
                      Expanded(child: _kpiGasto('Acumulado', _gastoAcumulado, Colores.texto)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _kpiGasto('Costo promedio por km', costoPorKm, Colores.ok, esPorKm: true),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _kpiGasto(String etiqueta, double valor, Color color, {bool esPorKm = false}) {
    return VidrioLigero(
      radio: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: const TextStyle(fontSize: 11, color: Colores.textoSecundario),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                esPorKm ? '\$${valor.toStringAsFixed(2)}' : _fmtMoneda.format(valor),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (esPorKm) ...[
                const SizedBox(width: 4),
                const Text(
                  '/ km',
                  style: TextStyle(fontSize: 12, color: Colores.textoSecundario),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _barraPestanas() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chipPestana('Todo', _FiltroHistorial.todo, Icons.all_inclusive_rounded),
          const SizedBox(width: 8),
          _chipPestana('Servicios', _FiltroHistorial.servicios, Icons.build_rounded),
          const SizedBox(width: 8),
          _chipPestana('Odómetro', _FiltroHistorial.odometro, Icons.speed_rounded),
          const SizedBox(width: 8),
          _chipPestana('Combustible', _FiltroHistorial.combustible, Icons.local_gas_station_rounded),
          const SizedBox(width: 8),
          _chipPestana('Gastos (\$\$)', _FiltroHistorial.gastos, Icons.payments_rounded),
        ],
      ),
    );
  }

  Widget _chipPestana(String etiqueta, _FiltroHistorial filtro, IconData icono) {
    final activa = _filtroActivo == filtro;

    return InkWell(
      onTap: () => setState(() => _filtroActivo = filtro),
      borderRadius: BorderRadius.circular(14),
      child: VidrioLigero(
        radio: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        seleccionado: activa,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 16, color: activa ? Colores.oroClaro : Colores.textoSecundario),
            const SizedBox(width: 8),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 13,
                fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                color: activa ? Colores.oroClaro : Colores.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineaTemporal(List<_EventoHistorial> eventos) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: eventos.length,
      itemBuilder: (context, i) {
        final ev = eventos[i];
        final esUltimo = i == eventos.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Columna del nodo y línea conectora
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x33D4AF37),
                        border: Border.all(color: Colores.oro.withValues(alpha: 0.7), width: 1.5),
                      ),
                      child: Icon(ev.icono, size: 16, color: Colores.oroClaro),
                    ),
                    if (!esUltimo)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: Colores.borde,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Tarjeta del evento
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: PanelVidrio(
                    radio: 18,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Fila cabecera del evento
                        Row(
                          children: [
                            Text(
                              DateFormat('dd/MM/yyyy · HH:mm').format(ev.fecha),
                              style: const TextStyle(fontSize: 11, color: Colores.textoSecundario),
                            ),
                            const Spacer(),
                            if (ev.badge != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (ev.colorBadge ?? Colores.oro).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  ev.badge!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ev.colorBadge ?? Colores.oroClaro,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Título y costo si aplica
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                ev.titulo,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colores.texto,
                                ),
                              ),
                            ),
                            if (ev.costo != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                _fmtMoneda.format(ev.costo),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colores.oroClaro,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Subtítulo con detalles y kilometraje
                        Text(
                          ev.subtitulo,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colores.textoSecundario,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tarjetaVacia() {
    return PanelVidrio(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.history_toggle_off_rounded, size: 40, color: Colores.textoSecundario),
          const SizedBox(height: 12),
          const Text(
            'Sin eventos para este filtro',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.texto),
          ),
          const SizedBox(height: 6),
          const Text(
            'No hay registros que coincidan con la categoría seleccionada.',
            style: TextStyle(fontSize: 13, color: Colores.textoSecundario),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _filtroActivo = _FiltroHistorial.todo),
            child: const Text('Mostrar todos los eventos', style: TextStyle(color: Colores.oroClaro)),
          ),
        ],
      ),
    );
  }
}
