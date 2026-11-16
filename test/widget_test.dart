import 'package:dm300_system/aplicacion.dart';
import 'package:dm300_system/datos/repositorios/repositorio_moto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Carga AplicacionMoto y muestra el tablero DM300', (
    WidgetTester tester,
  ) async {
    await RepositorioMoto.instancia.inicializar();
    await tester.pumpWidget(const AplicacionMoto());
    await tester.pump();

    expect(find.text('DM300'), findsWidgets);
    expect(find.text('Salud general'), findsOneWidget);
  });
}
