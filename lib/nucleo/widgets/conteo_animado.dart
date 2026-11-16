import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Número que cuenta desde 0 hasta [valor].
class ConteoAnimado extends StatelessWidget {
  const ConteoAnimado({
    super.key,
    required this.valor,
    this.decimales = 0,
    this.sufijo = '',
    this.estilo,
    this.duracion = const Duration(milliseconds: 900),
  });

  final double valor;
  final int decimales;
  final String sufijo;
  final TextStyle? estilo;
  final Duration duracion;

  @override
  Widget build(BuildContext context) {
    final formato = NumberFormat(
      decimales == 0 ? '#,##0' : '#,##0.${'0' * decimales}',
    );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: valor),
      duration: duracion,
      curve: Curves.easeOutExpo,
      builder: (context, v, _) => Text('${formato.format(v)}$sufijo', style: estilo),
    );
  }
}
