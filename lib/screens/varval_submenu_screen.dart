import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'visor_caso_screen.dart';
import 'package:untitled/services/app_theme.dart';


// ══════════════════════════════════════════════════════════════════════════════
// NIVEL 1 — Adición / Sustracción / Rotación
// ══════════════════════════════════════════════════════════════════════════════
class VarvalSubmenuScreen extends StatefulWidget {
  const VarvalSubmenuScreen({super.key});

  @override
  State<VarvalSubmenuScreen> createState() => _VarvalSubmenuScreenState();
}

class _VarvalSubmenuScreenState extends State<VarvalSubmenuScreen>
    with TickerProviderStateMixin {

  late AnimationController _bgController;
  late AnimationController _shimmerController;
  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>> _cardFades = [];
  final List<Animation<Offset>> _cardSlides = [];

  static const _opciones = [
    _VarvalOpcion(
      id: 'Adicion',
      label: 'Adición',
      descripcion: 'Planificación quirúrgica\nmediante técnica de adición',
      icono: Icons.add_circle_outline_rounded,
      accentColor: Color(0xFF34A853),
      accentColorLight: Color(0xFF81C995),
        imagenAsset: 'assets/images/palos.jpeg'
    ),
    _VarvalOpcion(
      id: 'Sustraccion',
      label: 'Sustracción',
      descripcion: 'Planificación quirúrgica\nmediante técnica de sustracción',
      icono: Icons.remove_circle_outline_rounded,
      accentColor: Color(0xFF2A7FF5),
      accentColorLight: Color(0xFF7EC8FF),
        imagenAsset: 'assets/images/d.jpeg'
    ),
    _VarvalOpcion(
      id: 'Rotacion',
      label: 'Rotación',
      descripcion: 'Planificación quirúrgica\nmediante técnica de rotación',
      icono: Icons.rotate_90_degrees_ccw_rounded,
      accentColor: Color(0xFFE8840A),
      accentColorLight: Color(0xFFFFB74D),
        imagenAsset: 'assets/images/impactor.jpeg'
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
      final ctrl = AnimationController(
          duration: const Duration(milliseconds: 600), vsync: this);
      _cardFades.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _cardSlides.add(Tween<Offset>(
        begin: Offset(i.isEven ? -0.10 : 0.10, 0.05), end: Offset.zero,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));
      _cardControllers.add(ctrl);
    }

    _headerController.forward();
    for (int i = 0; i < _opciones.length; i++) {
      Future.delayed(Duration(milliseconds: 150 + i * 120),
          () { if (mounted) _cardControllers[i].forward(); });
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        _fondo(),
        _orbe(top: -80, right: -60, color: const Color(0xFF34A853), cw: true),
        _orbe(bottom: 60, left: -80, color: const Color(0xFF8E44AD), cw: false),
        SafeArea(child: Column(children: [
          _header('Varval', 'Selecciona técnica quirúrgica'),
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: _opciones.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: FadeTransition(
                opacity: _cardFades[i],
                child: SlideTransition(
                  position: _cardSlides[i],
                  child: _buildCard(_opciones[i], size, onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => VarvalZonaScreen(opcion: _opciones[i]),
                    ));
                  }),
                ),
              ),
            ),
          )),
        ])),
      ]),
    );
  }

  Widget _fondo() => Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [AppTheme.bgTop, AppTheme.bgBottom],
          begin: Alignment.topCenter, end: Alignment.bottomCenter),
    ),
  );

  Widget _orbe({double? top, double? bottom, double? left, double? right,
      required Color color, required bool cw}) {
    return Positioned(top: top, bottom: bottom, left: left, right: right,
      child: AnimatedBuilder(animation: _bgController,
        builder: (_, __) => Transform.rotate(
          angle: (cw ? 1 : -1) * _bgController.value * 2 * math.pi,
          child: Container(width: 300, height: 300,
            decoration: BoxDecoration(shape: BoxShape.circle,
              gradient: RadialGradient(
                  colors: [color.withOpacity(0.13), Colors.transparent]))),
        ),
      ),
    );
  }

  Widget _header(String titulo, String sub) => SlideTransition(
    position: _headerSlide,
    child: FadeTransition(opacity: _headerFade,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
        child: Row(children: [
          _glassBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: TextStyle(color: AppTheme.darkText,
                fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            Text(sub, style: TextStyle(
                color: AppTheme.subtitleColor, fontSize: 12)),
          ]),
        ]),
      ),
    ),
  );

  Widget _buildCard(_VarvalOpcion op, Size size, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
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
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.cardBg1,
                      AppTheme.cardBg2,
                      op.accentColor.withOpacity(0.08),
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
                      color: op.accentColor.withOpacity(0.18),
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
                          color: op.accentColor.withOpacity(0.06)),
                    ),
                  ),

                  // Círculos decorativos de color del acento
                  Positioned(right: -35, top: -35,
                    child: Container(width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: op.accentColor.withOpacity(0.07)))),
                  Positioned(right: 25, bottom: -55,
                    child: Container(width: 155, height: 155,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: op.accentColor.withOpacity(0.05)))),

                  // Imagen asset (derecha, difuminada hacia la izquierda)
                  if (op.imagenAsset != null)
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
                            op.imagenAsset!,
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
                          colors: [op.accentColor, op.accentColorLight],
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
                              color: op.accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: op.accentColor.withOpacity(0.28)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: op.accentColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: op.accentColor.withOpacity(0.6),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text('VARVAL',
                                  style: TextStyle(
                                      color: op.accentColor,
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
                                  Text('TÉCNICA',
                                      style: TextStyle(
                                          color: op.accentColor.withOpacity(0.65),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2.5)),
                                  const SizedBox(height: 3),
                                  Text(op.label,
                                      style: TextStyle(
                                          color: AppTheme.darkText,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.8,
                                          height: 1.05)),
                                  const SizedBox(height: 7),
                                  Text(op.descripcion,
                                      style: TextStyle(
                                          color: AppTheme.subtitleColor,
                                          fontSize: 12.5,
                                          height: 1.45)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _arrowBtn(op.accentColor, op.accentColorLight,
                                Icons.arrow_forward_rounded),
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

  Widget _badge(String texto, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.28)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)])),
      const SizedBox(width: 5),
      Text(texto, style: TextStyle(color: color, fontSize: 9,
          fontWeight: FontWeight.w800, letterSpacing: 1.5)),
    ]),
  );

  Widget _arrowBtn(Color c1, Color c2, IconData icon) => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [c1, c2],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      boxShadow: [BoxShadow(color: c1.withOpacity(0.35),
          blurRadius: 14, offset: const Offset(0, 5))],
    ),
    child: Icon(icon, color: Colors.white, size: 22),
  );

  Widget _glassBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.lockedCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, color: AppTheme.darkText, size: 18),
        ),
      ),
    ),
  );
}


// ══════════════════════════════════════════════════════════════════════════════
// NIVEL 2 — Tibial / Femoral
// ══════════════════════════════════════════════════════════════════════════════
class VarvalZonaScreen extends StatefulWidget {
  final _VarvalOpcion opcion;
  const VarvalZonaScreen({super.key, required this.opcion});

  @override
  State<VarvalZonaScreen> createState() => _VarvalZonaScreenState();
}

class _VarvalZonaScreenState extends State<VarvalZonaScreen>
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

  static const _zonas = [
    _VarvalZona(id: 'Tibial',  label: 'Tibial',
        descripcion: 'Modelos 3D de la\ncomponente tibial',
        icono: Icons.airline_seat_legroom_extra,
        imagenAsset: null), // ej: 'assets/images/tibial.jpeg'
    _VarvalZona(id: 'Femoral', label: 'Femoral',
        descripcion: 'Modelos 3D de la\ncomponente femoral',
        icono: Icons.accessibility_new,
        imagenAsset:  'assets/images/logo.png'), // ej: 'assets/images/femoral.jpeg'
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

    for (int i = 0; i < _zonas.length; i++) {
      final ctrl = AnimationController(
          duration: const Duration(milliseconds: 600), vsync: this);
      _cardFades.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _cardSlides.add(Tween<Offset>(
        begin: Offset(i.isEven ? -0.10 : 0.10, 0.05), end: Offset.zero,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));
      _cardControllers.add(ctrl);
    }

    _headerController.forward();
    for (int i = 0; i < _zonas.length; i++) {
      Future.delayed(Duration(milliseconds: 150 + i * 120),
          () { if (mounted) _cardControllers[i].forward(); });
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

  // 👇 SOLO PEGA ESTE MÉTODO DENTRO DE TU CLASE VarvalZonaScreen

  Future<void> _abrirVisor(_VarvalZona zona) async {
    setState(() => _cargandoVisor = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('login_email') ?? '';
      final pass  = prefs.getString('login_password') ?? '';
      final cred  = base64Encode(utf8.encode('$email:$pass'));

      final uri = Uri.parse(
        'https://profesional.planificacionquirurgica.com/listar_varval.php'
            '?tipo=${widget.opcion.id}&zona=${zona.id}',
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Basic $cred'},
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('Error HTTP ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['success'] != true) {
        throw Exception('Respuesta inválida');
      }

      // 🔵 BIOMODELOS
      final biomodelos = (data['biomodelos'] as List? ?? [])
          .map((e) => GlbArchivo(
        nombre:  e['nombre'],
        archivo: e['archivo'],
        url:     e['url'],
        tipo:    'biomodelo',
      ))
          .toList();

      // 🟢 PLACAS
      final placas = (data['placas'] as List? ?? [])
          .map((g) => GrupoPlagas(
        nombre: g['nombre'],
        placas: (g['placas'] as List)
            .map((e) => GlbArchivo(
          nombre:  e['nombre'],
          archivo: e['archivo'],
          url:     e['url'],
          tipo:    'placa',
        ))
            .toList(),
      ))
          .toList();

      // 🟠 TORNILLOS
      final tornillos = (data['tornillos'] as List? ?? [])
          .map((g) => GrupoTornillos(
        nombre: g['nombre'],
        tornillos: (g['tornillos'] as List)
            .map((e) => GlbArchivo(
          nombre:  e['nombre'],
          archivo: e['archivo'],
          url:     e['url'],
          tipo:    'tornillo',
        ))
            .toList(),
      ))
          .toList();

      final caso = CasoMedico(
        id:       '${widget.opcion.id}_${zona.id}',
        nombre:   '${widget.opcion.label} · ${zona.label}',
        paciente: '',
        fechaOp:  '',
        estado:   'generico',
        biomodelos: biomodelos,
        placas: placas,
        tornillos: tornillos,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VisorCasoScreen(
            caso: caso,
            autoCargar: true,   // 🔥 IMPORTANTE
            modoGenerico: true,
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cargando visor: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _cargandoVisor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final op   = widget.opcion;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Container(decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.bgTop, AppTheme.bgBottom],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
        )),
        Positioned(top: -80, right: -60,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: _bgController.value * 2 * math.pi,
              child: Container(width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    op.accentColor.withOpacity(0.13), Colors.transparent]))),
            ),
          ),
        ),
        Positioned(bottom: 60, left: -80,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: -_bgController.value * 2 * math.pi,
              child: Container(width: 260, height: 260,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF8E44AD).withOpacity(0.09), Colors.transparent]))),
            ),
          ),
        ),

        SafeArea(child: Column(children: [
          // Header
          SlideTransition(position: _headerSlide,
            child: FadeTransition(opacity: _headerFade,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Row(children: [
                  _glassBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(op.label, style: TextStyle(
                        color: AppTheme.darkText, fontSize: 26,
                        fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    Text('Selecciona zona', style: TextStyle(
                        color: AppTheme.subtitleColor, fontSize: 12)),
                  ]),
                ]),
              ),
            ),
          ),

          Expanded(child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: _zonas.length,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: FadeTransition(
                opacity: _cardFades[i],
                child: SlideTransition(
                  position: _cardSlides[i],
                  child: _buildZonaCard(_zonas[i], op, size),
                ),
              ),
            ),
          )),
        ])),

        // Overlay cargando visor
        if (_cargandoVisor)
          Positioned.fill(
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.white.withOpacity(0.45),
                child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(width: 52, height: 52,
                    child: CircularProgressIndicator(
                        color: op.accentColor, strokeWidth: 2.5)),
                  const SizedBox(height: 16),
                  Text('Cargando visor...', style: TextStyle(
                      color: Colors.black.withOpacity(0.55), fontSize: 14,
                      fontWeight: FontWeight.w500)),
                ])),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildZonaCard(_VarvalZona zona, _VarvalOpcion op, Size size) {
    return GestureDetector(
      onTap: () => _abrirVisor(zona),
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, __) => ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 195,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: LinearGradient(colors: [
                  AppTheme.cardBg1,
                  AppTheme.cardBg2,
                  op.accentColor.withOpacity(0.08),
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                boxShadow: [
                  BoxShadow(color: op.accentColor.withOpacity(0.18),
                      blurRadius: 32, offset: const Offset(0, 12), spreadRadius: -4),
                  BoxShadow(color: AppTheme.cardGlowWhite, blurRadius: 0),
                ],
              ),
              child: Stack(children: [
                // Grid de puntos muy suave
                Positioned.fill(child: CustomPaint(
                    painter: _DotGridPainter(
                        color: op.accentColor.withOpacity(0.06)))),
                // Círculos decorativos
                Positioned(right: -35, top: -35, child: Container(width: 200, height: 200,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: op.accentColor.withOpacity(0.07)))),
                Positioned(right: 25, bottom: -55, child: Container(width: 155, height: 155,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                        color: op.accentColor.withOpacity(0.05)))),
                // Imagen asset (derecha, difuminada hacia la izquierda)
                if (zona.imagenAsset != null)
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
                          zona.imagenAsset!,
                          fit: BoxFit.cover,
                          color: Colors.white.withOpacity(0.88),
                          colorBlendMode: BlendMode.modulate,
                        ),
                      ),
                    ),
                  ),
                // Shimmer sweep diagonal blanco
                Positioned.fill(child: Transform.translate(
                  offset: Offset((size.width + 300) * _shimmerController.value - 150, 0),
                  child: Transform.rotate(angle: 0.3, child: Container(width: 80,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [
                      Colors.transparent, Colors.white.withOpacity(0.22), Colors.transparent,
                    ])))),
                )),
                // Barra lateral de color acento izquierda
                Positioned(left: 0, top: 20, bottom: 20, child: Container(width: 4,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                    gradient: LinearGradient(colors: [op.accentColor, op.accentColorLight],
                        begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _badge('3D LISTO', op.accentColor),
                    const Spacer(),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(op.label.toUpperCase(), style: TextStyle(
                              color: op.accentColor.withOpacity(0.65), fontSize: 10,
                              fontWeight: FontWeight.w700, letterSpacing: 2.5)),
                          const SizedBox(height: 3),
                          Text(zona.label, style: TextStyle(
                              color: AppTheme.darkText, fontSize: 28,
                              fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.05)),
                          const SizedBox(height: 7),
                          Text(zona.descripcion, style: TextStyle(
                              color: AppTheme.subtitleColor,
                              fontSize: 12.5, height: 1.45)),
                        ],
                      )),
                      const SizedBox(width: 12),
                      _arrowBtn(op.accentColor, op.accentColorLight,
                          Icons.arrow_forward_ios_rounded),
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

  Widget _badge(String texto, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.28)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.6), blurRadius: 4)])),
      const SizedBox(width: 5),
      Text(texto, style: TextStyle(color: color, fontSize: 9,
          fontWeight: FontWeight.w800, letterSpacing: 1.5)),
    ]),
  );

  Widget _arrowBtn(Color c1, Color c2, IconData icon) => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: [c1, c2],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
      boxShadow: [BoxShadow(color: c1.withOpacity(0.35),
          blurRadius: 14, offset: const Offset(0, 5))],
    ),
    child: Icon(icon, color: Colors.white, size: 22),
  );

  Widget _glassBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.lockedCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Icon(icon, color: AppTheme.darkText, size: 18),
        ),
      ),
    ),
  );
}


// ══════════════════════════════════════════════════════════════════════════════
// Modelos de datos
// ══════════════════════════════════════════════════════════════════════════════
class _VarvalOpcion {
  final String id;
  final String label;
  final String descripcion;
  final IconData icono;
  final Color accentColor;
  final Color accentColorLight;
  final String? imagenAsset;
  const _VarvalOpcion({
    required this.id, required this.label, required this.descripcion,
    required this.icono, required this.accentColor, required this.accentColorLight,
    this.imagenAsset,
  });
}

class _VarvalZona {
  final String id;
  final String label;
  final String descripcion;
  final IconData icono;
  final String? imagenAsset;
  const _VarvalZona({
    required this.id, required this.label,
    required this.descripcion, required this.icono,
    this.imagenAsset,
  });
}


// ══════════════════════════════════════════════════════════════════════════════
// Painter de puntos decorativos
// ══════════════════════════════════════════════════════════════════════════════
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
