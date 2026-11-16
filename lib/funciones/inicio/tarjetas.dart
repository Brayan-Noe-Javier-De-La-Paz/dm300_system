import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../datos/repositorios/repositorio_moto.dart';
import '../../dominio/modelos/estado_tarea.dart';
import '../../nucleo/tema/colores.dart';
import '../../nucleo/widgets/conteo_animado.dart';
import '../../nucleo/widgets/panel_vidrio.dart';
import '../../nucleo/widgets/pildora_estado.dart';
import '../../nucleo/widgets/vidrio_ligero.dart';

/// Medidor semicircular animado ("Salud general").
class TarjetaSalud extends StatelessWidget {
  const TarjetaSalud({super.key, this.valor});

  final double? valor;

  @override
  Widget build(BuildContext context) {
    final repo = RepositorioMoto.instancia;
    final porcentaje = (valor ?? (repo.inicializado ? repo.saludGeneral : 92.0))
        .clamp(0.0, 100.0);
    final EstadoTarea estadoPildora = porcentaje >= 80
        ? EstadoTarea.alDia
        : (porcentaje >= 55 ? EstadoTarea.proximo : EstadoTarea.vencido);
    final String textoPildora = porcentaje >= 80
        ? 'Buena'
        : (porcentaje >= 55 ? 'Atención' : 'Urgente');

    return PanelVidrio(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Salud general',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              PildoraEstado(estado: estadoPildora, texto: textoPildora),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 124,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: porcentaje / 100),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _PintorMedidor(t)),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(t * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'HOY',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: Colores.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PintorMedidor extends CustomPainter {
  _PintorMedidor(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const grosor = 14.0;
    final radio = math.min(size.width / 2, size.height) - grosor / 2;
    final centro = Offset(size.width / 2, size.height - grosor / 2);
    final rect = Rect.fromCircle(center: centro, radius: radio);
    final pista = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x1AFFFFFF);
    canvas.drawArc(rect, math.pi, math.pi, false, pista);
    final progreso = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: math.pi,
        endAngle: 2 * math.pi,
        colors: [Colores.oro, Colores.oroClaro],
      ).createShader(rect);
    canvas.drawArc(rect, math.pi, math.pi * t, false, progreso);
  }

  @override
  bool shouldRepaint(_PintorMedidor old) => old.t != t;
}

/// Barras de km por mes con crecimiento escalonado y barra resaltada.
class TarjetaBarras extends StatefulWidget {
  const TarjetaBarras({super.key, this.datos});

  final List<double>? datos;

  @override
  State<TarjetaBarras> createState() => _EstadoBarras();
}

class _EstadoBarras extends State<TarjetaBarras>
    with SingleTickerProviderStateMixin {
  static const _nombresMeses = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];

  late final AnimationController _ctl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  int _sel = 11;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  List<String> _etiquetas12Meses() {
    final ahora = DateTime.now();
    return List.generate(12, (i) {
      final fecha = DateTime(ahora.year, ahora.month - (11 - i), 1);
      return _nombresMeses[fecha.month - 1];
    });
  }

  List<double> _obtenerDatos() {
    if (widget.datos != null && widget.datos!.length == 12) {
      return widget.datos!;
    }
    final repo = RepositorioMoto.instancia;
    if (repo.inicializado) {
      final serie = repo.kmUltimos12Meses;
      if (serie.length == 12 && serie.any((v) => v > 0)) {
        return serie;
      }
    }
    return const <double>[820, 940, 1100, 900, 760, 480, 530, 610, 720, 980, 860, 700];
  }

  @override
  Widget build(BuildContext context) {
    final formato = NumberFormat('#,##0');
    final meses = _etiquetas12Meses();
    final datos = _obtenerDatos();
    final indiceSel = _sel.clamp(0, datos.length - 1);

    return PanelVidrio(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Km por mes',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Últimos 12 meses · odómetro y servicios',
                    style: TextStyle(fontSize: 12, color: Colores.textoSecundario),
                  ),
                ],
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: VidrioLigero(
                  key: ValueKey('$indiceSel-${datos[indiceSel]}'),
                  radio: 999,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    '${meses[indiceSel]} · ${formato.format(datos[indiceSel])} km',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colores.oroClaro,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: AnimatedBuilder(
              animation: _ctl,
              builder: (context, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < datos.length; i++)
                    Expanded(child: _barra(i, datos, meses[i], indiceSel)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barra(int i, List<double> datos, String etiquetaMes, int indiceSel) {
    final maximo = math.max(1.0, datos.reduce(math.max));
    final avance =
        ((_ctl.value - i * 0.04) / (1 - 0.04 * (datos.length - 1)))
            .clamp(0.0, 1.0);
    final altura = Curves.easeOutCubic.transform(avance) * (datos[i] / maximo);
    final activo = i == indiceSel;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _sel = i),
      child: Column(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: altura.clamp(0.06, 1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: activo
                        ? Colores.degradadoOro
                        : const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x8CFFFFFF), Color(0x1FFFFFFF)],
                          ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            etiquetaMes,
            style: TextStyle(
              fontSize: 10,
              color: activo ? Colores.oroClaro : Colores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta pequeña con número que cuenta y una etiqueta de estado.
class TarjetaKpi extends StatelessWidget {
  const TarjetaKpi({
    super.key,
    required this.titulo,
    required this.valor,
    required this.etiqueta,
    required this.estado,
    required this.icono,
  });

  final String titulo;
  final double valor;
  final String etiqueta;
  final EstadoTarea estado;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return VidrioLigero(
      radio: 20,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colores.textoSecundario,
                  ),
                ),
              ),
              Icon(icono, size: 16, color: Colores.textoSecundario),
            ],
          ),
          ConteoAnimado(
            valor: valor,
            estilo: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          PildoraEstado(estado: estado, texto: etiqueta),
        ],
      ),
    );
  }
}

/// Tarjeta interactiva con anillo de progreso de la Ficha de mi moto (X/24).
class TarjetaFichaResumen extends StatelessWidget {
  const TarjetaFichaResumen({
    super.key,
    required this.verificados,
    required this.total,
    required this.alAbrir,
  });

  final int verificados;
  final int total;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (verificados / total).clamp(0.0, 1.0) : 0.0;
    return GestureDetector(
      onTap: alAbrir,
      child: VidrioLigero(
        radio: 20,
        padding: const EdgeInsets.all(16),
        seleccionado: verificados < total,
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: ratio,
                    strokeWidth: 5,
                    backgroundColor: const Color(0x26FFFFFF),
                    color: Colores.oroClaro,
                  ),
                  Center(
                    child: Text(
                      '$verificados/$total',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colores.oroClaro,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ficha de mi moto',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    verificados == total
                        ? 'Todos los datos técnicos verificados'
                        : '${total - verificados} datos pendientes para filtrar refacciones',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colores.oroClaro,
            ),
          ],
        ),
      ),
    );
  }
}

/// Recordatorio suave cuando pasan >= 7 días sin lectura de odómetro.
class TarjetaRecordatorioKm extends StatelessWidget {
  const TarjetaRecordatorioKm({
    super.key,
    required this.diasSinLectura,
    required this.kmEstimado,
    required this.alActualizar,
  });

  final int diasSinLectura;
  final double kmEstimado;
  final VoidCallback alActualizar;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0');
    return VidrioLigero(
      radio: 20,
      padding: const EdgeInsets.all(14),
      seleccionado: true,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colores.aviso.withValues(alpha: 0.18),
            ),
            child: const Icon(
              Icons.speed_rounded,
              size: 20,
              color: Colores.aviso,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Han pasado $diasSinLectura días sin lectura',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colores.texto,
                  ),
                ),
                Text(
                  'Estimado hoy ≈ ${fmt.format(kmEstimado)} km · Confirma en 3 s',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: alActualizar,
            style: TextButton.styleFrom(
              foregroundColor: Colores.oroClaro,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            child: const Text(
              'Capturar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra segmentada: avance del plan preventivo de la DM300.
class TarjetaServicio extends StatelessWidget {
  const TarjetaServicio({super.key, this.alVerMantenimiento});

  final VoidCallback? alVerMantenimiento;

  @override
  Widget build(BuildContext context) {
    final repo = RepositorioMoto.instancia;
    final tareas = repo.tareasMantenimiento;
    final total = tareas.isNotEmpty ? tareas.length : 5;
    final alDia = tareas.isNotEmpty
        ? tareas
            .where((t) => repo.estadoDeTarea(t.id) == EstadoTarea.alDia)
            .length
        : 3;

    return GestureDetector(
      onTap: alVerMantenimiento,
      child: VidrioLigero(
        radio: 20,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Plan preventivo DM300',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                if (alVerMantenimiento != null)
                  const Text(
                    'Abrir',
                    style: TextStyle(fontSize: 12, color: Colores.oroClaro),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Aceite · cadena · bujía · frenos · llantas',
              style: TextStyle(fontSize: 12, color: Colores.textoSecundario),
            ),
            const SizedBox(height: 14),
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: alDia.toDouble()),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Row(
                children: [
                  for (var i = 0; i < total; i++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
                        child: _Segmento((v - i).clamp(0.0, 1.0)),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Al día $alDia de $total revisiones',
              style: const TextStyle(fontSize: 12, color: Colores.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmento extends StatelessWidget {
  const _Segmento(this.relleno);

  final double relleno;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: relleno,
          child: Container(
            height: 10,
            decoration: BoxDecoration(
              gradient: Colores.degradadoOro,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista de actividad reciente conectada al repositorio.
class TarjetaActividad extends StatelessWidget {
  const TarjetaActividad({super.key, this.alVerTodo});

  final VoidCallback? alVerTodo;

  @override
  Widget build(BuildContext context) {
    final repo = RepositorioMoto.instancia;
    final fmtKm = NumberFormat('#,##0');
    final servicios = repo.registrosServicio.reversed.take(2).toList();
    final cargas = repo.cargasCombustible.reversed.take(1).toList();

    final items = <(IconData, String, String)>[
      for (final s in servicios)
        (
          Icons.build_rounded,
          s.tituloTarea,
          '${fmtKm.format(s.km)} km · hecho por ${s.realizadoPor}',
        ),
      for (final c in cargas)
        (
          Icons.local_gas_station_rounded,
          'Gasolina · ${c.litros.toStringAsFixed(1)} L',
          '${fmtKm.format(c.km)} km${c.kmPorLitro != null ? ' · ${c.kmPorLitro!.toStringAsFixed(1)} km/L' : ''}',
        ),
    ];

    final listaFinal = items.isNotEmpty
        ? items
        : const [
            (
              Icons.build_rounded,
              'Lubricación de cadena',
              '22,700 km · hecho por Mí',
            ),
            (
              Icons.oil_barrel_outlined,
              'Cambio de aceite y cedazo',
              '21,000 km · Taller',
            ),
          ];

    return VidrioLigero(
      radio: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Actividad reciente',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              GestureDetector(
                onTap: alVerTodo,
                child: const Text(
                  'Ver todo',
                  style: TextStyle(fontSize: 12, color: Colores.oroClaro),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (icono, titulo, detalle) in listaFinal)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0x26D4AF37),
                    ),
                    child: Icon(icono, size: 18, color: Colores.oroClaro),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          detalle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colores.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
