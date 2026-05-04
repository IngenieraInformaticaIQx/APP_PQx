// ─────────────────────────────────────────────────────────────────────────────
//  formulario_caso_screen.dart
//  FormularioCasoScreen  → llamado desde CapturaRxScreen
//  ProcesandoIAScreen    → llamado desde MisPlanificacionesLocalesScreen
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'planificacion_local.dart';
import 'rx_processor_service.dart';
import 'visor_caso_screen.dart';
import 'package:untitled/services/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Entry point desde CapturaRxScreen (tipoVisor + paths directos)
// ─────────────────────────────────────────────────────────────────────────────
class FormularioCasoScreen extends StatelessWidget {
  final TipoVisor tipoVisor;
  final String?   fotoPath;
  final String?   fotoLateralPath;

  const FormularioCasoScreen({
    super.key,
    required this.tipoVisor,
    this.fotoPath,
    this.fotoLateralPath,
  });

  @override
  Widget build(BuildContext context) {
    final plan = PlanificacionLocal(
      id:              DateTime.now().millisecondsSinceEpoch.toString(),
      nombrePaciente:  'Nueva planificación',
      notas:           '',
      fechaCirugia:    DateTime.now(),
      zonaImplanteId:  'tobillo',
      tipoVisor:       tipoVisor,
      fotoPath:        fotoPath,
      fotoLateralPath: fotoLateralPath,
      fechaCreacion:   DateTime.now(),
    );
    return MedicionManualMilimetricaScreen(plan: plan);
  }
}

class MedicionManualMilimetricaScreen extends StatefulWidget {
  final PlanificacionLocal plan;
  const MedicionManualMilimetricaScreen({super.key, required this.plan});

  @override
  State<MedicionManualMilimetricaScreen> createState() =>
      _MedicionManualMilimetricaScreenState();
}

class _MedicionManualMilimetricaScreenState
    extends State<MedicionManualMilimetricaScreen> {
  static const Color _purple  = Color(0xFF8E44AD);
  static const Color _purpleL = Color(0xFFCE93D8);
  static const double _bolaMm = 9.98;
  static const double _barraLongMm = 96.30;
  static const double _barraDiamMm = 7.98;

  Size? _frontalSize;
  Size? _lateralSize;
  bool _cargando = true;
  bool _procesando = false;
  String? _error;
  int _paso = 0;
  bool _usarLateral = false;
  double? _mmPorPx;
  final Map<String, List<Offset>> _puntos = {};
  final Map<String, double> _calibradoresPx = {};
  final Map<String, double> _calibradoresMmPorPx = {};
  final Set<String> _pasosSaltados = {};
  final Map<String, double> _medidasMm = {};

  List<_MedicionPaso> get _pasosManual {
    final hayLateral = _hayLateral;
    return [
      const _MedicionPaso.calibracion(
        id: 'calibracion_barra_longitud',
        titulo: 'Calibrador - barra completa',
        ayuda: 'Marca los dos extremos de la barra radiopaca vertical.',
        calibradorMm: _barraLongMm,
        opcional: true,
      ),
      const _MedicionPaso.calibracion(
        id: 'calibracion_barra_diametro',
        titulo: 'Calibrador - grosor de barra',
        ayuda: 'Marca los dos bordes del grosor de la barra.',
        calibradorMm: _barraDiamMm,
        opcional: true,
      ),
      const _MedicionPaso.calibracion(
        id: 'calibracion_bola_1',
        titulo: 'Calibrador - bola 1',
        ayuda: 'Marca el diametro de una bola metalica.',
        calibradorMm: _bolaMm,
        opcional: true,
      ),
      const _MedicionPaso.calibracion(
        id: 'calibracion_bola_2',
        titulo: 'Calibrador - bola 2',
        ayuda: 'Marca el diametro de otra bola metalica.',
        calibradorMm: _bolaMm,
        opcional: true,
      ),
      const _MedicionPaso.calibracion(
        id: 'calibracion_bola_3',
        titulo: 'Calibrador - bola 3',
        ayuda: 'Marca el diametro de la tercera bola metalica.',
        calibradorMm: _bolaMm,
        opcional: true,
      ),
      const _MedicionPaso(
        id: 'tibia_anchura_mm',
        titulo: 'Tibia - anchura',
        ayuda: 'Marca los dos bordes de la tibia distal.',
      ),
      const _MedicionPaso(
        id: 'perone_anchura_mm',
        titulo: 'Perone - anchura',
        ayuda: 'Marca los dos bordes del perone distal.',
      ),
      const _MedicionPaso(
        id: 'astragalo_anchura_mm',
        titulo: 'Astragalo - anchura',
        ayuda: 'Marca la anchura maxima del astragalo.',
      ),
      _MedicionPaso(
        id: 'astragalo_altura_mm',
        titulo: 'Astragalo - altura',
        ayuda: 'Marca la altura del astragalo; usa lateral si se ve mejor.',
        preferLateral: hayLateral,
      ),
      _MedicionPaso(
        id: 'calcaneo_longitud_mm',
        titulo: 'Calcaneo - longitud',
        ayuda: 'Marca la longitud maxima antero-posterior del calcaneo.',
        preferLateral: hayLateral,
      ),
      _MedicionPaso(
        id: 'calcaneo_altura_mm',
        titulo: 'Calcaneo - altura',
        ayuda: 'Marca la altura maxima del calcaneo.',
        preferLateral: hayLateral,
      ),
    ];
  }

  _MedicionPaso get _pasoActualManual => _pasosManual[_paso];
  bool get _hayLateral => widget.plan.fotoLateralPath != null && _lateralSize != null;
  String? get _imagenActivaPath =>
      _usarLateral ? widget.plan.fotoLateralPath : widget.plan.fotoPath;
  Size? get _imagenActivaSize => _usarLateral ? _lateralSize : _frontalSize;

  List<_MedicionPaso> get _pasosCalibracion =>
      _pasosManual.where((p) => p.esCalibracion).toList();

  String get _calibradoresLabel {
    final total = _calibradoresMmPorPx.length;
    if (total == 0) return 'pendientes';
    return '$total calibrador${total == 1 ? '' : 'es'}';
  }

  double _mediana(List<double> values) {
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  void _recalcularEscala() {
    _mmPorPx = _calibradoresMmPorPx.isEmpty
        ? null
        : _mediana(_calibradoresMmPorPx.values.toList());
  }

  List<String> get _faltantes => [
        for (final p in _pasosManual)
          if (!p.esCalibracion && !_medidasMm.containsKey(p.id)) p.titulo,
      ];

  bool get _puedeProcesar =>
      _mmPorPx != null && _faltantes.isEmpty && !_procesando;

  bool get _esUltimoPaso => _paso >= _pasosManual.length - 1;

  bool _pasoCompleto(_MedicionPaso paso) {
    if (_pasosSaltados.contains(paso.id)) return true;
    final pts = _puntos[paso.id] ?? const <Offset>[];
    if (pts.length != 2) return false;
    if (paso.esCalibracion) {
      return _calibradoresMmPorPx.containsKey(paso.id);
    }
    return _medidasMm.containsKey(paso.id);
  }

  @override
  void initState() {
    super.initState();
    _cargarImagenes();
  }

  Future<void> _cargarImagenes() async {
    try {
      if (widget.plan.fotoPath == null) {
        throw Exception('No se proporciono ninguna radiografia frontal');
      }
      final frontal = await _leerTamano(widget.plan.fotoPath!);
      Size? lateral;
      if (widget.plan.fotoLateralPath != null) {
        lateral = await _leerTamano(widget.plan.fotoLateralPath!);
      }
      if (!mounted) return;
      setState(() {
        _frontalSize = frontal;
        _lateralSize = lateral;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _cargando = false;
      });
    }
  }

  Future<Size> _leerTamano(String path) async {
    final bytes = await File(path).readAsBytes();
    final img = await decodeImageFromList(bytes);
    final size = Size(img.width.toDouble(), img.height.toDouble());
    img.dispose();
    return size;
  }

  void _irPaso(int nuevo) {
    if (nuevo > _paso && !_pasoCompleto(_pasoActualManual)) return;
    final pasos = _pasosManual;
    final idx = nuevo.clamp(0, pasos.length - 1);
    if (!pasos[idx].esCalibracion && _mmPorPx == null) return;
    setState(() {
      _paso = idx;
      _usarLateral = pasos[idx].preferLateral && _hayLateral;
    });
  }

  void _registrarPunto(Offset imagePoint) {
    final paso = _pasoActualManual;
    final pasoIndex = _paso;
    final pts = List<Offset>.from(_puntos[paso.id] ?? const []);
    if (pts.length >= 2) {
      pts.clear();
      if (paso.esCalibracion) {
        _calibradoresPx.remove(paso.id);
        _calibradoresMmPorPx.remove(paso.id);
        _pasosSaltados.remove(paso.id);
        _recalcularEscala();
        _medidasMm.clear();
      } else {
        _medidasMm.remove(paso.id);
      }
    }
    pts.add(imagePoint);
    _puntos[paso.id] = pts;

    if (pts.length == 2) {
      final distanciaPx = (pts[1] - pts[0]).distance;
      if (paso.esCalibracion) {
        _calibradoresPx[paso.id] = distanciaPx;
        _calibradoresMmPorPx[paso.id] = paso.calibradorMm! / distanciaPx;
        _pasosSaltados.remove(paso.id);
        _recalcularEscala();
        _medidasMm.clear();
      } else if (_mmPorPx != null) {
        _medidasMm[paso.id] = distanciaPx * _mmPorPx!;
      }
    }
    setState(() {});

    if (pts.length == 2 && pasoIndex < _pasosManual.length - 1) {
      Future.delayed(const Duration(milliseconds: 550), () {
        if (!mounted || _paso != pasoIndex) return;
        if (!_pasoCompleto(paso)) return;
        _irPaso(pasoIndex + 1);
      });
    }
  }

  void _limpiarPaso() {
    final paso = _pasoActualManual;
    setState(() {
      _puntos.remove(paso.id);
      if (paso.esCalibracion) {
        _calibradoresPx.remove(paso.id);
        _calibradoresMmPorPx.remove(paso.id);
        _pasosSaltados.remove(paso.id);
        _recalcularEscala();
        _medidasMm.clear();
      } else {
        _medidasMm.remove(paso.id);
      }
    });
  }

  void _saltarPasoCalibracion() {
    final paso = _pasoActualManual;
    if (!paso.esCalibracion || !paso.opcional) return;
    setState(() {
      _puntos.remove(paso.id);
      _calibradoresPx.remove(paso.id);
      _calibradoresMmPorPx.remove(paso.id);
      _pasosSaltados.add(paso.id);
      _recalcularEscala();
    });
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      _irPaso(_paso + 1);
    });
  }

  void _procesarManual() {
    if (!_puedeProcesar) return;
    HapticFeedback.mediumImpact();
    setState(() => _procesando = true);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProcesandoIAScreen(
          plan: widget.plan,
          medidasManual: Map<String, double>.from(_medidasMm),
          diagnosticoManual: {
            'metodo_calibracion': 'manual_guiado',
            'mm_por_px': _mmPorPx,
            'calibradores_px': Map<String, double>.from(_calibradoresPx),
            'calibradores_mm_por_px':
                Map<String, double>.from(_calibradoresMmPorPx),
            'calibradores_usados': _calibradoresMmPorPx.keys.toList(),
            'calibradores_saltados': _pasosSaltados.toList(),
            'medicion_manual': true,
            'longitudes_proximales_estimadas': true,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.darkText;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.bgTop, AppTheme.bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : (_error != null
                    ? _manualError(dark)
                    : Column(children: [
                        _manualHeader(dark),
                        const SizedBox(height: 14),
                        Expanded(child: _manualBody(dark)),
                      ])),
          ),
        ),
      ),
    );
  }

  Widget _manualError(Color dark) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline_rounded,
            color: Colors.redAccent, size: 44),
        const SizedBox(height: 14),
        Text(_error ?? 'Error',
            textAlign: TextAlign.center,
            style: TextStyle(color: dark, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
      ]),
    );
  }

  Widget _manualHeader(Color dark) {
    return Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.lockedCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder, width: 1.2),
          ),
          child: Icon(Icons.arrow_back_ios_new_rounded,
              color: dark, size: 18),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Medicion milimetrica',
              style: TextStyle(color: dark,
                  fontSize: 24, fontWeight: FontWeight.w800)),
          Text('Marca 2 puntos por paso; la escala sale del calibrador',
              style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
        ],
      )),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _purple.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _purple.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.straighten_rounded, color: _purple, size: 15),
          const SizedBox(width: 6),
          Text('Sin IA',
              style: TextStyle(color: _purple,
                  fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      ),
    ]);
  }

  Widget _manualBody(Color dark) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 980;
      final imagePanel = _imagePanel(dark);
      final panel = SizedBox(
        width: wide ? 390 : double.infinity,
        child: _controlPanel(dark),
      );
      return wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(flex: 7, child: imagePanel),
              const SizedBox(width: 16),
              panel,
            ])
          : Column(children: [
              Expanded(child: imagePanel),
              const SizedBox(height: 12),
              panel,
            ]);
    });
  }

  Widget _imagePanel(Color dark) {
    final path = _imagenActivaPath;
    final imageSize = _imagenActivaSize;
    if (path == null || imageSize == null) {
      return Center(child: Text('Imagen no disponible',
          style: TextStyle(color: dark)));
    }
    final pts = _puntos[_pasoActualManual.id] ?? const <Offset>[];

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: Colors.black,
        child: LayoutBuilder(builder: (context, c) {
          final size = Size(c.maxWidth, c.maxHeight);
          final rect = _imageRect(imageSize, size);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final p = _localToImage(d.localPosition, rect, imageSize);
              if (p != null) _registrarPunto(p);
            },
            child: Stack(children: [
              Positioned.fromRect(
                rect: rect,
                child: Image.file(File(path), fit: BoxFit.fill),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _MedicionPainter(
                    imageRect: rect,
                    imageSize: imageSize,
                    points: pts,
                    color: _purpleL,
                  ),
                ),
              ),
            ]),
          );
        }),
      ),
    );
  }

  Rect _imageRect(Size image, Size box) {
    final fitted = applyBoxFit(BoxFit.contain, image, box);
    return Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & box,
    );
  }

  Offset? _localToImage(Offset local, Rect rect, Size image) {
    if (!rect.contains(local)) return null;
    return Offset(
      (local.dx - rect.left) / rect.width * image.width,
      (local.dy - rect.top) / rect.height * image.height,
    );
  }

  Widget _controlPanel(Color dark) {
    final paso = _pasoActualManual;
    final pts = _puntos[paso.id] ?? const <Offset>[];
    final distanciaPx = pts.length == 2 ? (pts[1] - pts[0]).distance : null;
    final valorMedido = paso.esCalibracion
        ? _calibradoresMmPorPx[paso.id]
        : _medidasMm[paso.id];
    final pasoCompleto = _pasoCompleto(paso);
    final siguientePaso = _esUltimoPaso ? null : _pasosManual[_paso + 1];
    final puedeContinuar = pasoCompleto &&
        !_esUltimoPaso &&
        (siguientePaso!.esCalibracion || _mmPorPx != null);

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg1,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.cardBorder, width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Referencia ${_paso + 1} / ${_pasosManual.length}',
              style: TextStyle(color: AppTheme.subtitleColor,
                  fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(paso.titulo,
              style: TextStyle(color: dark,
                  fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(paso.ayuda,
              style: TextStyle(color: AppTheme.subtitleColor,
                  fontSize: 12.5, height: 1.35)),
          const SizedBox(height: 14),

          if (_hayLateral) _vistaSelector(),

          _valorBox(
            dark,
            paso.esCalibracion
                ? (valorMedido == null
                    ? 'Calibrador pendiente'
                    : '${valorMedido.toStringAsFixed(4)} mm/px')
                : (valorMedido == null
                    ? 'Medida pendiente'
                    : '${valorMedido.toStringAsFixed(1)} mm'),
            distanciaPx == null
                ? 'Puntos marcados: ${pts.length}/2'
                : (paso.esCalibracion
                    ? '${distanciaPx.toStringAsFixed(1)} px = ${paso.calibradorMm!.toStringAsFixed(2)} mm'
                    : 'Distancia: ${distanciaPx.toStringAsFixed(1)} px'),
          ),
          if (paso.esCalibracion && _mmPorPx != null) ...[
            const SizedBox(height: 8),
            Text(
              'Escala final actual: ${_mmPorPx!.toStringAsFixed(4)} mm/px con $_calibradoresLabel.',
              style: TextStyle(color: AppTheme.subtitleColor, fontSize: 11.5),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            pasoCompleto
                ? (_mmPorPx == null && siguientePaso?.esCalibracion == false
                    ? 'Necesitas medir al menos un calibrador antes de pasar a huesos.'
                    : _esUltimoPaso
                    ? 'Referencia final completada. Ya puedes generar el biomodelo.'
                    : 'Referencia guardada. Continuando con la siguiente...')
                : 'Marca el punto ${pts.length + 1} de 2 en la imagen.',
            style: TextStyle(
              color: pasoCompleto ? _purple : AppTheme.subtitleColor,
              fontSize: 11.5,
              fontWeight: pasoCompleto ? FontWeight.w700 : FontWeight.w500,
            ),
          ),

          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: pts.isEmpty ? null : _limpiarPaso,
                icon: const Icon(Icons.backspace_outlined, size: 17),
                label: const Text('Limpiar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _paso == 0 ? null : () => _irPaso(_paso - 1),
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Anterior'),
              ),
            ),
          ]),
          if (paso.esCalibracion && paso.opcional) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _saltarPasoCalibracion,
              icon: const Icon(Icons.visibility_off_outlined, size: 17),
              label: const Text('No se ve, saltar'),
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: puedeContinuar
                ? () => _irPaso(_paso + 1)
                : null,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Continuar'),
          ),

          const SizedBox(height: 16),
          _resumenMedidas(dark),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _puedeProcesar ? _procesarManual : null,
            icon: _procesando
                ? const SizedBox(
                    width: 17, height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.view_in_ar_rounded),
            label: const Text('Generar biomodelo 3D'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: _purple,
              foregroundColor: Colors.white,
            ),
          ),
          if (!_puedeProcesar && !_procesando) ...[
            const SizedBox(height: 8),
            Text(_mmPorPx == null
                ? 'Primero completa al menos un calibrador.'
                : 'Faltan: ${_faltantes.take(3).join(', ')}${_faltantes.length > 3 ? '...' : ''}',
                style: TextStyle(color: AppTheme.subtitleColor, fontSize: 11.5)),
          ],
        ]),
      ),
    );
  }

  Widget _vistaSelector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Frontal')),
          ButtonSegment(value: true, label: Text('Lateral')),
        ],
        selected: {_usarLateral},
        onSelectionChanged: (s) => setState(() => _usarLateral = s.first),
      ),
    );
  }

  Widget _valorBox(Color dark, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(children: [
        const Icon(Icons.straighten_rounded, color: _purple, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: dark,
                fontSize: 15, fontWeight: FontWeight.w800)),
            Text(subtitle, style: TextStyle(
                color: AppTheme.subtitleColor, fontSize: 11.5)),
          ],
        )),
      ]),
    );
  }

  Widget _resumenMedidas(Color dark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Resumen',
            style: TextStyle(color: dark,
                fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(_mmPorPx == null
            ? 'Calibradores: pendientes'
            : 'Escala: ${_mmPorPx!.toStringAsFixed(4)} mm/px ($_calibradoresLabel)',
            style: TextStyle(color: AppTheme.subtitleColor, fontSize: 11.5)),
        const SizedBox(height: 6),
        for (final p in _pasosCalibracion)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              _pasosSaltados.contains(p.id)
                  ? '${p.titulo}: saltado'
                  : '${p.titulo}: ${_calibradoresPx[p.id]?.toStringAsFixed(1) ?? '--'} px',
              style: TextStyle(color: AppTheme.subtitleColor2, fontSize: 11.5),
            ),
          ),
        const SizedBox(height: 6),
        for (final p in _pasosManual.where((p) => !p.esCalibracion))
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '${p.titulo}: ${_medidasMm[p.id]?.toStringAsFixed(1) ?? '--'} mm',
              style: TextStyle(color: AppTheme.subtitleColor2, fontSize: 11.5),
            ),
          ),
      ]),
    );
  }
}

class _MedicionPaso {
  final String id;
  final String titulo;
  final String ayuda;
  final bool preferLateral;
  final bool esCalibracion;
  final double? calibradorMm;
  final bool opcional;

  const _MedicionPaso({
    required this.id,
    required this.titulo,
    required this.ayuda,
    this.preferLateral = false,
  })  : esCalibracion = false,
        calibradorMm = null,
        opcional = false;

  const _MedicionPaso.calibracion({
    required this.id,
    required this.titulo,
    required this.ayuda,
    required this.calibradorMm,
    this.opcional = false,
  })  : preferLateral = false,
        esCalibracion = true;
}

class _MedicionPainter extends CustomPainter {
  final Rect imageRect;
  final Size imageSize;
  final List<Offset> points;
  final Color color;

  const _MedicionPainter({
    required this.imageRect,
    required this.imageSize,
    required this.points,
    required this.color,
  });

  Offset _toScreen(Offset p) => Offset(
        imageRect.left + p.dx / imageSize.width * imageRect.width,
        imageRect.top + p.dy / imageSize.height * imageRect.height,
      );

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final halo = Paint()
      ..color = Colors.black.withOpacity(0.45)
      ..style = PaintingStyle.fill;

    if (points.length == 2) {
      canvas.drawLine(_toScreen(points[0]), _toScreen(points[1]), stroke);
    }
    for (final p in points) {
      final s = _toScreen(p);
      canvas.drawCircle(s, 8, halo);
      canvas.drawCircle(s, 5, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _MedicionPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.imageRect != imageRect ||
      oldDelegate.imageSize != imageSize;
}

// ─────────────────────────────────────────────────────────────────────────────
//  ProcesandoIAScreen — pantalla de procesado IA
// ─────────────────────────────────────────────────────────────────────────────
class ProcesandoIAScreen extends StatefulWidget {
  final PlanificacionLocal plan;
  final Map<String, double>? medidasManual;
  final Map<String, dynamic> diagnosticoManual;
  const ProcesandoIAScreen({
    super.key,
    required this.plan,
    this.medidasManual,
    this.diagnosticoManual = const {},
  });

  @override
  State<ProcesandoIAScreen> createState() => _ProcesandoIAScreenState();
}

class _ProcesandoIAScreenState extends State<ProcesandoIAScreen>
    with TickerProviderStateMixin {
  static const Map<String, String> _fallbackGlbUrls = {
    'tibia':
        'https://profesional.planificacionquirurgica.com/3D/Tabal/Biomodelo/Tibia.glb',
    'perone':
        'https://profesional.planificacionquirurgica.com/3D/Tabal/Biomodelo/Perone.glb',
    'astragalo':
        'https://profesional.planificacionquirurgica.com/3D/Tabal/Biomodelo/Astragalo.glb',
    'calcaneo':
        'https://profesional.planificacionquirurgica.com/3D/Tabal/Biomodelo/Calcaneo.glb',
  };

  // ── Animaciones ──────────────────────────────────────────────────────────────
  late AnimationController _bgController;
  late AnimationController _headerController;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;
  late AnimationController _pulseController;
  late AnimationController _iconoController;
  late AnimationController _entradaController;
  late Animation<double>   _entradaFade;
  late Animation<Offset>   _entradaSlide;

  // ── Estado ───────────────────────────────────────────────────────────────────
  static const _pasos = [
    'Preparando radiografías',
    'Analizando radiografías con IA',
    'Midiendo huesos en mm',
    'Descargando modelos base',
    'Escalando modelos 3D',
    'Finalizando',
  ];

  int    _pasoActual   = 0;
  bool   _error        = false;
  String _mensajeError = '';
  Timer? _pasoTimer;

  // Estado del panel de confianza (se muestra entre el procesado y el visor).
  RxProcessorResult? _resultadoListo;
  CasoMedico?        _casoPreparado;
  List<String>       _huesosSinReescalado = const [];

  bool get _modoManual => widget.medidasManual != null;

  List<String> get _pasosActivos => _modoManual
      ? const [
          'Validando medidas manuales',
          'Calculando escala milimétrica',
          'Descargando modelos base',
          'Escalando modelos 3D',
          'Finalizando',
        ]
      : _pasos;

  static const Color _purple  = Color(0xFF8E44AD);
  static const Color _purpleL = Color(0xFFCE93D8);

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);

    _bgController = AnimationController(
        duration: const Duration(seconds: 20), vsync: this)..repeat();

    _headerController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _headerFade  = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));

    _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1800), vsync: this)..repeat();

    _iconoController = AnimationController(
        duration: const Duration(seconds: 5), vsync: this)..repeat();

    _entradaController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _entradaFade  = CurvedAnimation(parent: _entradaController, curve: Curves.easeOut);
    _entradaSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entradaController, curve: Curves.easeOutCubic));

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entradaController.forward();
    });
    _procesarFoto();
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    _bgController.dispose();
    _headerController.dispose();
    _pulseController.dispose();
    _iconoController.dispose();
    _entradaController.dispose();
    _pasoTimer?.cancel();
    super.dispose();
  }

  // ── Procesado local con Gemini + escala GLB ───────────────────────────────

  Future<void> _navegarAlVisorConResult(RxProcessorResult result) async {
    if (!mounted) return;

    const orden   = ['tibia', 'perone', 'astragalo', 'calcaneo'];
    const nombres = {
      'tibia':     'Tibia',
      'perone':    'Peroné',
      'astragalo': 'Astrágalo',
      'calcaneo':  'Calcáneo',
    };

    final dir = await getTemporaryDirectory();
    final List<GlbArchivo> biomodelos = [];
    final List<String> huesosSinReescalado = [];

    for (final hueso in orden) {
      final bytes = result.glbBytes[hueso];
      if (bytes == null) {
        huesosSinReescalado.add(hueso);
        continue;
      }
      final file = File('${dir.path}/biomodelo_${widget.plan.id}_$hueso.glb');
      await file.writeAsBytes(bytes);
      biomodelos.add(GlbArchivo(
        nombre:  nombres[hueso] ?? hueso,
        archivo: '$hueso.glb',
        url:     file.path,
        tipo:    'biomodelo',
      ));
    }

    // Si el procesado IA no devuelve algún hueso (o falla completo),
    // completar con GLB base remoto para no arrancar el visor sin biomodelos.
    final Set<String> yaIncluidos = biomodelos
        .map((b) => b.archivo.replaceAll('.glb', '').toLowerCase())
        .toSet();
    for (final hueso in orden) {
      if (yaIncluidos.contains(hueso)) continue;
      final fallbackUrl = _fallbackGlbUrls[hueso];
      if (fallbackUrl == null || fallbackUrl.isEmpty) continue;
      biomodelos.add(GlbArchivo(
        nombre: nombres[hueso] ?? hueso,
        archivo: '$hueso.glb',
        url: fallbackUrl,
        tipo: 'biomodelo',
      ));
    }

    if (!mounted) return;

    final catalogo = await _cargarCatalogoImplantesRx();

    final caso = CasoMedico(
      id:         widget.plan.id,
      nombre:     widget.plan.nombrePaciente,
      paciente:   widget.plan.nombrePaciente,
      fechaOp:    widget.plan.fechaCirugia.toIso8601String(),
      estado:     'pendiente',
      biomodelos: biomodelos,
      placas:     catalogo.$1,
      tornillos:  catalogo.$2,
    );

    if (!mounted) return;
    setState(() {
      _resultadoListo      = result;
      _casoPreparado       = caso;
      _huesosSinReescalado = huesosSinReescalado;
    });
  }

  void _continuarAlVisor() {
    final caso = _casoPreparado;
    if (caso == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VisorCasoScreen(
          caso:       caso,
          autoCargar: true,
          planLocal:  widget.plan,
        ),
      ),
    );
  }

  Future<void> _remedirRadiografia() async {
    HapticFeedback.mediumImpact();
    if (_modoManual) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MedicionManualMilimetricaScreen(plan: widget.plan),
        ),
      );
      return;
    }
    await RxProcessorService.limpiarCacheGemini();
    if (!mounted) return;
    setState(() {
      _resultadoListo      = null;
      _casoPreparado       = null;
      _huesosSinReescalado = const [];
      _pasoActual          = 0;
    });
    await _procesarFoto();
  }

  Future<(List<GrupoPlagas>, List<GrupoTornillos>)> _cargarCatalogoImplantesRx() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('login_email') ?? '';
      final pass = prefs.getString('login_password') ?? '';
      if (email.isEmpty || pass.isEmpty) {
        return (const <GrupoPlagas>[], const <GrupoTornillos>[]);
      }

      final cred = base64Encode(utf8.encode('$email:$pass'));
      final response = await http.get(
        Uri.parse('https://profesional.planificacionquirurgica.com/listar_visores_genericos.php'),
        headers: {'Authorization': 'Basic $cred'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return (const <GrupoPlagas>[], const <GrupoTornillos>[]);
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic> || data['success'] != true) {
        return (const <GrupoPlagas>[], const <GrupoTornillos>[]);
      }

      final visores = (data['visores'] as List? ?? [])
          .map((e) => CasoMedico.fromJson(e as Map<String, dynamic>))
          .toList();

      if (visores.isEmpty) {
        return (const <GrupoPlagas>[], const <GrupoTornillos>[]);
      }

      final casoCatalogo = visores.firstWhere(
        (c) => c.nombre.toLowerCase().contains('tabal'),
        orElse: () => visores.first,
      );

      return (casoCatalogo.placas, casoCatalogo.tornillos);
    } catch (_) {
      return (const <GrupoPlagas>[], const <GrupoTornillos>[]);
    }
  }

  void _animarEspera() {
    int idx = 0;
    _pasoTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (!mounted) { t.cancel(); return; }
      if (idx < _pasosActivos.length - 2) {
        idx++;
        setState(() => _pasoActual = idx);
      }
    });
  }

  Future<void> _procesarFoto() async {
    if (widget.plan.fotoPath == null) {
      setState(() {
        _error        = true;
        _mensajeError = 'No se proporcionó ninguna radiografía';
      });
      return;
    }

    setState(() { _pasoActual = 0; _error = false; _mensajeError = ''; });
    _animarEspera();

    try {
      final RxProcessorResult result;
      if (_modoManual) {
        result = await RxProcessorService.procesarMedidasManual(
          medidas: widget.medidasManual!,
          diagnosticoManual: widget.diagnosticoManual,
        );
      } else {
        final frontalBytes = await File(widget.plan.fotoPath!).readAsBytes();
        Uint8List? lateralBytes;
        if (widget.plan.fotoLateralPath != null) {
          lateralBytes = await File(widget.plan.fotoLateralPath!).readAsBytes();
        }

        result = await RxProcessorService.procesar(
          frontalImage: frontalBytes,
          lateralImage: lateralBytes,
        );
      }

      if (!mounted) return;

      _pasoTimer?.cancel();
      setState(() => _pasoActual = _pasosActivos.length - 1);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      await _navegarAlVisorConResult(result);

    } catch (e) {
      if (!mounted) return;
      _pasoTimer?.cancel();
      setState(() {
        _error        = true;
        _mensajeError = e.toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Error backend: ', '');
      });
    }
  }

  void _reintentar() {
    _pasoTimer?.cancel();
    if (!mounted) return;
    Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bgTop = AppTheme.bgTop;
    final bgBot = AppTheme.bgBottom;
    final dark  = AppTheme.darkText;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [

        // Fondo
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgTop, bgBot],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Orbe superior
        Positioned(top: -80, right: -60,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: _bgController.value * 2 * math.pi,
              child: Container(width: 320, height: 320,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _purple.withOpacity(0.15), Colors.transparent])))))),

        // Orbe inferior
        Positioned(bottom: 60, left: -80,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: -_bgController.value * 2 * math.pi,
              child: Container(width: 280, height: 280,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _purple.withOpacity(0.09), Colors.transparent])))))),

        SafeArea(
          child: Column(children: [

            // ── Header ────────────────────────────────────────────────────────
            SlideTransition(position: _headerSlide,
              child: FadeTransition(opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(children: [
                    _glassBtn(Icons.arrow_back_ios_new_rounded,
                        () => Navigator.pop(context)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _error
                              ? 'Error en el proceso'
                              : (_resultadoListo != null
                                  ? 'Análisis completado'
                                  : (_modoManual
                                      ? 'Aplicando medidas'
                                      : 'Procesando IA')),
                          style: TextStyle(color: dark, fontSize: 24,
                              fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        Text(
                          _error
                              ? 'Algo salió mal'
                              : (_resultadoListo != null
                                  ? 'Revisa la calidad antes de continuar'
                                  : (_modoManual
                                      ? 'Escalando biomodelos en milímetros'
                                      : 'Generando modelo 3D del tobillo')),
                          style: TextStyle(
                              color: AppTheme.subtitleColor, fontSize: 12),
                        ),
                      ],
                    )),
                    if (!_error && _resultadoListo == null)
                      _modoManual ? _badgeManual() : _badgeIA(),
                  ]),
                ),
              ),
            ),

            // ── Cuerpo ────────────────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _entradaFade,
                child: SlideTransition(
                  position: _entradaSlide,
                  child: _error
                      ? _buildError()
                      : (_resultadoListo != null
                          ? _buildConfianza(_resultadoListo!)
                          : _buildProcesando()),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Pantalla de procesado ─────────────────────────────────────────────────────

  Widget _buildProcesando() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(children: [

        // Animación central
        SizedBox(
          width: 200, height: 200,
          child: Stack(alignment: Alignment.center, children: [

            // Anillos de pulso
            ...List.generate(3, (i) => AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final delay = i / 3.0;
                final t = ((_pulseController.value - delay) % 1.0).abs();
                return Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0) * 0.55,
                  child: Container(
                    width:  55 + t * 135,
                    height: 55 + t * 135,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _purple.withOpacity(0.55 * (1 - t)),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            )),

            // Card central con icono
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(colors: [
                      AppTheme.cardBg1,
                      _purple.withOpacity(0.18),
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(
                        color: _purple.withOpacity(0.40), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _purple.withOpacity(0.28),
                        blurRadius: 28, offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _iconoController,
                    builder: (_, __) => Transform.rotate(
                      angle: math.sin(_iconoController.value * 2 * math.pi) * 0.18,
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: _purple, size: 42),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 28),

        // Card de pasos
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.cardBg1,
                  AppTheme.cardBg2,
                  _purple.withOpacity(0.05),
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cardBorder, width: 1.3),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withOpacity(0.08),
                    blurRadius: 20, offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: List.generate(_pasosActivos.length, (i) {
                  final done    = i < _pasoActual;
                  final current = i == _pasoActual;

                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: i < _pasosActivos.length - 1 ? 14 : 0),
                    child: Row(children: [

                      // Indicador circular
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? _purple
                              : current
                                  ? _purple.withOpacity(0.15)
                                  : AppTheme.isDark.value
                                      ? Colors.white.withOpacity(0.07)
                                      : Colors.black.withOpacity(0.05),
                          border: current
                              ? Border.all(
                                  color: _purple.withOpacity(0.50), width: 1.5)
                              : null,
                        ),
                        child: done
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : current
                                ? AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (_, __) => Center(
                                      child: Container(
                                        width: 9, height: 9,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _purple.withOpacity(
                                              0.55 + _pulseController.value * 0.45),
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                      ),

                      const SizedBox(width: 14),

                      // Texto del paso
                      Expanded(
                        child: Text(
                          _pasosActivos[i],
                          style: TextStyle(
                            color: done
                                ? AppTheme.darkText
                                : current
                                    ? _purple
                                    : AppTheme.subtitleColor2,
                            fontSize: 13.5,
                            fontWeight: (done || current)
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),

                      if (done && i == _pasosActivos.length - 1)
                        const Icon(Icons.star_rounded, color: _purple, size: 15),
                    ]),
                  );
                }),
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Barra de progreso
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_pasoActual + 1) / _pasosActivos.length,
            backgroundColor: AppTheme.isDark.value
                ? Colors.white.withOpacity(0.09)
                : Colors.black.withOpacity(0.07),
            valueColor: const AlwaysStoppedAnimation<Color>(_purple),
            minHeight: 4,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Paso ${_pasoActual + 1} de ${_pasosActivos.length}',
          style: TextStyle(
              color: AppTheme.subtitleColor,
              fontSize: 12, fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 20),

        // Nota informativa
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: _purple.withOpacity(0.60), size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _modoManual
                        ? 'El escalado local puede tardar unos segundos.\nNo cierres la aplicación.'
                        : 'El análisis con IA puede tardar hasta 1 minuto.\nNo cierres la aplicación.',
                    style: TextStyle(
                        color: AppTheme.subtitleColor,
                        fontSize: 12, height: 1.45),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Panel de confianza (entre procesado y visor) ─────────────────────────
  // Stub mínimo funcional: muestra la confianza y deja continuar al visor o
  // re-medir limpiando la caché. Diseño detallado pendiente.
  Widget _buildConfianza(RxProcessorResult result) {
    final dark = AppTheme.darkText;

    Color colorConfianza() {
      switch (result.confianza) {
        case 'alta':  return Colors.green;
        case 'media': return Colors.amber;
        default:      return Colors.redAccent;
      }
    }

    final discrepancias = (result.diagnostico['discrepancias'] as List?) ?? const [];
    final bolaCv  = (result.diagnostico['bola_cv'] as num?)?.toDouble();
    final bolas   = (result.diagnostico['bolas_detectadas'] as num?)?.toInt();
    final factores = result.diagnostico['factores_escala'] as Map?;
    final fiabilidadRaw = result.diagnostico['fiabilidad_pct'];
    final fiabilidadPct = fiabilidadRaw is num
        ? fiabilidadRaw.clamp(0, 100).round()
        : (result.confianza == 'alta' ? 92 : result.confianza == 'media' ? 72 : 46);
    final fiabilidad = fiabilidadPct / 100.0;
    final cvPasadas = (result.diagnostico['cv_pasadas'] as num?)?.toDouble();
    final metodoCalibracion = result.diagnostico['metodo_calibracion']?.toString();
    final barraLongPxRaw =
        (result.diagnostico['barra_calibracion_longitud_px'] as num?)?.toDouble();
    final barraLongPx =
        barraLongPxRaw != null && barraLongPxRaw > 0 ? barraLongPxRaw : null;
    final calibradorManualPx =
        (result.diagnostico['calibrador_px'] as num?)?.toDouble();
    final calibradorManualMm =
        (result.diagnostico['calibrador_mm'] as num?)?.toDouble();
    final calibradoresPx = result.diagnostico['calibradores_px'] as Map?;
    final calibradoresMmPorPx =
        result.diagnostico['calibradores_mm_por_px'] as Map?;
    final calibracionEstimada = result.diagnostico['calibracion_estimada'] == true;
    final escalaAnatomicaCv =
        (result.diagnostico['escala_anatomica_cv'] as num?)?.toDouble();
    final escalaAnatomicaRefs =
        (result.diagnostico['escala_anatomica_referencias'] as num?)?.toInt();
    final medidasRellenadas =
        (result.diagnostico['medidas_rellenadas'] as List?) ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Pill de confianza
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: colorConfianza().withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorConfianza().withOpacity(0.45)),
          ),
          child: Row(children: [
            Icon(Icons.verified_rounded, color: colorConfianza(), size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Confianza: ${result.confianza.toUpperCase()} · ${result.metodoEscala}',
              style: TextStyle(color: dark,
                  fontSize: 13, fontWeight: FontWeight.w700),
            )),
          ]),
        ),
        const SizedBox(height: 14),

        // Métricas
        Row(children: [
          Expanded(child: Text('Fiabilidad',
              style: TextStyle(color: dark.withOpacity(0.72),
                  fontSize: 12, fontWeight: FontWeight.w700))),
          Text('$fiabilidadPct%',
              style: TextStyle(color: colorConfianza(),
                  fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fiabilidad,
            minHeight: 11,
            backgroundColor: dark.withOpacity(0.10),
            valueColor: AlwaysStoppedAnimation<Color>(colorConfianza()),
          ),
        ),
        const SizedBox(height: 14),

        if (bolas != null || bolaCv != null || cvPasadas != null)
          _confCard(dark, 'Calibración', [
            if (bolas != null) 'Bolas detectadas: $bolas / 3',
            if (bolaCv != null) 'Dispersión bolas: ${(bolaCv * 100).toStringAsFixed(1)} %',
          ]),
        if (cvPasadas != null)
          _confCard(dark, 'Variacion de medicion IA', [
            'CV entre pasadas: ${(cvPasadas * 100).toStringAsFixed(1)} %',
          ]),
        if (metodoCalibracion != null ||
            barraLongPx != null ||
            calibradorManualPx != null ||
            (calibradoresPx != null && calibradoresPx.isNotEmpty))
          _confCard(dark,
              calibracionEstimada ? 'Metodo de escala' : 'Calibrador usado', [
            if (metodoCalibracion != null) 'Metodo: $metodoCalibracion',
            if (barraLongPx != null) 'Barra: ${barraLongPx.toStringAsFixed(1)} px',
            if (calibradorManualPx != null && calibradorManualMm != null)
              'Calibrador: ${calibradorManualPx.toStringAsFixed(1)} px = ${calibradorManualMm.toStringAsFixed(2)} mm',
            if (calibradoresPx != null)
              for (final e in calibradoresPx.entries)
                '${e.key}: ${(e.value as num).toStringAsFixed(1)} px'
                    '${calibradoresMmPorPx?[e.key] is num ? ' (${(calibradoresMmPorPx![e.key] as num).toStringAsFixed(4)} mm/px)' : ''}',
          ]),
        if (calibracionEstimada ||
            escalaAnatomicaCv != null ||
            escalaAnatomicaRefs != null)
          _confCard(dark, 'Escala estimada', [
            'Sin calibrador fisico visible',
            if (escalaAnatomicaRefs != null)
              'Referencias anatomicas: $escalaAnatomicaRefs',
            if (escalaAnatomicaCv != null)
              'Dispersion escala: ${(escalaAnatomicaCv * 100).toStringAsFixed(1)} %',
          ], accent: Colors.amber),
        if (medidasRellenadas.isNotEmpty)
          _confCard(dark, 'Medidas estimadas', [
            medidasRellenadas.map((e) => e.toString()).join(', '),
          ], accent: Colors.amber),
        if (factores != null && factores.isNotEmpty)
          _confCard(dark, 'Factores de escala', [
            for (final e in factores.entries)
              '${e.key}: ×${(e.value as num).toStringAsFixed(3)}',
          ]),
        if (discrepancias.isNotEmpty)
          _confCard(dark, 'Discrepancias frontal/lateral',
              discrepancias.map((e) => e.toString()).toList(),
              accent: Colors.amber),
        if (_huesosSinReescalado.isNotEmpty)
          _confCard(dark, 'Huesos sin reescalado',
              [_huesosSinReescalado.join(', ')], accent: Colors.amber),
        if (result.errores.isNotEmpty)
          _confCard(dark, 'Avisos', result.errores, accent: Colors.redAccent),

        const SizedBox(height: 18),

        // Botón continuar
        GestureDetector(
          onTap: _continuarAlVisor,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: const LinearGradient(
                colors: [_purple, _purpleL],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(
                color: _purple.withOpacity(0.32),
                blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Abrir visor 3D',
                  style: TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
        const SizedBox(height: 10),

        // Re-medir
        TextButton.icon(
          onPressed: _remedirRadiografia,
          icon: Icon(Icons.refresh_rounded, color: _purple, size: 18),
          label: Text(_modoManual ? 'Volver a medir' : 'Re-medir con IA',
              style: TextStyle(color: _purple, fontWeight: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Volver a las fotos',
              style: TextStyle(color: AppTheme.subtitleColor, fontSize: 13)),
        ),
      ]),
    );
  }

  Widget _confCard(Color dark, String titulo, List<String> lineas,
      {Color? accent}) {
    final c = accent ?? _purple;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: TextStyle(color: c,
              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          for (final l in lineas)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(l, style: TextStyle(color: dark.withOpacity(0.85),
                  fontSize: 12.5, height: 1.4)),
            ),
        ],
      ),
    );
  }

  // ── Pantalla de error ─────────────────────────────────────────────────────────

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // Icono error
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(colors: [
                    AppTheme.cardBg1,
                    Colors.red.withOpacity(0.12),
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(
                      color: Colors.red.withOpacity(0.32), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.12),
                      blurRadius: 24, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 42),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Tarjeta de mensaje
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppTheme.cardBg1,
                    Colors.red.withOpacity(0.05),
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: Colors.red.withOpacity(0.20), width: 1.2),
                ),
                child: Column(children: [
                  Text('No se pudo procesar',
                      style: TextStyle(
                          color: AppTheme.darkText,
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(
                    _mensajeError.isNotEmpty
                        ? _mensajeError
                        : 'Error desconocido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.subtitleColor,
                        fontSize: 13.5, height: 1.5),
                  ),
                ]),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Botón reintentar
          GestureDetector(
            onTap: _reintentar,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: const LinearGradient(
                  colors: [_purple, _purpleL],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withOpacity(0.35),
                    blurRadius: 18, offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 21),
                  SizedBox(width: 9),
                  Text('Reintentar',
                      style: TextStyle(color: Colors.white,
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(
                    color: AppTheme.subtitleColor, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ── Widgets auxiliares ────────────────────────────────────────────────────────

  Widget _badgeIA() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withOpacity(0.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: _purple,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: _purple.withOpacity(0.45 + _pulseController.value * 0.55),
                blurRadius: 5,
              )],
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text('IA activa',
            style: TextStyle(color: _purple,
                fontSize: 8.5, fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
      ]),
    );
  }

  Widget _badgeManual() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withOpacity(0.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.straighten_rounded, color: _purple, size: 13),
        const SizedBox(width: 5),
        Text('MM manual',
            style: TextStyle(color: _purple,
                fontSize: 8.5, fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
      ]),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.lockedCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder, width: 1.2),
          ),
          child: Icon(icon, color: AppTheme.darkText, size: 18),
        ),
      ),
    ),
  );
}
