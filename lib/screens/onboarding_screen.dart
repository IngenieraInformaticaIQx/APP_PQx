import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/services/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool fromPerfil;
  const OnboardingScreen({super.key, this.fromPerfil = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _accent = Color(0xFF2A7FF5);

  static const _slides = [
    _Slide(
      icon: Icons.waving_hand_rounded,
      color: Color(0xFF2A7FF5),
      title: 'Bienvenido a PQx',
      desc: 'Tu herramienta de planificación quirúrgica. Gestiona casos, visualiza modelos 3D y planifica intervenciones desde un solo lugar.',
    ),
    _Slide(
      icon: Icons.folder_open_rounded,
      color: Color(0xFF2A7FF5),
      title: 'Mis Casos',
      desc: 'Crea y organiza los casos de tus pacientes. Cada caso almacena modelos óseos, placas, tornillos y notas de voz.',
    ),
    _Slide(
      icon: Icons.view_in_ar_rounded,
      color: Color(0xFF5BA8FF),
      title: 'Visor 3D',
      desc: 'Navega el modelo con un dedo para rotar, pellizca para hacer zoom y desplaza con dos dedos. Doble toque para abrir el panel de capas.',
    ),
    _Slide(
      icon: Icons.layers_rounded,
      color: Color(0xFF5BA8FF),
      title: 'Panel de capas',
      desc: 'Muestra u oculta modelos óseos, placas y guías de forma independiente. Toca fuera del panel para cerrarlo.',
    ),
    _Slide(
      icon: Icons.hardware_rounded,
      color: Color(0xFF8E44AD),
      title: 'Tornillos',
      desc: 'Coloca tornillos sobre la placa desde el visor. Toca un tornillo para ver su nombre y medidas. Guarda la sesión para no perder tu planificación.',
    ),
    _Slide(
      icon: Icons.mic_rounded,
      color: Color(0xFF2A7FF5),
      title: 'Notas de voz',
      desc: 'Graba observaciones rápidas vinculadas al caso con el botón de micrófono del visor. Escúchalas o elimínalas cuando quieras.',
    ),
    _Slide(
      icon: Icons.picture_as_pdf_rounded,
      color: Color(0xFFE53935),
      title: 'Documentación',
      desc: 'Accede a los documentos técnicos del caso (fichas de producto, guías quirúrgicas) con el botón PDF del visor.',
    ),
  ];

  Future<void> _finalizar() async {
    if (!widget.fromPerfil) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_visto', true);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLast = _page == _slides.length - 1;

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
          child: Column(children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                if (widget.fromPerfil)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.cardBg1,
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Icon(Icons.close, size: 18, color: AppTheme.subtitleColor),
                    ),
                  )
                else
                  const SizedBox(width: 36),
                const Spacer(),
                if (!isLast)
                  GestureDetector(
                    onTap: _finalizar,
                    child: Text('Saltar',
                        style: TextStyle(
                            color: AppTheme.subtitleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  )
                else
                  const SizedBox(width: 36),
              ]),
            ),

            // ── PageView ──────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _buildSlide(_slides[i], size),
              ),
            ),

            // ── Indicadores ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? _accent : AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // ── Botón ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: GestureDetector(
                onTap: isLast
                    ? _finalizar
                    : () => _ctrl.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: isLast
                            ? const LinearGradient(
                                colors: [_accent, Color(0xFF5BA8FF)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight)
                            : null,
                        color: isLast ? null : AppTheme.cardBg1,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isLast
                              ? _accent.withOpacity(0.6)
                              : AppTheme.cardBorder,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          isLast ? 'Empezar' : 'Siguiente',
                          style: TextStyle(
                            color: isLast ? Colors.white : AppTheme.darkText,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSlide(_Slide slide, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icono en glass card
          ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  color: slide.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: slide.color.withOpacity(0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: slide.color.withOpacity(0.15),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Icon(slide.icon, size: 48, color: slide.color),
              ),
            ),
          ),
          const SizedBox(height: 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            slide.desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.subtitleColor,
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _Slide({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });
}