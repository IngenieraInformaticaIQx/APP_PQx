// ─────────────────────────────────────────────────────────────────────────────
//  nuevo_caso_screen.dart  (actualizado)
//  • "Desde radiografía" → abre cámara nativa → FormularioCasoScreen
//  • "Elegir visor 3D"   → VisorSelectorScreen (Tabal / Varval)
//
//  Dependencias pubspec.yaml:
//    image_picker: ^1.1.2
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

import 'visor_selector_screen.dart';
import 'captura_rx_screen.dart';
import 'package:untitled/services/app_theme.dart';

class NuevoCasoScreen extends StatefulWidget {
  const NuevoCasoScreen({super.key});

  @override
  State<NuevoCasoScreen> createState() => _NuevoCasoScreenState();
}

class _NuevoCasoScreenState extends State<NuevoCasoScreen>
    with TickerProviderStateMixin {

  late AnimationController _bgController;
  late AnimationController _shimmerController;
  late AnimationController _headerController;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;

  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>>   _cardFades       = [];
  final List<Animation<Offset>>   _cardSlides      = [];

  static const Color _accent   = Color(0xFF2A7FF5);

  static const List<_OpcionItem> _opciones = [
    _OpcionItem(
      id: 'radiografia',
      icon: Icons.document_scanner_outlined,
      titulo: 'Desde radiografía',
      zona: 'Radiografía',
      descripcion: 'Fotografía la radiografía del paciente.\nLa IA generará el modelo 3D automáticamente.',
      accentColor: Color(0xFF8E44AD),
      accentColorLight: Color(0xFFCE93D8),
      tag: 'RADIOGRAFÍA + IA',
      disponible: true,
      imagenAsset: 'assets/images/tobillo.jpg',
    ),
    _OpcionItem(
      id: 'visor',
      icon: Icons.view_in_ar_rounded,
      titulo: 'Elegir visor 3D',
      zona: 'Visores',
      descripcion: 'Selecciona Tabal (tobillo) o Varval (rodilla)\ny trabaja sobre modelos existentes.',
      accentColor: Color(0xFF2A7FF5),
      accentColorLight: Color(0xFF5BA8FF),
      tag: 'VISOR 3D',
      disponible: true,
      imagenAsset: 'assets/images/caja.jpeg',
    ),
  ];

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);
    _bgController = AnimationController(
        duration: const Duration(seconds: 20), vsync: this)..repeat();
    _shimmerController = AnimationController(
        duration: const Duration(milliseconds: 2200), vsync: this)..repeat();
    _headerController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _headerFade  = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));
    for (int i = 0; i < _opciones.length; i++) {
      final c = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
      _cardFades.add(CurvedAnimation(parent: c, curve: Curves.easeOut));
      _cardSlides.add(Tween<Offset>(
        begin: Offset(i.isEven ? -0.10 : 0.10, 0.05), end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)));
      _cardControllers.add(c);
    }
    _headerController.forward();
    for (int i = 0; i < _opciones.length; i++) {
      Future.delayed(Duration(milliseconds: 150 + i * 120), () {
        if (mounted) _cardControllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    _bgController.dispose();
    _shimmerController.dispose();
    _headerController.dispose();
    for (final c in _cardControllers) c.dispose();
    super.dispose();
  }
  bool _abriendo = false;
  Future<void> _navegar(_OpcionItem opcion) async {
    if (_abriendo) return;
    if (opcion.id == 'radiografia') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => const CapturaRxScreen(),
      ));
      return;
    }
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const VisorSelectorScreen(desdeNuevoCaso: true)));
  }

  @override
  Widget build(BuildContext context) {
    final _bgTop    = AppTheme.bgTop;
    final _bgBottom = AppTheme.bgBottom;
    final _dark     = AppTheme.darkText;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_bgTop, _bgBottom],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
          ),
        ),
        Positioned(top: -80, right: -60,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: _bgController.value * 2 * math.pi,
              child: Container(width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _accent.withOpacity(0.13), Colors.transparent])))))),
        Positioned(bottom: 60, left: -80,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: -_bgController.value * 2 * math.pi,
              child: Container(width: 260, height: 260,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF8E44AD).withOpacity(0.09),
                    Colors.transparent])))))),
        Positioned.fill(child: CustomPaint(
            painter: _DotGridPainter(color: _dark.withOpacity(0.045)))),
        SafeArea(
          child: Column(children: [
            SlideTransition(position: _headerSlide,
              child: FadeTransition(opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(children: [
                    _glassIconBtn(Icons.arrow_back_ios_new_rounded,
                        () => Navigator.pop(context)),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Nuevo caso',
                          style: TextStyle(color: _dark, fontSize: 26,
                              fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      Text('Elige cómo crear tu planificación',
                          style: TextStyle(color: AppTheme.subtitleColor,
                              fontSize: 12)),
                    ]),
                  ]),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: _opciones.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: FadeTransition(opacity: _cardFades[i],
                    child: SlideTransition(position: _cardSlides[i],
                      child: _buildHeroCard(_opciones[i]))),
                ),
              ),
            ),
          ]),
        ),
        if (_abriendo)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: AppTheme.isDark.value
                    ? Colors.black.withOpacity(0.50)
                    : Colors.white.withOpacity(0.35),
                child: const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF8E44AD), strokeWidth: 2.5)),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildHeroCard(_OpcionItem opcion) {
    return GestureDetector(
      onTap: () => _navegar(opcion),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 195,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(colors: [
                  AppTheme.cardBg1,
                  AppTheme.cardBg2,
                  opcion.accentColor.withOpacity(0.08),
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(color: opcion.accentColor.withOpacity(0.18),
                      blurRadius: 32, offset: const Offset(0, 12), spreadRadius: -4),
                  BoxShadow(color: AppTheme.cardGlowWhite, blurRadius: 0),
                ],
              ),
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(
                    painter: _DotGridPainter(color: opcion.accentColor.withOpacity(0.06)))),
                Positioned(right: -35, top: -35,
                  child: Container(width: 200, height: 200,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: opcion.accentColor.withOpacity(0.07)))),
                Positioned(right: 25, bottom: -55,
                  child: Container(width: 155, height: 155,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: opcion.accentColor.withOpacity(0.05)))),
                if (opcion.imagenAsset != null)
                  Positioned(right: 0, top: 0, bottom: 0, width: 180,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(28),
                        bottomRight: Radius.circular(28),
                      ),
                      child: ShaderMask(
                        shaderCallback: (rect) => LinearGradient(
                          begin: Alignment.centerLeft, end: Alignment.centerRight,
                          colors: [Colors.transparent,
                            Colors.white.withOpacity(0.55),
                            Colors.white.withOpacity(0.75)],
                          stops: const [0.0, 0.35, 1.0],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: Image.asset(opcion.imagenAsset!, fit: BoxFit.cover,
                            color: Colors.white.withOpacity(0.88),
                            colorBlendMode: BlendMode.modulate),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset((MediaQuery.of(context).size.width + 300) *
                        _shimmerController.value - 150, 0),
                    child: Transform.rotate(angle: 0.3,
                      child: Container(width: 80,
                        decoration: BoxDecoration(gradient: LinearGradient(colors: [
                          Colors.transparent, Colors.white.withOpacity(0.22),
                          Colors.transparent])))),
                  ),
                ),
                Positioned(left: 0, top: 20, bottom: 20,
                  child: Container(width: 4,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                      gradient: LinearGradient(
                        colors: [opcion.accentColor, opcion.accentColorLight],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: opcion.accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: opcion.accentColor.withOpacity(0.28))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6,
                          decoration: BoxDecoration(color: opcion.accentColor,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(
                              color: opcion.accentColor.withOpacity(0.6), blurRadius: 4)])),
                        const SizedBox(width: 5),
                        Text(opcion.tag, style: TextStyle(color: opcion.accentColor,
                            fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                      ]),
                    ),
                    const Spacer(),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(opcion.zona.toUpperCase(), style: TextStyle(
                          color: opcion.accentColor.withOpacity(0.65),
                          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
                        const SizedBox(height: 3),
                        Text(opcion.titulo, style: TextStyle(color: AppTheme.darkText,
                          fontSize: 28, fontWeight: FontWeight.w800,
                          letterSpacing: -0.8, height: 1.05)),
                        const SizedBox(height: 7),
                        Text(opcion.descripcion, style: TextStyle(
                          color: AppTheme.subtitleColor,
                          fontSize: 12.5, height: 1.45)),
                      ])),
                      const SizedBox(width: 12),
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [opcion.accentColor, opcion.accentColorLight],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                          boxShadow: [BoxShadow(
                            color: opcion.accentColor.withOpacity(0.35),
                            blurRadius: 14, offset: const Offset(0, 5))]),
                        child: const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 22)),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _glassIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
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
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2)),
            child: Icon(icon, color: AppTheme.darkText, size: 18)),
        ),
      ),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;
  _DotGridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const s = 22.0; const r = 1.2;
    for (double x = s; x < size.width; x += s)
    for (double y = s; y < size.height; y += s)
      canvas.drawCircle(Offset(x, y), r, p);
  }
  @override
  bool shouldRepaint(_DotGridPainter o) => o.color != color;
}

class _OpcionItem {
  final String id;
  final IconData icon;
  final String titulo;
  final String zona;
  final String descripcion;
  final Color accentColor;
  final Color accentColorLight;
  final String tag;
  final bool disponible;
  final String? imagenAsset;
  const _OpcionItem({
    required this.id, required this.icon, required this.titulo,
    required this.zona, required this.descripcion,
    required this.accentColor, required this.accentColorLight,
    required this.tag, required this.disponible, this.imagenAsset,
  });
}
