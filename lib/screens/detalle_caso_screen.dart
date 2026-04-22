import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:untitled/services/app_theme.dart';
import 'package:untitled/services/audio_notas_service.dart';
import 'visor_caso_screen.dart';
import 'archivos_caso_screen.dart';

class DetalleCasoScreen extends StatefulWidget {
  final CasoMedico caso;
  final void Function(String nuevoEstado)? onEstadoCambiado;

  const DetalleCasoScreen({
    super.key,
    required this.caso,
    this.onEstadoCambiado,
  });

  @override
  State<DetalleCasoScreen> createState() => _DetalleCasoScreenState();
}

class _DetalleCasoScreenState extends State<DetalleCasoScreen>
    with TickerProviderStateMixin {

  late AnimationController _bgCtrl;
  late AnimationController _shimmerCtrl;
  late AnimationController _headerCtrl;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;
  late AnimationController _card1Ctrl;
  late AnimationController _card2Ctrl;
  late Animation<double>   _card1Fade;
  late Animation<double>   _card2Fade;
  late Animation<Offset>   _card1Slide;
  late Animation<Offset>   _card2Slide;

  static const _accent = Color(0xFF2A7FF5);

  int _numNotasVoz = 0;

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);
    AudioNotasService.cargar(widget.caso.id).then((notas) {
      if (mounted) setState(() => _numNotasVoz = notas.length);
    });

    _bgCtrl = AnimationController(duration: const Duration(seconds: 60), vsync: this)..repeat();
    _shimmerCtrl = AnimationController(duration: const Duration(milliseconds: 8200), vsync: this)..repeat();

    _headerCtrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));

    _card1Ctrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _card2Ctrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _card1Fade  = CurvedAnimation(parent: _card1Ctrl, curve: Curves.easeOut);
    _card2Fade  = CurvedAnimation(parent: _card2Ctrl, curve: Curves.easeOut);
    _card1Slide = Tween<Offset>(begin: const Offset(-0.10, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _card1Ctrl, curve: Curves.easeOutCubic));
    _card2Slide = Tween<Offset>(begin: const Offset(0.10, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _card2Ctrl, curve: Curves.easeOutCubic));

    _headerCtrl.forward();
    Future.delayed(const Duration(milliseconds: 150), () { if (mounted) _card1Ctrl.forward(); });
    Future.delayed(const Duration(milliseconds: 280), () { if (mounted) _card2Ctrl.forward(); });
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    _bgCtrl.dispose();
    _shimmerCtrl.dispose();
    _headerCtrl.dispose();
    _card1Ctrl.dispose();
    _card2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [

        // ── Fondo degradado ──────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.bgTop, AppTheme.bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // ── Orbe azul ────────────────────────────────────────────────────
        Positioned(
          top: -80, right: -60,
          child: AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => Transform.rotate(
              angle: _bgCtrl.value * 2 * math.pi,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _accent.withOpacity(0.07),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
        ),

        // ── Orbe lila ────────────────────────────────────────────────────
        Positioned(
          bottom: 60, left: -80,
          child: AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => Transform.rotate(
              angle: -_bgCtrl.value * 2 * math.pi,
              child: Container(
                width: 260, height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF8E44AD).withOpacity(0.05),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
        ),

        SafeArea(
          child: Column(children: [

            // ── Header ───────────────────────────────────────────────────
            SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(children: [
                    _glassIconBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Mis Casos',
                            style: TextStyle(
                                color: AppTheme.darkText,
                                fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        Text(widget.caso.nombre,
                            style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
                            overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Label sección ─────────────────────────────────────────────
            FadeTransition(
              opacity: _headerFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('¿Qué quieres hacer?',
                      style: TextStyle(
                          color: AppTheme.subtitleColor,
                          fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Tarjeta Visor 3D ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FadeTransition(
                opacity: _card1Fade,
                child: SlideTransition(
                  position: _card1Slide,
                  child: _buildAccionCard(
                    size: size,
                    badge: 'VISOR 3D',
                    titulo: 'Visor 3D',
                    subtitulo: _numNotasVoz > 0
                        ? 'Modelos · Placas · Tornillos\n🎙 $_numNotasVoz nota${_numNotasVoz == 1 ? '' : 's'} de voz'
                        : 'Modelos · Placas · Tornillos',
                    accentColor: _accent,
                    accentColorLight: const Color(0xFF5BA8FF),
                    icon: Icons.view_in_ar_rounded,
                    imagenAsset: 'assets/images/tobillo_3d.png',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VisorCasoScreen(
                          caso: widget.caso,
                          onEstadoCambiado: widget.onEstadoCambiado,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Tarjeta Archivos ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FadeTransition(
                opacity: _card2Fade,
                child: SlideTransition(
                  position: _card2Slide,
                  child: _buildAccionCard(
                    size: size,
                    badge: 'ARCHIVOS',
                    titulo: 'Archivos',
                    subtitulo: 'PDFs · Imágenes compartidas',
                    accentColor: const Color(0xFF8E44AD),
                    accentColorLight: const Color(0xFFBE90D4),
                    icon: Icons.folder_open_rounded,
                    imagenAsset: 'assets/images/carpeta.png',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ArchivosCasoScreen(caso: widget.caso),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // FIX: BackdropFilter fuera del AnimatedBuilder para evitar el crash
  // _dependents.isEmpty al navegar mientras el shimmer está animando.
  // Solo el shimmer sweep se anima, el blur queda estático.
  Widget _buildAccionCard({
    required Size     size,
    required String   badge,
    required String   titulo,
    required String   subtitulo,
    required Color    accentColor,
    required Color    accentColorLight,
    required IconData icon,
    required VoidCallback onTap,
    String?  imagenAsset,
  }) {
    return GestureDetector(
      onTap: onTap,
      // FIX: ClipRRect y BackdropFilter fuera del AnimatedBuilder
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 185,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                colors: [
                  AppTheme.cardBg1,
                  AppTheme.cardBg2,
                  accentColor.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: accentColor.withOpacity(0.30),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
                BoxShadow(color: AppTheme.cardGlowWhite, blurRadius: 0),
              ],
            ),
            child: Stack(children: [

              // Grid de puntos
              Positioned.fill(
                child: CustomPaint(
                  painter: _DotGridPainter(color: accentColor.withOpacity(0.06)),
                ),
              ),

              // Círculos decorativos
              Positioned(right: -35, top: -35,
                child: Container(width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withOpacity(0.07)))),
              Positioned(right: 25, bottom: -55,
                child: Container(width: 155, height: 155,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withOpacity(0.05)))),

              // Imagen asset con fade ShaderMask lateral (igual que menu_screen)
              if (imagenAsset != null)
                Positioned(
                  right: 0, top: 0, bottom: 0,
                  width: 140,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Color(0x80FFFFFF),
                          Color(0xB8FFFFFF),
                        ],
                        stops: [0.0, 0.40, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: Image.asset(
                        imagenAsset,
                        fit: BoxFit.cover,
                        color: Colors.white.withOpacity(0.88),
                        colorBlendMode: BlendMode.modulate,
                      ),
                    ),
                  ),
                ),

              // Shimmer sweep — solo esto se anima
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: AnimatedBuilder(
                    animation: _shimmerCtrl,
                    builder: (_, __) => Transform.translate(
                      offset: Offset((size.width + 300) * _shimmerCtrl.value - 150, 0),
                      child: Transform.rotate(
                        angle: 0.3,
                        child: Container(
                          width: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.22),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Barra lateral izquierda
              Positioned(
                left: 0, top: 20, bottom: 20,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                    gradient: LinearGradient(
                      colors: [accentColor, accentColorLight],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // Contenido
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Badge
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: accentColor.withOpacity(0.28)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(
                                color: accentColor.withOpacity(0.6),
                                blurRadius: 4,
                              )],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(badge,
                              style: TextStyle(
                                  color: accentColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.5)),
                        ]),
                      ),
                    ]),

                    const Spacer(),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(icon,
                                    size: 13,
                                    color: accentColor.withOpacity(0.65)),
                                const SizedBox(width: 4),
                                Text(titulo.toUpperCase(),
                                    style: TextStyle(
                                        color: accentColor.withOpacity(0.65),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 2.5)),
                              ]),
                              const SizedBox(height: 3),
                              Text(titulo,
                                  style: TextStyle(
                                      color: AppTheme.darkText,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      height: 1.1)),
                              const SizedBox(height: 7),
                              Text(subtitulo,
                                  style: TextStyle(
                                      color: AppTheme.subtitleColor,
                                      fontSize: 11.5,
                                      height: 1.4)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Botón circular flecha
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [accentColor, accentColorLight],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [BoxShadow(
                              color: accentColor.withOpacity(0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            )],
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ]),
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
              border: Border.all(color: AppTheme.cardBorder, width: 1.2),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Icon(icon, color: AppTheme.darkText, size: 18),
          ),
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
    final paint = Paint()..color = color;
    const spacing = 22.0;
    const radius  = 1.2;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
