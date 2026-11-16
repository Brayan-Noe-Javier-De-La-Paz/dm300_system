import 'package:flutter/material.dart';

import '../../datos/repositorios/repositorio_moto.dart';
import '../../dominio/modelos/ficha_moto.dart';
import '../../nucleo/tema/colores.dart';
import '../../nucleo/widgets/boton_oro.dart';
import '../../nucleo/widgets/panel_vidrio.dart';
import '../../nucleo/widgets/vidrio_ligero.dart';

/// Abre el asistente guiado "Ficha de mi moto" en diálogo o pantalla completa.
Future<void> mostrarAsistenteFichaMoto(
  BuildContext context, {
  RepositorioMoto? repo,
  String? claveInicial,
}) async {
  final r = repo ?? RepositorioMoto.instancia;
  final ancho = MediaQuery.of(context).size.width;

  if (ancho >= 800) {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 780),
          child: AsistenteFichaMoto(
            repo: r,
            claveInicial: claveInicial,
            alCerrar: () => Navigator.of(ctx).pop(),
          ),
        ),
      ),
    );
  } else {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colores.fondo,
          body: SafeArea(
            child: AsistenteFichaMoto(
              repo: r,
              claveInicial: claveInicial,
              alCerrar: () => Navigator.of(ctx).pop(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asistente guiado "Ficha de mi moto" (24 campos en 7 secciones)
/// Diseñado para responder 1 pregunta por pantalla sin fricción.
class AsistenteFichaMoto extends StatefulWidget {
  const AsistenteFichaMoto({
    super.key,
    this.repo,
    this.claveInicial,
    this.alCerrar,
  });

  final RepositorioMoto? repo;
  final String? claveInicial;
  final VoidCallback? alCerrar;

  @override
  State<AsistenteFichaMoto> createState() => _EstadoAsistenteFichaMoto();
}

class _EstadoAsistenteFichaMoto extends State<AsistenteFichaMoto> {
  late final RepositorioMoto _repo;
  int _indiceActual = 0;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _notaFotoCtrl;
  bool _mostrarNotaFoto = false;
  EstadoBoton _estadoBoton = EstadoBoton.normal;

  @override
  void initState() {
    super.initState();
    _repo = widget.repo ?? RepositorioMoto.instancia;
    _valorCtrl = TextEditingController();
    _notaFotoCtrl = TextEditingController();

    final campos = _repo.camposFicha;
    if (widget.claveInicial != null && campos.isNotEmpty) {
      final i = campos.indexWhere((c) => c.clave == widget.claveInicial);
      if (i != -1) _indiceActual = i;
    }
    _sincronizarControladores();
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    _notaFotoCtrl.dispose();
    super.dispose();
  }

  void _sincronizarControladores() {
    final campos = _repo.camposFicha;
    if (campos.isEmpty || _indiceActual >= campos.length) return;
    final c = campos[_indiceActual];
    _valorCtrl.text = c.valor;
    _notaFotoCtrl.text = c.notaFoto ?? '';
    _mostrarNotaFoto = (c.notaFoto != null && c.notaFoto!.isNotEmpty);
  }

  void _cambiarIndice(int nuevoIndice) {
    final campos = _repo.camposFicha;
    if (nuevoIndice < 0 || nuevoIndice >= campos.length) return;
    setState(() {
      _indiceActual = nuevoIndice;
      _estadoBoton = EstadoBoton.normal;
      _sincronizarControladores();
    });
  }

  void _irASeccion(SeccionFicha seccion) {
    final campos = _repo.camposFicha;
    final idx = campos.indexWhere((c) => c.seccion == seccion);
    if (idx != -1) _cambiarIndice(idx);
  }

  Future<void> _guardarYContinuar(EstadoCampoFicha estado) async {
    final campos = _repo.camposFicha;
    if (campos.isEmpty) return;
    final c = campos[_indiceActual];

    final val = _valorCtrl.text.trim();
    final nota = _notaFotoCtrl.text.trim();

    if (estado == EstadoCampoFicha.verificado) {
      setState(() => _estadoBoton = EstadoBoton.cargando);
    }

    await _repo.actualizarCampoFicha(
      c.clave,
      val,
      estado: estado,
      notaFoto: nota.isEmpty ? null : nota,
    );

    if (!mounted) return;

    if (estado == EstadoCampoFicha.verificado) {
      setState(() => _estadoBoton = EstadoBoton.listo);
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    if (!mounted) return;

    if (_indiceActual < campos.length - 1) {
      _cambiarIndice(_indiceActual + 1);
    } else {
      _mostrarDialogoCompletado();
    }
  }

  void _mostrarDialogoCompletado() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => AlertDialog(
        backgroundColor: Colores.vidrio,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Colores.oro),
        ),
        title: const Row(
          children: [
            Icon(Icons.stars_rounded, color: Colores.oroClaro, size: 28),
            SizedBox(width: 10),
            Text('¡Ficha completada!', style: TextStyle(color: Colores.texto, fontSize: 18)),
          ],
        ),
        content: Text(
          'Has revisado los ${_repo.totalCamposFicha} puntos clave de tu DM300. '
          'Verificados: ${_repo.camposVerificadosCount}/${_repo.totalCamposFicha}.\n\n'
          'Tus recomendaciones de refacciones y filtros ahora son más precisas.',
          style: const TextStyle(color: Colores.textoSecundario, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (widget.alCerrar != null) {
                widget.alCerrar!();
              } else {
                Navigator.of(context).maybePop();
              }
            },
            child: const Text('Aceptar', style: TextStyle(color: Colores.oroClaro, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _repo,
      builder: (context, _) {
        final campos = _repo.camposFicha;
        if (campos.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: Colores.oro),
          );
        }

        final campo = campos[_indiceActual.clamp(0, campos.length - 1)];
        final totalVerificados = _repo.camposVerificadosCount;
        final totalCampos = _repo.totalCamposFicha;
        final porcentajeVerificado = totalCampos > 0 ? (totalVerificados / totalCampos) : 0.0;

        return PanelVidrio(
          radio: 28,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra superior: Cerrar + Anillo Progreso
              _barraSuperior(porcentajeVerificado, totalVerificados, totalCampos),
              const SizedBox(height: 12),

              // Chips de las 7 Secciones
              _carruselSecciones(campo.seccion),
              const SizedBox(height: 14),

              // Tarjeta de la Pregunta Actual
              Expanded(
                child: SingleChildScrollView(
                  child: _tarjetaPregunta(campo),
                ),
              ),
              const SizedBox(height: 14),

              // Barra inferior de navegación
              _barraNavegacion(campos.length),
            ],
          ),
        );
      },
    );
  }

  Widget _barraSuperior(double porcentaje, int verificados, int total) {
    return Row(
      children: [
        // Mini anillo dorado de progreso
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: porcentaje,
                strokeWidth: 4,
                backgroundColor: const Color(0x33FFFFFF),
                color: Colores.oro,
              ),
              Center(
                child: Text(
                  '${(porcentaje * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colores.oroClaro,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ficha de mi Moto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colores.texto,
                ),
              ),
              Text(
                '$verificados de $total verificados · Pregunta ${_indiceActual + 1} de $total',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            if (widget.alCerrar != null) {
              widget.alCerrar!();
            } else {
              Navigator.of(context).maybePop();
            }
          },
          icon: const Icon(Icons.close_rounded, color: Colores.textoSecundario),
          splashRadius: 20,
        ),
      ],
    );
  }

  Widget _carruselSecciones(SeccionFicha seccionActual) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: SeccionFicha.values.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = SeccionFicha.values[i];
          final activa = s == seccionActual;
          return InkWell(
            onTap: () => _irASeccion(s),
            borderRadius: BorderRadius.circular(12),
            child: VidrioLigero(
              radio: 12,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              seleccionado: activa,
              child: Text(
                s.etiqueta,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                  color: activa ? Colores.oroClaro : Colores.textoSecundario,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _tarjetaPregunta(CampoFicha campo) {
    final estaVerificado = campo.estaVerificado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header de sección y estado actual
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colores.oro.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                campo.seccion.etiqueta.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colores.oroClaro,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: estaVerificado
                    ? Colores.ok.withValues(alpha: 0.15)
                    : Colores.aviso.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: estaVerificado
                      ? Colores.ok.withValues(alpha: 0.5)
                      : Colores.aviso.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    estaVerificado ? Icons.check_circle_rounded : Icons.schedule_rounded,
                    size: 13,
                    color: estaVerificado ? Colores.ok : Colores.aviso,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    estaVerificado ? 'Verificado en mi moto' : 'Pendiente',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: estaVerificado ? Colores.ok : Colores.aviso,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Título y Pregunta Clara
        Text(
          campo.titulo,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colores.texto,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          campo.pregunta,
          style: const TextStyle(
            fontSize: 14,
            color: Colores.textoSecundario,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),

        // Chips con Opciones Rápidas
        if (campo.opciones.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: campo.opciones.map((opc) {
              final seleccionada = _valorCtrl.text == opc;
              return ChoiceChip(
                label: Text(opc),
                selected: seleccionada,
                onSelected: (sel) {
                  setState(() {
                    _valorCtrl.text = sel ? opc : '';
                  });
                },
                selectedColor: Colores.oro,
                backgroundColor: const Color(0x3326292E),
                labelStyle: TextStyle(
                  color: seleccionada ? Colores.oroOscuro : Colores.texto,
                  fontWeight: seleccionada ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
                side: BorderSide(
                  color: seleccionada ? Colores.oro : Colores.borde,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Campo de texto para afinar o valor personalizado
        TextField(
          controller: _valorCtrl,
          style: const TextStyle(color: Colores.texto, fontSize: 15),
          decoration: InputDecoration(
            labelText: 'Valor especificado en tu moto',
            labelStyle: const TextStyle(color: Colores.textoSecundario),
            filled: true,
            fillColor: const Color(0x33181A1E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colores.borde),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colores.oro, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 14),

        // Dónde verlo en tu DM300
        VidrioLigero(
          radio: 16,
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.search_rounded,
                size: 20,
                color: Colores.oroClaro,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dónde verlo en tu DM300:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colores.oroClaro,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      campo.dondeVerlo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colores.textoSecundario,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Nota de foto o etiqueta opcional
        if (!_mostrarNotaFoto)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _mostrarNotaFoto = true),
              icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: Colores.oroClaro),
              label: const Text(
                'Adjuntar etiqueta / nota de foto',
                style: TextStyle(fontSize: 12, color: Colores.oroClaro),
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0x26181A1E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colores.borde),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.photo_camera_outlined, size: 16, color: Colores.oroClaro),
                        SizedBox(width: 6),
                        Text(
                          'Nota de foto o etiqueta',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colores.texto),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colores.textoSecundario),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() {
                        _mostrarNotaFoto = false;
                        _notaFotoCtrl.clear();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notaFotoCtrl,
                  style: const TextStyle(color: Colores.texto, fontSize: 13),
                  decoration: const InputDecoration(
                    hintText: 'Ej. Foto tomada de la placa del cilindro...',
                    hintStyle: TextStyle(color: Colores.textoSecundario, fontSize: 12),
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),

        // Botones de acción rápida: "No sé todavía" vs "Verificar en mi moto"
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _guardarYContinuar(EstadoCampoFicha.pendiente),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colores.textoSecundario,
                  side: const BorderSide(color: Colores.borde),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'No sé todavía\n(Pendiente)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: BotonOro(
                etiqueta: 'Verificar en mi moto',
                etiquetaListo: '¡Verificado!',
                icono: Icons.verified_outlined,
                estado: _estadoBoton,
                alPresionar: () => _guardarYContinuar(EstadoCampoFicha.verificado),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _barraNavegacion(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton.icon(
          onPressed: _indiceActual > 0 ? () => _cambiarIndice(_indiceActual - 1) : null,
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: const Text('Anterior'),
          style: TextButton.styleFrom(
            foregroundColor: _indiceActual > 0 ? Colores.oroClaro : Colores.sinDatos,
          ),
        ),
        Text(
          '${_indiceActual + 1} / $total',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colores.textoSecundario,
          ),
        ),
        TextButton.icon(
          onPressed: _indiceActual < total - 1 ? () => _cambiarIndice(_indiceActual + 1) : null,
          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
          label: const Text('Siguiente'),
          style: TextButton.styleFrom(
            foregroundColor: _indiceActual < total - 1 ? Colores.oroClaro : Colores.sinDatos,
          ),
        ),
      ],
    );
  }
}
