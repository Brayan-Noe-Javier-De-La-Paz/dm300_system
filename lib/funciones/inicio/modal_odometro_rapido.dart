import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../datos/repositorios/repositorio_moto.dart';
import '../../dominio/modelos/lectura_odometro.dart';
import '../../dominio/reglas/validador_odometro.dart';
import '../../nucleo/tema/colores.dart';
import '../../nucleo/widgets/boton_oro.dart';
import '../../nucleo/widgets/panel_vidrio.dart';
import '../../nucleo/widgets/vidrio_ligero.dart';

/// Abre el modal de Odómetro Rápido adaptativo (diálogo en pantallas amplias
/// y bottom sheet expandido en móvil).
Future<void> mostrarModalOdometroRapido(
  BuildContext context, {
  RepositorioMoto? repo,
}) async {
  final r = repo ?? RepositorioMoto.instancia;
  final ancho = MediaQuery.of(context).size.width;

  if (ancho >= 700) {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ModalOdometroRapido(repo: r),
        ),
      ),
    );
  } else {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: ModalOdometroRapido(repo: r),
      ),
    );
  }
}

/// Modal táctil para capturar la lectura de odómetro en ~3 segundos con
/// teclado numérico grande, cálculo estimado de 1 toque y validación en vivo.
class ModalOdometroRapido extends StatefulWidget {
  const ModalOdometroRapido({super.key, this.repo});

  final RepositorioMoto? repo;

  @override
  State<ModalOdometroRapido> createState() => _EstadoModalOdometroRapido();
}

class _EstadoModalOdometroRapido extends State<ModalOdometroRapido> {
  late final RepositorioMoto _repo;
  final NumberFormat _fmt = NumberFormat('#,##0');

  String _digitos = '';
  bool _cambioTablero = false;
  bool _confirmarSalto = false;
  EstadoBoton _estadoBoton = EstadoBoton.normal;
  ResultadoValidacionOdometro? _validacion;

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? RepositorioMoto.instancia;
    final inicial = _repo.kmEstimadoHoy;
    if (inicial > 0) {
      _digitos = inicial.round().toString();
    } else if (_repo.kmActual > 0) {
      _digitos = _repo.kmActual.round().toString();
    }
    _revalidar();
  }

  double get _kmIngresado => double.tryParse(_digitos) ?? 0.0;

  LecturaOdometro? get _ultimaLectura {
    if (_repo.lecturasOdometro.isEmpty) return null;
    return _repo.lecturasOdometro.last;
  }

  void _revalidar() {
    if (_digitos.isEmpty) {
      setState(() => _validacion = null);
      return;
    }
    final res = _repo.prevalidarOdometro(_kmIngresado, cambioTablero: _cambioTablero);
    setState(() => _validacion = res);
  }

  void _agregarDigito(String digito) {
    if (_digitos.length >= 7) return;
    setState(() {
      _digitos += digito;
      _revalidar();
    });
  }

  void _borrarDigito() {
    if (_digitos.isEmpty) return;
    setState(() {
      _digitos = _digitos.substring(0, _digitos.length - 1);
      _revalidar();
    });
  }

  void _limpiar() {
    setState(() {
      _digitos = '';
      _revalidar();
    });
  }

  void _aplicarAjuste(int delta) {
    final actual = _kmIngresado;
    final nuevo = (actual + delta).clamp(0, 999999).round();
    setState(() {
      _digitos = nuevo.toString();
      _revalidar();
    });
  }

  void _usarSugerencia(double km) {
    setState(() {
      _digitos = km.round().toString();
      _revalidar();
    });
  }

  Future<void> _guardarConKm(double km) async {
    if (_estadoBoton == EstadoBoton.cargando) return;
    setState(() => _estadoBoton = EstadoBoton.cargando);

    try {
      final res = await _repo.registrarLecturaOdometro(
        km,
        origen: OrigenOdometro.rapido,
        cambioTablero: _cambioTablero,
        nota: _confirmarSalto ? 'Salto de odómetro confirmado por usuario' : null,
      );

      if (!mounted) return;

      if (res.permiteGuardar) {
        setState(() => _estadoBoton = EstadoBoton.listo);
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() {
          _estadoBoton = EstadoBoton.normal;
          _validacion = res;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _estadoBoton = EstadoBoton.normal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _ultimaLectura;
    final fechaUltima = ultima != null
        ? DateFormat('dd/MM/yyyy').format(ultima.fecha)
        : 'Sin lecturas previas';

    final estimado = _repo.kmEstimadoHoy;
    final res = _validacion;

    return PanelVidrio(
      radio: 28,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con botón cerrar
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: Colores.degradadoOro,
                  ),
                  child: const Icon(
                    Icons.speed_rounded,
                    size: 20,
                    color: Colores.oroOscuro,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Odómetro Rápido',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colores.texto,
                        ),
                      ),
                      Text(
                        'Última lectura: ${_fmt.format(ultima?.km ?? _repo.kmActual)} km · $fechaUltima',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colores.textoSecundario,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colores.textoSecundario),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tarjeta Estimado de un toque
            VidrioLigero(
              radio: 18,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: Colores.oroClaro,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estimado de hoy',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colores.textoSecundario,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '≈ ${_fmt.format(estimado)} km',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colores.oroClaro,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => _guardarConKm(estimado),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colores.oro,
                          foregroundColor: Colores.oroOscuro,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Es correcto',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Botones rápidos de ajuste
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _botonAjuste('-10', () => _aplicarAjuste(-10)),
                      const SizedBox(width: 6),
                      _botonAjuste('+10', () => _aplicarAjuste(10)),
                      const SizedBox(width: 6),
                      _botonAjuste('+50', () => _aplicarAjuste(50)),
                      const SizedBox(width: 6),
                      _botonAjuste('+100', () => _aplicarAjuste(100)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Display Numérico Grande
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0x66181A1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: res != null && !res.permiteGuardar
                      ? Colores.vencido
                      : Colores.oro.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    _digitos.isEmpty ? '0' : _fmt.format(_kmIngresado),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: Colores.texto,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'km',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colores.oroClaro,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Mensajes y acciones de validación en tiempo real
            if (res != null) ...[
              if (res.nivel == NivelValidacionOdometro.errorDigitoProbable)
                _bannerAdvertencia(
                  icono: Icons.help_outline_rounded,
                  color: Colores.aviso,
                  mensaje: res.mensaje,
                  accion: res.kmSugerido != null
                      ? TextButton(
                          onPressed: () => _usarSugerencia(res.kmSugerido!),
                          style: TextButton.styleFrom(
                            foregroundColor: Colores.oroClaro,
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          child: Text(
                            '¿Quisiste decir ${_fmt.format(res.kmSugerido)} km?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        )
                      : null,
                ),
              if (res.requiereCambioTablero || _cambioTablero)
                _tarjetaCambioTablero(),
              if (res.nivel == NivelValidacionOdometro.advertenciaSalto)
                _bannerSalto(res.mensaje),
              if (res.nivel == NivelValidacionOdometro.bloqueadoMenor && !_cambioTablero)
                _bannerAdvertencia(
                  icono: Icons.block_rounded,
                  color: Colores.vencido,
                  mensaje: res.mensaje,
                  accion: TextButton(
                    onPressed: () {
                      setState(() {
                        _cambioTablero = true;
                        _revalidar();
                      });
                    },
                    style: TextButton.styleFrom(foregroundColor: Colores.oroClaro),
                    child: const Text('Activar cambio de tablero'),
                  ),
                ),
              const SizedBox(height: 8),
            ],

            // Teclado numérico táctil grande (para ingresar en 3 segundos)
            _tecladoNumerico(),
            const SizedBox(height: 14),

            // Botón de guardado
            BotonOro(
              etiqueta: 'Guardar odómetro',
              etiquetaListo: '¡Odómetro registrado!',
              icono: Icons.check_circle_outline_rounded,
              estado: _estadoBoton,
              alPresionar: () => _guardarConKm(_kmIngresado),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonAjuste(String texto, VoidCallback alPresionar) {
    return Expanded(
      child: InkWell(
        onTap: alPresionar,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x3326292E),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colores.borde),
          ),
          child: Text(
            texto,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colores.texto,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bannerAdvertencia({
    required IconData icono,
    required Color color,
    required String mensaje,
    Widget? accion,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mensaje,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (accion != null) ...[
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: accion),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaCambioTablero() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x26FF9F43),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colores.aviso.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.swap_horiz_rounded, size: 18, color: Colores.aviso),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Cambié el tablero / odómetro nuevo',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colores.texto),
            ),
          ),
          Switch(
            value: _cambioTablero,
            activeThumbColor: Colores.oro,
            onChanged: (val) {
              setState(() {
                _cambioTablero = val;
                _revalidar();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _bannerSalto(String mensaje) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colores.aviso.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colores.aviso.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: Colores.aviso),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$mensaje Confirmar salto inusual:',
              style: const TextStyle(fontSize: 12, color: Colores.aviso),
            ),
          ),
          Checkbox(
            value: _confirmarSalto,
            activeColor: Colores.aviso,
            checkColor: Colors.black,
            onChanged: (val) {
              setState(() {
                _confirmarSalto = val ?? false;
                _revalidar();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _tecladoNumerico() {
    return Column(
      children: [
        Row(
          children: [
            _tecla('1'),
            const SizedBox(width: 8),
            _tecla('2'),
            const SizedBox(width: 8),
            _tecla('3'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _tecla('4'),
            const SizedBox(width: 8),
            _tecla('5'),
            const SizedBox(width: 8),
            _tecla('6'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _tecla('7'),
            const SizedBox(width: 8),
            _tecla('8'),
            const SizedBox(width: 8),
            _tecla('9'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _teclaEspecial(
              icono: Icons.delete_sweep_rounded,
              etiqueta: 'Limpiar',
              alPresionar: _limpiar,
            ),
            const SizedBox(width: 8),
            _tecla('0'),
            const SizedBox(width: 8),
            _teclaEspecial(
              icono: Icons.backspace_rounded,
              etiqueta: 'Borrar',
              alPresionar: _borrarDigito,
            ),
          ],
        ),
      ],
    );
  }

  Widget _tecla(String numero) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: Material(
          color: const Color(0x3326292E),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _agregarDigito(numero),
            child: Center(
              child: Text(
                numero,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colores.texto,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _teclaEspecial({
    required IconData icono,
    required String etiqueta,
    required VoidCallback alPresionar,
  }) {
    return Expanded(
      child: SizedBox(
        height: 52,
        child: Material(
          color: const Color(0x22181A1E),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: alPresionar,
            child: Center(
              child: Icon(icono, size: 20, color: Colores.textoSecundario),
            ),
          ),
        ),
      ),
    );
  }
}
