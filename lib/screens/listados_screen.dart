import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'visor_caso_screen.dart';
import 'package:untitled/services/app_theme.dart';
import 'package:untitled/services/audio_notas_service.dart';

class ListadosScreen extends StatefulWidget {
  const ListadosScreen({super.key});

  @override
  State<ListadosScreen> createState() => _ListadosScreenState();
}

class _ListadosScreenState extends State<ListadosScreen>
    with TickerProviderStateMixin {

  List<Map<String, dynamic>> _sesiones = [];
  bool _loading = true;

  late AnimationController _bgController;
  late AnimationController _shimmerController;
  late AnimationController _headerController;
  late Animation<double>  _headerFade;
  late Animation<Offset>  _headerSlide;

  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>>   _cardFades       = [];
  final List<Animation<Offset>>   _cardSlides      = [];

  static const Color _accent   = Color(0xFFE8840A);
  static const Color _accentL  = Color(0xFFFFB74D);

  static const String _exportarUrl =
      'https://n8n.srv1089937.hstgr.cloud/webhook/adf721aa-c593-42e0-a40e-93d32b0c9d60';

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);
    _bgController = AnimationController(
        duration: const Duration(seconds: 60), vsync: this)..repeat();
    _shimmerController = AnimationController(
        duration: const Duration(milliseconds: 8200), vsync: this)..repeat();
    _headerController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _headerFade  = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));
    _headerController.forward();
    _cargarSesiones();
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

  Future<void> _cargarSesiones() async {
    setState(() => _loading = true);
    for (final c in _cardControllers) c.dispose();
    _cardControllers.clear();
    _cardFades.clear();
    _cardSlides.clear();

    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString('listados_sesiones') ?? '[]';
    final List<dynamic> lista = json.decode(raw);
    final sesiones = lista.cast<Map<String, dynamic>>();

    for (int i = 0; i < sesiones.length; i++) {
      final ctrl = AnimationController(
          duration: const Duration(milliseconds: 600), vsync: this);
      _cardFades.add(CurvedAnimation(parent: ctrl, curve: Curves.easeOut));
      _cardSlides.add(Tween<Offset>(
        begin: Offset(i.isEven ? -0.10 : 0.10, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)));
      _cardControllers.add(ctrl);
    }

    setState(() { _sesiones = sesiones; _loading = false; });

    for (int i = 0; i < sesiones.length; i++) {
      Future.delayed(Duration(milliseconds: 150 + i * 100), () {
        if (mounted) _cardControllers[i].forward();
      });
    }
  }

  Future<void> _eliminarSesion(int index) async {
    final confirmado = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
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
              const Icon(Icons.delete_outline_rounded, size: 32, color: Colors.redAccent),
              const SizedBox(height: 10),
              Text(_sesiones[index]['nombre'] ?? '',
                  style: TextStyle(color: AppTheme.darkText, fontSize: 17,
                      fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text('¿Eliminar esta sesión guardada?',
                  style: TextStyle(color: Colors.black.withOpacity(0.45), fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Eliminar',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar',
                    style: TextStyle(color: Colors.black.withOpacity(0.38), fontSize: 14)),
              ),
            ]),
          ),
        ),
      ),
    );
    if (confirmado != true || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    _sesiones.removeAt(index);
    await prefs.setString('listados_sesiones', json.encode(_sesiones));
    _cargarSesiones();
  }

  String _formatFecha(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final _bgTop    = AppTheme.bgTop;
    final _bgBottom = AppTheme.bgBottom;
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Container(decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_bgTop, _bgBottom],
              begin: Alignment.topCenter, end: Alignment.bottomCenter))),
        Positioned(top: -80, right: -60,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: _bgController.value * 2 * math.pi,
              child: Container(width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _accent.withOpacity(0.07), Colors.transparent])))))),
        Positioned(bottom: 60, left: -80,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: -_bgController.value * 2 * math.pi,
              child: Container(width: 260, height: 260,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    const Color(0xFF8E44AD).withOpacity(0.05),
                    Colors.transparent])))))),
        SafeArea(
          child: Column(children: [
            SlideTransition(position: _headerSlide,
              child: FadeTransition(opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(children: [
                    _glassIconBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Mis planificaciones', style: TextStyle(color: AppTheme.darkText, fontSize: 26,
                          fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      Text('Sesiones guardadas desde los visores 3D',
                          style: TextStyle(color: AppTheme.subtitleColor,
                              fontSize: 12, letterSpacing: 0.1)),
                    ])),
                    _glassIconBtn(Icons.refresh, _cargarSesiones),
                  ]),
                ),
              ),
            ),
            Expanded(child: _buildBody(size)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBody(Size size) {
    if (_loading) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(width: 48, height: 48,
          child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5)),
        const SizedBox(height: 16),
        Text('Cargando listados…', style: TextStyle(color: AppTheme.subtitleColor,
            fontSize: 14, fontWeight: FontWeight.w500)),
      ]));
    }
    if (_sesiones.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: _accent.withOpacity(0.07),
            border: Border.all(color: _accent.withOpacity(0.15))),
          child: Icon(Icons.bookmark_border_rounded, color: _accent.withOpacity(0.4), size: 32)),
        const SizedBox(height: 16),
        Text('Sin sesiones guardadas',
            style: TextStyle(color: AppTheme.darkText, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Abre el Visor 3D y pulsa "Guardar"',
            style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
      ]));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      itemCount: _sesiones.length,
      itemBuilder: (ctx, i) {
        final sesion = _sesiones[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: FadeTransition(opacity: _cardFades[i],
            child: SlideTransition(position: _cardSlides[i],
              child: _buildCard(sesion, i, size))),
        );
      },
    );
  }

  Widget _buildCard(Map<String, dynamic> sesion, int index, Size size) {
    final nombre       = sesion['nombre'] as String? ?? 'Sin nombre';
    final fecha        = sesion['fecha'] as String? ?? '';
    final casoOrigen   = sesion['caso_origen'] as String? ?? '';
    final numTornillos = sesion['num_tornillos'] as int? ?? 0;
    final numCapas     = sesion['num_capas'] as int? ?? 0;
    final estadoSesion = sesion['estado'] as String? ?? 'guardado';
    final Color badgeColor;
    final String badgeLabel;
    switch (estadoSesion) {
      case 'pendiente': badgeColor = const Color(0xFFE8840A); badgeLabel = 'PENDIENTE'; break;
      case 'enviado':   badgeColor = const Color(0xFF34A853); badgeLabel = 'ENVIADO A PQx'; break;
      default:          badgeColor = _accent;                 badgeLabel = 'GUARDADO';
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => _DetalleScreen(
          sesion: sesion,
          exportarUrl: _exportarUrl,
          onEliminar: () {
            Navigator.pop(context);
            _eliminarSesion(index);
          },
        ),
      )).then((_) => _cargarSesiones()),
      onLongPress: () => _eliminarSesion(index),
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
                  gradient: LinearGradient(colors: [
                    AppTheme.cardBg1,
                    AppTheme.cardBg2,
                    _accent.withOpacity(0.08),
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(color: _accent.withOpacity(0.30), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: _accent.withOpacity(0.18),
                        blurRadius: 32, offset: const Offset(0, 12), spreadRadius: -4),
                    BoxShadow(color: AppTheme.cardGlowWhite, blurRadius: 0),
                  ],
                ),
                child: Stack(children: [
                  Positioned.fill(child: CustomPaint(
                      painter: _DotGridPainter(color: _accent.withOpacity(0.06)))),
                  Positioned(right: -35, top: -35,
                    child: Container(width: 200, height: 200,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: _accent.withOpacity(0.07)))),
                  Positioned(right: 25, bottom: -55,
                    child: Container(width: 155, height: 155,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                          color: _accent.withOpacity(0.05)))),
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset((size.width + 300) * _shimmerController.value - 150, 0),
                      child: Transform.rotate(angle: 0.3,
                        child: Container(width: 80,
                          decoration: BoxDecoration(gradient: LinearGradient(colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.22),
                            Colors.transparent,
                          ])))))),
                  Positioned(left: 0, top: 20, bottom: 20,
                    child: Container(width: 4,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                        gradient: const LinearGradient(
                          colors: [_accent, _accentL],
                          begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      ))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: badgeColor.withOpacity(0.28)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(width: 6, height: 6,
                              decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: badgeColor.withOpacity(0.6), blurRadius: 4)])),
                            const SizedBox(width: 5),
                            Text(badgeLabel, style: TextStyle(color: badgeColor,
                                fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                          ]),
                        ),
                      ]),
                      const Spacer(),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (casoOrigen.isNotEmpty) ...[
                            Text(casoOrigen.toUpperCase(),
                                style: TextStyle(color: _accent.withOpacity(0.65),
                                    fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
                            const SizedBox(height: 3),
                          ],
                          Text(nombre, style: TextStyle(color: AppTheme.darkText, fontSize: 22,
                              fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.1)),
                          const SizedBox(height: 7),
                          Text(
                            '$numTornillos tornillo${numTornillos != 1 ? 's' : ''}'
                            '  ·  $numCapas capa${numCapas != 1 ? 's' : ''}',
                            style: TextStyle(color: AppTheme.subtitleColor,
                                fontSize: 11.5, height: 1.4),
                          ),
                          if (fecha.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(_formatFecha(fecha),
                                style: TextStyle(color: AppTheme.subtitleColor2,
                                    fontSize: 10.5)),
                          ],
                        ])),
                        const SizedBox(width: 12),
                        // Botón ver detalle
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [_accent, _accentL],
                              begin: Alignment.topLeft, end: Alignment.bottomRight),
                            boxShadow: [BoxShadow(color: _accent.withOpacity(0.35),
                                blurRadius: 14, offset: const Offset(0, 5))],
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 22),
                        ),
                      ]),
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

  Widget _glassIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
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
          ))),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Pantalla de detalle de sesión
// ══════════════════════════════════════════════════════════════════════════════
class _DetalleScreen extends StatefulWidget {
  final Map<String, dynamic> sesion;
  final String exportarUrl;
  final VoidCallback onEliminar;

  const _DetalleScreen({
    required this.sesion,
    required this.exportarUrl,
    required this.onEliminar,
  });

  @override
  State<_DetalleScreen> createState() => _DetalleScreenState();
}

class _DetalleScreenState extends State<_DetalleScreen>
    with TickerProviderStateMixin {

  late AnimationController _bgController;
  late AnimationController _headerController;
  late Animation<double>  _headerFade;
  late Animation<Offset>  _headerSlide;
  bool _exportando = false;
  int  _numNotasVoz = 0;

  static const Color _accent  = Color(0xFFE8840A);
  static const Color _accentL = Color(0xFFFFB74D);
  static const Color _green   = Color(0xFF34A853);
  static const Color _blue    = Color(0xFF2A7FF5);

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);
    _bgController = AnimationController(
        duration: const Duration(seconds: 60), vsync: this)..repeat();
    _headerController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _headerFade  = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));
    _headerController.forward();
    final audioId = widget.sesion['audio_notas_id'] as String?;
    if (audioId != null) {
      AudioNotasService.cargar(audioId).then((notas) {
        if (mounted) setState(() => _numNotasVoz = notas.length);
      });
    }
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    _bgController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  bool _abriendoVisor = false;

  Future<void> _abrirEnVisor() async {
    setState(() => _abriendoVisor = true);
    try {
      final prefs  = await SharedPreferences.getInstance();
      final email  = prefs.getString('login_email') ?? '';
      final pass   = prefs.getString('login_password') ?? '';
      final cred   = base64Encode(utf8.encode('$email:$pass'));
      final casoOrigen = (widget.sesion['caso_origen'] as String? ?? '').toLowerCase();
      final nombre = casoOrigen.contains('varval') ? 'Varval' : 'Tabal';
      final response = await http.get(
        Uri.parse('https://profesional.planificacionquirurgica.com/listar_visores_genericos.php'),
        headers: {'Authorization': 'Basic $cred'},
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final visores = (data['visores'] as List)
              .map((e) => CasoMedico.fromJson(e))
              .toList();
          final caso = visores.firstWhere(
            (c) => c.nombre.toLowerCase().contains(nombre.toLowerCase()),
            orElse: () => throw Exception('Visor no encontrado'),
          );
          if (!mounted) return;
          setState(() => _abriendoVisor = false);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => VisorCasoScreen(
              caso: caso,
              modoGenerico: true,
              sesionGuardada: widget.sesion,
            ),
          ));
          return;
        }
      }
      throw Exception('Error ${response.statusCode}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _abriendoVisor = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo abrir el visor: $e'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  Future<void> _exportar() async {
    if (widget.exportarUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura _exportarUrl en listados_screen.dart'),
            backgroundColor: Colors.black87));
      return;
    }
    setState(() => _exportando = true);
    try {
      final prefs    = await SharedPreferences.getInstance();
      final email    = prefs.getString('login_email')    ?? '';
      final password = prefs.getString('login_password') ?? '';
      final cred     = base64Encode(utf8.encode('$email:$password'));
      final payload  = Map<String, dynamic>.from(widget.sesion);
      payload['exportado_en'] = DateTime.now().toIso8601String();
      final jsonStr  = const JsonEncoder.withIndent('  ').convert(payload);
      final request  = http.MultipartRequest('POST', Uri.parse(widget.exportarUrl))
        ..headers['Authorization'] = 'Basic $cred'
        ..fields['datos'] = jsonStr;
      final resp = await request.send();
      if (!mounted) return;
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (ok) {
        // Actualizar estado en listados_sesiones
        final sesionId = widget.sesion['id'] as String?;
        if (sesionId != null) {
          final listaRaw = prefs.getString('listados_sesiones') ?? '[]';
          final List<dynamic> lista = json.decode(listaRaw);
          final idx = lista.indexWhere((s) => s['id'] == sesionId);
          if (idx >= 0) {
            lista[idx] = {...(lista[idx] as Map<String, dynamic>), 'estado': 'enviado'};
            await prefs.setString('listados_sesiones', json.encode(lista));
          }
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Enviado a PQx correctamente' : 'Error al enviar (${resp.statusCode})'),
        backgroundColor: ok ? _green : Colors.redAccent,
        duration: const Duration(seconds: 3),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error de conexión: $e'),
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  String _formatFecha(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  // Quita prefijo numérico tipo "02.07.01xxx " del nombre
  String _limpiar(String s) {
    return s.replaceFirst(RegExp(r'^[\d.x]+\s+'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final _dark = AppTheme.darkText;
    final s          = widget.sesion;
    final nombre     = s['nombre'] as String? ?? 'Sin nombre';
    final fecha      = s['fecha'] as String? ?? '';
    final casoOrigen = s['caso_origen'] as String? ?? '';

    final capas      = (s['capas_visibles'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final tornillos  = (s['tornillos_sesion_actual'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final historial  = (s['historial_sesiones'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    // Agrupar capas por tipo
    final biomodelos = capas.where((c) => c['tipo'] == 'biomodelo').toList();
    final placas     = capas.where((c) => c['tipo'] == 'placa').toList();
    final tornCapas  = capas.where((c) => c['tipo'] == 'tornillo' || c['tipo'] == 'tornillo_cat').toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        Container(decoration: BoxDecoration(
          gradient: LinearGradient(colors: [AppTheme.bgTop, AppTheme.bgBottom],
              begin: Alignment.topCenter, end: Alignment.bottomCenter))),

        Positioned(top: -80, right: -60,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: _bgController.value * 2 * math.pi,
              child: Container(width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _accent.withOpacity(0.07), Colors.transparent])))))),

        SafeArea(
          child: Column(children: [

            // Header
            SlideTransition(position: _headerSlide,
              child: FadeTransition(opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(children: [
                    _glassIconBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(nombre, style: TextStyle(color: AppTheme.darkText, fontSize: 22,
                          fontWeight: FontWeight.w800, letterSpacing: -0.5),
                          overflow: TextOverflow.ellipsis),
                      if (fecha.isNotEmpty)
                        Text(_formatFecha(fecha),
                            style: TextStyle(color: AppTheme.subtitleColor,
                                fontSize: 11, letterSpacing: 0.1)),
                    ])),
                    // Botón eliminar
                    _glassIconBtn(Icons.delete_outline_rounded, widget.onEliminar,
                        iconColor: Colors.redAccent),
                  ]),
                ),
              ),
            ),

            // Cuerpo scrollable
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [

                  // ── Info general ──────────────────────────────────────
                  _sectionCard(children: [
                    if (casoOrigen.isNotEmpty)
                      _infoRow(Icons.folder_outlined, 'Visor origen', casoOrigen),
                    _infoRow(Icons.layers_outlined, 'Capas visibles', '${capas.length}'),
                    _infoRow(Icons.construction_outlined, 'Tornillos colocados', '${tornillos.length}'),
                    _infoRow(Icons.mic_rounded, 'Notas de voz',
                        _numNotasVoz > 0 ? '$_numNotasVoz nota${_numNotasVoz == 1 ? '' : 's'}' : '0'),
                    if (historial.isNotEmpty)
                      _infoRow(Icons.history, 'Sesiones anteriores', '${historial.length}'),
                  ]),

                  const SizedBox(height: 14),

                  // ── Biomodelos visibles ───────────────────────────────
                  if (biomodelos.isNotEmpty) ...[
                    _sectionTitle('BIOMODELOS', Icons.view_in_ar_outlined, _blue),
                    const SizedBox(height: 8),
                    _sectionCard(accentColor: _blue, children: [
                      for (final c in biomodelos)
                        _itemRow(_limpiar(c['nombre'] as String? ?? ''), _blue),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // ── Placas visibles ───────────────────────────────────
                  if (placas.isNotEmpty) ...[
                    _sectionTitle('PLACAS E IMPLANTES', Icons.medical_services_outlined, _green),
                    const SizedBox(height: 8),
                    _sectionCard(accentColor: _green, children: [
                      for (final c in placas)
                        _itemRow(_limpiar(c['nombre'] as String? ?? ''), _green),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // ── Tornillos colocados ───────────────────────────────
                  if (tornillos.isNotEmpty) ...[
                    _sectionTitle('TORNILLOS COLOCADOS', Icons.hardware_outlined, _accent),
                    const SizedBox(height: 8),
                    _sectionCard(accentColor: _accent, children: [
                      for (final t in tornillos) ...[
                        _tornilloRow(
                          nombre: _limpiar(t['nombre'] as String? ?? ''),
                          largo: t['largo_mm'] as num? ?? 0,
                        ),
                      ],
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // ── Otras capas (tipo tornillo_cat etc) ───────────────
                  if (tornCapas.isNotEmpty) ...[
                    _sectionTitle('CATÁLOGO DE TORNILLOS', Icons.category_outlined, _accent),
                    const SizedBox(height: 8),
                    _sectionCard(accentColor: _accent, children: [
                      for (final c in tornCapas)
                        _itemRow(_limpiar(c['nombre'] as String? ?? ''), _accent),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // ── Historial de sesiones ─────────────────────────────
                  if (historial.isNotEmpty) ...[
                    _sectionTitle('HISTORIAL DE SESIONES', Icons.history, _dark.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    _sectionCard(children: [
                      for (final ses in historial) ...[
                        _historialSesionRow(ses),
                      ],
                    ]),
                  ],
                ],
              ),
            ),
          ]),
        ),

        // ── Botones flotantes ─────────────────────────────────────────────
        Positioned(
          bottom: 32, left: 20, right: 20,
          child: Column(mainAxisSize: MainAxisSize.min, children: [

            // Botón "Abrir en visor"
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: GestureDetector(
                  onTap: _abriendoVisor ? null : _abrirEnVisor,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _abriendoVisor
                            ? [Colors.grey.shade400, Colors.grey.shade300]
                            : [_blue, const Color(0xFF5BA8FF)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: _blue.withOpacity(0.35),
                          blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_abriendoVisor)
                        const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      else
                        const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(_abriendoVisor ? 'Abriendo…' : 'Abrir en visor',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Botón "Exportar"
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: GestureDetector(
                  onTap: _exportando ? null : _exportar,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _exportando
                            ? [Colors.grey.shade400, Colors.grey.shade300]
                            : [_accent, _accentL],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: _accent.withOpacity(0.35),
                          blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (_exportando)
                        const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      else
                        const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(_exportando ? 'Enviando…' : 'Enviar a PQx',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ),
            ),

          ]),
        ),
      ]),
    );
  }

  // ── Widgets helpers ────────────────────────────────────────────────────────

  Widget _sectionTitle(String label, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, size: 13, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 10,
          fontWeight: FontWeight.w800, letterSpacing: 1.4)),
    ]);
  }

  Widget _sectionCard({List<Widget> children = const [], Color? accentColor}) {
    final c = accentColor ?? AppTheme.darkText.withOpacity(0.3);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withOpacity(0.20), width: 1.2),
            boxShadow: [BoxShadow(color: c.withOpacity(0.08),
                blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                Divider(height: 1, color: Colors.black.withOpacity(0.06)),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(icon, size: 16, color: AppTheme.darkText.withOpacity(0.4)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: AppTheme.darkText.withOpacity(0.55),
            fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: TextStyle(color: AppTheme.darkText,
            fontSize: 13, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _itemRow(String nombre, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        Container(width: 7, height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)])),
        const SizedBox(width: 10),
        Expanded(child: Text(nombre, style: TextStyle(color: AppTheme.darkText.withOpacity(0.85),
            fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
    );
  }

  Widget _tornilloRow({required String nombre, required num largo}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        Container(width: 7, height: 7,
          decoration: BoxDecoration(color: _accent, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: _accent.withOpacity(0.5), blurRadius: 4)])),
        const SizedBox(width: 10),
        Expanded(child: Text(nombre, style: TextStyle(color: AppTheme.darkText.withOpacity(0.85),
            fontSize: 13, fontWeight: FontWeight.w500))),
        if (largo > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _accent.withOpacity(0.25)),
            ),
            child: Text('$largo mm', style: TextStyle(color: _accent,
                fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }

  Widget _historialSesionRow(Map<String, dynamic> ses) {
    final numSesion  = ses['sesion'] as int? ?? 0;
    final tornillos  = (ses['tornillos'] as List? ?? []).cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sesión $numSesion', style: TextStyle(color: AppTheme.darkText.withOpacity(0.55),
            fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        for (final t in tornillos)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Text('· ${_limpiar(t['nombre'] as String? ?? '')}',
                style: TextStyle(color: AppTheme.darkText.withOpacity(0.70), fontSize: 12)),
          ),
      ]),
    );
  }

  Widget _glassIconBtn(IconData icon, VoidCallback onTap, {Color? iconColor}) {
    return GestureDetector(
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
            child: Icon(icon, color: iconColor ?? AppTheme.darkText, size: 18),
          ))),
    );
  }
}

// ── Dot grid ──────────────────────────────────────────────────────────────────
class _DotGridPainter extends CustomPainter {
  final Color color;
  _DotGridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    const spacing = 22.0; const radius = 1.2;
    for (double x = spacing; x < size.width;  x += spacing)
    for (double y = spacing; y < size.height; y += spacing)
      canvas.drawCircle(Offset(x, y), radius, paint);
  }
  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
