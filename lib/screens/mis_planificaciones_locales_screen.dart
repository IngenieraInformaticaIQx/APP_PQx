// ─────────────────────────────────────────────────────────────────────────────
//  mis_planificaciones_locales_screen.dart
//  Lista de planificaciones creadas desde "Nuevo caso" (guardadas localmente).
//  Misma estética glass que el resto de la app.
//  Integrar en menu_screen.dart: case 3 → MisPlanificacionesLocalesScreen()
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'planificacion_local.dart';
import 'formulario_caso_screen.dart';
import 'visor_caso_screen.dart';
import 'package:untitled/services/app_theme.dart';

class MisPlanificacionesLocalesScreen extends StatefulWidget {
  const MisPlanificacionesLocalesScreen({super.key});

  @override
  State<MisPlanificacionesLocalesScreen> createState() =>
      _MisPlanificacionesLocalesScreenState();
}

class _MisPlanificacionesLocalesScreenState
    extends State<MisPlanificacionesLocalesScreen>
    with TickerProviderStateMixin {

  late AnimationController _bgController;
  late AnimationController _headerController;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;

  List<PlanificacionLocal> _planes = [];
  bool _cargando = true;
  final Map<String, String> _estadosPlan = {};

  static const Color _accent   = Color(0xFF2A7FF5);

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
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final lista = await PlanificacionRepository.cargarTodas();
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final estados = <String, String>{};
    for (final p in lista) {
      final e = prefs.getString('estado_plan_${p.id}');
      if (e != null) estados[p.id] = e;
    }
    setState(() {
      _planes = lista;
      // Fusionar: prefs tiene prioridad, pero conservar estados en memoria
      // si prefs aún no los refleja (evita race condition con _cambiarEstadoAEnviado)
      final merged = Map<String, String>.from(_estadosPlan);
      merged.removeWhere((k, _) => !lista.any((p) => p.id == k));
      merged.addAll(estados);
      _estadosPlan..clear()..addAll(merged);
      _cargando = false;
    });
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    _bgController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  // ── Abrir visor de una planificación ya guardada ──────────────────────────
  Future<void> _abrirPlan(PlanificacionLocal plan) async {
    if (plan.tipoVisor == TipoVisor.radiografia) {
      // Flujo radiografía: muestra pantalla procesado / resultado IA
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProcesandoIAScreen(plan: plan)));
      return;
    }
    // Flujo visor 3D: carga el visor genérico
    _showCargandoOverlay(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('login_email') ?? '';
      final pass  = prefs.getString('login_password') ?? '';
      final cred  = base64Encode(utf8.encode('$email:$pass'));
      final nombre = plan.tipoVisor == TipoVisor.tabal ? 'Tabal' : 'Varval';
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
            (c) => c.nombre.toLowerCase().contains(nombre.toLowerCase()),
            orElse: () => throw Exception('Visor no encontrado'),
          );
          if (!mounted) return;
          _showCargandoOverlay(false);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) =>
                  VisorCasoScreen(
                    caso: caso,
                    modoGenerico: true,
                    planLocal: plan,
                    onEstadoCambiado: (nuevoEstado) {
                      if (mounted) setState(() => _estadosPlan[plan.id] = nuevoEstado);
                    },
                  )))
              .then((_) => _cargar());
          return;
        }
      }
      throw Exception('Error al cargar el visor');
    } catch (e) {
      if (!mounted) return;
      _showCargandoOverlay(false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('No se pudo cargar el visor: $e'),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ));
    }
  }

  bool _mostraCargando = false;
  void _showCargandoOverlay(bool v) {
    if (mounted) setState(() => _mostraCargando = v);
  }

  Future<void> _confirmarEliminar(PlanificacionLocal plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar planificación',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('¿Eliminar el caso de ${plan.nombrePaciente}?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await PlanificacionRepository.eliminar(plan.id);
      _cargar();
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
                    const Color(0xFFE8840A).withOpacity(0.11),
                    Colors.transparent])))))),

        Positioned(bottom: 60, left: -80,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: -_bgController.value * 2 * math.pi,
              child: Container(width: 260, height: 260,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _accent.withOpacity(0.09), Colors.transparent])))))),

        Positioned.fill(child: CustomPaint(
            painter: _DotGridPainter(color: _dark.withOpacity(0.04)))),

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
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Mis planificaciones',
                            style: TextStyle(color: _dark, fontSize: 22,
                                fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        Text('Casos creados localmente',
                            style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
                      ]),
                    ),
                    // Badge total
                    if (!_cargando)
                      _glassCard(
                        child: Text('${_planes.length}',
                            style: TextStyle(color: _accent,
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Lista / empty / loading
            Expanded(
              child: _cargando
                  ? _buildLoader()
                  : _planes.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          color: _accent,
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            itemCount: _planes.length,
                            itemBuilder: (_, i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildCard(_planes[i]),
                            ),
                          ),
                        ),
            ),
          ]),
        ),

        if (_mostraCargando)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: AppTheme.cardBg1.withOpacity(0.40),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
                    const SizedBox(height: 14),
                    Text('Cargando visor…',
                        style: TextStyle(color: AppTheme.subtitleColor,
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  // ── Card de cada planificación ─────────────────────────────────────────────

  Widget _buildCard(PlanificacionLocal plan) {
    final acent  = _colorVisor(plan.tipoVisor);
    final acentL = _colorVisorLight(plan.tipoVisor);

    return GestureDetector(
      onTap: () => _abrirPlan(plan),
      onLongPress: () => _confirmarEliminar(plan),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppTheme.cardBg1,
                AppTheme.cardBg2,
                acent.withOpacity(0.06),
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.cardBorder, width: 1.3),
              boxShadow: [
                BoxShadow(color: acent.withOpacity(0.10),
                    blurRadius: 20, offset: const Offset(0, 6), spreadRadius: -3),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [

                // Barra lateral de color
                Container(
                  width: 3.5,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [acent, acentL],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Icono zona
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: acent.withOpacity(0.10),
                    border: Border.all(color: acent.withOpacity(0.22)),
                  ),
                  child: Center(
                    child: Text(plan.zonaIcono,
                        style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),

                // Textos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plan.nombrePaciente,
                          style: TextStyle(color: AppTheme.darkText, fontSize: 14.5,
                              fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Row(children: [
                        Text(plan.zonaLabel,
                            style: TextStyle(color: AppTheme.subtitleColor,
                                fontSize: 11.5)),
                        Text('  ·  ', style: TextStyle(
                            color: AppTheme.subtitleColor2)),
                        Text(plan.visorLabel,
                            style: TextStyle(color: acent.withOpacity(0.80),
                                fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 10, color: AppTheme.subtitleColor2),
                        const SizedBox(width: 4),
                        Text(
                          'Cirugía: ${plan.fechaCirugia.day.toString().padLeft(2,'0')}/'
                          '${plan.fechaCirugia.month.toString().padLeft(2,'0')}/'
                          '${plan.fechaCirugia.year}',
                          style: TextStyle(color: AppTheme.subtitleColor,
                              fontSize: 10.5),
                        ),
                        if (plan.fotoPath != null) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.image_outlined,
                              size: 10, color: acent.withOpacity(0.55)),
                          const SizedBox(width: 3),
                          Text('Rx adjunta',
                              style: TextStyle(color: acent.withOpacity(0.65),
                                  fontSize: 10)),
                        ],
                      ]),
                    ],
                  ),
                ),

                // Badge estado
                _buildEstadoBadge(_estadosPlan[plan.id]),
                const SizedBox(width: 8),

                // Flecha
                Icon(Icons.arrow_forward_ios_rounded,
                    color: acent.withOpacity(0.50), size: 14),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Estado vacío ───────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              decoration: BoxDecoration(
                color: AppTheme.cardBg1,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE8840A).withOpacity(0.12),
                    border: Border.all(
                        color: const Color(0xFFE8840A).withOpacity(0.22)),
                  ),
                  child: const Icon(Icons.assignment_outlined,
                      color: Color(0xFFE8840A), size: 30),
                ),
                const SizedBox(height: 18),
                Text('Sin planificaciones',
                    style: TextStyle(color: AppTheme.darkText, fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('Crea tu primer caso desde\n"Nuevo caso" en el menú principal.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.subtitleColor,
                        fontSize: 13.5, height: 1.5)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoader() {
    return Center(
      child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
    );
  }

  // ── Badge de estado ────────────────────────────────────────────────────────

  Widget _buildEstadoBadge(String? estado) {
    final Color color;
    final String label;
    switch (estado) {
      case 'pendiente':
        color = const Color(0xFFE8840A);
        label = 'Pendiente';
        break;
      case 'enviado':
        color = const Color(0xFF34A853);
        label = 'Enviado a PQx';
        break;
      default:
        color = const Color(0xFF9E9E9E);
        label = 'Guardado';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35), width: 1),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 9.5,
              fontWeight: FontWeight.w700)),
    );
  }

  // ── Helpers colores ────────────────────────────────────────────────────────

  Color _colorVisor(TipoVisor t) {
    switch (t) {
      case TipoVisor.tabal:       return const Color(0xFF2A7FF5);
      case TipoVisor.varval:      return const Color(0xFF34A853);
      case TipoVisor.radiografia: return const Color(0xFF8E44AD);
    }
  }

  Color _colorVisorLight(TipoVisor t) {
    switch (t) {
      case TipoVisor.tabal:       return const Color(0xFF5BA8FF);
      case TipoVisor.varval:      return const Color(0xFF81C995);
      case TipoVisor.radiografia: return const Color(0xFFCE93D8);
    }
  }

  // ── Widgets auxiliares ─────────────────────────────────────────────────────

  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding ?? const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.lockedCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.80), width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: _glassCard(
        child: Icon(icon, color: AppTheme.darkText, size: 18),
        padding: const EdgeInsets.all(10),
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
    for (double x = s; x < size.width;  x += s)
    for (double y = s; y < size.height; y += s)
      canvas.drawCircle(Offset(x, y), r, p);
  }
  @override
  bool shouldRepaint(_DotGridPainter o) => o.color != color;
}
