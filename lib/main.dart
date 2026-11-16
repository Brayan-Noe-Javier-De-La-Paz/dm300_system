import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'aplicacion.dart';
import 'datos/repositorios/repositorio_moto.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RepositorioMoto.instancia.inicializar();
  if (!kIsWeb && Platform.isWindows) {
    await windowManager.ensureInitialized();
    const opciones = WindowOptions(
      size: Size(1400, 880),
      minimumSize: Size(420, 720),
      center: true,
      title: 'DM300 · Mantenimiento',
    );
    await windowManager.waitUntilReadyToShow(opciones, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  runApp(const AplicacionMoto());
}
