import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:untitled/services/app_theme.dart';
import 'login_screen.dart';
import 'casos_screen.dart';
import 'visor_selector_screen.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'visor_caso_screen.dart';
import 'listados_screen.dart';
import 'nuevo_caso_screen.dart';
import 'onboarding_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  late AnimationController _bgController;
  late AnimationController _shimmerController;
  late AnimationController _headerController;
  late Animation<double>  _headerFade;
  late Animation<Offset>  _headerSlide;

  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>>   _cardFades       = [];
  final List<Animation<Offset>>   _cardSlides      = [];

  String _userEmail = '';

  // ── Último caso ───────────────────────────────────────────────────────────
  String? _ultimoCasoNombre;
  String? _ultimoCasoId;
  String? _ultimoCasoEstado;

  // ── Slider de frases ──────────────────────────────────────────────────────
  static const int _fraseOffset = 10000;
  late final PageController _fraseController = PageController(initialPage: _fraseOffset);
  int _fraseActual = 0;
  Timer? _fraseTimer;
  late final List<int> _fraseOrder = (List.generate(_frases.length, (i) => i)..shuffle(math.Random()));

  static const List<_Frase> _frases = [
    _Frase('«La precisión en la planificación\nes la primera incisión del cirujano»', Icons.precision_manufacturing_outlined),
    _Frase('«Ver en 3D lo que otros\nsolo imaginan en 2D»', Icons.view_in_ar_outlined),
    _Frase('«Cada caso es único.\nCada planificación, una oportunidad»', Icons.health_and_safety_outlined),
    _Frase('«La tecnología al servicio\ndel paciente quirúrgico»', Icons.biotech_outlined),
    _Frase('«Planificar bien hoy\nes operar mejor mañana»', Icons.event_available_outlined),
    _Frase('«La cirugía empieza\nmucho antes del quirófano»', Icons.medical_services_outlined),
    _Frase('«Donde otros ven límites,\nnosotros diseñamos soluciones»', Icons.architecture_outlined),
    _Frase('«Precisión milimétrica\npara decisiones críticas»', Icons.straighten_outlined),
    _Frase('«Transformar datos\nen confianza quirúrgica»', Icons.analytics_outlined),
    _Frase('«Visualizar mejor\npara intervenir con certeza»', Icons.visibility_outlined),
    _Frase('«Cada detalle cuenta\ncuando la precisión importa»', Icons.tune_outlined),
    _Frase('«Innovar hoy\npara salvar mañana»', Icons.lightbulb_outlined),
    _Frase('«Tecnología que guía\nmanos expertas»', Icons.psychology_outlined),
    _Frase('«Menos incertidumbre,\nmás control quirúrgico»', Icons.track_changes_outlined),
    _Frase('«Del análisis a la acción\ncon máxima exactitud»', Icons.play_circle_outline_outlined),
    _Frase('«Un milímetro de error\npuede marcar la diferencia»', Icons.space_bar_outlined),
    _Frase('«La anatomía habla;\nla planificación escucha»', Icons.hearing_outlined),
    _Frase('«Cada implante tiene\nsu lugar exacto»', Icons.place_outlined),
    _Frase('«La confianza del cirujano\nnace de la preparación»', Icons.verified_outlined),
    _Frase('«Operar con certeza\nes el mayor arte»', Icons.auto_awesome_outlined),
    _Frase('«El paciente no espera;\nla precisión tampoco»', Icons.access_time_outlined),
    _Frase('«Anticipar el gesto quirúrgico\nantes de entrar al campo»', Icons.preview_outlined),
    _Frase('«Datos que se convierten\nen decisiones que salvan»', Icons.bar_chart_outlined),
    _Frase('«Modelar el futuro\nantes de intervenir el presente»', Icons.model_training_outlined),
    _Frase('«La imagen 3D\nes el mapa del cirujano»', Icons.map_outlined),
    _Frase('«Reducir variables\nes maximizar resultados»', Icons.compress_outlined),
    _Frase('«El quirófano premia\na quien planificó»', Icons.emoji_events_outlined),
    _Frase('«Cada hueso tiene\nsu historia y su solución»', Icons.auto_stories_outlined),
    _Frase('«Tecnología que se convierte\nen segundos de vida»', Icons.timer_outlined),
    _Frase('«Donde la geometría\nes cuestión de vida»', Icons.pentagon_outlined),
    _Frase('«La planificación no sustituye\nal cirujano; lo potencia»', Icons.upgrade_outlined),
    _Frase('«Ver el caso completo\nantes del primer corte»', Icons.zoom_out_map_outlined),
    _Frase('«Innovación que no se nota\nen la sala; sí en el resultado»', Icons.trending_up_outlined),
    _Frase('«La excelencia quirúrgica\ncomienza fuera del quirófano»', Icons.workspace_premium_outlined),
    _Frase('«Planificar es cuidar\nantes de curar»', Icons.favorite_border_outlined),
  ];

  // ── Paleta ────────────────────────────────────────────────────────────────
  static const Color _accent = Color(0xFF2A7FF5);

  // ── Items del menú ────────────────────────────────────────────────────────
  static const List<_MenuItem> _items = [
    _MenuItem(
      icon: Icons.airline_seat_flat,
      title: 'Catálogo 3D',
      subtitle: 'Explora modelos anatómicos en tres dimensiones',
      colorA: Color(0xFF2A7FF5),
      colorB: Color(0xFF5BA8FF),
      tag: 'VISOR 3D',
      imagenAsset: 'assets/images/tobillo_3d.png',
    ),
    _MenuItem(
      icon: Icons.manage_accounts_outlined,
      title: 'Nuevo caso',
      subtitle: 'Crea un caso desde cero',
      colorA: Color(0xFF8E44AD),
      colorB: Color(0xFFCE93D8),
      tag: 'NUEVO',
      imagenAsset: 'assets/images/tabal.jpeg',
    ),
    _MenuItem(
      icon: Icons.biotech,
      title: 'Mis Casos',
      subtitle: 'Casos clínicos quirúrgicos asignados',
      colorA: Color(0xFF34A853),
      colorB: Color(0xFF81C995),
      tag: 'CASOS ASIGNADOS',
      imagenAsset: 'assets/images/SamitierSports.jpg',
    ),
    _MenuItem(
      icon: Icons.assignment_outlined,
      title: 'Mis planificaciones',
      subtitle: 'Planificaciones y ediciones libres guardadas',
      colorA: Color(0xFFE8840A),
      colorB: Color(0xFFFFB74D),
      tag: 'MODO LIBRE',
      imagenAsset: 'assets/images/medico.jpg',
    ),

  ];

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);

    _bgController = AnimationController(
        duration: const Duration(seconds: 60), vsync: this)..repeat();

    _shimmerController = AnimationController(
        duration: const Duration(milliseconds: 5000), vsync: this)..repeat();

    _headerController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _headerFade  = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));

    for (int i = 0; i < _items.length; i++) {
      final c = AnimationController(
          duration: const Duration(milliseconds: 600), vsync: this);
      _cardFades.add(CurvedAnimation(parent: c, curve: Curves.easeOut));
      _cardSlides.add(Tween<Offset>(
        begin: Offset(i.isEven ? -0.10 : 0.10, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic)));
      _cardControllers.add(c);
    }

    _headerController.forward();
    for (int i = 0; i < _items.length; i++) {
      Future.delayed(Duration(milliseconds: 150 + i * 100), () {
        if (mounted) _cardControllers[i].forward();
      });
    }

    _loadUser();
    _loadUltimoCaso();
    _startFraseTimer();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadUltimoCaso();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _userEmail = prefs.getString('login_email') ?? '');
  }

  CasoMedico? _ultimoCaso;

  Future<void> _loadUltimoCaso() async {
    final prefs   = await SharedPreferences.getInstance();
    final nombre  = prefs.getString('ultimo_caso_nombre');
    final jsonStr = prefs.getString('ultimo_caso_json');
    if (!mounted || nombre == null) return;

    CasoMedico? caso;
    if (jsonStr != null) {
      try {
        caso = CasoMedico.fromJson(json.decode(jsonStr) as Map<String, dynamic>);
      } catch (_) {}
    }

    setState(() {
      _ultimoCasoNombre = nombre;
      _ultimoCasoId     = prefs.getString('ultimo_caso_id');
      _ultimoCasoEstado = prefs.getString('ultimo_caso_estado') ?? 'pendiente';
      _ultimoCaso       = caso;
    });
  }

  void _startFraseTimer() {
    _fraseTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_fraseController.hasClients) return;
      final nextPage = (_fraseController.page?.round() ?? _fraseOffset) + 1;
      _fraseController.animateToPage(nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    WidgetsBinding.instance.removeObserver(this);
    _bgController.dispose();
    _shimmerController.dispose();
    _headerController.dispose();
    for (final c in _cardControllers) c.dispose();
    _fraseController.dispose();
    _fraseTimer?.cancel();
    super.dispose();
  }

  void _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', false);
    await prefs.remove('login_email');
    await prefs.remove('login_password');
    if (mounted) Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _mostrarPerfil() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
              decoration: BoxDecoration(
                color: AppTheme.sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: AppTheme.sheetBorder, width: 1.5),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 40, height: 4,
                    decoration: BoxDecoration(color: AppTheme.handleColor,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                // ── Datos de usuario ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _accent.withOpacity(0.15)),
                  ),
                  child: Row(children: [
                    Container(width: 44, height: 44,
                      decoration: const BoxDecoration(shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [_accent, Color(0xFF5BA8FF)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight)),
                      child: const Icon(Icons.person_outline, color: Colors.white, size: 22)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Sesión activa', style: TextStyle(color: AppTheme.darkText,
                          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                      Text(_userEmail, style: TextStyle(color: AppTheme.subtitleColor,
                          fontSize: 12), overflow: TextOverflow.ellipsis),
                    ])),
                  ]),
                ),
                const SizedBox(height: 12),
                // ── Switch modo oscuro ──
                ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg1,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(children: [
                        Icon(AppTheme.isDark.value ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            color: AppTheme.isDark.value ? const Color(0xFF7EC8FF) : const Color(0xFFFFB300),
                            size: 22),
                        const SizedBox(width: 12),
                        Expanded(child: Text(
                          AppTheme.isDark.value ? 'Modo oscuro' : 'Modo claro',
                          style: TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w600),
                        )),
                        Switch.adaptive(
                          value: AppTheme.isDark.value,
                          activeColor: const Color(0xFF2A7FF5),
                          onChanged: (_) async {
                            await AppTheme.toggle();
                            setSheetState(() {});
                          },
                        ),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Tutorial ──
                ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A7FF5).withOpacity(0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2A7FF5).withOpacity(0.18)),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.school_outlined, color: Color(0xFF2A7FF5)),
                        title: Text('Tutorial',
                            style: TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w600)),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const OnboardingScreen(fromPerfil: true)));
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Cerrar sesión ──
                ClipRRect(borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.red.withOpacity(0.22))),
                      child: ListTile(
                        leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                        title: Text('Cerrar sesión',
                            style: TextStyle(color: AppTheme.darkText, fontWeight: FontWeight.w600)),
                        onTap: () { Navigator.pop(context); _cerrarSesion(); },
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
/////////////////////////////////////////////ONTAP////////////////////////
  void _onTap(int index) {
    switch (index) {
      case 0:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const VisorSelectorScreen()));
        break;
      case 1:
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const NuevoCasoScreen()));
        break;

      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CasosScreen(onVolverAlMenu: _loadUltimoCaso),
          ),
        ).then((_) => _loadUltimoCaso());
        break;

      case 3:
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ListadosScreen()),
      );
      break;

    }
  }

  @override
  Widget build(BuildContext context) {
    final size    = MediaQuery.of(context).size;
    final _bgTop    = AppTheme.bgTop;
    final _bgBottom = AppTheme.bgBottom;
    final _dark     = AppTheme.darkText;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [

        // Fondo degradado
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_bgTop, _bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Orbe azul arriba derecha
        Positioned(top: -80, right: -60,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: _bgController.value * 2 * math.pi,
              child: Container(width: 320, height: 320,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _accent.withOpacity(0.10), Colors.transparent]))),
            ),
          ),
        ),

        // Orbe lila abajo izquierda
        Positioned(bottom: 40, left: -80,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: -_bgController.value * 2 * math.pi,
              child: Container(width: 260, height: 260,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF8E44AD).withOpacity(0.07),
                    Colors.transparent]))),
            ),
          ),
        ),

        // Contenido
        SafeArea(
          child: Column(children: [

            // ── Header ──────────────────────────────────────────────────────
            SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(children: [

                    // Logo glass compacto
                    GestureDetector(
                      onTap: () => launchUrl(Uri.parse('https://planificacionquirurgica.com/'), mode: LaunchMode.externalApplication),
                      child: ClipRRect(borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Container(width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.white.withOpacity(0.70),
                                Colors.white.withOpacity(0.45),
                              ]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.5),
                              boxShadow: [BoxShadow(color: _accent.withOpacity(0.10),
                                  blurRadius: 14, offset: const Offset(0, 4))],
                            ),
                            child: Padding(padding: const EdgeInsets.all(7),
                              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 14),

                    // Título + email
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Menú principal',
                          style: TextStyle(color: _dark, fontSize: 22,
                              fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      if (_userEmail.isNotEmpty)
                        Text(_userEmail,
                            style: TextStyle(color: Colors.black.withOpacity(0.32),
                                fontSize: 11.5),
                            overflow: TextOverflow.ellipsis),
                    ])),

                    // Botón perfil
                    _glassIconBtn(Icons.person_outline_rounded, _mostrarPerfil),
                  ]),
                ),
              ),
            ),

            // ── Cards ────────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  // Cards del menú
                  ...List.generate(_items.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: FadeTransition(
                      opacity: _cardFades[i],
                      child: SlideTransition(
                        position: _cardSlides[i],
                        child: _buildCard(_items[i], i, size),
                      ),
                    ),
                  )),

                  const SizedBox(height: 10),

                  // ── Separador ─────────────────────────────────────────────
                  Container(height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        Colors.transparent,
                        _accent.withOpacity(0.18),
                        Colors.transparent,
                      ])),
                  ),

                  const SizedBox(height: 12),

                  // ── Acceso rápido al último caso ───────────────────────────
                  if (_ultimoCasoNombre != null)
                    _buildAccesoRapido()
                  else
                    _buildSinCasoReciente(),

                  const SizedBox(height: 16),

                  // ── Slider de frases ───────────────────────────────────────
                  _buildSliderFrases(),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Card ─────────────────────────────────────────────────────────────────
  Widget _buildCard(_MenuItem item, int index, Size size) {
    return GestureDetector(
      onTap: () => _onTap(index),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, __) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(colors: [
                    AppTheme.cardBg1,
                    AppTheme.cardBg2,
                    item.colorA.withOpacity(0.07),
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: item.colorA.withOpacity(0.16),
                        blurRadius: 28, offset: const Offset(0, 10),
                        spreadRadius: -4),
                    BoxShadow(color: AppTheme.cardGlowWhite, blurRadius: 0),
                  ],
                ),
                child: Stack(children: [

                  // Dot grid
                  Positioned.fill(child: CustomPaint(
                    painter: _DotGridPainter(color: item.colorA.withOpacity(0.06)))),

                  // Círculos decorativos
                  Positioned(right: -30, top: -30,
                    child: Container(width: 140, height: 140,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: item.colorA.withOpacity(0.07)))),
                  Positioned(right: 30, bottom: -45,
                    child: Container(width: 100, height: 100,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: item.colorA.withOpacity(0.05)))),

                  // Imagen asset (derecha, difuminada hacia la izquierda)
                  if (item.imagenAsset != null)
                    Positioned(
                      right: 0, top: 0, bottom: 0,
                      width: 130,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(26),
                          bottomRight: Radius.circular(26),
                        ),
                        child: ShaderMask(
                          shaderCallback: (rect) => LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.50),
                              Colors.white.withOpacity(0.72),
                            ],
                            stops: const [0.0, 0.40, 1.0],
                          ).createShader(rect),
                          blendMode: BlendMode.dstIn,
                          child: Image.asset(
                            item.imagenAsset!,
                            fit: BoxFit.cover,
                            color: Colors.white.withOpacity(0.88),
                            colorBlendMode: BlendMode.modulate,
                          ),
                        ),
                      ),
                    ),

                  // Shimmer sweep
                  Positioned.fill(
                    child: ClipRRect(borderRadius: BorderRadius.circular(26),
                      child: Transform.translate(
                        offset: Offset((size.width + 200) * _shimmerController.value - 100, 0),
                        child: Transform.rotate(angle: 0.3,
                          child: Container(width: 60,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.20),
                                Colors.transparent,
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Barra lateral izquierda
                  Positioned(left: 0, top: 16, bottom: 16,
                    child: Container(width: 4,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                        gradient: LinearGradient(
                          colors: [item.colorA, item.colorB],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Contenido
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
                    child: Row(children: [

                      // Icono con halo
                      Container(width: 56, height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(colors: [
                            item.colorA.withOpacity(0.16),
                            item.colorA.withOpacity(0.05),
                            Colors.transparent,
                          ], stops: const [0.0, 0.6, 1.0]),
                        ),
                        child: Center(
                          child: ShaderMask(
                            shaderCallback: (b) => LinearGradient(
                              colors: [item.colorA, item.colorB],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(b),
                            child: Icon(item.icon, size: 28, color: Colors.white),
                          ),
                        ),
                      ),

                      const SizedBox(width: 14),

                      // Texto
                      Expanded(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tag
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: item.colorA.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: item.colorA.withOpacity(0.22)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(width: 5, height: 5,
                                decoration: BoxDecoration(
                                  color: item.colorA, shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: item.colorA.withOpacity(0.6),
                                      blurRadius: 4)],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(item.tag, style: TextStyle(color: item.colorA,
                                  fontSize: 8.5, fontWeight: FontWeight.w800,
                                  letterSpacing: 1.4)),
                            ]),
                          ),
                          const SizedBox(height: 5),
                          // Título
                          Text(item.title, style: TextStyle(color: AppTheme.darkText,
                              fontSize: 18, fontWeight: FontWeight.w800,
                              letterSpacing: -0.4, height: 1.1)),
                          const SizedBox(height: 3),
                          // Subtítulo
                          Text(item.subtitle, style: TextStyle(
                              color: AppTheme.subtitleColor,
                              fontSize: 11, height: 1.3),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      )),

                      const SizedBox(width: 10),

                      // Flecha
                      Container(width: 38, height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              colors: [item.colorA, item.colorB],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                          boxShadow: [BoxShadow(color: item.colorA.withOpacity(0.32),
                              blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Sin caso reciente ────────────────────────────────────────────────────
  Widget _buildSinCasoReciente() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.55),
              Colors.white.withOpacity(0.30),
            ], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.50)),
          ),
          child: Row(
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bolt_rounded, color: _accent.withOpacity(0.40), size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACCESO RÁPIDO',
                      style: TextStyle(color: _accent.withOpacity(0.40), fontSize: 8.5,
                          fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                  const SizedBox(height: 2),
                  Text('Sin casos recientes',
                      style: TextStyle(color: AppTheme.darkText.withOpacity(0.35), fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Acceso rápido ──────────────────────────────────────────────────────────
  Widget _buildAccesoRapido() {
    final color = _estadoColor(_ultimoCasoEstado ?? '');
    final colorL = _estadoColorLight(_ultimoCasoEstado ?? '');
    return GestureDetector(
      onTap: () {
        if (_ultimoCaso != null) {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => VisorCasoScreen(caso: _ultimoCaso!, autoCargar: true)))
              .then((_) => _loadUltimoCaso());
        } else {
          Navigator.push(context,
              MaterialPageRoute(
                builder: (_) => CasosScreen(onVolverAlMenu: _loadUltimoCaso),
              )).then((_) => _loadUltimoCaso());
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.white.withOpacity(0.65),
                Colors.white.withOpacity(0.40),
                color.withOpacity(0.06),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.25), width: 1.2),
              boxShadow: [
                BoxShadow(color: color.withOpacity(0.12),
                    blurRadius: 20, offset: const Offset(0, 6), spreadRadius: -3),
              ],
            ),
            child: Row(children: [
              // Icono bolt / reciente
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [color, colorL],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.30),
                      blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              // Texto
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ACCESO RÁPIDO AL ULTIMO CASO MODIFICADO',
                      style: TextStyle(color: color, fontSize: 8.5,
                          fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                  const SizedBox(height: 2),
                  Text(_ultimoCasoNombre ?? '',
                      style: TextStyle(color: AppTheme.darkText, fontSize: 13,
                          fontWeight: FontWeight.w700, letterSpacing: -0.2),
                      overflow: TextOverflow.ellipsis),
                ],
              )),
              // Flecha pequeña
              Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.6), size: 14),
            ]),
          ),
        ),
      ),
    );
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'validado':   return const Color(0xFF34A853);
      case 'modificado': return const Color(0xFFE8840A);
      case 'firmado':    return const Color(0xFF2A7FF5);
      default:           return const Color(0xFF2A7FF5);
    }
  }

  Color _estadoColorLight(String estado) {
    switch (estado) {
      case 'validado':   return const Color(0xFF81C995);
      case 'modificado': return const Color(0xFFFFB74D);
      case 'firmado':    return const Color(0xFF5BA8FF);
      default:           return const Color(0xFF5BA8FF);
    }
  }

  // ── Slider de frases médicas ──────────────────────────────────────────
  Widget _buildSliderFrases() {
    return Column(children: [
      SizedBox(
        height: 45,
        child: PageView.builder(
          controller: _fraseController,
          itemCount: null, // infinito
          onPageChanged: (i) => setState(() => _fraseActual = i % _frases.length),
          itemBuilder: (_, i) {
            final frase = _frases[_fraseOrder[i % _frases.length]];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(frase.icon, color: _accent.withOpacity(0.30), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(frase.texto,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: AppTheme.darkText.withOpacity(0.48),
                        fontSize: 14.5,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                        letterSpacing: 0.1,
                      )),
                ),
              ]),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      // Puntos indicadores (simbólicos: anterior · actual · siguiente)
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (i) {
          final isCenter = i == 1;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width:  isCenter ? 18 : 5,
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: isCenter
                  ? _accent.withOpacity(0.55)
                  : AppTheme.darkText.withOpacity(0.15),
            ),
          );
        }),
      ),
    ]);
  }

  Widget _glassIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.75), width: 1.2),
            ),
            child: Icon(icon, color: AppTheme.darkText, size: 20),
          ),
        ),
      ),
    );
  }
}

// ── Modelos ───────────────────────────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color colorA;
  final Color colorB;
  final String tag;
  final String? imagenAsset;
  const _MenuItem({
    required this.icon, required this.title, required this.subtitle,
    required this.colorA, required this.colorB, required this.tag,
    this.imagenAsset,
  });
}

// ── Frase ────────────────────────────────────────────────────────────────────
class _Frase {
  final String texto;
  final IconData icon;
  const _Frase(this.texto, this.icon);
}

// ── Dot grid ──────────────────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  final Color color;
  _DotGridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const s = 22.0; const r = 1.2;
    for (double x = s; x < size.width;  x += s)
    for (double y = s; y < size.height; y += s)
      canvas.drawCircle(Offset(x, y), r, p);
  }
  @override
  bool shouldRepaint(_DotGridPainter o) => o.color != color;
}
