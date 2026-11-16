import 'package:flutter/material.dart';

import '../tema/colores.dart';
import 'panel_vidrio.dart';

class ElementoRiel {
  const ElementoRiel(this.icono, this.etiqueta);

  final IconData icono;
  final String etiqueta;
}

/// Riel flotante: solo íconos y, al pasar el cursor, se expande con texto.
/// La píldora dorada se desliza entre opciones.
class RielNavegacion extends StatefulWidget {
  const RielNavegacion({
    super.key,
    required this.elementos,
    required this.seleccionado,
    required this.alSeleccionar,
  });

  final List<ElementoRiel> elementos;
  final int seleccionado;
  final ValueChanged<int> alSeleccionar;

  @override
  State<RielNavegacion> createState() => _EstadoRiel();
}

class _EstadoRiel extends State<RielNavegacion> {
  static const double _altoItem = 46;
  static const double _separacion = 6;
  static const Duration _duracion = Duration(milliseconds: 320);

  bool _abierto = false;

  @override
  Widget build(BuildContext context) {
    final n = widget.elementos.length;
    return MouseRegion(
      onEnter: (_) => setState(() => _abierto = true),
      onExit: (_) => setState(() => _abierto = false),
      child: AnimatedContainer(
        duration: _duracion,
        curve: Curves.easeOutCubic,
        width: _abierto ? 224 : 76,
        child: PanelVidrio(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _logo(),
              const SizedBox(height: 14),
              SizedBox(
                height: n * _altoItem + (n - 1) * _separacion,
                child: Stack(
                  children: [
                    AnimatedPositioned(
                      duration: _duracion,
                      curve: Curves.easeOutCubic,
                      top: widget.seleccionado * (_altoItem + _separacion),
                      left: 0,
                      right: 0,
                      height: _altoItem,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: Colores.degradadoOro,
                          borderRadius: BorderRadius.all(Radius.circular(14)),
                        ),
                      ),
                    ),
                    for (var i = 0; i < n; i++)
                      Positioned(
                        top: i * (_altoItem + _separacion),
                        left: 0,
                        right: 0,
                        height: _altoItem,
                        child: _item(i),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logo() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0x1FFFFFFF),
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: Colores.borde),
          ),
          child: const Icon(Icons.two_wheeler_rounded, color: Colores.oroClaro),
        ),
        Expanded(
          child: AnimatedOpacity(
            opacity: _abierto ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Padding(
              padding: EdgeInsets.only(left: 10),
              child: Text(
                'DM300.',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _item(int i) {
    final e = widget.elementos[i];
    final activo = i == widget.seleccionado;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0x14FFFFFF),
        onTap: () => widget.alSeleccionar(i),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              child: Icon(
                e.icono,
                size: 22,
                color: activo ? Colores.oroOscuro : Colores.textoSecundario,
              ),
            ),
            Expanded(
              child: AnimatedOpacity(
                opacity: _abierto ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Text(
                  e.etiqueta,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: activo ? Colores.oroOscuro : Colores.texto,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
