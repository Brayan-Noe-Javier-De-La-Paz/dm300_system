import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../datos/repositorios/repositorio_moto.dart';
import '../../dominio/modelos/modelos_mantenimiento.dart';
import '../../nucleo/tema/colores.dart';
import '../../nucleo/widgets/boton_oro.dart';
import '../../nucleo/widgets/conteo_animado.dart';
import '../../nucleo/widgets/panel_vidrio.dart';
import '../../nucleo/widgets/vidrio_ligero.dart';

/// Pantalla de monitoreo de desgaste físico (balatas, cadena, llantas)
/// y rendimiento de combustible (km/L) con detección de anomalías.
class PantallaDesgaste extends StatefulWidget {
  const PantallaDesgaste({super.key, this.repo});

  final RepositorioMoto? repo;

  @override
  State<PantallaDesgaste> createState() => _EstadoPantallaDesgaste();
}

class _EstadoPantallaDesgaste extends State<PantallaDesgaste> {
  late final RepositorioMoto _repo;
  final NumberFormat _fmtKm = NumberFormat('#,##0');
  final NumberFormat _fmtMoneda = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? RepositorioMoto.instancia;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final ancho = MediaQuery.of(context).size.width;
        final esEscritorio = ancho >= 1000;

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
              // Cabecera principal
              _cabecera(),
              const SizedBox(height: 16),

              if (esEscritorio)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Columna A: Desgaste Físico
                    Expanded(child: _bloqueDesgasteFisico()),
                    const SizedBox(width: 20),
                    // Columna B: Combustible y Rendimiento
                    Expanded(child: _bloqueCombustible()),
                  ],
                )
              else ...[
                // En móvil se apilan ambos bloques
                _bloqueDesgasteFisico(),
                const SizedBox(height: 20),
                _bloqueCombustible(),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _cabecera() {
    return PanelVidrio(
      radio: 24,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: Colores.degradadoOro,
            ),
            child: const Icon(
              Icons.speed_rounded,
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
                  'Desgaste & Rendimiento',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colores.texto,
                  ),
                ),
                Text(
                  'Tolerancias seguras de tu DM300 y consumo real de gasolina',
                  style: const TextStyle(fontSize: 13, color: Colores.textoSecundario),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BLOQUE A: DESGASTE FÍSICO
  // ==========================================

  Widget _bloqueDesgasteFisico() {
    final mediciones = _repo.medicionesDesgaste;
    final alertasCount = mediciones.where((m) => m.enAlerta).length;

    return PanelVidrio(
      radio: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Título de bloque y botón de nueva medición
          Row(
            children: [
              const Icon(Icons.straighten_rounded, color: Colores.oroClaro, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Desgaste Físico de Componentes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colores.texto,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _mostrarModalNuevaMedicion,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Medir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colores.oro,
                  foregroundColor: Colores.oroOscuro,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Resumen de componentes críticos
          if (alertasCount > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colores.vencido.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colores.vencido.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded, color: Colores.vencido, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$alertasCount componente(s) fuera del límite de seguridad.',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colores.vencido),
                    ),
                  ),
                ],
              ),
            ),

          // Tarjetas de componentes monitoreados
          if (mediciones.isEmpty)
            _tarjetaVaciaMediciones()
          else
            for (final m in mediciones) ...[
              _tarjetaMedicion(m),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _tarjetaMedicion(MedicionDesgaste m) {
    final enAlerta = m.enAlerta;
    final color = enAlerta ? Colores.vencido : Colores.ok;

    // Calcular proporción respecto al mínimo seguro
    final limite = m.minimoSeguro;
    final pct = limite > 0 ? (m.valor / (limite * 2)).clamp(0.0, 1.0) : 0.5;

    return VidrioLigero(
      radio: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                enAlerta ? Icons.error_rounded : Icons.check_circle_rounded,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  m.componente,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colores.texto,
                  ),
                ),
              ),
              Text(
                '${m.valor} ${m.unidad}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Barra de desgaste / tolerancia
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: const Color(0x33FFFFFF),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),

          // Límites y fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Límite seguro: min ${m.minimoSeguro} ${m.unidad}${m.maximoSeguro != null ? ' (máx ${m.maximoSeguro})' : ''}',
                style: const TextStyle(fontSize: 11, color: Colores.textoSecundario),
              ),
              Text(
                '${_fmtKm.format(m.km)} km · ${DateFormat('dd/MM').format(m.fecha)}',
                style: const TextStyle(fontSize: 11, color: Colores.textoSecundario),
              ),
            ],
          ),
          if (m.nota != null && m.nota!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Nota: ${m.nota}',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colores.textoSecundario),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaVaciaMediciones() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const Icon(Icons.straighten_outlined, size: 36, color: Colores.textoSecundario),
          const SizedBox(height: 8),
          const Text(
            'Sin mediciones de desgaste',
            style: TextStyle(color: Colores.texto, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Registra el grosor de balatas o tensión de cadena con el botón "Medir".',
            style: TextStyle(color: Colores.textoSecundario, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BLOQUE B: COMBUSTIBLE Y RENDIMIENTO (km/L)
  // ==========================================

  Widget _bloqueCombustible() {
    final promedio = _repo.rendimientoPromedioKmL ?? 0.0;
    final alertaCaida = _repo.alertaRendimiento;
    final cargas = _repo.cargasCombustible;

    return PanelVidrio(
      radio: 24,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Título de bloque y botón registrar carga
          Row(
            children: [
              const Icon(Icons.local_gas_station_rounded, color: Colores.oroClaro, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Combustible & Rendimiento',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colores.texto,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _mostrarModalRegistrarCarga,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Carga', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colores.oro,
                  foregroundColor: Colores.oroOscuro,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  elevation: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tarjeta de Promedio de Rendimiento (km/L)
          VidrioLigero(
            radio: 18,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rendimiento promedio',
                        style: TextStyle(fontSize: 12, color: Colores.textoSecundario),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          ConteoAnimado(
                            valor: promedio,
                            decimales: 1,
                            estilo: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colores.oroClaro,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'km/L',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colores.texto,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Autonomía estimada: ~350 km por tanque (14 L)',
                        style: TextStyle(fontSize: 11, color: Colores.textoSecundario),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x26D4AF37),
                  ),
                  child: const Icon(Icons.eco_rounded, color: Colores.oroClaro, size: 28),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Alerta Automática de Caída de Rendimiento
          if (alertaCaida != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colores.aviso.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colores.aviso.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 20, color: Colores.aviso),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alertaCaida,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colores.aviso,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Se detectó una reducción anormal en los últimos tanques. '
                    'Causas probables: filtro de aire saturado, bujía gastada, carburación o llantas con baja presión.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colores.texto,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Gráfica de barras de las últimas cargas
          if (cargas.isNotEmpty) ...[
            const Text(
              'Historial de consumo por carga (km/L)',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colores.textoSecundario),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 150,
              child: _GraficaBarrasCombustible(
                cargas: cargas.take(8).toList().reversed.toList(),
                promedio: promedio,
              ),
            ),
            const SizedBox(height: 14),

            // Lista compacta de últimas cargas
            for (final c in cargas.take(4)) ...[
              _filaCarga(c),
              const SizedBox(height: 8),
            ],
          ] else
            _tarjetaVaciaCombustible(),
        ],
      ),
    );
  }

  Widget _filaCarga(CargaCombustible c) {
    return VidrioLigero(
      radio: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.local_gas_station_outlined, size: 16, color: Colores.oroClaro),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${c.litros.toStringAsFixed(1)} L · ${_fmtMoneda.format(c.costo)} · ${_fmtKm.format(c.km)} km',
              style: const TextStyle(fontSize: 12, color: Colores.texto),
            ),
          ),
          if (c.kmPorLitro != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (c.kmPorLitro! >= 25 ? Colores.ok : Colores.aviso).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${c.kmPorLitro!.toStringAsFixed(1)} km/L',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.kmPorLitro! >= 25 ? Colores.ok : Colores.aviso,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaVaciaCombustible() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const Icon(Icons.local_gas_station_outlined, size: 36, color: Colores.textoSecundario),
          const SizedBox(height: 8),
          const Text(
            'Sin registros de combustible',
            style: TextStyle(color: Colores.texto, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Registra tus recargas para que el sistema calcule el km/L real de tu DM300.',
            style: TextStyle(color: Colores.textoSecundario, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==========================================
  // MODALES DE REGISTRO
  // ==========================================

  void _mostrarModalNuevaMedicion() {
    String componente = 'Balata delantera';
    String unidad = 'mm';
    final valorCtrl = TextEditingController(text: '3.5');
    final minCtrl = TextEditingController(text: '2.0');
    final maxCtrl = TextEditingController();
    final kmCtrl = TextEditingController(text: _repo.kmActual.round().toString());
    final notaCtrl = TextEditingController();
    EstadoBoton estadoBoton = EstadoBoton.normal;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: PanelVidrio(
              radio: 28,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.straighten_rounded, color: Colores.oroClaro, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Nueva Medición de Desgaste',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colores.texto),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colores.textoSecundario),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Selector de componente
                    DropdownButtonFormField<String>(
                      initialValue: componente,
                      dropdownColor: Colores.vidrio,
                      style: const TextStyle(color: Colores.texto, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Componente',
                        labelStyle: const TextStyle(color: Colores.textoSecundario),
                        filled: true,
                        fillColor: const Color(0x33181A1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Balata delantera', child: Text('Balata delantera (min 2.0 mm)')),
                        DropdownMenuItem(value: 'Balata trasera', child: Text('Balata trasera (min 2.0 mm)')),
                        DropdownMenuItem(value: 'Tensión de cadena', child: Text('Tensión de cadena (15-20 mm)')),
                        DropdownMenuItem(value: 'Llanta delantera', child: Text('Llanta delantera (min 1.5 mm)')),
                        DropdownMenuItem(value: 'Llanta trasera', child: Text('Llanta trasera (min 2.0 mm)')),
                        DropdownMenuItem(value: 'Batería (reposo)', child: Text('Batería reposo (min 12.4 V)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            componente = val;
                            if (val.contains('cadena')) {
                              unidad = 'mm';
                              valorCtrl.text = '18.0';
                              minCtrl.text = '15.0';
                              maxCtrl.text = '20.0';
                            } else if (val.contains('Batería')) {
                              unidad = 'V';
                              valorCtrl.text = '12.6';
                              minCtrl.text = '12.4';
                              maxCtrl.clear();
                            } else if (val.contains('Llanta delantera')) {
                              unidad = 'mm';
                              valorCtrl.text = '3.0';
                              minCtrl.text = '1.5';
                              maxCtrl.clear();
                            } else {
                              unidad = 'mm';
                              valorCtrl.text = '3.5';
                              minCtrl.text = '2.0';
                              maxCtrl.clear();
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),

                    // Valor medido y unidad
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: valorCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colores.texto),
                            decoration: InputDecoration(
                              labelText: 'Valor medido',
                              labelStyle: const TextStyle(color: Colores.textoSecundario),
                              suffixText: unidad,
                              suffixStyle: const TextStyle(color: Colores.oroClaro),
                              filled: true,
                              fillColor: const Color(0x33181A1E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colores.texto),
                            decoration: InputDecoration(
                              labelText: 'Mínimo seguro',
                              labelStyle: const TextStyle(color: Colores.textoSecundario, fontSize: 11),
                              filled: true,
                              fillColor: const Color(0x33181A1E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Kilometraje en odómetro
                    TextField(
                      controller: kmCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colores.texto),
                      decoration: InputDecoration(
                        labelText: 'Kilometraje en odómetro',
                        labelStyle: const TextStyle(color: Colores.textoSecundario),
                        suffixText: 'km',
                        suffixStyle: const TextStyle(color: Colores.oroClaro),
                        filled: true,
                        fillColor: const Color(0x33181A1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Nota
                    TextField(
                      controller: notaCtrl,
                      style: const TextStyle(color: Colores.texto, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Nota u observación (opcional)',
                        labelStyle: const TextStyle(color: Colores.textoSecundario, fontSize: 12),
                        filled: true,
                        fillColor: const Color(0x33181A1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón Guardar
                    BotonOro(
                      etiqueta: 'Guardar medición',
                      etiquetaListo: '¡Medición registrada!',
                      icono: Icons.check_circle_rounded,
                      estado: estadoBoton,
                      alPresionar: () async {
                        final valNum = double.tryParse(valorCtrl.text) ?? 0.0;
                        final minNum = double.tryParse(minCtrl.text) ?? 0.0;
                        final maxNum = double.tryParse(maxCtrl.text);
                        final kmNum = double.tryParse(kmCtrl.text) ?? _repo.kmActual;

                        setModalState(() => estadoBoton = EstadoBoton.cargando);

                        await _repo.registrarMedicionDesgaste(
                          componente: componente,
                          unidad: unidad,
                          valor: valNum,
                          minimoSeguro: minNum,
                          maximoSeguro: maxNum,
                          km: kmNum,
                          nota: notaCtrl.text.trim().isEmpty ? null : notaCtrl.text.trim(),
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

  void _mostrarModalRegistrarCarga() {
    final kmCtrl = TextEditingController(text: _repo.kmActual.round().toString());
    final litrosCtrl = TextEditingController(text: '10.0');
    final costoCtrl = TextEditingController(text: '240');
    DateTime fecha = DateTime.now();
    EstadoBoton estadoBoton = EstadoBoton.normal;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: PanelVidrio(
              radio: 28,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_gas_station_rounded, color: Colores.oroClaro, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Carga de Gasolina',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colores.texto),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded, color: Colores.textoSecundario),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Odómetro actual
                    TextField(
                      controller: kmCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colores.texto),
                      decoration: InputDecoration(
                        labelText: 'Kilometraje en odómetro',
                        labelStyle: const TextStyle(color: Colores.textoSecundario),
                        suffixText: 'km',
                        suffixStyle: const TextStyle(color: Colores.oroClaro),
                        helperText: 'Se usa para calcular el rendimiento desde la carga previa',
                        helperStyle: const TextStyle(color: Colores.textoSecundario, fontSize: 11),
                        filled: true,
                        fillColor: const Color(0x33181A1E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Litros y Costo
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: litrosCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colores.texto),
                            decoration: InputDecoration(
                              labelText: 'Litros',
                              labelStyle: const TextStyle(color: Colores.textoSecundario),
                              suffixText: 'L',
                              suffixStyle: const TextStyle(color: Colores.oroClaro),
                              filled: true,
                              fillColor: const Color(0x33181A1E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: costoCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: Colores.texto),
                            decoration: InputDecoration(
                              labelText: 'Costo total',
                              labelStyle: const TextStyle(color: Colores.textoSecundario),
                              prefixText: '\$ ',
                              prefixStyle: const TextStyle(color: Colores.oroClaro),
                              filled: true,
                              fillColor: const Color(0x33181A1E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Botón Guardar Carga
                    BotonOro(
                      etiqueta: 'Guardar carga',
                      etiquetaListo: '¡Carga registrada!',
                      icono: Icons.check_circle_rounded,
                      estado: estadoBoton,
                      alPresionar: () async {
                        final kmVal = double.tryParse(kmCtrl.text) ?? _repo.kmActual;
                        final litVal = double.tryParse(litrosCtrl.text) ?? 0.0;
                        final costVal = double.tryParse(costoCtrl.text) ?? 0.0;

                        setModalState(() => estadoBoton = EstadoBoton.cargando);

                        await _repo.registrarCargaCombustible(
                          km: kmVal,
                          litros: litVal,
                          costo: costVal,
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

/// Gráfica visual de barras de las últimas cargas mostrando km/L con línea de referencia promedio.
class _GraficaBarrasCombustible extends StatelessWidget {
  const _GraficaBarrasCombustible({
    required this.cargas,
    required this.promedio,
  });

  final List<CargaCombustible> cargas;
  final double promedio;

  @override
  Widget build(BuildContext context) {
    if (cargas.isEmpty) return const SizedBox.shrink();

    final maxKmL = math.max(
      40.0,
      cargas.fold<double>(0.0, (m, c) => math.max(m, c.kmPorLitro ?? 0.0)),
    );

    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            // Línea de referencia del promedio
            if (promedio > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: (promedio / maxKmL) * (c.maxHeight - 24),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colores.oro.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Prom. ${promedio.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 9, color: Colores.oroClaro, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 1,
                        color: Colores.oro.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),

            // Barras verticales
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: cargas.map((item) {
                  final kml = item.kmPorLitro ?? 0.0;
                  final alturaBarra = maxKmL > 0
                      ? (kml / maxKmL) * (c.maxHeight - 26)
                      : 0.0;
                  final enAlerta = kml > 0 && kml < (promedio * 0.85);

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        kml > 0 ? kml.toStringAsFixed(1) : '-',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: enAlerta ? Colores.aviso : Colores.texto,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 20,
                        height: math.max(6.0, alturaBarra),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: enAlerta
                                ? [Colores.aviso.withValues(alpha: 0.5), Colores.aviso]
                                : [Colores.oro.withValues(alpha: 0.4), Colores.oroClaro],
                          ),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM').format(item.fecha),
                        style: const TextStyle(fontSize: 9, color: Colores.textoSecundario),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
