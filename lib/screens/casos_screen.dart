import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'visor_caso_screen.dart';
import 'package:untitled/services/app_theme.dart';

// Los modelos GlbArchivo y CasoMedico están definidos en visor_caso_screen.dart

class CasosScreen extends StatefulWidget {
  final VoidCallback? onVolverAlMenu;
  const CasosScreen({super.key, this.onVolverAlMenu});

  @override
  State<CasosScreen> createState() => _CasosScreenState();
}

class _CasosScreenState extends State<CasosScreen>
    with TickerProviderStateMixin {

  List<CasoMedico> _casos = [];
  bool _loading = true;
  String? _error;
  String _uid = '';

  // ── Animaciones (igual que VisorSelectorScreen) ───────────────────────────
  late AnimationController _bgController;
  late AnimationController _shimmerController;
  late AnimationController _headerController;
  late Animation<double> _headerFade;
  late Animation<Offset> _headerSlide;

  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>> _cardFades = [];
  final List<Animation<Offset>> _cardSlides = [];

  // ── Paleta (idéntica al VisorSelectorScreen) ──────────────────────────────
  static const Color _accent      = Color(0xFF2A7FF5);
  static const Color _accentLight = Color(0xFF5BA8FF);

  static const String _apiUrl =
      'https://profesional.planificacionquirurgica.com/listar_casos.php';

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);

    _bgController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 8200),
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

    _headerController.forward();
    _cargarCasos();
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

  // ── Lógica de negocio ─────────────────────────────────────────────────────
  Future<void> _cargarCasos() async {
    setState(() { _loading = true; _error = null; });

    // Resetear animaciones de cards anteriores
    for (final c in _cardControllers) c.dispose();
    _cardControllers.clear();
    _cardFades.clear();
    _cardSlides.clear();

    try {
      final prefs = await SharedPreferences.getInstance();
      _uid = prefs.getString('login_email') ?? '';
      final pass = prefs.getString('login_password') ?? '';

      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_uid:$pass'))}',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final casos = (data['casos'] as List)
              .map((e) => CasoMedico.fromJson(e))
              .toList();

          // Crear un AnimationController por card
          for (int i = 0; i < casos.length; i++) {
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

          setState(() {
            _casos = casos;
            _loading = false;
          });

          // Lanzar animaciones escalonadas
          for (int i = 0; i < casos.length; i++) {
            Future.delayed(Duration(milliseconds: 150 + i * 100), () {
              if (mounted) _cardControllers[i].forward();
            });
          }
          return;
        } else {
          setState(() { _error = data['message'] ?? 'Error'; _loading = false; });
        }
      } else {
        setState(() { _error = 'Error HTTP ${response.statusCode}'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = 'Error de conexión'; _loading = false; });
    }
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'validado':   return const Color(0xFF34A853);
      case 'modificado': return const Color(0xFFE8840A);
      case 'firmado':    return const Color(0xFF2A7FF5);
      case 'enviado':    return const Color(0xFFE65100);
      default:           return const Color(0xFF6969DD);
    }
  }

  Color _estadoColorLight(String estado) {
    switch (estado) {
      case 'validado':   return const Color(0xFF81C995);
      case 'modificado': return const Color(0xFFFFB74D);
      case 'firmado':    return const Color(0xFF7EC8FF);
      case 'enviado':    return const Color(0xFFFF8A65);
      default:           return const Color(0xFFBDBDBD);
    }
  }

  String _estadoLabel(String estado) {
    switch (estado) {
      case 'validado':   return 'Validado';
      case 'modificado': return 'Modificado';
      case 'firmado':    return 'Firmado';
      case 'enviado':    return 'Enviado';
      default:           return 'Pendiente';
    }
  }

  // ── Build principal ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final _bgTop    = AppTheme.bgTop;
    final _bgBottom = AppTheme.bgBottom;
    final _dark     = AppTheme.darkText;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [

        // Fondo degradado gris claro
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_bgTop, _bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Orbe azul arriba derecha (animado)
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
                    _accent.withOpacity(0.07),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
        ),

        // Orbe lila abajo izquierda (animado)
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
                    const Color(0xFF8E44AD).withOpacity(0.05),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
        ),

        // Contenido

        SafeArea(
          child: Column(children: [

            // Header animado
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
                                color: _dark,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5)),
                        Text(_uid.isNotEmpty ? _uid : 'Casos quirúrgicos',
                            style: TextStyle(
                                color: AppTheme.subtitleColor,
                                fontSize: 12,
                                letterSpacing: 0.1)),
                      ]),
                    ),
                    _glassIconBtn(Icons.refresh, _cargarCasos),
                  ]),
                ),
              ),
            ),

            // Cuerpo
            Expanded(child: _buildBody(size)),
          ]),
        ),
      ]),
    );
  }

  // ── Cuerpo según estado ───────────────────────────────────────────────────
  Widget _buildBody(Size size) {
    if (_loading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
          ),
          const SizedBox(height: 16),
          Text('Cargando casos...',
              style: TextStyle(
                  color: AppTheme.subtitleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ]),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.08),
                border: Border.all(color: Colors.red.withOpacity(0.2)),
              ),
              child: Icon(Icons.error_outline, color: Colors.red.withOpacity(0.6), size: 30),
            ),
            const SizedBox(height: 16),
            Text(_error!,
                style: TextStyle(
                    color: Colors.black.withOpacity(0.55),
                    fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _glassIconBtn(Icons.refresh, _cargarCasos),
          ]),
        ),
      );
    }

    if (_casos.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withOpacity(0.07),
              border: Border.all(color: _accent.withOpacity(0.15)),
            ),
            child: Icon(Icons.folder_open_outlined, color: _accent.withOpacity(0.4), size: 32),
          ),
          const SizedBox(height: 16),
          Text('No tienes casos asignados',
              style: TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Contacta con tu centro médico',
              style: TextStyle(
                  color: AppTheme.subtitleColor,
                  fontSize: 12)),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _casos.length,
      itemBuilder: (ctx, i) {
        final caso = _casos[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FadeTransition(
            opacity: _cardFades[i],
            child: SlideTransition(
              position: _cardSlides[i],
              child: _buildCasoCard(caso, size),
            ),
          ),
        );
      },
    );
  }

  // ── Card de caso (estilo hero del VisorSelector) ──────────────────────────
  Widget _buildCasoCard(CasoMedico caso, Size size) {
    final accentColor      = _estadoColor(caso.estado);
    final accentColorLight = _estadoColorLight(caso.estado);

    return GestureDetector(
      onTap: () async {
        // Guardar caso completo como último visitado
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('ultimo_caso_nombre', caso.nombre);
        await prefs.setString('ultimo_caso_id', caso.id);
        await prefs.setString('ultimo_caso_estado', caso.estado);
        await prefs.setString('ultimo_caso_json', json.encode(caso.toJson()));
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisorCasoScreen(
                caso: caso,
                onEstadoCambiado: (nuevoEstado) {
                  // Actualizar el card en CasosScreen sin recargar toda la lista
                  setState(() {
                    final idx = _casos.indexWhere((c) => c.id == caso.id);
                    if (idx >= 0) {
                      _casos[idx] = CasoMedico(
                        id:         caso.id,
                        nombre:     caso.nombre,
                        paciente:   caso.paciente,
                        fechaOp:    caso.fechaOp,
                        estado:     nuevoEstado,
                        biomodelos: caso.biomodelos,
                        placas:     caso.placas,
                        tornillos:  caso.tornillos,
                      );
                    }
                  });
                },
              ),
            ),
          ).then((_) {
            // Notificar al menú para que recargue el último caso al volver
            widget.onVolverAlMenu?.call();
          });
        }
      },
      child: AnimatedBuilder(
        animation: _shimmerController,
        builder: (_, __) {
          return ClipRRect(
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
                    color: _accent.withOpacity(0.30),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.18),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: AppTheme.cardGlowWhite,
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Stack(children: [

                  // Grid de puntos
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DotGridPainter(
                          color: accentColor.withOpacity(0.06)),
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

                  // Shimmer sweep diagonal
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

                  // Barra lateral izquierda con color de estado
                  Positioned(
                    left: 0, top: 20, bottom: 20,
                    child: Container(
                      width: 4,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                            right: Radius.circular(4)),
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

                        // Badge de estado
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: accentColor.withOpacity(0.28)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                width: 6, height: 6,
                                decoration: BoxDecoration(
                                  color: accentColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: accentColor.withOpacity(0.6),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(_estadoLabel(caso.estado).toUpperCase(),
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
                                  // Paciente (subtítulo pequeño)
                                  if (caso.paciente.isNotEmpty) ...[
                                    Text(caso.paciente.toUpperCase(),
                                        style: TextStyle(
                                            color: accentColor.withOpacity(0.65),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2.5)),
                                    const SizedBox(height: 3),
                                  ],
                                  // Nombre del caso
                                  Text(caso.nombre,
                                      style: TextStyle(
                                          color: AppTheme.darkText,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                          height: 1.1)),
                                  const SizedBox(height: 7),
                                  // Resumen de contenido
                                  Text(
                                    '${caso.biomodelos.length} hueso${caso.biomodelos.length != 1 ? 's' : ''}'
                                    '  ·  ${caso.placas.fold(0, (s, g) => s + g.placas.length)} placa${caso.placas.fold(0, (s, g) => s + g.placas.length) != 1 ? 's' : ''}'
                                    '  ·  ${caso.todosTornillos.length} tornillo${caso.todosTornillos.length != 1 ? 's' : ''}',
                                    style: TextStyle(
                                        color: AppTheme.subtitleColor,
                                        fontSize: 11.5,
                                        height: 1.4),
                                  ),
                                  // Fecha si existe
                                  if (caso.fechaOp.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(caso.fechaOp,
                                        style: TextStyle(
                                            color: AppTheme.subtitleColor2,
                                            fontSize: 10.5)),
                                  ],
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
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.35),
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

  // ── Botón glass (idéntico al VisorSelector) ─────────────────────────────────
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

// ── Grid de puntos decorativo (copiado del VisorSelector) ──────────────────
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
