// ─────────────────────────────────────────────────────────────────────────────
//  formulario_caso_screen.dart
//  FormularioCasoScreen  → llamado desde CapturaRxScreen
//  ProcesandoIAScreen    → llamado desde MisPlanificacionesLocalesScreen
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'planificacion_local.dart';
import 'visor_caso_screen.dart';
import 'package:untitled/services/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Entry point desde CapturaRxScreen (tipoVisor + paths directos)
// ─────────────────────────────────────────────────────────────────────────────
class FormularioCasoScreen extends StatelessWidget {
  final TipoVisor tipoVisor;
  final String?   fotoPath;
  final String?   fotoLateralPath;

  const FormularioCasoScreen({
    super.key,
    required this.tipoVisor,
    this.fotoPath,
    this.fotoLateralPath,
  });

  @override
  Widget build(BuildContext context) {
    final plan = PlanificacionLocal(
      id:              DateTime.now().millisecondsSinceEpoch.toString(),
      nombrePaciente:  'Nueva planificación',
      notas:           '',
      fechaCirugia:    DateTime.now(),
      zonaImplanteId:  'tobillo',
      tipoVisor:       tipoVisor,
      fotoPath:        fotoPath,
      fotoLateralPath: fotoLateralPath,
      fechaCreacion:   DateTime.now(),
    );
    return ProcesandoIAScreen(plan: plan);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ProcesandoIAScreen — pantalla de procesado IA
// ─────────────────────────────────────────────────────────────────────────────
class ProcesandoIAScreen extends StatefulWidget {
  final PlanificacionLocal plan;
  const ProcesandoIAScreen({super.key, required this.plan});

  @override
  State<ProcesandoIAScreen> createState() => _ProcesandoIAScreenState();
}

class _ProcesandoIAScreenState extends State<ProcesandoIAScreen>
    with TickerProviderStateMixin {

  // ── Animaciones ──────────────────────────────────────────────────────────────
  late AnimationController _bgController;
  late AnimationController _headerController;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;
  late AnimationController _pulseController;
  late AnimationController _iconoController;
  late AnimationController _entradaController;
  late Animation<double>   _entradaFade;
  late Animation<Offset>   _entradaSlide;

  // ── Estado ───────────────────────────────────────────────────────────────────
  static const _pasos = [
    'Preparando radiografías',
    'Subiendo al servidor',
    'Análisis con IA quirúrgica',
    'Segmentación de huesos',
    'Generando modelo 3D',
    'Finalizando',
  ];

  int    _pasoActual   = 0;
  bool   _error        = false;
  String _mensajeError = '';
  Timer? _pasoTimer;

  static const Color _purple  = Color(0xFF8E44AD);
  static const Color _purpleL = Color(0xFFCE93D8);

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);

    _bgController = AnimationController(
        duration: const Duration(seconds: 20), vsync: this)..repeat();

    _headerController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _headerFade  = CurvedAnimation(parent: _headerController, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.4), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic));

    _pulseController = AnimationController(
        duration: const Duration(milliseconds: 1800), vsync: this)..repeat();

    _iconoController = AnimationController(
        duration: const Duration(seconds: 5), vsync: this)..repeat();

    _entradaController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _entradaFade  = CurvedAnimation(parent: _entradaController, curve: Curves.easeOut);
    _entradaSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entradaController, curve: Curves.easeOutCubic));

    _headerController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _entradaController.forward();
    });
    _procesarFoto();
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    _bgController.dispose();
    _headerController.dispose();
    _pulseController.dispose();
    _iconoController.dispose();
    _entradaController.dispose();
    _pasoTimer?.cancel();
    super.dispose();
  }

  // ── HTTP ─────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _subirYProcesarFoto(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('login_email') ?? '';
    final pass  = prefs.getString('login_password') ?? '';
    final cred  = base64Encode(utf8.encode('$email:$pass'));

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://profesional.planificacionquirurgica.com/procesar_rx.php'),
    )
      ..headers['Authorization'] = 'Basic $cred'
      ..files.add(await http.MultipartFile.fromPath('frontal', path));

    if (widget.plan.fotoLateralPath != null) {
      request.files.add(
        await http.MultipartFile.fromPath('lateral', widget.plan.fotoLateralPath!),
      );
    }

    final streamed = await request.send().timeout(const Duration(minutes: 3));
    final respStr  = await streamed.stream.bytesToString();
    debugPrint('procesar_rx → $respStr');

    if (streamed.statusCode != 200) {
      throw Exception('Error HTTP ${streamed.statusCode}: $respStr');
    }

    Map<String, dynamic> data;
    try {
      data = json.decode(respStr);
    } catch (_) {
      throw Exception('Respuesta inesperada del servidor:\n$respStr');
    }

    if (data['success'] != true) {
      final msg    = data['message'] ?? 'Error desconocido';
      final detail = data['detalle']?.toString() ?? '';
      throw Exception(detail.isNotEmpty ? '$msg\n$detail' : msg);
    }

    final glbUrl = data['glb_url']?.toString() ?? '';
    if (glbUrl.isEmpty) {
      throw Exception('El servidor no devolvió una URL de modelo válida');
    }

    return data;
  }

  void _navegarAlVisor(Map<String, dynamic> data) {
    if (!mounted) return;

    final List<GlbArchivo> biomodelos = [];
    final glbHuesos = data['glb_huesos'] as Map<String, dynamic>?;

    if (glbHuesos != null && glbHuesos.isNotEmpty) {
      const orden   = ['tibia', 'perone', 'astragalo', 'calcaneo'];
      const nombres = {
        'tibia':     'Tibia',
        'perone':    'Peroné',
        'astragalo': 'Astrágalo',
        'calcaneo':  'Calcáneo',
      };
      for (final hueso in orden) {
        final url = glbHuesos[hueso]?.toString() ?? '';
        if (url.isNotEmpty) {
          biomodelos.add(GlbArchivo(
            nombre:  nombres[hueso] ?? hueso,
            archivo: '$hueso.glb',
            url:     url,
            tipo:    'biomodelo',
          ));
        }
      }
    }

    if (biomodelos.isEmpty) {
      final glbUrl = data['glb_url']?.toString() ?? '';
      if (glbUrl.isNotEmpty) {
        biomodelos.add(GlbArchivo(
          nombre:  'Modelo IA',
          archivo: 'modelo.glb',
          url:     glbUrl,
          tipo:    'biomodelo',
        ));
      }
    }

    final caso = CasoMedico(
      id:         widget.plan.id,
      nombre:     widget.plan.nombrePaciente,
      paciente:   widget.plan.nombrePaciente,
      fechaOp:    widget.plan.fechaCirugia.toIso8601String(),
      estado:     'pendiente',
      biomodelos: biomodelos,
      placas:     [],
      tornillos:  [],
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VisorCasoScreen(
          caso:      caso,
          autoCargar: true,
          planLocal:  widget.plan,
        ),
      ),
    );
  }

  void _animarEspera() {
    int idx = 0;
    _pasoTimer = Timer.periodic(const Duration(seconds: 4), (t) {
      if (!mounted) { t.cancel(); return; }
      if (idx < _pasos.length - 2) {
        idx++;
        setState(() => _pasoActual = idx);
      }
    });
  }

  Future<void> _procesarFoto() async {
    if (widget.plan.fotoPath == null) {
      setState(() {
        _error        = true;
        _mensajeError = 'No se proporcionó ninguna radiografía';
      });
      return;
    }

    setState(() { _pasoActual = 0; _error = false; _mensajeError = ''; });
    _animarEspera();

    try {
      final data = await _subirYProcesarFoto(widget.plan.fotoPath!);
      if (!mounted) return;

      _pasoTimer?.cancel();
      setState(() => _pasoActual = _pasos.length - 1);
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      _navegarAlVisor(data);

    } catch (e) {
      if (!mounted) return;
      _pasoTimer?.cancel();
      setState(() {
        _error        = true;
        _mensajeError = e.toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Error backend: ', '');
      });
    }
  }

  void _reintentar() {
    _pasoTimer?.cancel();
    _procesarFoto();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bgTop = AppTheme.bgTop;
    final bgBot = AppTheme.bgBottom;
    final dark  = AppTheme.darkText;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [

        // Fondo
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bgTop, bgBot],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // Orbe superior
        Positioned(top: -80, right: -60,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: _bgController.value * 2 * math.pi,
              child: Container(width: 320, height: 320,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _purple.withOpacity(0.15), Colors.transparent])))))),

        // Orbe inferior
        Positioned(bottom: 60, left: -80,
          child: AnimatedBuilder(animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: -_bgController.value * 2 * math.pi,
              child: Container(width: 280, height: 280,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _purple.withOpacity(0.09), Colors.transparent])))))),

        SafeArea(
          child: Column(children: [

            // ── Header ────────────────────────────────────────────────────────
            SlideTransition(position: _headerSlide,
              child: FadeTransition(opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(children: [
                    _glassBtn(Icons.arrow_back_ios_new_rounded,
                        () => Navigator.pop(context)),
                    const SizedBox(width: 16),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _error ? 'Error en el proceso' : 'Procesando IA',
                          style: TextStyle(color: dark, fontSize: 24,
                              fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        Text(
                          _error
                              ? 'Algo salió mal'
                              : 'Generando modelo 3D del tobillo',
                          style: TextStyle(
                              color: AppTheme.subtitleColor, fontSize: 12),
                        ),
                      ],
                    )),
                    if (!_error) _badgeIA(),
                  ]),
                ),
              ),
            ),

            // ── Cuerpo ────────────────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _entradaFade,
                child: SlideTransition(
                  position: _entradaSlide,
                  child: _error ? _buildError() : _buildProcesando(),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Pantalla de procesado ─────────────────────────────────────────────────────

  Widget _buildProcesando() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(children: [

        // Animación central
        SizedBox(
          width: 200, height: 200,
          child: Stack(alignment: Alignment.center, children: [

            // Anillos de pulso
            ...List.generate(3, (i) => AnimatedBuilder(
              animation: _pulseController,
              builder: (_, __) {
                final delay = i / 3.0;
                final t = ((_pulseController.value - delay) % 1.0).abs();
                return Opacity(
                  opacity: (1.0 - t).clamp(0.0, 1.0) * 0.55,
                  child: Container(
                    width:  55 + t * 135,
                    height: 55 + t * 135,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _purple.withOpacity(0.55 * (1 - t)),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            )),

            // Card central con icono
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    gradient: LinearGradient(colors: [
                      AppTheme.cardBg1,
                      _purple.withOpacity(0.18),
                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    border: Border.all(
                        color: _purple.withOpacity(0.40), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: _purple.withOpacity(0.28),
                        blurRadius: 28, offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _iconoController,
                    builder: (_, __) => Transform.rotate(
                      angle: math.sin(_iconoController.value * 2 * math.pi) * 0.18,
                      child: const Icon(Icons.auto_awesome_rounded,
                          color: _purple, size: 42),
                    ),
                  ),
                ),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 28),

        // Card de pasos
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.cardBg1,
                  AppTheme.cardBg2,
                  _purple.withOpacity(0.05),
                ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cardBorder, width: 1.3),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withOpacity(0.08),
                    blurRadius: 20, offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: List.generate(_pasos.length, (i) {
                  final done    = i < _pasoActual;
                  final current = i == _pasoActual;

                  return Padding(
                    padding: EdgeInsets.only(
                        bottom: i < _pasos.length - 1 ? 14 : 0),
                    child: Row(children: [

                      // Indicador circular
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? _purple
                              : current
                                  ? _purple.withOpacity(0.15)
                                  : AppTheme.isDark.value
                                      ? Colors.white.withOpacity(0.07)
                                      : Colors.black.withOpacity(0.05),
                          border: current
                              ? Border.all(
                                  color: _purple.withOpacity(0.50), width: 1.5)
                              : null,
                        ),
                        child: done
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14)
                            : current
                                ? AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (_, __) => Center(
                                      child: Container(
                                        width: 9, height: 9,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _purple.withOpacity(
                                              0.55 + _pulseController.value * 0.45),
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                      ),

                      const SizedBox(width: 14),

                      // Texto del paso
                      Expanded(
                        child: Text(
                          _pasos[i],
                          style: TextStyle(
                            color: done
                                ? AppTheme.darkText
                                : current
                                    ? _purple
                                    : AppTheme.subtitleColor2,
                            fontSize: 13.5,
                            fontWeight: (done || current)
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),

                      if (done && i == _pasos.length - 1)
                        const Icon(Icons.star_rounded, color: _purple, size: 15),
                    ]),
                  );
                }),
              ),
            ),
          ),
        ),

        const SizedBox(height: 18),

        // Barra de progreso
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_pasoActual + 1) / _pasos.length,
            backgroundColor: AppTheme.isDark.value
                ? Colors.white.withOpacity(0.09)
                : Colors.black.withOpacity(0.07),
            valueColor: const AlwaysStoppedAnimation<Color>(_purple),
            minHeight: 4,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          'Paso ${_pasoActual + 1} de ${_pasos.length}',
          style: TextStyle(
              color: AppTheme.subtitleColor,
              fontSize: 12, fontWeight: FontWeight.w500),
        ),

        const SizedBox(height: 20),

        // Nota informativa
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(children: [
                Icon(Icons.info_outline_rounded,
                    color: _purple.withOpacity(0.60), size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Este proceso puede tardar hasta 3 minutos.\nNo cierres la aplicación.',
                    style: TextStyle(
                        color: AppTheme.subtitleColor,
                        fontSize: 12, height: 1.45),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Pantalla de error ─────────────────────────────────────────────────────────

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          // Icono error
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: LinearGradient(colors: [
                    AppTheme.cardBg1,
                    Colors.red.withOpacity(0.12),
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  border: Border.all(
                      color: Colors.red.withOpacity(0.32), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withOpacity(0.12),
                      blurRadius: 24, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: Colors.redAccent, size: 42),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Tarjeta de mensaje
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppTheme.cardBg1,
                    Colors.red.withOpacity(0.05),
                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                      color: Colors.red.withOpacity(0.20), width: 1.2),
                ),
                child: Column(children: [
                  Text('No se pudo procesar',
                      style: TextStyle(
                          color: AppTheme.darkText,
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text(
                    _mensajeError.isNotEmpty
                        ? _mensajeError
                        : 'Error desconocido',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.subtitleColor,
                        fontSize: 13.5, height: 1.5),
                  ),
                ]),
              ),
            ),
          ),

          const SizedBox(height: 28),

          // Botón reintentar
          GestureDetector(
            onTap: _reintentar,
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(17),
                gradient: const LinearGradient(
                  colors: [_purple, _purpleL],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _purple.withOpacity(0.35),
                    blurRadius: 18, offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 21),
                  SizedBox(width: 9),
                  Text('Reintentar',
                      style: TextStyle(color: Colors.white,
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar',
                style: TextStyle(
                    color: AppTheme.subtitleColor, fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // ── Widgets auxiliares ────────────────────────────────────────────────────────

  Widget _badgeIA() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _purple.withOpacity(0.28)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, __) => Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: _purple,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: _purple.withOpacity(0.45 + _pulseController.value * 0.55),
                blurRadius: 5,
              )],
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text('IA activa',
            style: TextStyle(color: _purple,
                fontSize: 8.5, fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
      ]),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) => GestureDetector(
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
          ),
          child: Icon(icon, color: AppTheme.darkText, size: 18),
        ),
      ),
    ),
  );
}
