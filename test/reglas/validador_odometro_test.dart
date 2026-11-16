import 'package:dm300_system/dominio/modelos/ficha_moto.dart';
import 'package:dm300_system/dominio/modelos/modelos_mantenimiento.dart';
import 'package:dm300_system/dominio/reglas/motor_mantenimiento.dart';
import 'package:dm300_system/dominio/reglas/validador_odometro.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ValidadorOdometro', () {
    final fechaBase = DateTime(2026, 11, 10);
    final fechaHoy = DateTime(2026, 11, 15);

    test('acepta lectura normal válida', () {
      final res = ValidadorOdometro.validar(
        nuevoKm: 24020,
        ultimoKm: 23880,
        fechaUltimaLectura: fechaBase,
        fechaNueva: fechaHoy,
      );

      expect(res.nivel, NivelValidacionOdometro.valido);
      expect(res.permiteGuardar, isTrue);
    });

    test('bloquea lectura menor a la anterior cuando no hubo cambio de tablero', () {
      final res = ValidadorOdometro.validar(
        nuevoKm: 18500,
        ultimoKm: 23880,
        fechaUltimaLectura: fechaBase,
        fechaNueva: fechaHoy,
      );

      expect(res.nivel, NivelValidacionOdometro.bloqueadoMenor);
      expect(res.requiereCambioTablero, isTrue);
      expect(res.permiteGuardar, isFalse);
    });

    test('detecta probable error de dígito faltante (2388 vs 23880)', () {
      final res = ValidadorOdometro.validar(
        nuevoKm: 2388,
        ultimoKm: 23880,
        fechaUltimaLectura: fechaBase,
        fechaNueva: fechaHoy,
      );

      expect(res.nivel, NivelValidacionOdometro.errorDigitoProbable);
      expect(res.kmSugerido, 23880);
      expect(res.permiteGuardar, isFalse);
    });

    test('permite lectura menor si el usuario confirma cambio de tablero', () {
      final res = ValidadorOdometro.validar(
        nuevoKm: 15,
        ultimoKm: 23880,
        fechaUltimaLectura: fechaBase,
        fechaNueva: fechaHoy,
        cambioTablero: true,
      );

      expect(res.nivel, NivelValidacionOdometro.valido);
      expect(res.permiteGuardar, isTrue);
    });

    test('advierte cuando el salto supera 400 km/día', () {
      final res = ValidadorOdometro.validar(
        nuevoKm: 25000,
        ultimoKm: 23880,
        fechaUltimaLectura: DateTime(2026, 11, 14),
        fechaNueva: DateTime(2026, 11, 15),
      );

      expect(res.nivel, NivelValidacionOdometro.advertenciaSalto);
      expect(res.requiereConfirmacionSalto, isTrue);
      expect(res.permiteGuardar, isTrue);
    });
  });

  group('MotorMantenimiento - Ficha y Rendimiento', () {
    const kit428 = RefaccionDm300(
      id: 'ref_428',
      sku: 'DM300-CAD-428',
      nombre: 'Kit de arrastre paso 428 reforzado',
      categoria: 'Transmisión',
      zona: 'Cadena y transmisión',
      precioEstimado: 680,
      dependeDeClaveFicha: 'paso_cadena',
      valorRequerido: '428',
    );
    const kit520 = RefaccionDm300(
      id: 'ref_520',
      sku: 'DM300-CAD-520',
      nombre: 'Kit de arrastre paso 520 O-Ring',
      categoria: 'Transmisión',
      zona: 'Cadena y transmisión',
      precioEstimado: 1150,
      dependeDeClaveFicha: 'paso_cadena',
      valorRequerido: '520',
    );

    CampoFicha crearCampoPaso(EstadoCampoFicha estado, String valor) {
      return CampoFicha(
        clave: 'paso_cadena',
        seccion: SeccionFicha.traccion,
        titulo: 'Paso de la cadena',
        pregunta: '¿Qué paso tiene?',
        dondeVerlo: 'Placas de la cadena',
        opciones: const ['428', '520'],
        valor: valor,
        estado: estado,
      );
    }

    test('marca piezas como dudosas mientras paso_cadena está pendiente', () {
      final evaluadas = MotorMantenimiento.filtrarRefacciones(
        catalogo: const [kit428, kit520],
        ficha: [crearCampoPaso(EstadoCampoFicha.pendiente, '')],
      );

      expect(evaluadas, hasLength(2));
      expect(
        evaluadas.every(
          (e) => e.estado == EstadoCompatibilidadRefaccion.dudosaPendienteFicha,
        ),
        isTrue,
      );
    });

    test('sugiere kit 428 y descarta 520 cuando paso_cadena está verificado en 428', () {
      final evaluadas = MotorMantenimiento.filtrarRefacciones(
        catalogo: const [kit428, kit520],
        ficha: [crearCampoPaso(EstadoCampoFicha.verificado, '428')],
      );

      expect(evaluadas[0].estado, EstadoCompatibilidadRefaccion.sugerida);
      expect(
        evaluadas[1].estado,
        EstadoCompatibilidadRefaccion.noAplicaAccesorio,
      );
    });

    test('detecta caída de rendimiento >= 15% en km/L', () {
      final cargas = [
        CargaCombustible(
          id: 'c1',
          km: 23000,
          litros: 10,
          costo: 250,
          fecha: DateTime(2026, 11, 1),
          kmPorLitro: 28.5,
        ),
        CargaCombustible(
          id: 'c2',
          km: 23285,
          litros: 10,
          costo: 250,
          fecha: DateTime(2026, 11, 8),
          kmPorLitro: 28.5,
        ),
        CargaCombustible(
          id: 'c3',
          km: 23500,
          litros: 10,
          costo: 250,
          fecha: DateTime(2026, 11, 15),
          kmPorLitro: 21.5,
        ),
      ];

      final alerta = MotorMantenimiento.detectarCaidaRendimiento(cargas);
      expect(alerta, isNotNull);
      expect(alerta, contains('filtro de aire'));
    });
  });
}
