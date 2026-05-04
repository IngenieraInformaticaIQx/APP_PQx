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
  String? _planSeleccionadoId;
  double _previewRotX = -0.18;
  double _previewRotY = 0.35;
  double _previewZoom = 1.0;
  Offset _previewPan = Offset.zero;

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
      if (lista.isEmpty) {
        _planSeleccionadoId = null;
      } else if (_planSeleccionadoId == null ||
          !lista.any((p) => p.id == _planSeleccionadoId)) {
        _planSeleccionadoId = lista.first.id;
      }
      _cargando = false;
    });
  }

  PlanificacionLocal? get _planSeleccionado {
    if (_planes.isEmpty) return null;
    for (final plan in _planes) {
      if (plan.id == _planSeleccionadoId) return plan;
    }
    return _planes.first;
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
      // Flujo radiografia: medicion manual milimetrica, sin API externa.
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => MedicionManualMilimetricaScreen(plan: plan)));
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
                      : LayoutBuilder(builder: (context, constraints) {
                          final desktop = constraints.maxWidth >= 980;
                          if (desktop) return _buildDesktopWorkspace(_dark);
                          return RefreshIndicator(
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
                          );
                        }),
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

  Widget _buildDesktopWorkspace(Color dark) {
    final selected = _planSeleccionado;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(width: 220, child: _buildDesktopSidebar(dark)),
        const SizedBox(width: 14),
        SizedBox(width: 410, child: _buildDesktopList(dark)),
        const SizedBox(width: 14),
        Expanded(child: _buildPreviewPanel(dark, selected)),
      ]),
    );
  }

  Widget _buildDesktopSidebar(Color dark) {
    final rx = _planes.where((p) => p.tipoVisor == TipoVisor.radiografia).length;
    final tabal = _planes.where((p) => p.tipoVisor == TipoVisor.tabal).length;
    final varval = _planes.where((p) => p.tipoVisor == TipoVisor.varval).length;
    final enviados = _estadosPlan.values.where((e) => e == 'enviado').length;
    final pendientes = _estadosPlan.values.where((e) => e == 'pendiente').length;

    return _desktopSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: _accent.withOpacity(0.12),
              border: Border.all(color: _accent.withOpacity(0.24)),
            ),
            child: const Icon(Icons.dashboard_customize_outlined,
                color: _accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('Panel',
              style: TextStyle(color: dark, fontSize: 17,
                  fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 18),
        _desktopMetric('Total', _planes.length.toString(), _accent),
        _desktopMetric('RX manual', rx.toString(), const Color(0xFF8E44AD)),
        _desktopMetric('Tabal', tabal.toString(), const Color(0xFF2A7FF5)),
        _desktopMetric('Varval', varval.toString(), const Color(0xFF34A853)),
        const Spacer(),
        _desktopMetric('Pendientes', pendientes.toString(), const Color(0xFFE8840A)),
        _desktopMetric('Enviados', enviados.toString(), const Color(0xFF34A853)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _cargar,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          label: const Text('Actualizar'),
        ),
      ]),
    );
  }

  Widget _desktopMetric(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.18)),
        ),
        child: Row(children: [
          Expanded(child: Text(label,
              style: TextStyle(color: AppTheme.subtitleColor, fontSize: 11.5,
                  fontWeight: FontWeight.w700))),
          Text(value,
              style: TextStyle(color: color, fontSize: 14,
                  fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }

  Widget _buildDesktopList(Color dark) {
    return _desktopSurface(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Row(children: [
            Expanded(child: Text('Casos',
                style: TextStyle(color: dark, fontSize: 17,
                    fontWeight: FontWeight.w800))),
            Text('${_planes.length}',
                style: TextStyle(color: AppTheme.subtitleColor,
                    fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ),
        Divider(height: 1, color: AppTheme.cardBorder),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: _planes.length,
            itemBuilder: (_, i) {
              final plan = _planes[i];
              final selected = plan.id == _planSeleccionado?.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildCompactPlanTile(plan, selected: selected),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _buildCompactPlanTile(PlanificacionLocal plan, {required bool selected}) {
    final acent = _colorVisor(plan.tipoVisor);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _planSeleccionadoId = plan.id),
      onDoubleTap: () => _abrirPlan(plan),
      onLongPress: () => _confirmarEliminar(plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: selected ? acent.withOpacity(0.12) : AppTheme.cardBg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? acent.withOpacity(0.45) : AppTheme.cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: acent.withOpacity(0.12),
            ),
            child: Center(child: Text(plan.zonaIcono,
                style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.nombrePaciente,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.darkText, fontSize: 13,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('${plan.zonaLabel}  ·  ${_fecha(plan.fechaCirugia)}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.subtitleColor,
                      fontSize: 10.8)),
            ],
          )),
          const SizedBox(width: 8),
          _buildEstadoBadge(_estadosPlan[plan.id]),
        ]),
      ),
    );
  }

  Widget _buildPreviewPanel(Color dark, PlanificacionLocal? plan) {
    if (plan == null) {
      return _desktopSurface(
        child: Center(child: Text('Selecciona un caso',
            style: TextStyle(color: AppTheme.subtitleColor))),
      );
    }
    final acent = _colorVisor(plan.tipoVisor);
    return _desktopSurface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: acent.withOpacity(0.12),
              border: Border.all(color: acent.withOpacity(0.24)),
            ),
            child: Center(child: Text(plan.zonaIcono,
                style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.nombrePaciente,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: dark, fontSize: 20,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${plan.zonaLabel} · ${plan.visorLabel}',
                  style: TextStyle(color: AppTheme.subtitleColor,
                      fontSize: 12)),
            ],
          )),
          _buildEstadoBadge(_estadosPlan[plan.id]),
        ]),
        const SizedBox(height: 18),
        Expanded(flex: 5, child: _buildMiniPreview(plan)),
        const SizedBox(height: 14),
        _detailRow(Icons.calendar_today_outlined, 'Fecha cirugía',
            _fecha(plan.fechaCirugia)),
        _detailRow(Icons.category_outlined, 'Tipo', plan.visorLabel),
        _detailRow(Icons.image_outlined, 'Radiografía',
            plan.fotoPath == null ? 'Sin imagen adjunta' : 'Imagen adjunta'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _abrirPlan(plan),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Abrir caso'),
              style: ElevatedButton.styleFrom(
                backgroundColor: acent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: () => _confirmarEliminar(plan),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Eliminar'),
          ),
        ]),
      ]),
    );
  }

  Widget _buildMiniPreview(PlanificacionLocal plan) {
    final acent = _colorVisor(plan.tipoVisor);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GestureDetector(
        onPanUpdate: (d) {
          setState(() {
            _previewRotY += d.delta.dx * 0.01;
            _previewRotX -= d.delta.dy * 0.01;
            _previewRotX = _previewRotX.clamp(-1.1, 1.1).toDouble();
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg2,
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Stack(children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _MiniPreviewPainter(
                  color: acent,
                  rotX: _previewRotX,
                  rotY: _previewRotY,
                  zoom: _previewZoom,
                  pan: _previewPan,
                ),
              ),
            ),
            Positioned(
              left: 12, top: 10,
              child: Text('Preview 3D',
                  style: TextStyle(color: AppTheme.subtitleColor,
                      fontSize: 11, fontWeight: FontWeight.w800)),
            ),
            Positioned(
              right: 10, bottom: 10,
              child: Row(children: [
                _miniTool(Icons.remove_rounded, () {
                  setState(() => _previewZoom =
                      (_previewZoom - 0.08).clamp(0.72, 1.45).toDouble());
                }),
                const SizedBox(width: 6),
                _miniTool(Icons.center_focus_strong_rounded, () {
                  setState(() {
                    _previewRotX = -0.18;
                    _previewRotY = 0.35;
                    _previewZoom = 1.0;
                    _previewPan = Offset.zero;
                  });
                }),
                const SizedBox(width: 6),
                _miniTool(Icons.add_rounded, () {
                  setState(() => _previewZoom =
                      (_previewZoom + 0.08).clamp(0.72, 1.45).toDouble());
                }),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _miniTool(IconData icon, VoidCallback onTap) {
    return Material(
      color: AppTheme.lockedCardBg,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: SizedBox(width: 30, height: 30,
            child: Icon(icon, size: 16, color: AppTheme.darkText)),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 16, color: AppTheme.subtitleColor),
        const SizedBox(width: 9),
        SizedBox(width: 92, child: Text(label,
            style: TextStyle(color: AppTheme.subtitleColor, fontSize: 11.5))),
        Expanded(child: Text(value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppTheme.darkText, fontSize: 12.5,
                fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _desktopSurface({required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBg1,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.cardBorder, width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  String _fecha(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}/'
      '${fecha.year}';

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

class _MiniPreviewPainter extends CustomPainter {
  final Color color;
  final double rotX;
  final double rotY;
  final double zoom;
  final Offset pan;

  _MiniPreviewPainter({
    required this.color,
    required this.rotX,
    required this.rotY,
    required this.zoom,
    required this.pan,
  });

  Offset _project(double x, double y, double z, Size size) {
    final cosY = math.cos(rotY);
    final sinY = math.sin(rotY);
    final cosX = math.cos(rotX);
    final sinX = math.sin(rotX);

    final x1 = x * cosY + z * sinY;
    final z1 = -x * sinY + z * cosY;
    final y1 = y * cosX - z1 * sinX;
    final z2 = y * sinX + z1 * cosX;
    final perspective = 280 / (280 + z2);
    final scale = math.min(size.width, size.height) / 190 * zoom * perspective;
    return Offset(
      size.width / 2 + pan.dx + x1 * scale,
      size.height / 2 + pan.dy - y1 * scale,
    );
  }

  void _bone(Canvas canvas, Size size, List<List<double>> pts, Paint paint) {
    final path = Path();
    for (int i = 0; i < pts.length; i++) {
      final p = _project(pts[i][0], pts[i][1], pts[i][2], size);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color.withOpacity(0.05)
      ..strokeWidth = 1;
    for (double x = 18; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 18; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.12)
      ..strokeWidth = 18 * zoom
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final bone = Paint()
      ..color = color.withOpacity(0.72)
      ..strokeWidth = 13 * zoom
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final highlight = Paint()
      ..color = Colors.white.withOpacity(0.55)
      ..strokeWidth = 4 * zoom
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final shapes = <List<List<double>>>[
      [[-24, 72, 0], [-20, 28, 2], [-16, -15, 4]],
      [[18, 70, -2], [20, 24, 0], [24, -18, 2]],
      [[-18, -18, 3], [4, -34, 5], [30, -38, 7]],
      [[4, -36, 2], [-18, -55, -1], [-48, -64, -6]],
      [[20, -38, 6], [42, -52, 8], [62, -60, 6]],
    ];

    for (final s in shapes) {
      _bone(canvas, size, s, shadow);
    }
    for (final s in shapes) {
      _bone(canvas, size, s, bone);
    }
    for (final s in shapes) {
      _bone(canvas, size, s, highlight);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniPreviewPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.rotX != rotX ||
      oldDelegate.rotY != rotY ||
      oldDelegate.zoom != zoom ||
      oldDelegate.pan != pan;
}
