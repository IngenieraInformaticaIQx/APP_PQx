import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'visor_caso_screen.dart';
import 'varval_submenu_screen.dart';
import 'package:untitled/services/app_theme.dart';

class VisorSelectorScreen extends StatefulWidget {
  final bool desdeNuevoCaso;
  const VisorSelectorScreen({super.key, this.desdeNuevoCaso = false});

  @override
  State<VisorSelectorScreen> createState() => _VisorSelectorScreenState();
}

class _VisorSelectorScreenState extends State<VisorSelectorScreen>
    with TickerProviderStateMixin {

  late AnimationController _bgController;
  late AnimationController _shimmerController;
  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>> _cardFades = [];
  final List<Animation<Offset>> _cardSlides = [];

  bool _cargandoVisor = false;

  // ── Paleta de la app (light glass) ────────────────────────────────────────
  static const Color _accent      = Color(0xFF2A7FF5); // azul vivo
  static const Color _accentLight = Color(0xFF5BA8FF);





  // DISEÑO DE CARDVIEWS


  final List<_VisorItem> _visores = [
    _VisorItem(
      id: 'tabal',
      titulo: 'Visor Tabal',
      zona: 'Tobillo',
      descripcion: 'Planificación quirúrgica\nde tobillo con placas\ny tornillos 3D',
      icono: Icons.accessibility_new,
      accentColor: const Color(0xFF2A7FF5),
      accentColorLight: const Color(0xFF7EC8FF),
      disponible: true,
      casoNombre: 'Tabal',
      imagenAsset: 'assets/images/tabal.jpeg',
    ),
    _VisorItem(
      id: 'rodilla',
      titulo: 'Visor Varval',
      zona: 'Rodilla',
      descripcion: 'Planificación quirúrgica\nde rodilla con placas\ny tornillos 3D',
      icono: Icons.airline_seat_legroom_extra,
      accentColor: const Color(0xFF34A853),
      accentColorLight: const Color(0xFF81C995),
      disponible: true,
      casoNombre: 'Varval',
      imagenAsset: 'assets/images/caja.jpeg',
    ),
    _VisorItem(
      id: 'cadera',
      titulo: 'Visor Cadera',
      zona: 'Cadera',
      descripcion: 'Planificación quirúrgica de cadera',
      icono: Icons.self_improvement,
      accentColor: const Color(0xFFE8840A),
      accentColorLight: const Color(0xFFFFB74D),
      disponible: false,
      casoNombre: '',
    ),
    _VisorItem(
      id: 'columna',
      titulo: 'Visor Columna',
      zona: 'Columna',
      descripcion: 'Planificación quirúrgica de columna vertebral',
      icono: Icons.linear_scale,
      accentColor: const Color(0xFF8E44AD),
      accentColorLight: const Color(0xFFCE93D8),
      disponible: false,
      casoNombre: '',
    ),
  ];

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);

    _bgController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat();

    _headerController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _headerFade = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));

    for (int i = 0; i < _visores.length; i++) {
      final ctrl = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      _cardFades.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _cardSlides.add(Tween<Offset>(
        begin: Offset(i.isEven ? -0.10 : 0.10, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));
      _cardControllers.add(ctrl);
    }

    _headerController.forward();
    for (int i = 0; i < _visores.length; i++) {
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

  Future<void> _abrirVisor(_VisorItem visor) async {
    if (!visor.disponible) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${visor.titulo} estará disponible próximamente'),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    // ── Varval: navega por el submenú en lugar de abrir el visor directamente ──
    if (visor.id == 'rodilla') {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => const VarvalSubmenuScreen(),
      ));
      return;
    }

    // Directo al visor
    setState(() => _cargandoVisor = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('login_email') ?? '';
      final pass  = prefs.getString('login_password') ?? '';
      final cred  = base64Encode(utf8.encode('$email:$pass'));

      final response = await http.get(
        Uri.parse('https://profesional.planificacionquirurgica.com/listar_visores_genericos.php'),
        headers: {'Authorization': 'Basic $cred'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final visores = (data['visores'] as List)
              .map((e) => CasoMedico.fromJson(e))
              .toList();
          final caso = visores.firstWhere(
            (c) => c.nombre.toLowerCase().contains(visor.casoNombre.toLowerCase()),
            orElse: () => throw Exception('Visor no encontrado'),
          );
          if (!mounted) return;
          Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => VisorCasoScreen(caso: caso, modoGenerico: true)));
          return;
        }
      }
      throw Exception('Error al cargar el visor');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo cargar el visor: $e'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ));
    } finally {
      if (mounted) setState(() => _cargandoVisor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final _bgTop    = AppTheme.bgTop;
    final _bgBottom = AppTheme.bgBottom;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [

        // ── Fondo degradado gris claro (estilo app) ──────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_bgTop, _bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Orbe azul suave arriba derecha
        Positioned(
          top: -80, right: -60,
          child: AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: _bgController.value * 2 * math.pi,
              child: Container(
                width: 300, height: 300,
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
        ),

        // Orbe lila suave abajo izquierda
        Positioned(
          bottom: 60, left: -80,
          child: AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: -_bgController.value * 2 * math.pi,
              child: Container(
                width: 260, height: 260,
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
        ),

        // ── Contenido ────────────────────────────────────────────────────────
        SafeArea(
          child: Column(children: [

            // Header
            SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(children: [
                    _glassIconBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Visores 3D',
                          style: TextStyle(
                              color: AppTheme.darkText,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5)),
                      Text('Selecciona módulo de planificación',
                          style: TextStyle(
                              color: AppTheme.subtitleColor,
                              fontSize: 12,
                              letterSpacing: 0.1)),
                    ]),
                  ]),
                ),
              ),
            ),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                itemCount: _visores.length,
                itemBuilder: (ctx, i) {
                  final visor = _visores[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: FadeTransition(
                      opacity: _cardFades[i],
                      child: SlideTransition(
                        position: _cardSlides[i],
                        child: visor.disponible
                            ? _buildHeroCard(visor, size)
                            : _buildLockedCard(visor),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),

        // Overlay carga
        if (_cargandoVisor)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                color: AppTheme.isDark.value
                    ? Colors.black.withOpacity(0.55)
                    : Colors.white.withOpacity(0.45),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                      width: 52, height: 52,
                      child: CircularProgressIndicator(
                          color: _accent, strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 16),
                    Text('Cargando visor...',
                        style: TextStyle(
                            color: AppTheme.subtitleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  // ── Card hero grande (disponible) ──────────────────────────────────────────
  Widget _buildHeroCard(_VisorItem visor, Size size) {
    return GestureDetector(
      onTap: () => _abrirVisor(visor),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, __) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 195,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  // Glass blanco luminoso con toque azul muy suave
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.cardBg1,
                      AppTheme.cardBg2,
                      visor.accentColor.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppTheme.cardBorder,
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: visor.accentColor.withOpacity(0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: AppTheme.cardGlowWhite,
                      blurRadius: 0,
                      offset: const Offset(0, 0),
                    ),
                  ],
                ),
                child: Stack(children: [

                  // Grid de puntos muy suave
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DotGridPainter(
                          color: visor.accentColor.withOpacity(0.06)),
                    ),
                  ),

                  // Círculos decorativos de color del acento
                  Positioned(right: -35, top: -35,
                    child: Container(width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: visor.accentColor.withOpacity(0.07)))),
                  Positioned(right: 25, bottom: -55,
                    child: Container(width: 155, height: 155,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: visor.accentColor.withOpacity(0.05)))),


                  // Imagen asset (derecha, difuminada hacia la izquierda)
                  if (visor.imagenAsset != null)
                    Positioned(
                      right: 0, top: 0, bottom: 0,
                      width: 180,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(28),
                          bottomRight: Radius.circular(28),
                        ),
                        child: ShaderMask(
                          shaderCallback: (rect) => LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.55),
                              Colors.white.withOpacity(0.75),
                            ],
                            stops: const [0.0, 0.35, 1.0],
                          ).createShader(rect),
                          blendMode: BlendMode.dstIn,
                          child: Image.asset(
                            visor.imagenAsset!,
                            fit: BoxFit.cover,
                            color: Colors.white.withOpacity(0.88),
                            colorBlendMode: BlendMode.modulate,
                          ),
                        ),
                      ),
                    ),

                  // Shimmer sweep diagonal blanco
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(
                        (size.width + 300) * _shimmerController.value - 150, 0),
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

                  // Barra lateral de color acento izquierda
                  Positioned(
                    left: 0, top: 20, bottom: 20,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4)),
                        gradient: LinearGradient(
                          colors: [visor.accentColor, visor.accentColorLight],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Contenido
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Badge ACTIVO
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: visor.accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: visor.accentColor.withOpacity(0.28)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: visor.accentColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: visor.accentColor.withOpacity(0.6),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text('ACTIVO',
                                  style: TextStyle(
                                      color: visor.accentColor,
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
                                  Text(visor.zona.toUpperCase(),
                                      style: TextStyle(
                                          color: visor.accentColor.withOpacity(0.65),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2.5)),
                                  const SizedBox(height: 3),
                                  Text(visor.titulo,
                                      style: TextStyle(
                                          color: AppTheme.darkText,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.8,
                                          height: 1.05)),
                                  const SizedBox(height: 7),
                                  Text(visor.descripcion,
                                      style: TextStyle(
                                          color: AppTheme.subtitleColor,
                                          fontSize: 12.5,
                                          height: 1.45)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Botón circular flecha con color acento
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [visor.accentColor, visor.accentColorLight],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: visor.accentColor.withOpacity(0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
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
          );
        },
      ),
    );
  }

  // ── Card compacta bloqueada ────────────────────────────────────────────────
  Widget _buildLockedCard(_VisorItem visor) {
    return GestureDetector(
      onTap: () => _abrirVisor(visor),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  AppTheme.lockedCardBg,
                  AppTheme.lockedCardBg,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: AppTheme.lockedCardBorder,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [

                // Icono con tono del acento (opaco, bloqueado)
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: visor.accentColor.withOpacity(0.09),
                    border: Border.all(
                        color: visor.accentColor.withOpacity(0.18)),
                  ),
                  child: Icon(visor.icono, size: 20,
                      color: visor.accentColor.withOpacity(0.38)),
                ),
                const SizedBox(width: 14),

                // Texto
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(visor.titulo,
                          style: TextStyle(
                              color: AppTheme.subtitleColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 1),
                      Text(visor.zona,
                          style: TextStyle(
                              color: AppTheme.subtitleColor2,
                              fontSize: 11)),
                    ],
                  ),
                ),

                // Badge próximamente
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.isDark.value
                        ? Colors.white.withOpacity(0.06)
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.handleColor),
                  ),
                  child: Text('Próximamente',
                      style: TextStyle(
                          color: AppTheme.subtitleColor2,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                ),
                const SizedBox(width: 10),
                Icon(Icons.lock_outline,
                    color: AppTheme.subtitleColor2, size: 13),
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
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: AppTheme.darkText, size: 18),
          ),
        ),
      ),
    );
  }
}

// ── Grid de puntos decorativo ──────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  final Color color;
  _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 22.0;
    const radius = 1.2;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

// ── Modelo ─────────────────────────────────────────────────────────────────
class _VisorItem {
  final String id;
  final String titulo;
  final String zona;
  final String descripcion;
  final IconData icono;
  final Color accentColor;
  final Color accentColorLight;
  final bool disponible;
  final String casoNombre;
  final String? imagenAsset;

  const _VisorItem({
    required this.id,
    required this.titulo,
    required this.zona,
    required this.descripcion,
    required this.icono,
    required this.accentColor,
    required this.accentColorLight,
    required this.disponible,
    required this.casoNombre,
    this.imagenAsset,
  });
}
