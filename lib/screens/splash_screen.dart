import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:untitled/services/app_theme.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // Logo
  late AnimationController _logoCtrl;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoFade;

  // Título PQx
  late AnimationController _titleCtrl;
  late Animation<double>   _titleFade;
  late Animation<Offset>   _titleSlide;

  // Subtítulo
  late AnimationController _subCtrl;
  late Animation<double>   _subFade;

  // Línea shimmer bajo el logo
  late AnimationController _shimmerCtrl;

  // Fade-out total al salir
  late AnimationController _exitCtrl;
  late Animation<double>   _exitFade;

  // Orbe de fondo
  late AnimationController _orbeCtrl;

  static const _accent = Color(0xFF2A7FF5);

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _logoScale = Tween<double>(begin: 0.55, end: 1.0)
        .animate(CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutBack));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOut);

    _titleCtrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _titleFade  = CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOut);
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOutCubic));

    _subCtrl = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _subFade = CurvedAnimation(parent: _subCtrl, curve: Curves.easeOut);

    _shimmerCtrl = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this)..repeat();

    _exitCtrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _exitFade = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));

    _orbeCtrl = AnimationController(
        duration: const Duration(seconds: 8), vsync: this)..repeat();

    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _logoCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 350));
    _titleCtrl.forward();

    await Future.delayed(const Duration(milliseconds: 250));
    _subCtrl.forward();

    // Esperar y salir
    await Future.delayed(const Duration(milliseconds: 1400));
    await _exitCtrl.forward();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _titleCtrl.dispose();
    _subCtrl.dispose();
    _shimmerCtrl.dispose();
    _exitCtrl.dispose();
    _orbeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _exitFade,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.bgTop, AppTheme.bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(children: [

            // ── Orbe azul animado ─────────────────────────────────────────
            AnimatedBuilder(
              animation: _orbeCtrl,
              builder: (_, __) => Positioned(
                top: size.height * 0.08 + math.sin(_orbeCtrl.value * 2 * math.pi) * 18,
                right: -60,
                child: Container(
                  width: 340, height: 340,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      _accent.withOpacity(0.13),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),

            // ── Orbe lila animado ─────────────────────────────────────────
            AnimatedBuilder(
              animation: _orbeCtrl,
              builder: (_, __) => Positioned(
                bottom: size.height * 0.10 - math.sin(_orbeCtrl.value * 2 * math.pi) * 14,
                left: -80,
                child: Container(
                  width: 280, height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF8E44AD).withOpacity(0.09),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),

            // ── Contenido central ─────────────────────────────────────────
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  // Logo con glass card
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            width: 110, height: 110,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.cardBg1,
                                  AppTheme.cardBg2,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: _accent.withOpacity(0.18),
                                  blurRadius: 40,
                                  offset: const Offset(0, 12),
                                ),
                                BoxShadow(color: AppTheme.cardGlowWhite, blurRadius: 0),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Shimmer bar bajo el logo
                  FadeTransition(
                    opacity: _logoFade,
                    child: AnimatedBuilder(
                      animation: _shimmerCtrl,
                      builder: (_, __) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            width: 110, height: 3,
                            decoration: BoxDecoration(
                              color: AppTheme.handleColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Stack(children: [
                              Positioned(
                                left: 110 * _shimmerCtrl.value - 40,
                                child: Container(
                                  width: 50, height: 3,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: LinearGradient(colors: [
                                      Colors.transparent,
                                      _accent.withOpacity(0.8),
                                      Colors.transparent,
                                    ]),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Título PQx
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: Text(
                        'PQx',
                        style: TextStyle(
                          color: AppTheme.darkText,
                          fontSize: 52,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -2,
                          height: 1,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Subtítulo
                  FadeTransition(
                    opacity: _subFade,
                    child: Text(
                      'Planificación Quirúrgica',
                      style: TextStyle(
                        color: AppTheme.subtitleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  FadeTransition(
                    opacity: _subFade,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5, height: 5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _accent.withOpacity(0.6),
                            boxShadow: [BoxShadow(
                              color: _accent.withOpacity(0.5),
                              blurRadius: 6,
                            )],
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          'by PQx',
                          style: TextStyle(
                            color: AppTheme.subtitleColor2,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          ]),
        ),
      ),
    );
  }
}
