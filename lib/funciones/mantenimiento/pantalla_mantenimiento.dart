import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../datos/repositorios/repositorio_moto.dart';
import '../../dominio/modelos/estado_tarea.dart';
import '../../dominio/modelos/modelos_mantenimiento.dart';
import '../../nucleo/tema/colores.dart';
import '../../nucleo/tema/estado_visual.dart';
import '../../nucleo/widgets/boton_oro.dart';
import '../../nucleo/widgets/conteo_animado.dart';
import '../../nucleo/widgets/panel_vidrio.dart';
import '../../nucleo/widgets/pildora_estado.dart';
import '../../nucleo/widgets/vidrio_ligero.dart';

/// Pantalla de gestión de mantenimiento preventivo y correctivo para DM300.
class PantallaMantenimiento extends StatefulWidget {
  const PantallaMantenimiento({
    super.key,
    this.repo,
    this.zonaInicial,
  });

  final RepositorioMoto? repo;
  final String? zonaInicial;

  @override
  State<PantallaMantenimiento> createState() => _EstadoPantallaMantenimiento();
}

class _EstadoPantallaMantenimiento extends State<PantallaMantenimiento> {
  late final RepositorioMoto _repo;
  final NumberFormat _fmtKm = NumberFormat('#,##0');
  final NumberFormat _fmtMoneda = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  EstadoTarea? _filtroEstado;
  String? _filtroZona;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? RepositorioMoto.instancia;
    _filtroZona = widget.zonaInicial;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final ancho = MediaQuery.of(context).size.width;
        final esEscritorio = ancho >= 1000;

        final tareas = _filtrarTareas(_repo.tareasMantenimiento);

        final tareasVencidas = _repo.tareasMantenimiento
            .where((t) => _repo.estadoDeTarea(t.id) == EstadoTarea.vencido)
            .length;
        final tareasProximas = _repo.tareasMantenimiento
            .where((t) => _repo.estadoDeTarea(t.id) == EstadoTarea.proximo)
            .length;
        final tareasAlDia = _repo.tareasMantenimiento
            .where((t) => _repo.estadoDeTarea(t.id) == EstadoTarea.alDia)
            .length;

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
              // Cabecera con KPIs de mantenimiento
              _cabecera(tareasVencidas, tareasProximas, tareasAlDia),
              const SizedBox(height: 16),

              // Barra de filtros y buscador
              _barraFiltros(tareasVencidas, tareasProximas, tareasAlDia),
              const SizedBox(height: 16),

              // Lista o cuadrícula responsiva de tareas
              if (tareas.isEmpty)
                _tarjetaVacia()
              else if (esEscritorio)
                _grillaEscritorio(tareas)
              else
                _listaMovil(tareas),
            ],
          ),
        );
      },
    );
  }

  List<TareaMantenimiento> _filtrarTareas(List<TareaMantenimiento> todas) {
    return todas.where((t) {
      if (_filtroEstado != null && _repo.estadoDeTarea(t.id) != _filtroEstado) {
        return false;
      }
      if (_filtroZona != null && _filtroZona!.isNotEmpty && t.zona != _filtroZona) {
        return false;
      }
      if (_busqueda.isNotEmpty) {
        final b = _busqueda.toLowerCase();
        final coincide = t.titulo.toLowerCase().contains(b) ||
            t.descripcion.toLowerCase().contains(b) ||
            t.zona.toLowerCase().contains(b);
        if (!coincide) return false;
      }
      return true;
    }).toList();
  }

  Widget _cabecera(int vencidas, int proximas, int alDia) {
    return PanelVidrio(
      radio: 24,
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, c) {
          final horizontal = c.maxWidth >= 600;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                      Icons.build_circle_rounded,
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
                          'Mantenimiento DM300',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colores.texto,
                          ),
                        ),
                        Text(
                          'Odómetro actual: ${_fmtKm.format(_repo.kmActual)} km · Salud general: ${_repo.saludGeneral.round()}%',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colores.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (horizontal)
                Row(
                  children: [
                    Expanded(child: _kpiResumen('Vencidos', vencidas, Colores.vencido, Icons.error_outline_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _kpiResumen('Próximos', proximas, Colores.aviso, Icons.schedule_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _kpiResumen('Al día', alDia, Colores.ok, Icons.check_circle_outline_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _kpiSalud()),
                  ],
                )
              else
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _kpiResumen('Vencidos', vencidas, Colores.vencido, Icons.error_outline_rounded)),
                        const SizedBox(width: 10),
                        Expanded(child: _kpiResumen('Próximos', proximas, Colores.aviso, Icons.schedule_rounded)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _kpiResumen('Al día', alDia, Colores.ok, Icons.check_circle_outline_rounded)),
                        const SizedBox(width: 10),
                        Expanded(child: _kpiSalud()),
                      ],
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _kpiResumen(String titulo, int cantidad, Color color, IconData icono) {
    return VidrioLigero(
      radio: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icono, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 11, color: Colores.textoSecundario),
                ),
                Text(
                  '$cantidad',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiSalud() {
    return VidrioLigero(
      radio: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, size: 20, color: Colores.oroClaro),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Salud Moto',
                  style: TextStyle(fontSize: 11, color: Colores.textoSecundario),
                ),
                ConteoAnimado(
                  valor: _repo.saludGeneral,
                  sufijo: '%',
                  estilo: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colores.oroClaro,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _barraFiltros(int vencidas, int proximas, int alDia) {
    final zonas = _repo.tareasMantenimiento.map((t) => t.zona).toSet().toList();

    return Column(
      children: [
        // Buscador
        VidrioLigero(
          radio: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, size: 20, color: Colores.textoSecundario),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  style: const TextStyle(color: Colores.texto, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Buscar por tarea, zona o descripción...',
                    hintStyle: TextStyle(color: Colores.textoSecundario, fontSize: 13),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _busqueda = val),
                ),
              ),
              if (_busqueda.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Colores.textoSecundario),
                  onPressed: () => setState(() => _busqueda = ''),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Chips de estado y zona
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chipFiltroEstado('Todos', null, _repo.tareasMantenimiento.length),
              const SizedBox(width: 8),
              _chipFiltroEstado('Vencidos', EstadoTarea.vencido, vencidas),
              const SizedBox(width: 8),
              _chipFiltroEstado('Próximos', EstadoTarea.proximo, proximas),
              const SizedBox(width: 8),
              _chipFiltroEstado('Al día', EstadoTarea.alDia, alDia),
              if (zonas.isNotEmpty) ...[
                const SizedBox(width: 14),
                Container(width: 1, height: 24, color: Colores.borde),
                const SizedBox(width: 14),
                for (final z in zonas) ...[
                  InkWell(
                    onTap: () {
                      setState(() {
                        _filtroZona = (_filtroZona == z) ? null : z;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: VidrioLigero(
                      radio: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      seleccionado: _filtroZona == z,
                      child: Text(
                        z,
                        style: TextStyle(
                          fontSize: 12,
                          color: _filtroZona == z ? Colores.oroClaro : Colores.textoSecundario,
                          fontWeight: _filtroZona == z ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _chipFiltroEstado(String etiqueta, EstadoTarea? estado, int total) {
    final activo = _filtroEstado == estado;
    final color = estado != null ? estado.color : Colores.oroClaro;

    return InkWell(
      onTap: () => setState(() => _filtroEstado = estado),
      borderRadius: BorderRadius.circular(14),
      child: VidrioLigero(
        radio: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        seleccionado: activo,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (estado != null) ...[
              Icon(estado.icono, size: 14, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              '$etiqueta ($total)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                color: activo ? color : Colores.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grillaEscritorio(List<TareaMantenimiento> tareas) {
    return LayoutBuilder(
      builder: (context, c) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: tareas.map((t) {
            return SizedBox(
              width: (c.maxWidth - 16) / 2,
              child: _tarjetaTarea(t),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _listaMovil(List<TareaMantenimiento> tareas) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tareas.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _tarjetaTarea(tareas[i]),
    );
  }

  Widget _tarjetaTarea(TareaMantenimiento tarea) {
    final estado = _repo.estadoDeTarea(tarea.id);
    final kmRest = tarea.kmRestantes(_repo.kmActual);
    final diasRest = tarea.diasRestantes(DateTime.now());

    return PanelVidrio(
      radio: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fila superior: Zona + Píldora de Estado
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0x3326292E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colores.borde),
                ),
                child: Text(
                  tarea.zona,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colores.oroClaro,
                  ),
                ),
              ),
              const Spacer(),
              PildoraEstado(estado: estado),
            ],
          ),
          const SizedBox(height: 10),

          // Título y descripción
          Text(
            tarea.titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colores.texto,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tarea.descripcion,
            style: const TextStyle(
              fontSize: 12,
              color: Colores.textoSecundario,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Indicador de restantes (Km / Días)
          VidrioLigero(
            radio: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _indicadorRestante(
                  'Kilómetros restantes',
                  kmRest != null
                      ? (kmRest <= 0 ? 'Vencido por ${_fmtKm.format(kmRest.abs())} km' : 'En ${_fmtKm.format(kmRest)} km')
                      : 'Sin intervalo km',
                  kmRest != null && kmRest <= 0 ? Colores.vencido : (kmRest != null && kmRest <= 300 ? Colores.aviso : Colores.texto),
                ),
                Container(width: 1, height: 26, color: Colores.borde),
                _indicadorRestante(
                  'Tiempo restante',
                  diasRest != null
                      ? (diasRest <= 0 ? 'Vencido hace ${diasRest.abs()} d' : 'En $diasRest días')
                      : 'Sin intervalo días',
                  diasRest != null && diasRest <= 0 ? Colores.vencido : (diasRest != null && diasRest <= 15 ? Colores.aviso : Colores.texto),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Datos del último servicio
          Row(
            children: [
              const Icon(Icons.history_rounded, size: 14, color: Colores.textoSecundario),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tarea.ultimoKm != null
                      ? 'Último: ${_fmtKm.format(tarea.ultimoKm)} km · ${tarea.ultimaFecha != null ? DateFormat('dd/MM/yyyy').format(tarea.ultimaFecha!) : ''} · ${tarea.hechoPor ?? ''}'
                      : 'Sin servicios registrados',
                  style: const TextStyle(fontSize: 11, color: Colores.textoSecundario),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (tarea.ultimoCosto != null && tarea.ultimoCosto! > 0)
                Text(
                  _fmtMoneda.format(tarea.ultimoCosto),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colores.oroClaro,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Botón Registrar Servicio
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => _mostrarDialogoRegistroServicio(tarea),
              icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
              label: const Text('Registrar servicio', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colores.oro,
                foregroundColor: Colores.oroOscuro,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicadorRestante(String titulo, String valor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          titulo,
          style: const TextStyle(fontSize: 10, color: Colores.textoSecundario),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _tarjetaVacia() {
    return PanelVidrio(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 40, color: Colores.textoSecundario),
          const SizedBox(height: 12),
          const Text(
            'No se encontraron tareas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.texto),
          ),
          const SizedBox(height: 6),
          const Text(
            'Intenta cambiar los filtros o el término de búsqueda.',
            style: TextStyle(fontSize: 13, color: Colores.textoSecundario),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _filtroEstado = null;
              _filtroZona = null;
              _busqueda = '';
            }),
            child: const Text('Restablecer filtros', style: TextStyle(color: Colores.oroClaro)),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoRegistroServicio(TareaMantenimiento tarea) {
    final kmCtrl = TextEditingController(text: _repo.kmActual.round().toString());
    final costoCtrl = TextEditingController(text: tarea.ultimoCosto != null && tarea.ultimoCosto! > 0 ? tarea.ultimoCosto!.round().toString() : '0');
    final notasCtrl = TextEditingController();
    String realizadoPor = 'Mí';
    DateTime fecha = DateTime.now();
    EstadoBoton estadoBoton = EstadoBoton.normal;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: PanelVidrio(
              radio: 28,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Título modal
                    Row(
                      children: [
                        const Icon(Icons.build_circle_rounded, color: Colores.oroClaro, size: 24),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Registrar Servicio',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colores.texto),
                              ),
                              Text(
                                tarea.titulo,
                                style: const TextStyle(fontSize: 12, color: Colores.oroClaro),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colores.textoSecundario),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Kilometraje del servicio
                    TextField(
                      controller: kmCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colores.texto),
                      decoration: InputDecoration(
                        labelText: 'Kilometraje en el odómetro',
                        labelStyle: const TextStyle(color: Colores.textoSecundario),
                        suffixText: 'km',
                        suffixStyle: const TextStyle(color: Colores.oroClaro),
                        helperText: 'Actualiza automáticamente el odómetro general si es mayor',
                        helperStyle: const TextStyle(color: Colores.textoSecundario, fontSize: 11),
                        filled: true,
                        fillColor: const Color(0x33181A1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Selector: Mí vs Taller
                    Row(
                      children: [
                        const Text('Realizado por:', style: TextStyle(color: Colores.texto, fontSize: 13)),
                        const Spacer(),
                        ChoiceChip(
                          label: const Text('Por mí'),
                          selected: realizadoPor == 'Mí',
                          selectedColor: Colores.oro,
                          onSelected: (val) {
                            if (val) setModalState(() => realizadoPor = 'Mí');
                          },
                          labelStyle: TextStyle(
                            color: realizadoPor == 'Mí' ? Colores.oroOscuro : Colores.texto,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('En taller'),
                          selected: realizadoPor == 'Taller',
                          selectedColor: Colores.oro,
                          onSelected: (val) {
                            if (val) setModalState(() => realizadoPor = 'Taller');
                          },
                          labelStyle: TextStyle(
                            color: realizadoPor == 'Taller' ? Colores.oroOscuro : Colores.texto,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Costo y Fecha
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: costoCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colores.texto),
                            decoration: InputDecoration(
                              labelText: 'Costo (\$)',
                              labelStyle: const TextStyle(color: Colores.textoSecundario),
                              prefixText: '\$ ',
                              prefixStyle: const TextStyle(color: Colores.oroClaro),
                              filled: true,
                              fillColor: const Color(0x33181A1E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final f = await showDatePicker(
                                context: ctx,
                                initialDate: fecha,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 1)),
                              );
                              if (f != null) setModalState(() => fecha = f);
                            },
                            child: VidrioLigero(
                              radio: 14,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: Colores.oroClaro),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(fecha),
                                    style: const TextStyle(fontSize: 13, color: Colores.texto, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Notas del servicio
                    TextField(
                      controller: notasCtrl,
                      maxLines: 2,
                      style: const TextStyle(color: Colores.texto, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Notas o refacciones cambiadas (opcional)',
                        labelStyle: const TextStyle(color: Colores.textoSecundario, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0x33181A1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón Guardar Servicio
                    BotonOro(
                      etiqueta: 'Guardar servicio',
                      etiquetaListo: '¡Servicio guardado!',
                      icono: Icons.check_circle_rounded,
                      estado: estadoBoton,
                      alPresionar: () async {
                        final kmVal = double.tryParse(kmCtrl.text) ?? _repo.kmActual;
                        final costoVal = double.tryParse(costoCtrl.text) ?? 0.0;
                        setModalState(() => estadoBoton = EstadoBoton.cargando);

                        await _repo.registrarServicioTarea(
                          tareaId: tarea.id,
                          km: kmVal,
                          realizadoPor: realizadoPor,
                          costo: costoVal,
                          notas: notasCtrl.text.trim().isEmpty ? null : notasCtrl.text.trim(),
                          fecha: fecha,
                        );

                        if (ctx.mounted) {
                          setModalState(() => estadoBoton = EstadoBoton.listo);
                          await Future<void>.delayed(const Duration(milliseconds: 350));
                          if (ctx.mounted) Navigator.of(ctx).pop();
                        }
                      },
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
