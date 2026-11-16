import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../datos/repositorios/repositorio_moto.dart';
import '../../dominio/modelos/estado_tarea.dart';
import '../../dominio/modelos/modelos_mantenimiento.dart';
import '../../nucleo/tema/colores.dart';
import '../../nucleo/widgets/boton_oro.dart';
import '../../nucleo/widgets/conteo_animado.dart';
import '../../nucleo/widgets/panel_vidrio.dart';
import '../../nucleo/widgets/pildora_estado.dart';
import '../../nucleo/widgets/vidrio_ligero.dart';
import 'datos_ejemplo.dart';
import 'vista_moto.dart';

/// Tarjeta flotante con el detalle en vivo de la zona seleccionada de la DM300.
class TarjetaZona extends StatefulWidget {
  const TarjetaZona({
    super.key,
    required this.zona,
    required this.alCerrar,
    this.alVerMantenimiento,
  });

  final ZonaVista zona;
  final VoidCallback alCerrar;
  final VoidCallback? alVerMantenimiento;

  @override
  State<TarjetaZona> createState() => _EstadoTarjetaZona();
}

class _EstadoTarjetaZona extends State<TarjetaZona> {
  EstadoBoton _boton = EstadoBoton.normal;

  DetalleZona _detalleEnVivo(RepositorioMoto repo, TareaMantenimiento? tarea) {
    final respaldo = detalleDe(widget.zona);
    if (!repo.inicializado || tarea == null) return respaldo;

    final kmActual = repo.kmActual;
    final ahora = DateTime.now();
    final estado = repo.estadoDeZona(widget.zona.nombre);
    final kmRest = tarea.kmRestantes(kmActual);
    final diasRest = tarea.diasRestantes(ahora);
    final fmt = NumberFormat('#,##0');

    double metrica = 0;
    String unidad = 'pendientes';
    String delta = 'Al día';

    if (estado == EstadoTarea.sinDatos) {
      metrica = 0;
      unidad = 'sin datos previos';
      delta = 'Registrar';
    } else if (diasRest != null && diasRest <= 0) {
      metrica = diasRest.abs().toDouble();
      unidad = 'días de retraso';
      delta = 'Vencido';
    } else if (kmRest != null && kmRest <= 0) {
      metrica = kmRest.abs();
      unidad = 'km de retraso';
      delta = 'Vencido';
    } else if (kmRest != null) {
      metrica = kmRest;
      unidad = 'km para el servicio';
      final objetivo = (tarea.ultimoKm ?? kmActual) + (tarea.intervaloKm ?? 0);
      delta = 'a ${fmt.format(objetivo)} km';
    } else if (diasRest != null) {
      metrica = diasRest.toDouble();
      unidad = 'días restantes';
      delta = 'Próximo';
    }

    final ultimaStr = tarea.ultimaFecha != null
        ? DateFormat('dd/MM/yyyy').format(tarea.ultimaFecha!)
        : 'sin fecha';
    final lineaSecundaria = tarea.ultimoKm != null
        ? 'Último: ${fmt.format(tarea.ultimoKm)} km ($ultimaStr) · por ${tarea.hechoPor ?? 'Mí'}'
        : respaldo.lineaSecundaria;

    return DetalleZona(
      titulo: widget.zona.nombre,
      subtitulo: tarea.descripcion,
      estado: estado,
      metrica: metrica,
      unidad: unidad,
      delta: delta,
      lineaSecundaria: lineaSecundaria,
    );
  }

  Future<void> _registrar(
    RepositorioMoto repo,
    TareaMantenimiento? tarea,
  ) async {
    setState(() => _boton = EstadoBoton.cargando);
    if (tarea != null) {
      await repo.registrarServicioTarea(
        tareaId: tarea.id,
        km: repo.kmActual,
        realizadoPor: 'Mí',
        costo: tarea.ultimoCosto ?? 0,
        notas: 'Registro rápido desde vista DM300',
      );
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    if (!mounted) return;
    setState(() => _boton = EstadoBoton.listo);
  }

  @override
  Widget build(BuildContext context) {
    final repo = RepositorioMoto.instancia;
    final tareasZona = repo.tareasPorZona(widget.zona.nombre);
    final tareaPrincipal = tareasZona.isNotEmpty ? tareasZona.first : null;
    final d = _detalleEnVivo(repo, tareaPrincipal);
    final fmt = NumberFormat('#,##0');

    return PanelVidrio(
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PildoraEstado(estado: d.estado),
              const Spacer(),
              if (widget.alVerMantenimiento != null)
                TextButton(
                  onPressed: widget.alVerMantenimiento,
                  style: TextButton.styleFrom(
                    foregroundColor: Colores.oroClaro,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Ver plan', style: TextStyle(fontSize: 12)),
                ),
              InkWell(
                onTap: widget.alCerrar,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colores.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            d.titulo,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            d.subtitulo,
            style: const TextStyle(fontSize: 13, color: Colores.textoSecundario),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConteoAnimado(
                valor: d.metrica,
                estilo: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  d.unidad,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colores.textoSecundario,
                  ),
                ),
              ),
              VidrioLigero(
                radio: 999,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: Text(
                  d.delta,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colores.oroClaro,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            d.lineaSecundaria,
            style: const TextStyle(fontSize: 12, color: Colores.textoSecundario),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: BotonOro(
              etiqueta: 'Registrar servicio',
              etiquetaListo: 'Registrado · ${fmt.format(repo.kmActual.round())} km',
              icono: Icons.build_rounded,
              estado: _boton,
              alPresionar: () => _registrar(repo, tareaPrincipal),
            ),
          ),
        ],
      ),
    );
  }
}
