// ─────────────────────────────────────────────────────────────────────────────
//  captura_rx_screen.dart
//  Pantalla de captura de 2 radiografías (Frontal + Lateral)
//  antes de pasar al FormularioCasoScreen → ProcesandoIAScreen.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'formulario_caso_screen.dart';
import 'planificacion_local.dart';
import 'package:untitled/services/app_theme.dart';

class CapturaRxScreen extends StatefulWidget {
  const CapturaRxScreen({super.key});

  @override
  State<CapturaRxScreen> createState() => _CapturaRxScreenState();
}

class _CapturaRxScreenState extends State<CapturaRxScreen>
    with TickerProviderStateMixin {

  static const Color _purple  = Color(0xFF8E44AD);
  static const Color _purpleL = Color(0xFFCE93D8);

  // El procesador (Gemini) trabaja bien con ~2K en el lado largo;
  // limitar evita base64 multi-MB en móviles y rotaciones HEIC pesadas.
  static const double _maxImageDimension = 2200;
  static const int    _imageQuality      = 88;

  late final AnimationController _bgController;
  late final AnimationController _headerController;
  late final Animation<double>   _headerFade;
  late final Animation<Offset>   _headerSlide;

  final ImagePicker _picker = ImagePicker();
  final GlobalKey   _lateralKey = GlobalKey();

  String? _fotoFrontalPath;
  String? _fotoLateralPath;
  bool    _abriendoCamara = false;
  bool    _continuando    = false;

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);
    _bgController = AnimationController(
        duration: const Duration(seconds: 20), vsync: this)..repeat();
    _headerController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _headerFade  = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));
    _headerController.forward();
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    _bgController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  // ── Captura ────────────────────────────────────────────────────────────────
  Future<void> _capturar(bool esFrontal, ImageSource source) async {
    if (_abriendoCamara) return;
    setState(() => _abriendoCamara = true);
    HapticFeedback.selectionClick();

    XFile? foto;
    try {
      foto = await _picker.pickImage(
        source: source,
        imageQuality: _imageQuality,
        maxWidth: _maxImageDimension,
        maxHeight: _maxImageDimension,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      if (mounted) {
        _toast(source == ImageSource.camera
            ? 'No se pudo abrir la cámara. Revisa los permisos.'
            : 'No se pudo abrir la galería.');
      }
    } finally {
      if (mounted) setState(() => _abriendoCamara = false);
    }

    if (foto == null || !mounted) return;
    if (!await File(foto.path).exists()) {
      _toast('La imagen no se pudo guardar.');
      return;
    }

    HapticFeedback.lightImpact();
    // Limpia caché previa para que el thumbnail refresque al re-tomar.
    PaintingBinding.instance.imageCache.evict(FileImage(File(foto.path)));

    setState(() {
      if (esFrontal) {
        _fotoFrontalPath = foto!.path;
      } else {
        _fotoLateralPath = foto!.path;
      }
    });

    // Tras capturar la frontal, ofrece visualmente la lateral.
    if (esFrontal && _fotoLateralPath == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _lateralKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            alignment: 0.2,
          );
        }
      });
    }
  }

  void _eliminar(bool esFrontal) {
    HapticFeedback.selectionClick();
    setState(() {
      if (esFrontal) {
        _fotoFrontalPath = null;
      } else {
        _fotoLateralPath = null;
      }
    });
  }

  Future<void> _elegirFuente(bool esFrontal) async {
    if (_abriendoCamara) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SourceSheet(purple: _purple),
    );
    if (source == null || !mounted) return;
    await _capturar(esFrontal, source);
  }

  Future<void> _continuar() async {
    if (_fotoFrontalPath == null || _continuando) return;
    if (!await File(_fotoFrontalPath!).exists()) {
      _toast('La radiografía frontal ya no existe. Vuelve a capturarla.');
      setState(() => _fotoFrontalPath = null);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _continuando = true);
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => FormularioCasoScreen(
        tipoVisor:        TipoVisor.radiografia,
        fotoPath:         _fotoFrontalPath,
        fotoLateralPath:  _fotoLateralPath,
      ),
    ));
  }

  void _previsualizar(String path) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _FullscreenPreview(path: path),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _purple,
        duration: const Duration(seconds: 3),
      ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bgTop = AppTheme.bgTop;
    final bgBot = AppTheme.bgBottom;
    final dark  = AppTheme.darkText;

    final hasFrontal = _fotoFrontalPath != null;
    final hasLateral = _fotoLateralPath != null;

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

        // Orbes
        Positioned(top: -80, right: -60, child: _orbe(300, 0.13, reverse: false)),
        Positioned(bottom: 60, left: -80, child: _orbe(260, 0.08, reverse: true)),

        SafeArea(
          child: Column(children: [
            // Header
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
                        Text('Radiografías',
                            style: TextStyle(color: dark, fontSize: 26,
                                fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        Text('Fotografía las radiografías del paciente',
                            style: TextStyle(color: AppTheme.subtitleColor,
                                fontSize: 12)),
                      ],
                    )),
                    _badgeIA(),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 18),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const BouncingScrollPhysics(),
                child: Column(children: [
                  _infoBox(dark),
                  const SizedBox(height: 12),
                  _tipsBox(),
                  const SizedBox(height: 18),

                  _buildCapturaCard(
                    esFrontal: true,
                    path: _fotoFrontalPath,
                    titulo: 'Vista Frontal',
                    subtitulo: 'Proyección AP (anteroposterior)',
                    obligatoria: true,
                  ),
                  const SizedBox(height: 14),

                  KeyedSubtree(
                    key: _lateralKey,
                    child: _buildCapturaCard(
                      esFrontal: false,
                      path: _fotoLateralPath,
                      titulo: 'Vista Lateral',
                      subtitulo: 'Mejora la precisión del modelo 3D',
                      obligatoria: false,
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildContinuarBtn(hasFrontal, hasLateral),
                  const SizedBox(height: 8),
                  Text(
                    !hasFrontal
                        ? 'La vista frontal es obligatoria'
                        : (hasLateral
                            ? 'Listo para generar el modelo 3D'
                            : 'Añadir lateral mejora la precisión'),
                    style: TextStyle(
                        color: AppTheme.subtitleColor2,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ]),
        ),

        // Spinner mientras se abre la cámara/galería
        if (_abriendoCamara && !_continuando)
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _purple.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: const [
                      SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Abriendo cámara…',
                          style: TextStyle(color: Colors.white,
                              fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
            ),
          ),

        // Overlay de transición a IA
        if (_continuando)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: AppTheme.cardBg1.withOpacity(0.6),
                child: Center(child: CircularProgressIndicator(
                    color: _purple, strokeWidth: 2.5)),
              ),
            ),
          ),
      ]),
    );
  }

  // ── Widgets internos ─────────────────────────────────────────────────────
  Widget _orbe(double size, double opacity, {required bool reverse}) =>
      AnimatedBuilder(
        animation: _bgController,
        builder: (_, __) => Transform.rotate(
          angle: (reverse ? -1 : 1) * _bgController.value * 2 * math.pi,
          child: Container(width: size, height: size,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _purple.withOpacity(opacity), Colors.transparent]))),
        ),
      );

  Widget _badgeIA() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _purple.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _purple.withOpacity(0.28)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6,
            decoration: BoxDecoration(color: _purple,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: _purple.withOpacity(0.6), blurRadius: 4)])),
          const SizedBox(width: 5),
          Text('PQx vision', style: TextStyle(color: _purple,
              fontSize: 8.5, fontWeight: FontWeight.w800,
              letterSpacing: 1.2)),
        ]),
      );

  Widget _infoBox(Color dark) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg1,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(children: [
              Icon(Icons.auto_awesome_rounded, color: _purple, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(
                'La IA analizará ambas vistas para generar un modelo 3D '
                'personalizado del tobillo.',
                style: TextStyle(color: dark.withOpacity(0.65),
                    fontSize: 12.5, height: 1.4),
              )),
            ]),
          ),
        ),
      );

  Widget _tipsBox() => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.cardBg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.cardBorder.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tipRow(Icons.crop_free_rounded,
                    'Encuadra la radiografía completa, sin recortar bordes.'),
                const SizedBox(height: 6),
                _tipRow(Icons.wb_sunny_outlined,
                    'Luz uniforme, sin reflejos sobre la placa.'),
                const SizedBox(height: 6),
                _tipRow(Icons.straighten_rounded,
                    'Cámara perpendicular y nivelada al negatoscopio.'),
              ],
            ),
          ),
        ),
      );

  Widget _tipRow(IconData icon, String text) => Row(children: [
        Icon(icon, color: _purple.withOpacity(0.85), size: 14),
        const SizedBox(width: 8),
        Expanded(child: Text(text,
            style: TextStyle(
                color: AppTheme.subtitleColor, fontSize: 11.5, height: 1.3))),
      ]);

  Widget _buildCapturaCard({
    required bool esFrontal,
    required String? path,
    required String titulo,
    required String subtitulo,
    required bool obligatoria,
  }) {
    final bool capturada = path != null;
    final dark = AppTheme.darkText;

    return Semantics(
      label: '$titulo. ${capturada ? "Capturada" : "Sin capturar"}.',
      button: true,
      child: GestureDetector(
        onTap: capturada ? () => _previsualizar(path) : () => _elegirFuente(esFrontal),
        onLongPress: capturada ? () => _eliminar(esFrontal) : null,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(colors: [
                  AppTheme.cardBg1,
                  AppTheme.cardBg2,
                  _purple.withOpacity(capturada ? 0.10 : 0.04),
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: Border.all(
                  color: capturada
                      ? _purple.withOpacity(0.40)
                      : AppTheme.cardBorder,
                  width: capturada ? 1.8 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: capturada
                        ? _purple.withOpacity(0.15)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: capturada ? 20 : 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(children: [
                // Preview foto o placeholder
                Stack(children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                    child: SizedBox(
                      width: 90, height: 110,
                      child: capturada
                          ? Hero(
                              tag: 'rx_preview_$path',
                              child: Image.file(
                                File(path),
                                key: ValueKey(path),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, __, ___) => Container(
                                  color: _purple.withOpacity(0.06),
                                  child: Icon(
                                      Icons.broken_image_outlined,
                                      color: _purple.withOpacity(0.5),
                                      size: 28),
                                ),
                              ),
                            )
                          : Container(
                              color: _purple.withOpacity(0.06),
                              child: Icon(
                                Icons.document_scanner_outlined,
                                color: _purple.withOpacity(0.30), size: 36,
                              ),
                            ),
                    ),
                  ),
                  if (capturada)
                    Positioned(
                      top: 4, left: 4,
                      child: GestureDetector(
                        onTap: () => _eliminar(esFrontal),
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                ]),

                const SizedBox(width: 16),

                // Texto
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text(titulo,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: dark, fontSize: 16,
                              fontWeight: FontWeight.w800, letterSpacing: -0.3))),
                      const SizedBox(width: 8),
                      _chip(obligatoria ? 'requerida' : 'opcional', obligatoria),
                    ]),
                    const SizedBox(height: 4),
                    Text(subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppTheme.subtitleColor, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(
                        capturada
                            ? Icons.check_circle_rounded
                            : Icons.camera_alt_rounded,
                        color: capturada ? _purple : AppTheme.subtitleColor2,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Expanded(child: Text(
                        capturada
                            ? 'Toca para ver · mantén para eliminar'
                            : 'Toca para fotografiar',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: capturada ? _purple : AppTheme.subtitleColor2,
                          fontSize: 11.5,
                          fontWeight: capturada
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      )),
                    ]),
                  ],
                )),

                const SizedBox(width: 8),

                // Acción rápida (re-disparo / cámara)
                IconButton(
                  tooltip: capturada ? 'Repetir' : 'Capturar',
                  onPressed: () => _elegirFuente(esFrontal),
                  icon: Icon(
                    capturada
                        ? Icons.refresh_rounded
                        : Icons.add_a_photo_outlined,
                    color: _purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 4),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool primary) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: primary
              ? _purple.withOpacity(0.12)
              : (AppTheme.isDark.value
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: TextStyle(
            color: primary ? _purple : AppTheme.subtitleColor,
            fontSize: 8,
            fontWeight: primary ? FontWeight.w700 : FontWeight.w600)),
      );

  Widget _buildContinuarBtn(bool hasFrontal, bool hasLateral) {
    final enabled = hasFrontal && !_continuando;
    return GestureDetector(
      onTap: enabled ? _continuar : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              _purple.withOpacity(enabled ? 1.0 : 0.30),
              _purpleL.withOpacity(enabled ? 1.0 : 0.30),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: enabled ? [BoxShadow(
            color: _purple.withOpacity(0.35),
            blurRadius: 18, offset: const Offset(0, 7),
          )] : const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasLateral
                  ? Icons.view_in_ar_rounded
                  : Icons.arrow_forward_rounded,
              color: Colors.white, size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              hasLateral
                  ? 'Generar modelo 3D'
                  : (hasFrontal ? 'Continuar solo con frontal' : 'Captura la frontal'),
              style: const TextStyle(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
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
                border: Border.all(color: AppTheme.cardBorder, width: 1.2)),
              child: Icon(icon, color: AppTheme.darkText, size: 18),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom-sheet de selección de fuente
// ─────────────────────────────────────────────────────────────────────────────
class _SourceSheet extends StatelessWidget {
  final Color purple;
  const _SourceSheet({required this.purple});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.darkText;
    return SafeArea(
      top: false,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg1,
              border: Border(top: BorderSide(color: AppTheme.cardBorder)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.subtitleColor2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Origen de la radiografía',
                    style: TextStyle(color: dark,
                        fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                _option(context, Icons.photo_camera_rounded,
                    'Cámara', 'Fotografiar el negatoscopio',
                    ImageSource.camera),
                const SizedBox(height: 8),
                _option(context, Icons.photo_library_rounded,
                    'Galería', 'Seleccionar una imagen ya tomada',
                    ImageSource.gallery),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _option(BuildContext context, IconData icon, String title,
      String subtitle, ImageSource src) {
    final dark = AppTheme.darkText;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(src),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: purple.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: purple.withOpacity(0.20)),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: purple.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: purple, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: dark,
                  fontSize: 14, fontWeight: FontWeight.w700)),
              Text(subtitle, style: TextStyle(
                  color: AppTheme.subtitleColor, fontSize: 11.5)),
            ],
          )),
          Icon(Icons.chevron_right_rounded,
              color: AppTheme.subtitleColor2),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Visor a pantalla completa con pinch-zoom
// ─────────────────────────────────────────────────────────────────────────────
class _FullscreenPreview extends StatelessWidget {
  final String path;
  const _FullscreenPreview({required this.path});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                child: Center(
                  child: Hero(
                    tag: 'rx_preview_$path',
                    child: Image.file(
                      File(path),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white70, size: 64),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: Material(
                color: Colors.black.withOpacity(0.45),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}