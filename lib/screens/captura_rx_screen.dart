// ─────────────────────────────────────────────────────────────────────────────
//  captura_rx_screen.dart
//  Pantalla de captura de 2 radiografías (Frontal + Lateral)
//  antes de pasar al FormularioCasoScreen.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;

import 'package:flutter/material.dart';
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

  late AnimationController _bgController;
  late AnimationController _headerController;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;

  String? _fotoFrontalPath;
  String? _fotoLateralPath;
  bool    _continuando = false;

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

  Future<void> _capturar(bool esFrontal) async {
    final picker = ImagePicker();
    final foto = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (foto == null || !mounted) return;
    setState(() {
      if (esFrontal) {
        _fotoFrontalPath = foto.path;
      } else {
        _fotoLateralPath = foto.path;
      }
    });
  }

  Future<void> _continuar() async {
    if (_fotoFrontalPath == null) return;
    setState(() => _continuando = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => FormularioCasoScreen(
        tipoVisor:        TipoVisor.radiografia,
        fotoPath:         _fotoFrontalPath,
        fotoLateralPath:  _fotoLateralPath,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bgTop  = AppTheme.bgTop;
    final bgBot  = AppTheme.bgBottom;
    final dark   = AppTheme.darkText;

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
        Positioned(top: -80, right: -60,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: _bgController.value * 2 * math.pi,
              child: Container(width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _purple.withOpacity(0.13), Colors.transparent])))))),
        Positioned(bottom: 60, left: -80,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: -_bgController.value * 2 * math.pi,
              child: Container(width: 260, height: 260,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _purple.withOpacity(0.08), Colors.transparent])))))),

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
                    // Badge IA
                    Container(
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
                    ),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(children: [

                  // Info
                  ClipRRect(borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
                            'La IA analizará ambas vistas para generar un modelo 3D personalizado del tobillo.',
                            style: TextStyle(color: dark.withOpacity(0.65),
                                fontSize: 12.5, height: 1.4),
                          )),
                        ]),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tarjetas de captura
                  _buildCapturaCard(
                    esFrontal: true,
                    path: _fotoFrontalPath,
                    titulo: 'Vista Frontal',
                    subtitulo: 'Proyección AP (anteroposterior)',
                    obligatoria: true,
                  ),

                  const SizedBox(height: 14),

                  _buildCapturaCard(
                    esFrontal: false,
                    path: _fotoLateralPath,
                    titulo: 'Vista Lateral',
                    subtitulo: 'Mejora la precisión del modelo 3D',
                    obligatoria: false,
                  ),

                  const Spacer(),

                  // Botón continuar
                  GestureDetector(
                    onTap: _fotoFrontalPath != null ? _continuar : null,
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: [
                            _purple.withOpacity(_fotoFrontalPath != null ? 1.0 : 0.30),
                            _purpleL.withOpacity(_fotoFrontalPath != null ? 1.0 : 0.30),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: _fotoFrontalPath != null ? [BoxShadow(
                          color: _purple.withOpacity(0.35),
                          blurRadius: 18, offset: const Offset(0, 7),
                        )] : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _fotoLateralPath != null
                                ? Icons.view_in_ar_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.white, size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _fotoLateralPath != null
                                ? 'Generar modelo 3D'
                                : 'Continuar solo con frontal',
                            style: const TextStyle(color: Colors.white,
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ]),
              ),
            ),
          ]),
        ),

        // Overlay cargando
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

  Widget _buildCapturaCard({
    required bool esFrontal,
    required String? path,
    required String titulo,
    required String subtitulo,
    required bool obligatoria,
  }) {
    final bool capturada = path != null;
    final dark = AppTheme.darkText;

    return GestureDetector(
      onTap: () => _capturar(esFrontal),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
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
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: SizedBox(
                  width: 90, height: 110,
                  child: capturada
                      ? Image.file(File(path!), fit: BoxFit.cover)
                      : Container(
                          color: _purple.withOpacity(0.06),
                          child: Icon(
                            Icons.document_scanner_outlined,
                            color: _purple.withOpacity(0.30), size: 36,
                          ),
                        ),
                ),
              ),

              const SizedBox(width: 16),

              // Texto
              Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(titulo, style: TextStyle(
                        color: dark, fontSize: 16,
                        fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                    const SizedBox(width: 8),
                    if (obligatoria)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _purple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('requerida', style: TextStyle(
                            color: _purple, fontSize: 8,
                            fontWeight: FontWeight.w700)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.isDark.value
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('opcional', style: TextStyle(
                            color: AppTheme.subtitleColor, fontSize: 8,
                            fontWeight: FontWeight.w600)),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Text(subtitulo, style: TextStyle(
                      color: AppTheme.subtitleColor, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(
                      capturada ? Icons.check_circle_rounded : Icons.camera_alt_rounded,
                      color: capturada ? _purple : AppTheme.subtitleColor2,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      capturada ? 'Capturada — toca para repetir' : 'Toca para fotografiar',
                      style: TextStyle(
                        color: capturada ? _purple : AppTheme.subtitleColor2,
                        fontSize: 11.5,
                        fontWeight: capturada ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ]),
                ],
              )),

              const SizedBox(width: 16),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.lockedCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.cardBorder, width: 1.2)),
          child: Icon(icon, color: AppTheme.darkText, size: 18)),
      ),
    ),
  );
}
