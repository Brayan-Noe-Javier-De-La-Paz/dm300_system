import 'package:flutter/material.dart';

import 'datos/repositorios/repositorio_moto.dart';
import 'funciones/inicio/pantalla_inicio.dart';
import 'nucleo/tema/tema.dart';

class AplicacionMoto extends StatefulWidget {
  const AplicacionMoto({super.key});

  @override
  State<AplicacionMoto> createState() => _EstadoAplicacionMoto();
}

class _EstadoAplicacionMoto extends State<AplicacionMoto> {
  @override
  void initState() {
    super.initState();
    RepositorioMoto.instancia.inicializar();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DM300 · Mantenimiento',
      debugShowCheckedModeBanner: false,
      theme: crearTema(),
      home: const PantallaInicio(),
    );
  }
}
