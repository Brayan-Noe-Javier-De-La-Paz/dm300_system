import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tema/colores.dart';

/// Fondo animado "Aurora Mecánica y Telemetría HUD".
/// Combina un gradiente nocturno profundo, 4 orbes de luz en movimiento sinusoidal
/// y trazos técnicos de cuadrícula y telemetría que enriquecen el desenfoque
/// de los paneles con efecto de cristal (glassmorphism).
class FondoEscena extends StatefulWidget {
  const FondoEscena({super.key, required this.child});

  final Widget child;

  @override
  State<FondoEscena> createState() => _FondoEscenaState();
}

class _FondoEscenaState extends State<FondoEscena>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Gradiente base nocturno profundo (#0A0B0E -> #12151C -> #0D1017)
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0A0B0E),
                  Color(0xFF12151C),
                  Color(0xFF0D1017),
                ],
              ),
            ),
          ),
        ),
        // Nebulosas animadas y telemetría técnica HUD
        Positioned.fill(
          child: CustomPaint(
            painter: _PintorAuroraHUD(animation: _controller),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _PintorAuroraHUD extends CustomPainter {
  _PintorAuroraHUD({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = animation.value * 2 * math.pi;

    // --- 1. CUATRO ORBES / NEBULOSAS SUAVES ---
    // Orbe 1: Oro imperial
    final o1Center = Offset(
      size.width * (0.28 + 0.12 * math.sin(t)),
      size.height * (0.26 + 0.10 * math.cos(t)),
    );
    final double o1Radius = (size.shortestSide * 0.52).clamp(240.0, 540.0);
    final o1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colores.oroClaro.withValues(alpha: 0.22),
          Colores.oro.withValues(alpha: 0.12),
          Colores.oro.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: o1Center, radius: o1Radius));
    canvas.drawCircle(o1Center, o1Radius, o1Paint);

    // Orbe 2: Ámbar cálido
    final o2Center = Offset(
      size.width * (0.75 + 0.12 * math.cos(t * 0.85 + 0.6)),
      size.height * (0.32 + 0.10 * math.sin(t * 0.85 + 0.6)),
    );
    final double o2Radius = (size.shortestSide * 0.46).clamp(200.0, 480.0);
    final o2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colores.ambarCalido.withValues(alpha: 0.20),
          Colores.ambarCalido.withValues(alpha: 0.08),
          Colores.ambarCalido.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: o2Center, radius: o2Radius));
    canvas.drawCircle(o2Center, o2Radius, o2Paint);

    // Orbe 3: Cian técnico
    final o3Center = Offset(
      size.width * (0.64 + 0.14 * math.sin(t * 1.15 + 1.8)),
      size.height * (0.74 + 0.12 * math.cos(t * 1.15 + 1.8)),
    );
    final double o3Radius = (size.shortestSide * 0.48).clamp(220.0, 500.0);
    final o3Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colores.cianHuella.withValues(alpha: 0.20),
          Colores.cianHuella.withValues(alpha: 0.08),
          Colores.cianHuella.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.50, 1.0],
      ).createShader(Rect.fromCircle(center: o3Center, radius: o3Radius));
    canvas.drawCircle(o3Center, o3Radius, o3Paint);

    // Orbe 4: Azul profundo
    final o4Center = Offset(
      size.width * (0.22 + 0.10 * math.cos(t * 0.90 + 2.8)),
      size.height * (0.80 + 0.10 * math.sin(t * 0.90 + 2.8)),
    );
    final double o4Radius = (size.shortestSide * 0.55).clamp(260.0, 580.0);
    final o4Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colores.azulProfundo.withValues(alpha: 0.35),
          Colores.azulProfundo.withValues(alpha: 0.14),
          Colores.azulProfundo.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: o4Center, radius: o4Radius));
    canvas.drawCircle(o4Center, o4Radius, o4Paint);

    // --- 2. CUADRÍCULA TÉCNICA Y CRUCES DE CALIBRACIÓN ---
    final gridPaint = Paint()
      ..color = const Color(0x08FFFFFF)
      ..strokeWidth = 1.0;

    for (double x = 0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final crossPaint = Paint()
      ..color = const Color(0x1FFFFFFF)
      ..strokeWidth = 1.0;
    const double crossArm = 3.5;

    for (double x = 0; x < size.width; x += 96) {
      for (double y = 0; y < size.height; y += 96) {
        canvas.drawLine(Offset(x - crossArm, y), Offset(x + crossArm, y), crossPaint);
        canvas.drawLine(Offset(x, y - crossArm), Offset(x, y + crossArm), crossPaint);
      }
    }

    // --- 3. TELEMETRÍA TIPO VELOCÍMETRO / TACÓMETRO (ZONA CENTRAL-DERECHA) ---
    final double cx = size.width > 600 ? size.width * 0.80 : size.width * 0.72;
    final double cy = size.height * 0.48;
    final double baseR = (size.shortestSide * 0.38).clamp(130.0, 310.0);
    final hudCenter = Offset(cx, cy);

    // Anillo 1: Trazos discontinuos dorados tenues (radio interno)
    final dashPaintGold = Paint()
      ..color = const Color(0x1AD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const int dashCount1 = 24;
    const double step1 = (2 * math.pi) / dashCount1;
    final double rot1 = t * 0.04;
    final r1 = baseR * 0.55;
    for (int i = 0; i < dashCount1; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: hudCenter, radius: r1),
        i * step1 + rot1,
        step1 * 0.40,
        false,
        dashPaintGold,
      );
    }

    // Anillo 2: Escala de tacómetro (graduación con marcas radiales)
    final tickPaintGold = Paint()
      ..color = const Color(0x1AD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final tickPaintWhite = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const int tickCount = 28;
    const double startAngle = 0.65 * math.pi;
    const double sweepAngle = 1.00 * math.pi;
    final r2 = baseR * 0.82;

    for (int i = 0; i <= tickCount; i++) {
      final double a = startAngle + (i / tickCount) * sweepAngle;
      final bool isMajor = (i % 4 == 0);
      final double tickLen = isMajor ? 8.0 : 4.0;
      final p = isMajor ? tickPaintGold : tickPaintWhite;
      final p1 = Offset(cx + (r2 - tickLen) * math.cos(a), cy + (r2 - tickLen) * math.sin(a));
      final p2 = Offset(cx + r2 * math.cos(a), cy + r2 * math.sin(a));
      canvas.drawLine(p1, p2, p);
    }

    // Arco guía tenue de la escala
    final arcGuidePaint = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawArc(
      Rect.fromCircle(center: hudCenter, radius: r2),
      startAngle,
      sweepAngle,
      false,
      arcGuidePaint,
    );

    // Anillo 3: Segmentos arqueados principales (dorado y blanco tenue)
    final arcGoldMain = Paint()
      ..color = const Color(0x1AD4AF37)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final arcWhiteMain = Paint()
      ..color = const Color(0x14FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final r3 = baseR * 1.05;
    final rect3 = Rect.fromCircle(center: hudCenter, radius: r3);
    canvas.drawArc(rect3, 0.70 * math.pi, 0.35 * math.pi, false, arcGoldMain);
    canvas.drawArc(rect3, 1.15 * math.pi, 0.40 * math.pi, false, arcWhiteMain);
    canvas.drawArc(rect3, 1.62 * math.pi, 0.20 * math.pi, false, arcGoldMain);

    // Anillo 4: Pista discontinua periférica (radio exterior)
    const int dotCount = 44;
    const double step4 = (2 * math.pi) / dotCount;
    final double rot4 = -t * 0.02;
    final r4 = baseR * 1.25;
    final rect4 = Rect.fromCircle(center: hudCenter, radius: r4);
    for (int i = 0; i < dotCount; i++) {
      canvas.drawArc(
        rect4,
        i * step4 + rot4,
        step4 * 0.25,
        false,
        arcWhiteMain,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PintorAuroraHUD oldDelegate) => true;
}
