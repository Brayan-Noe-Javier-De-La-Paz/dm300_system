import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_animate/flutter_animate.dart';

import '../../dominio/modelos/estado_tarea.dart';
import '../../nucleo/tema/colores.dart';
import '../../nucleo/tema/estado_visual.dart';
import '../../nucleo/widgets/vidrio_ligero.dart';

class ZonaVista {
  const ZonaVista({
    required this.nombre,
    required this.x,
    required this.y,
    required this.estado,
  });

  final String nombre;
  final double x; // % del lienzo
  final double y; // % del lienzo
  final EstadoTarea estado;
}

class VistaDatos {
  const VistaDatos({
    required this.id,
    required this.real,
    required this.diagrama,
    required this.zonas,
  });

  final String id;
  final String real;
  final String diagrama;
  final List<ZonaVista> zonas;
}

EstadoTarea _estadoDeEjemplo(String? s) => switch (s) {
      'ok' => EstadoTarea.alDia,
      'av' => EstadoTarea.proximo,
      've' => EstadoTarea.vencido,
      _ => EstadoTarea.sinDatos,
    };

/// Moto interactiva: arrastra para girar entre 5 vistas, alterna Real/Diagrama
/// con un barrido dorado y toca una zona para ver su detalle.
class VistaMoto extends StatefulWidget {
  const VistaMoto({
    super.key,
    required this.alSeleccionarZona,
    this.zonaSeleccionada,
    this.estadoDeZona,
  });

  final ValueChanged<ZonaVista?> alSeleccionarZona;
  final String? zonaSeleccionada;
  final EstadoTarea Function(String nombreZona)? estadoDeZona;

  @override
  State<VistaMoto> createState() => _EstadoVistaMoto();
}

class _EstadoVistaMoto extends State<VistaMoto> with TickerProviderStateMixin {
  static const double _relacion = 1600 / 1120;

  late final AnimationController _giro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final AnimationController _modo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  List<VistaDatos> _vistas = const [];
  double _p = 0;
  double _desde = 0;
  double _hasta = 0;
  bool _diagrama = false;

  @override
  void initState() {
    super.initState();
    _giro.addListener(() {
      setState(() {
        _p = _desde + (_hasta - _desde) * Curves.easeOutCubic.transform(_giro.value);
      });
    });
    _cargar();
  }

  @override
  void dispose() {
    _giro.dispose();
    _modo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final texto = await rootBundle.loadString('assets/moto/vistas.json');
    final json = jsonDecode(texto) as Map<String, dynamic>;
    final lista = (json['vistas'] as List).map((e) {
      final m = e as Map<String, dynamic>;
      final zonas = ((m['zonas'] as List?) ?? const []).map((z) {
        final zm = z as Map<String, dynamic>;
        return ZonaVista(
          nombre: zm['nombre'] as String,
          x: (zm['x'] as num).toDouble(),
          y: (zm['y'] as num).toDouble(),
          estado: _estadoDeEjemplo(zm['estado_ejemplo'] as String?),
        );
      }).toList();
      return VistaDatos(
        id: m['id'] as String,
        real: m['real'] as String,
        diagrama: m['diagrama'] as String,
        zonas: zonas,
      );
    }).toList();
    if (!mounted) return;
    setState(() => _vistas = lista);
    for (final v in lista) {
      precacheImage(AssetImage(v.real), context);
      precacheImage(AssetImage(v.diagrama), context);
    }
  }

  void _ir(int destino) {
    _desde = _p;
    _hasta = destino.clamp(0, _vistas.length - 1).toDouble();
    _giro.forward(from: 0);
  }

  void _cambiarModo(bool diagrama) {
    if (diagrama == _diagrama) return;
    setState(() => _diagrama = diagrama);
    diagrama ? _modo.forward() : _modo.reverse();
  }

  double _suave(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  double _opacidad(int i) {
    final d = (_p - i).abs();
    return d >= 1 ? 0 : 1 - _suave(0.25, 0.75, d);
  }

  @override
  Widget build(BuildContext context) {
    if (_vistas.isEmpty) {
      return const AspectRatio(
        aspectRatio: _relacion,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colores.oro),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _controles(),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: _relacion,
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final h = c.maxHeight;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _giro.stop(),
                onHorizontalDragUpdate: (d) => setState(() {
                  _p = (_p + d.delta.dx / (w * 0.28))
                      .clamp(0.0, _vistas.length - 1.0);
                }),
                onHorizontalDragEnd: (_) => _ir(_p.round()),
                child: AnimatedBuilder(
                  animation: _modo,
                  builder: (context, _) {
                    final f = Curves.easeInOut.transform(_modo.value);
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        if (_modo.value > 0)
                          Positioned.fill(
                            child: _capa(_vistas.map((v) => v.diagrama).toList(), brillo: false),
                          ),
                        Positioned.fill(
                          child: ClipRect(
                            clipper: _Barrido(f),
                            child: _capa(_vistas.map((v) => v.real).toList(), brillo: true),
                          ),
                        ),
                        if (_modo.isAnimating)
                          Positioned(
                            left: w * f - 1,
                            top: -h * 0.04,
                            bottom: -h * 0.04,
                            width: 2,
                            child: const DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colores.oroClaro,
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x99F2D27A),
                                    blurRadius: 18,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ..._zonas(w, h),
                      ],
                    );
                  },
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _selector(),
      ],
    );
  }

  Widget _capa(List<String> rutas, {required bool brillo}) {
    final pila = Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < rutas.length; i++) _imagen(rutas[i], _opacidad(i)),
      ],
    );
    if (!brillo) return pila;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1.18, 0, 0, 0, 0, //
        0, 1.18, 0, 0, 0, //
        0, 0, 1.18, 0, 0, //
        0, 0, 0, 1, 0,
      ]),
      child: pila,
    );
  }

  Widget _imagen(String ruta, double opacidad) {
    if (opacidad <= 0.001) return const SizedBox.shrink();
    return Opacity(
      opacity: opacidad,
      child: Image.asset(
        ruta,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  List<Widget> _zonas(double w, double h) {
    final salida = <Widget>[];
    for (var i = 0; i < _vistas.length; i++) {
      final visible = (_p - i).abs() < 0.04;
      for (final z in _vistas[i].zonas) {
        final estadoActual = widget.estadoDeZona?.call(z.nombre) ?? z.estado;
        final zonaEfectiva = ZonaVista(
          nombre: z.nombre,
          x: z.x,
          y: z.y,
          estado: estadoActual,
        );
        salida.add(
          _Marcador(
            key: ValueKey('$i-${z.nombre}'),
            zona: zonaEfectiva,
            ancho: w,
            alto: h,
            visible: visible,
            seleccionada: widget.zonaSeleccionada == z.nombre,
            alTocar: () => widget.alSeleccionarZona(
              widget.zonaSeleccionada == z.nombre ? null : zonaEfectiva,
            ),
          ),
        );
      }
    }
    return salida;
  }

  Widget _controles() {
    return Row(
      children: [
        VidrioLigero(
          radio: 999,
          padding: const EdgeInsets.all(3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _segmento('Real', !_diagrama, () => _cambiarModo(false)),
              _segmento('Diagrama', _diagrama, () => _cambiarModo(true)),
            ],
          ),
        ),
        const Spacer(),
        const VidrioLigero(
          radio: 999,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Arrastra para girar',
            style: TextStyle(color: Colores.textoSecundario, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _segmento(String texto, bool activo, VoidCallback alTocar) {
    return GestureDetector(
      onTap: alTocar,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: activo ? Colores.degradadoOro : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: activo ? Colores.oroOscuro : Colores.textoSecundario,
          ),
        ),
      ),
    );
  }

  Widget _selector() {
    const etiquetas = ['Izq.', '3/4 izq.', 'Frente', '3/4 der.', 'Der.'];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < _vistas.length; i++)
          GestureDetector(
            onTap: () => _ir(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: _p.round() == i ? Colores.degradadoOro : null,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: _p.round() == i ? Colors.transparent : Colores.borde,
                ),
              ),
              child: Text(
                i < etiquetas.length ? etiquetas[i] : '${i + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _p.round() == i ? Colores.oroOscuro : Colores.textoSecundario,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Barrido extends CustomClipper<Rect> {
  _Barrido(this.fraccion);

  final double fraccion;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(size.width * fraccion, 0, size.width, size.height);

  @override
  bool shouldReclip(_Barrido old) => old.fraccion != fraccion;
}

class _Marcador extends StatelessWidget {
  const _Marcador({
    super.key,
    required this.zona,
    required this.ancho,
    required this.alto,
    required this.visible,
    required this.seleccionada,
    required this.alTocar,
  });

  final ZonaVista zona;
  final double ancho;
  final double alto;
  final bool visible;
  final bool seleccionada;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final px = zona.x / 100 * ancho;
    final py = zona.y / 100 * alto;
    final haciaIzquierda = zona.x > 55;
    final fila = Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: haciaIzquierda ? TextDirection.rtl : TextDirection.ltr,
      children: [
        _Punto(color: zona.estado.color, seleccionada: seleccionada),
        const SizedBox(width: 8),
        _Etiqueta(texto: zona.nombre, seleccionada: seleccionada),
      ],
    );
    return Positioned(
      left: haciaIzquierda ? null : px - 14,
      right: haciaIzquierda ? ancho - px - 14 : null,
      top: py - 14,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: alTocar,
            child: fila,
          ),
        ),
      ),
    );
  }
}

class _Punto extends StatelessWidget {
  const _Punto({required this.color, required this.seleccionada});

  final Color color;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (seleccionada)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colores.oroClaro, width: 2),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
                  begin: const Offset(0.6, 0.6),
                  end: const Offset(1.15, 1.15),
                  duration: 1500.ms,
                  curve: Curves.easeOut,
                )
                .fadeOut(duration: 1500.ms),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 12),
                const BoxShadow(color: Color(0xBF0E0F12), spreadRadius: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.seleccionada});

  final String texto;
  final bool seleccionada;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xD915171A),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: seleccionada ? Colores.oro : Colores.borde),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colores.texto,
        ),
      ),
    );
  }
}
