import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../datos/repositorios/repositorio_moto.dart';
import '../../dominio/modelos/modelos_mantenimiento.dart';
import '../../nucleo/tema/colores.dart';
import '../../nucleo/widgets/panel_vidrio.dart';
import '../../nucleo/widgets/vidrio_ligero.dart';
import '../inicio/asistente_ficha_moto.dart';

/// Pantalla de catálogo y compatibilidad inteligente de refacciones para DM300.
/// Cruza cada pieza con la Ficha de la moto para evitar compras erróneas.
class PantallaRefacciones extends StatefulWidget {
  const PantallaRefacciones({
    super.key,
    this.repo,
    this.alAbrirFicha,
  });

  final RepositorioMoto? repo;
  final void Function(String? claveFicha)? alAbrirFicha;

  @override
  State<PantallaRefacciones> createState() => _EstadoPantallaRefacciones();
}

class _EstadoPantallaRefacciones extends State<PantallaRefacciones> {
  late final RepositorioMoto _repo;
  final NumberFormat _fmtMoneda = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  EstadoCompatibilidadRefaccion? _filtroCompatibilidad;
  String? _filtroCategoria;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? RepositorioMoto.instancia;
  }

  void _abrirFicha(String? clave) {
    if (widget.alAbrirFicha != null) {
      widget.alAbrirFicha!(clave);
    } else {
      mostrarAsistenteFichaMoto(context, repo: _repo, claveInicial: clave);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final ancho = MediaQuery.of(context).size.width;
        final esEscritorio = ancho >= 1000;

        final evaluadas = _repo.refaccionesEvaluadas;
        final filtradas = _filtrarRefacciones(evaluadas);

        final sugeridasCount = evaluadas
            .where((r) => r.estado == EstadoCompatibilidadRefaccion.sugerida)
            .length;
        final dudosasCount = evaluadas
            .where((r) => r.estado == EstadoCompatibilidadRefaccion.dudosaPendienteFicha)
            .length;
        final noAplicanCount = evaluadas
            .where((r) => r.estado == EstadoCompatibilidadRefaccion.noAplicaAccesorio)
            .length;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            esEscritorio ? 24 : 16,
            16,
            esEscritorio ? 24 : 16,
            esEscritorio ? 24 : 120, // evitar barra flotante en móvil
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Banner superior: Resumen de Ficha y botón de verificación
              _bannerFicha(),
              const SizedBox(height: 16),

              // Buscador y Filtros de compatibilidad
              _barraFiltros(sugeridasCount, dudosasCount, noAplicanCount, evaluadas),
              const SizedBox(height: 16),

              // Catálogo de refacciones
              if (filtradas.isEmpty)
                _tarjetaVacia()
              else if (esEscritorio)
                _grillaEscritorio(filtradas)
              else
                _listaMovil(filtradas),
            ],
          ),
        );
      },
    );
  }

  List<RefaccionEvaluada> _filtrarRefacciones(List<RefaccionEvaluada> todas) {
    return todas.where((item) {
      if (_filtroCompatibilidad != null && item.estado != _filtroCompatibilidad) {
        return false;
      }
      if (_filtroCategoria != null && item.refaccion.categoria != _filtroCategoria) {
        return false;
      }
      if (_busqueda.isNotEmpty) {
        final b = _busqueda.toLowerCase();
        final ref = item.refaccion;
        final coincide = ref.nombre.toLowerCase().contains(b) ||
            ref.sku.toLowerCase().contains(b) ||
            ref.categoria.toLowerCase().contains(b) ||
            ref.zona.toLowerCase().contains(b);
        if (!coincide) return false;
      }
      return true;
    }).toList();
  }

  Widget _bannerFicha() {
    final verificados = _repo.camposVerificadosCount;
    final total = _repo.totalCamposFicha;
    final porcentaje = total > 0 ? (verificados / total) : 0.0;

    return PanelVidrio(
      radio: 24,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, c) {
          final horizontal = c.maxWidth >= 540;
          return Row(
            children: [
              // Indicador circular de verificación
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: porcentaje,
                      strokeWidth: 4.5,
                      backgroundColor: const Color(0x33FFFFFF),
                      color: Colores.oro,
                    ),
                    Center(
                      child: Text(
                        '${(porcentaje * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colores.oroClaro,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Compatibilidad DM300 con tu Ficha',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colores.texto,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$verificados de $total puntos verificados en tu moto. Verifica más datos para desbloquear recomendaciones 100% exactas.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colores.textoSecundario,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (horizontal) ...[
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _abrirFicha(null),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Completar Ficha'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colores.oro,
                    foregroundColor: Colores.oroOscuro,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _barraFiltros(
    int sugeridas,
    int dudosas,
    int noAplican,
    List<RefaccionEvaluada> evaluadas,
  ) {
    final categorias = evaluadas.map((r) => r.refaccion.categoria).toSet().toList();

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
                    hintText: 'Buscar por pieza, código SKU o categoría...',
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

        // Filtros de compatibilidad
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _chipFiltro(
                'Todas (${evaluadas.length})',
                _filtroCompatibilidad == null,
                Colores.oroClaro,
                () => setState(() => _filtroCompatibilidad = null),
              ),
              const SizedBox(width: 8),
              _chipFiltro(
                'Sugeridas ($sugeridas)',
                _filtroCompatibilidad == EstadoCompatibilidadRefaccion.sugerida,
                Colores.ok,
                () => setState(() => _filtroCompatibilidad = EstadoCompatibilidadRefaccion.sugerida),
                icono: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(width: 8),
              _chipFiltro(
                'Pendientes en Ficha ($dudosas)',
                _filtroCompatibilidad == EstadoCompatibilidadRefaccion.dudosaPendienteFicha,
                Colores.aviso,
                () => setState(() => _filtroCompatibilidad = EstadoCompatibilidadRefaccion.dudosaPendienteFicha),
                icono: Icons.warning_amber_rounded,
              ),
              const SizedBox(width: 8),
              _chipFiltro(
                'No aplican ($noAplican)',
                _filtroCompatibilidad == EstadoCompatibilidadRefaccion.noAplicaAccesorio,
                Colores.sinDatos,
                () => setState(() => _filtroCompatibilidad = EstadoCompatibilidadRefaccion.noAplicaAccesorio),
                icono: Icons.block_rounded,
              ),
              if (categorias.isNotEmpty) ...[
                const SizedBox(width: 14),
                Container(width: 1, height: 24, color: Colores.borde),
                const SizedBox(width: 14),
                for (final cat in categorias) ...[
                  InkWell(
                    onTap: () {
                      setState(() {
                        _filtroCategoria = (_filtroCategoria == cat) ? null : cat;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: VidrioLigero(
                      radio: 12,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      seleccionado: _filtroCategoria == cat,
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          color: _filtroCategoria == cat ? Colores.oroClaro : Colores.textoSecundario,
                          fontWeight: _filtroCategoria == cat ? FontWeight.w700 : FontWeight.w500,
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

  Widget _chipFiltro(
    String etiqueta,
    bool activo,
    Color color,
    VoidCallback alPresionar, {
    IconData? icono,
  }) {
    return InkWell(
      onTap: alPresionar,
      borderRadius: BorderRadius.circular(14),
      child: VidrioLigero(
        radio: 14,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        seleccionado: activo,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 14, color: activo ? color : Colores.textoSecundario),
              const SizedBox(width: 6),
            ],
            Text(
              etiqueta,
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

  Widget _grillaEscritorio(List<RefaccionEvaluada> lista) {
    return LayoutBuilder(
      builder: (context, c) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: lista.map((item) {
            return SizedBox(
              width: (c.maxWidth - 16) / 2,
              child: _tarjetaRefaccion(item),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _listaMovil(List<RefaccionEvaluada> lista) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lista.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (context, i) => _tarjetaRefaccion(lista[i]),
    );
  }

  Widget _tarjetaRefaccion(RefaccionEvaluada item) {
    final ref = item.refaccion;
    final esDudosa = item.estado == EstadoCompatibilidadRefaccion.dudosaPendienteFicha;
    final esSugerida = item.estado == EstadoCompatibilidadRefaccion.sugerida;
    final noAplica = item.estado == EstadoCompatibilidadRefaccion.noAplicaAccesorio;

    return PanelVidrio(
      radio: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Categoría, SKU y Precio Estimado
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
                  ref.categoria,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colores.oroClaro,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SKU: ${ref.sku}',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'monospace',
                  color: Colores.textoSecundario,
                ),
              ),
              const Spacer(),
              Text(
                _fmtMoneda.format(ref.precioEstimado),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colores.texto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Nombre de la Refacción
          Text(
            ref.nombre,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colores.texto,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Zona: ${ref.zona}${ref.notas != null ? ' · ${ref.notas}' : ''}',
            style: const TextStyle(fontSize: 12, color: Colores.textoSecundario),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Banner de Estado de Compatibilidad
          if (esDudosa)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colores.aviso.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colores.aviso.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 16, color: Colores.aviso),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'No sugerida para compra hasta verificar en tu Ficha',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colores.aviso,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.motivo,
                    style: const TextStyle(fontSize: 12, color: Colores.textoSecundario),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: () => _abrirFicha(item.claveFichaPendiente),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 14),
                      label: const Text('Verificar ahora', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colores.aviso,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (esSugerida)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colores.ok.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colores.ok.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Colores.ok),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.motivo.isNotEmpty ? item.motivo : '100% compatible con tu DM300',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colores.ok,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (noAplica)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colores.sinDatos.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colores.sinDatos.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.do_not_disturb_on_outlined, size: 16, color: Colores.sinDatos),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.motivo.isNotEmpty ? item.motivo : 'No aplica para tu configuración',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colores.sinDatos,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaVacia() {
    return PanelVidrio(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          const Icon(Icons.inventory_2_outlined, size: 40, color: Colores.textoSecundario),
          const SizedBox(height: 12),
          const Text(
            'No hay refacciones que coincidan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colores.texto),
          ),
          const SizedBox(height: 6),
          const Text(
            'Prueba buscando con otro término o limpiando los filtros.',
            style: TextStyle(fontSize: 13, color: Colores.textoSecundario),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() {
              _filtroCompatibilidad = null;
              _filtroCategoria = null;
              _busqueda = '';
            }),
            child: const Text('Ver todas las refacciones', style: TextStyle(color: Colores.oroClaro)),
          ),
        ],
      ),
    );
  }
}
