import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:gal/gal.dart';
import 'dart:io';
import 'visor_windows.dart';
import 'planificacion_local.dart';
import 'package:untitled/services/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:untitled/widgets/audio_notas_panel.dart';
import 'package:untitled/services/audio_notas_service.dart';
import 'visor_pdf_screen.dart';

// ── Modelos de datos ──────────────────────────────────────────────────────

class GlbArchivo {
  final String nombre;
  final String archivo;
  final String url;
  final String tipo;

  const GlbArchivo({
    required this.nombre,
    required this.archivo,
    required this.url,
    required this.tipo,
  });

  factory GlbArchivo.fromJson(Map<String, dynamic> j, String tipo) => GlbArchivo(
        nombre:  j['nombre']  ?? '',
        archivo: j['archivo'] ?? '',
        url:     j['url']     ?? '',
        tipo:    tipo,
      );
}

class GrupoPlagas {
  final String nombre;
  final List<GlbArchivo> placas;
  const GrupoPlagas({required this.nombre, required this.placas});
  factory GrupoPlagas.fromJson(Map<String, dynamic> j) => GrupoPlagas(
        nombre: j['nombre'] ?? '',
        placas: (j['placas'] as List? ?? [])
            .map((e) => GlbArchivo.fromJson(e, 'placa'))
            .toList(),
      );
}

class GrupoTornillos {
  final String nombre;
  final List<GlbArchivo> tornillos;
  const GrupoTornillos({required this.nombre, required this.tornillos});
  factory GrupoTornillos.fromJson(Map<String, dynamic> j) => GrupoTornillos(
        nombre: j['nombre'] ?? '',
        tornillos: (j['tornillos'] as List? ?? [])
            .map((e) => GlbArchivo.fromJson(e, 'tornillo'))
            .toList(),
      );
}

class CasoMedico {
  final String id;
  final String nombre;
  final String paciente;
  final String fechaOp;
  final String estado;
  final List<GlbArchivo> biomodelos;
  final List<GrupoPlagas> placas;
  final List<GrupoTornillos> tornillos;

  const CasoMedico({
    required this.id,
    required this.nombre,
    required this.paciente,
    required this.fechaOp,
    required this.estado,
    required this.biomodelos,
    required this.placas,
    required this.tornillos,
  });

  List<GlbArchivo> get todosGlb {
    final lista = <GlbArchivo>[...biomodelos];
    for (final g in placas) lista.addAll(g.placas);
    return lista;
  }

  List<GlbArchivo> get todosTornillos {
    final lista = <GlbArchivo>[];
    for (final g in tornillos) lista.addAll(g.tornillos);
    return lista;
  }

  factory CasoMedico.fromJson(Map<String, dynamic> j) => CasoMedico(
        id:         j['id']       ?? '',
        nombre:     j['nombre']   ?? j['id'] ?? '',
        paciente:   j['paciente'] ?? '',
        fechaOp:    j['fecha_op'] ?? '',
        estado:     j['estado']   ?? 'pendiente',
        biomodelos: (j['biomodelos'] as List? ?? [])
            .map((e) => GlbArchivo.fromJson(e, 'biomodelo'))
            .toList(),
        placas: (j['placas'] as List? ?? [])
            .map((e) => GrupoPlagas.fromJson(e))
            .toList(),
        tornillos: (j['tornillos'] as List? ?? [])
            .map((e) => GrupoTornillos.fromJson(e))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'id':         id,
    'nombre':     nombre,
    'paciente':   paciente,
    'fecha_op':   fechaOp,
    'estado':     estado,
    'biomodelos': biomodelos.map((e) => {
      'nombre':  e.nombre,
      'archivo': e.archivo,
      'url':     e.url,
    }).toList(),
    'placas': placas.map((g) => {
      'nombre': g.nombre,
      'placas': g.placas.map((e) => {
        'nombre':  e.nombre,
        'archivo': e.archivo,
        'url':     e.url,
      }).toList(),
    }).toList(),
    'tornillos': tornillos.map((g) => {
      'nombre': g.nombre,
      'tornillos': g.tornillos.map((e) => {
        'nombre':  e.nombre,
        'archivo': e.archivo,
        'url':     e.url,
      }).toList(),
    }).toList(),
  };
}

class _C {
  static const accentBone    = Color(0xFF2196F3);
  static const accentImplant = Color(0xFF4CAF50);
  static const accentScrew   = Color(0xFFFF9800);
}

class Medicion3D {
  final String id;
  double mm;
  bool visible;
  Medicion3D({required this.id, required this.mm, this.visible = true});
}

class Nota3D {
  final String id;
  final String texto;
  final double x, y, z; // posición 3D mundo
  bool visible;
  Nota3D({required this.id, required this.texto,
          required this.x, required this.y, required this.z,
          this.visible = true});
}

class TornilloColocado {
  final String instanceId;
  final String glbId;
  final String nombre;
  final String cilindroId;
  final double largo;
  final double hx, hy, hz;
  final double hnx, hny, hnz;
  final double hdx, hdy, hdz;
  final bool usarTrayectoria;
  bool visible;
  bool reglaVisible;
  TornilloColocado({
    required this.instanceId,
    required this.glbId,
    required this.nombre,
    this.cilindroId = '',
    this.largo = 0,
    this.hx = 0, this.hy = 0, this.hz = 0,
    this.hnx = 0, this.hny = 0, this.hnz = 0,
    this.hdx = 0, this.hdy = 0, this.hdz = 0,
    this.usarTrayectoria = false,
    this.visible = true,
    this.reglaVisible = true,
  });
}

// Datos del tap recibidos del JS
class _TapData {
  final double x, y, z;
  final double nx, ny, nz;
  final double sx, sy;
  final String? cilindroId;
  final double dx, dy, dz; // dirección de inserción (hacia dentro)
  final bool usarTrayectoria;
  _TapData({
    required this.x, required this.y, required this.z,
    required this.nx, required this.ny, required this.nz,
    required this.sx, required this.sy,
    this.cilindroId,
    this.dx = 0, this.dy = 0, this.dz = 0,
    this.usarTrayectoria = false,
  });
  factory _TapData.fromJson(Map<String, dynamic> j) => _TapData(
    x:  (j['x']  as num).toDouble(), y:  (j['y']  as num).toDouble(), z:  (j['z']  as num).toDouble(),
    nx: (j['nx'] as num).toDouble(), ny: (j['ny'] as num).toDouble(), nz: (j['nz'] as num).toDouble(),
    sx: (j['sx'] as num).toDouble(), sy: (j['sy'] as num).toDouble(),
    cilindroId: j['cilindroId'] as String?,
    dx: (j['dx'] as num? ?? 0).toDouble(),
    dy: (j['dy'] as num? ?? 0).toDouble(),
    dz: (j['dz'] as num? ?? 0).toDouble(),
    usarTrayectoria: j['usarTrayectoria'] as bool? ?? false,
  );
}

// ═══════════════════════════════════════════════════════════════════════════
class VisorCasoScreen extends StatefulWidget {
  final CasoMedico caso;
  /// Si true, carga y muestra todas las capas automáticamente al abrirse.
  /// Únlo desde acceso rápido para que el visor arranque con todo visible.
  final bool autoCargar;
  /// Si true, es un visor genérico (Tabal u otros recursos compartidos).
  /// Oculta cualquier control de estado (validar/firmar/modificar) que se añada en el futuro.
  final bool modoGenerico;
  /// Callback que se invoca cuando se exporta correctamente y el estado
  /// cambia a 'enviado'. Permite que CasosScreen actualice el color del card.
  final void Function(String nuevoEstado)? onEstadoCambiado;
  final Map<String, dynamic>? sesionGuardada;
  /// Plan local (solo cuando viene del flujo IA). Permite guardar en mis planificaciones.
  final PlanificacionLocal? planLocal;
  const VisorCasoScreen({
    super.key,
    required this.caso,
    this.autoCargar = false,
    this.modoGenerico = false,
    this.onEstadoCambiado,
    this.sesionGuardada,
    this.planLocal,
  });

  @override
  State<VisorCasoScreen> createState() => _VisorCasoScreenState();
}

// ── RegExp estáticos (compilados una sola vez) ────────────────────────────
// Evita recompilar la expresión regular en cada llamada a _parsearTornillo
const _kRegExpTornillo = r'^\d\d\.(\d\d)\.\d\d(\d\d\d)\s+(.+)$';
const _kRegExpLargo    = r'(\d+)\s*mm';
const _kRegExpPrefijo  = r'^[\d.x]+\s+';

class _VisorCasoScreenState extends State<VisorCasoScreen> {
  late final WebViewController _webController;

  // Cache de parseo de tornillos: evita reejecutar RegExp en cada rebuild
  final Map<String, Map<String, dynamic>> _tornilloParseCache = {};

  late Map<int, bool> _visibles;
  bool _panelAbierto = true;
  double _panelTopOffset = 74.0;
  double _panelLeftOffset = -1.0; // sentinel: se inicializa al primer build con el ancho real
  bool _panelArrastrando = false;
  Offset _panelDragLastPos = Offset.zero;

  double _panelHeight = 680.0;
  bool _autoRotate   = false;
  bool _visorListo   = false;
  final _visorWindowsKey = GlobalKey<VisorWindowsState>();
  String _credencial = '';
  late Future<void> _credencialesFuture;
  String _tabPanel   = 'capas';

  final Map<int, String>              _glbCache          = {};
  final Map<int, bool>                _grupoExpandido    = {};
  bool _bioExpanded = false; // grupo biomodelos colapsable
  final Map<int, double>              _opacidades        = {};
  final Map<int, ValueNotifier<bool>> _cargandoNotifiers = {};
  final Map<int, String>              _catCache          = {};
  final Map<int, ValueNotifier<bool>> _catCargando       = {};
  // Versión del caché de catálogos: se incrementa cada vez que un tornillo termina de cargar
  // para que el popup se refresque automáticamente
  final ValueNotifier<int> _catCacheVersion = ValueNotifier(0);
  final Map<int, bool>                _grupoTornilloExp  = {};
  final Map<int, bool>                _trayectoriasVis   = {}; // visibilidad trayectorias por capa GLB
  final Map<int, bool>                _capaExpandida     = {}; // desplegable por capa

  // Completers para esperar confirmación JS de que el tornillo está parseado y listo
  final Map<String, Completer<void>> _tornilloListoCompleters = {};
  Completer<Uint8List>? _capturaVistaCompleter; // para capturas secuenciales en exportación

  final List<TornilloColocado> _tornillosColocados = [];
  final Set<String> _instanciasEnEscena = {}; // instanceIds colocados en JS
  final Map<String, _TapData> _tapPorInstancia = {}; // tap guardado antes de que _tapPendiente se borre
  int _screwCounter = 0;

  // Estado local mutable del caso (se actualiza automáticamente según acciones)
  late String _estadoActual;
  final ValueNotifier<int> _colocadosVersion = ValueNotifier(0);

  // Tap pendiente para mostrar popup
  _TapData? _tapPendiente;
  bool _guiasVisibles = true;
  TornilloColocado? _screwInfoTc;
  double _screwInfoSx = 0, _screwInfoSy = 0;
  bool _planGuardado  = false;

  // Visualización
  double _xrayOpacity   = 1.0;
  bool   _modoXray      = false;
  int    _modoLuz       = 0;
  final Map<int, Color> _colores = {};

  // Notas 3D
  bool _modoNota       = false; // modo activo: próximo tap = nueva nota
  final List<Nota3D> _notas = [];
  int  _notaCounter    = 0;
  final ValueNotifier<int> _notasVersion = ValueNotifier(0);

  // Vistas rápidas
  bool _vistasPanelVisible = false;

  // ID para notas de voz de sesiones genéricas.
  // Se inicializa desde sesionGuardada si existe, o se genera nuevo.
  late String _sessionAudioId;
  bool _sesionAudioGuardada = false; // true cuando el usuario guarda la sesión

  String get _audioNotasId {
    if (widget.planLocal != null) return widget.planLocal!.id;
    if (!widget.modoGenerico) return widget.caso.id;
    return _sessionAudioId;
  }

  // Arrastrar placa
  bool _placaArrastrandoActiva = false;

  // Regla libre / mediciones
  bool   _modoRegla       = false;
  double? _reglaLibreMm;
  int    _medicionCounter = 0;
  final List<Medicion3D> _mediciones = [];
  final ValueNotifier<int> _medicionesVersion = ValueNotifier(0);

  // Plano de corte
  bool   _planoCortando  = false;
  int    _planoEje       = 1;    // 0=X 1=Y 2=Z
  double _planoPos       = 0.5;  // 0..1 normalizado
  final Set<int> _planoCapas = {}; // índices GLB con plano activo

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {});
    if (_visorListo) {
      _jsRun('window.visor.setBackground(${AppTheme.isDark.value});');
    }
  }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);
    _estadoActual = widget.caso.estado;
    // Notas de voz: recuperar ID de sesión guardada, o generar nuevo
    _sessionAudioId = (widget.sesionGuardada?['audio_notas_id'] as String?)
        ?? const Uuid().v4();
    // Estado inicial: no se auto-avanza al abrir
    // DEBUG acceso rápido
    if (widget.autoCargar) {
      debugPrint('=== AUTO_CARGAR DEBUG ===');
      debugPrint('caso.id: ${widget.caso.id}');
      debugPrint('caso.nombre: ${widget.caso.nombre}');
      debugPrint('biomodelos: ${widget.caso.biomodelos.length}');
      for (final b in widget.caso.biomodelos)
        debugPrint('  bio url: ${b.url}');
      debugPrint('placas grupos: ${widget.caso.placas.length}');
      for (final g in widget.caso.placas) {
        debugPrint('  grupo ${g.nombre}: ${g.placas.length} placas');
        for (final p in g.placas)
          debugPrint('    placa url: ${p.url}');
      }
      debugPrint('todosGlb total: ${widget.caso.todosGlb.length}');
      debugPrint('========================');
    }
    _visibles =
    { for (int i = 0; i < widget.caso.todosGlb.length; i++) i: false};
    if (widget.sesionGuardada != null) {
      final capas = (widget.sesionGuardada!['capas_visibles'] as List? ?? [])
          .cast<Map<String, dynamic>>();
      for (final c in capas) {
        final idx = c['indice'] as int?;
        if (idx != null && _visibles.containsKey(idx)) _visibles[idx] = true;
      }
    }
    for (int i = 0; i < widget.caso.placas.length; i++)
      _grupoExpandido[i] = false;
    for (int i = 0; i < widget.caso.todosGlb.length; i++) {
      _opacidades[i] = 1.0;
      _cargandoNotifiers[i] = ValueNotifier(false);
    }
    for (int i = 0; i < widget.caso.todosTornillos.length; i++)
      _catCargando[i] = ValueNotifier(false);
    for (int i = 0; i < widget.caso.tornillos.length; i++)
      _grupoTornilloExp[i] = false;
    for (int i = 0; i < widget.caso.todosGlb.length; i++)
      _trayectoriasVis[i] = true;
    for (int i = 0; i < widget.caso.todosGlb.length; i++)
      _capaExpandida[i] = false;
    if (!Platform.isWindows) {
    _webController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel('VisorReady', onMessageReceived: (_) {
          if (!mounted) return;
          setState(() => _visorListo = true);
          if (Platform.isIOS) {
            const MethodChannel('visor/webview_config')
                .invokeMethod('disableTextInteraction');
          }
          _jsRun('window.visor.setBackground(${AppTheme.isDark.value});');

          final numBio = widget.caso.biomodelos.length;
          _jsRun('window._numBiomodelos = $numBio;');

          final nombreEsc = widget.caso.nombre.replaceAll("'", "");
          final pacienteEsc = widget.caso.paciente.replaceAll("'", "");

          _jsRun(
              "document.getElementById('wm-nombre').textContent='$nombreEsc';");
          _jsRun(
              "document.getElementById('wm-paciente').textContent='$pacienteEsc';");

          if (widget.sesionGuardada != null) {
            _credencialesFuture.then((_) async {
              if (!mounted) return;
              await _restaurarSesion(widget.sesionGuardada!);
            });
          } else if (widget.autoCargar && widget.planLocal != null) {
            _credencialesFuture.then((_) async {
              if (!mounted) return;
              await _autoCargarTodo();
            });
          } else if (widget.autoCargar && widget.planLocal == null) {
            // Último caso desde menú: restaurar estado si existe, si no cargar todo
            _credencialesFuture.then((_) async {
              if (!mounted) return;
              final prefs = await SharedPreferences.getInstance();
              if (prefs.containsKey('estado_caso_${widget.caso.id}')) {
                await _restaurarEstadoCaso();
              } else {
                await _autoCargarTodo();
              }
            });
          } else if (!widget.modoGenerico) {
            // Caso normal: restaurar estado guardado de la última visita
            _credencialesFuture.then((_) async {
              if (!mounted) return;
              await _restaurarEstadoCaso();
            });
          }
        })..addJavaScriptChannel('PlateTapped', onMessageReceived: (msg) {
          if (!mounted) return;
          try {
            final data = jsonDecode(msg.message) as Map<String, dynamic>;
            setState(() { _tapPendiente = _TapData.fromJson(data); _screwInfoTc = null; });
          } catch (e) {
            debugPrint('PlateTapped parse error: $e');
          }
        })..addJavaScriptChannel('ScrewPlaced', onMessageReceived: (msg) {
          try {
            final data = jsonDecode(msg.message) as Map<String, dynamic>;
            final instanceId = data['instanceId'] as String? ?? '';
            final nombre = data['nombre'] as String? ?? '';
            _instanciasEnEscena.add(instanceId);
            if (_tornillosColocados.any((t) => t.instanceId == instanceId)) return;
            // Usar tap guardado por instanceId (evita problema de _tapPendiente borrado)
            final tap = _tapPorInstancia.remove(instanceId) ?? _tapPendiente;
            setState(() {
              _tornillosColocados.add(TornilloColocado(
                instanceId: instanceId,
                glbId: data['glbId'] ?? '',
                nombre: nombre,
                cilindroId: data['cilindroId'] as String? ?? '',
                largo: _largoDesdeNombre(nombre),
                hx: tap?.x ?? 0, hy: tap?.y ?? 0, hz: tap?.z ?? 0,
                hnx: tap?.nx ?? 0, hny: tap?.ny ?? 0, hnz: tap?.nz ?? 0,
                hdx: tap?.dx ?? 0, hdy: tap?.dy ?? 0, hdz: tap?.dz ?? 0,
                usarTrayectoria: tap?.usarTrayectoria ?? false,
              ));
              _screwCounter++;
            });
            _colocadosVersion.value++;
            _guardarVisiblesAlSalir();
            _autoAvanzarEstado('modificado');
          } catch (_) {}
        })..addJavaScriptChannel('VisorLog',
            onMessageReceived: (msg) =>
                debugPrint('🔵 ${msg.message}'))..addJavaScriptChannel(
            'TornilloListo', onMessageReceived: (msg) {
          final catId = msg.message;
          _tornilloListoCompleters[catId]?.complete();
          _tornilloListoCompleters.remove(catId);
        })..addJavaScriptChannel('CapturaVista', onMessageReceived: (msg) {
          // Canal exclusivo para capturas de exportación — no guarda en galería
          try {
            final base64Str = msg.message;
            final bytes = base64Decode(
                base64Str.replaceFirst('data:image/png;base64,', ''));
            _capturaVistaCompleter?.complete(Uint8List.fromList(bytes));
            _capturaVistaCompleter = null;
          } catch (e) {
            _capturaVistaCompleter?.completeError(e);
            _capturaVistaCompleter = null;
          }
        })..addJavaScriptChannel('Captura', onMessageReceived: (msg) async {
          try {
            final base64Str = msg.message;
            final bytes = base64Decode(
                base64Str.replaceFirst('data:image/png;base64,', ''));
            // Guardar en galería usando gal
            await Gal.putImageBytes(
                Uint8List.fromList(bytes), name: 'visor_${DateTime
                .now()
                .millisecondsSinceEpoch}.png');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Imagen guardada en galería'),
                      backgroundColor: Colors.black87,
                      duration: Duration(seconds: 2)));
            }
          } catch (e) {
            debugPrint('Captura error: $e');
          }
        })..addJavaScriptChannel('ReglaLibre', onMessageReceived: (msg) {
          if (!mounted) return;
          try {
            final d = jsonDecode(msg.message) as Map<String, dynamic>;
            final mm = (d['mm'] as num).toDouble();
            final mid = d['id'] as String? ?? 'med_${_medicionCounter++}';
            setState(() {
              _reglaLibreMm = mm;
              _modoRegla = false;
              _mediciones.add(Medicion3D(id: mid, mm: mm));
            });
            _medicionesVersion.value++;
            _jsRun("window.visor.setModoRegla(false);");
            _autoAvanzarEstado('modificado');
          } catch (e) {
            debugPrint('ReglaLibre error: $e');
          }
        })..addJavaScriptChannel('NotaTap', onMessageReceived: (msg) {
          if (!mounted || !_modoNota) return;
          try {
            final d = jsonDecode(msg.message) as Map<String, dynamic>;
            _mostrarDialogoNota(
              (d['x'] as num).toDouble(),
              (d['y'] as num).toDouble(),
              (d['z'] as num).toDouble(),
            );
          } catch (e) {
            debugPrint('NotaTap error: $e');
          }
        })..addJavaScriptChannel('ScrewTapped', onMessageReceived: (msg) {
          if (!mounted) return;
          try {
            final d = jsonDecode(msg.message) as Map<String, dynamic>;
            final instanceId = d['instanceId'] as String? ?? '';
            final tc = _tornillosColocados.firstWhere(
              (t) => t.instanceId == instanceId,
              orElse: () => throw StateError('not found'),
            );
            setState(() {
              _screwInfoTc = tc;
              _screwInfoSx = (d['sx'] as num).toDouble();
              _screwInfoSy = (d['sy'] as num).toDouble();
            });
          } catch (_) {}
        })..addJavaScriptChannel('PlacaArrastrando', onMessageReceived: (msg) {
          if (!mounted) return;
          try {
            final d = jsonDecode(msg.message) as Map<String, dynamic>;
            setState(() => _placaArrastrandoActiva = d['active'] == true);
          } catch (_) {}
        })

        ..loadHtmlString(_patchHtmlTheme(_buildHtml()));
    }

    _credencialesFuture = _cargarCredenciales();
  }

  void _onVisorReadyWindows() {
    if (!mounted) return;
    setState(() => _visorListo = true);
    _jsRun('window.visor.setBackground(${AppTheme.isDark.value});');
    final numBio = widget.caso.biomodelos.length;
    _jsRun('window._numBiomodelos = $numBio;');
    final nombreEsc = widget.caso.nombre.replaceAll("'", "");
    final pacienteEsc = widget.caso.paciente.replaceAll("'", "");
    _jsRun("document.getElementById('wm-nombre').textContent='$nombreEsc';");
    _jsRun("document.getElementById('wm-paciente').textContent='$pacienteEsc';");
    if (widget.autoCargar) {
      _credencialesFuture.then((_) async {
        if (!mounted) return;
        await _autoCargarTodo();
      });
    }
  }

  Future<void> _cargarCredenciales() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('login_email') ?? '';
    final pass  = prefs.getString('login_password') ?? '';
    _credencial = base64Encode(utf8.encode('$email:$pass'));
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    _guardarVisiblesAlSalir();
    for (final n in _cargandoNotifiers.values) n.dispose();
    for (final n in _catCargando.values) n.dispose();
    _colocadosVersion.dispose();
    _notasVersion.dispose();
    _catCacheVersion.dispose();
    // Borrar notas de sesión genérica solo si el usuario NO guardó la sesión
    if (widget.planLocal == null && widget.modoGenerico && !_sesionAudioGuardada
        && widget.sesionGuardada == null) {
      AudioNotasService.eliminarSesion(_sessionAudioId);
    }
    super.dispose();
  }

  void _guardarVisiblesAlSalir() {
    final indices = _visibles.entries
        .where((e) => e.value == true)
        .map((e) => e.key.toString())
        .toList();
    final tornillosEntries = _tornillosColocados.map((t) {
      final clave = t.cilindroId.isNotEmpty ? t.cilindroId : t.instanceId;
      return '$clave:${_nombreCorto(t.nombre)}';
    }).toList();

    // Estado completo para restaurar al volver al caso
    final capasVisibles = <Map<String, dynamic>>[];
    for (final entry in _visibles.entries) {
      if (entry.value && entry.key < widget.caso.todosGlb.length) {
        final glb = widget.caso.todosGlb[entry.key];
        capasVisibles.add({
          'indice': entry.key, 'nombre': glb.nombre,
          'archivo': glb.archivo, 'tipo': glb.tipo, 'url': glb.url,
        });
      }
    }
    final tornillosCompletos = _tornillosColocados.map((t) => {
      'instanceId': t.instanceId, 'glbId': t.glbId, 'nombre': t.nombre,
      'cilindroId': t.cilindroId, 'largo_mm': t.largo,
      'hx': t.hx, 'hy': t.hy, 'hz': t.hz,
      'hnx': t.hnx, 'hny': t.hny, 'hnz': t.hnz,
      'hdx': t.hdx, 'hdy': t.hdy, 'hdz': t.hdz,
      'usarTrayectoria': t.usarTrayectoria,
    }).toList();

    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('ultimo_caso_visibles', indices.join(','));
      if (tornillosEntries.isNotEmpty) {
        final casoKey = 'historial_tornillos_${widget.caso.id}';
        final existing = prefs.getString(casoKey) ?? '';
        final allEntries = [
          if (existing.isNotEmpty) existing,
          tornillosEntries.join('|'),
        ].join('||');
        prefs.setString(casoKey, allEntries);
      }
      // Guardar estado completo para restaurar al volver
      prefs.setString('estado_caso_${widget.caso.id}', json.encode({
        'capas_visibles': capasVisibles,
        'tornillos_sesion_actual': tornillosCompletos,
      }));
    });
  }

  Future<void> _descargarYCargarGlb(int idx) async {
    if (_glbCache.containsKey(idx)) {
      _jsRun("window.visor.cargarGlbBase64('glb_$idx','${_glbCache[idx]}');");
      return;
    }
    _cargandoNotifiers[idx]?.value = true;
    try {
      final glb = widget.caso.todosGlb[idx];
      // Los GLB generados por IA son URLs públicas que NO requieren
      // autenticación Basic. Solo añadimos la cabecera para URLs del
      // servidor propio (planificacionquirurgica.com).
      final esUrlPropia = glb.url.contains('planificacionquirurgica.com');
      final headers = esUrlPropia && _credencial.isNotEmpty
          ? {'Authorization': 'Basic $_credencial'}
          : <String, String>{};
      final res = await http.get(Uri.parse(glb.url), headers: headers)
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        final b64 = base64Encode(res.bodyBytes);
        _glbCache[idx] = b64;
        _jsRun("window.visor.cargarGlbBase64('glb_$idx','$b64');");
      } else {
        debugPrint('❌ GLB $idx HTTP \${res.statusCode}: \${glb.url}');
      }
    } catch (e) {
      debugPrint('❌ GLB $idx: $e');
    } finally {
      if (mounted) _cargandoNotifiers[idx]?.value = false;
    }
  }

  /// Descarga los catálogos de tornillos con concurrencia controlada (4 simultáneas).
  Future<void> _descargarCatalogosConLimite(int total) async {
    const concurrencia = 4;
    int idx = 0;
    while (idx < total) {
      final lote = <Future>[];
      for (int j = 0; j < concurrencia && idx < total; j++, idx++) {
        lote.add(_descargarTornilloCatalogo(idx));
      }
      await Future.wait(lote);
    }
  }

  Future<void> _descargarTornilloCatalogo(int idx) async {
    if (_catCache.containsKey(idx)) return;
    _catCargando[idx]?.value = true;
    try {
      final t = widget.caso.todosTornillos[idx];
      final res = await http.get(Uri.parse(t.url),
          headers: {'Authorization': 'Basic $_credencial'})
          .timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        final b64 = base64Encode(res.bodyBytes);
        _catCache[idx] = b64;
        _jsRun("window.visor.registrarTornillo('cat_$idx','$b64');");
        _catCacheVersion.value++; // notifica al popup para que se refresque
      }
    } catch (e) {
      debugPrint('❌ Cat $idx: $e');
    } finally {
      if (mounted) _catCargando[idx]?.value = false;
    }
  }

  // Parsea nomenclatura: "02.27.01008 Nombre" → {largo: 8, diametro: 2.7, nombre: "Nombre"}
  // RegExp compilados una única vez como campos de instancia
  static final _reNombre   = RegExp(_kRegExpTornillo);
  static final _reLargo    = RegExp(_kRegExpLargo, caseSensitive: false);
  static final _rePrefijo  = RegExp(_kRegExpPrefijo, caseSensitive: false);
  static final _reExt      = RegExp(r'\.[^.]+$');

  Map<String, dynamic> _parsearTornillo(String nombreArchivo) {
    // Caché: si ya se parseó esta cadena, devolver resultado directo
    if (_tornilloParseCache.containsKey(nombreArchivo)) {
      return _tornilloParseCache[nombreArchivo]!;
    }
    final sin = nombreArchivo.replaceAll(_reExt, '');
    final m = _reNombre.firstMatch(sin);
    Map<String, dynamic> result;
    if (m != null) {
      final diam = int.parse(m.group(1)!) / 10.0;
      final largo = int.parse(m.group(2)!).toDouble();
      final nombre = m.group(3)!.trim();
      result = {'largo': largo, 'diametro': diam, 'nombre': nombre};
    } else {
      result = {'largo': 0.0, 'diametro': 0.0, 'nombre': sin};
    }
    _tornilloParseCache[nombreArchivo] = result;
    return result;
  }

  String _nombreCorto(String nombre) {
    final p = _parsearTornillo(nombre);
    return p['nombre'] as String;
  }

  String _labelDiamLargo(String nombre) {
    final p = _parsearTornillo(nombre);
    final diam = p['diametro'] as double;
    final largo = p['largo'] as double;
    if (largo > 0) return 'Ø${diam % 1 == 0 ? diam.toInt() : diam} · ${largo.toInt()} mm';
    return '';
  }

  double _largoDesdeNombre(String nombre) {
    final p = _parsearTornillo(nombre);
    if ((p['largo'] as double) > 0) return p['largo'] as double;
    final m2 = _reLargo.firstMatch(nombre);
    if (m2 != null) return double.tryParse(m2.group(1)!) ?? 0;
    return 0;
  }

  /// Elimina prefijos numéricos tipo "02.07.01xxx " dejando solo el nombre legible.
  String _limpiarNombre(String nombre) {
    return nombre.replaceFirst(_rePrefijo, '').trim();
  }

  // Insertar tornillo elegido en el popup.
  // Un solo tap: descarga (si hace falta) + espera que el JS termine de parsear + inserta.
  Future<void> _insertarTornillo(int catIdx) async {
    final tap = _tapPendiente;
    if (tap == null) return;

    final catId = 'cat_$catIdx';
    final instanceId = 'screw_$_screwCounter';

    // Guardar tap ANTES de borrarlo, keyed por instanceId
    _tapPorInstancia[instanceId] = tap;

    // Cerrar popup inmediatamente para dar feedback visual al usuario
    setState(() => _tapPendiente = null);

    // Preparar completer ANTES de cualquier operación async para no perder la señal JS
    final completer = Completer<void>();
    _tornilloListoCompleters[catId] = completer;

    // Si no está en caché de Flutter, descargar y registrar en JS
    if (!_catCache.containsKey(catIdx)) {
      await _descargarTornilloCatalogo(catIdx);
      // Si falló la descarga, limpiar y salir
      if (!_catCache.containsKey(catIdx)) {
        _tornilloListoCompleters.remove(catId);
        return;
      }
      // _descargarTornilloCatalogo ya llama a registrarTornillo en JS,
      // que a su vez dispara TornilloListo → el completer se resolverá solo
    } else {
      // Ya en caché Flutter: re-registrar en JS (idempotente, el JS ya lo tiene
      // en catalogoGltf y responde TornilloListo inmediatamente)
      _jsRun("window.visor.registrarTornillo('$catId','${_catCache[catIdx]}');");
    }

    // Esperar confirmación JS de que loader.parse() terminó (máx 10s)
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () { _tornilloListoCompleters.remove(catId); },
    );

    if (!mounted) return;

    final archivo = widget.caso.todosTornillos[catIdx].archivo;
    final nombre  = archivo.isNotEmpty ? archivo : widget.caso.todosTornillos[catIdx].nombre;
    final id      = _screwCounter;

    // 🧪 DEBUG dirección del tornillo
    debugPrint('--- TAP DEBUG ---');
    debugPrint('cilindroId: ${tap.cilindroId}');
    debugPrint('POS: (${tap.x}, ${tap.y}, ${tap.z})');
    debugPrint('NORMAL: (${tap.nx}, ${tap.ny}, ${tap.nz})');
    debugPrint('DIR: (${tap.dx}, ${tap.dy}, ${tap.dz})');
    debugPrint('usarTrayectoria: ${tap.usarTrayectoria}');





    final payload = jsonEncode({
      'catId':      catId,
      'instanceId': instanceId,
      'nombre':     nombre,
      'x': tap.x, 'y': tap.y, 'z': tap.z,
      'nx': tap.nx, 'ny': tap.ny, 'nz': tap.nz,
      'dx': tap.dx, 'dy': tap.dy, 'dz': tap.dz,
      'cilindroId': tap.cilindroId,
      'usarTrayectoria': tap.usarTrayectoria,
    });
    final escaped = payload.replaceAll("'", "\\'");
    _jsRun("window.visor.insertarTornillo('$escaped');");
  }

  void _toggleVisibilidadTornillo(TornilloColocado tc) {
    final mostrar = !tc.visible;
    tc.visible = mostrar;
    _colocadosVersion.value++;

    if (mostrar && !_instanciasEnEscena.contains(tc.instanceId)) {
      // No está en la escena JS — colocarlo primero (async)
      _colocarTornilloEnEscena(tc);
    } else {
      _jsRun("window.visor.toggleGlb('${tc.instanceId}',$mostrar);");
      _jsRun("window.visor.toggleRegla('${tc.instanceId}',${mostrar && tc.reglaVisible});");
    }
  }

  /// Coloca un tornillo en la escena JS bajo demanda (cuando viene de sesión restaurada).
  Future<void> _colocarTornilloEnEscena(TornilloColocado tc) async {
    if (tc.glbId.isEmpty) return;
    if (tc.hx == 0 && tc.hy == 0 && tc.hz == 0) return; // sin coordenadas guardadas

    final catMatch = RegExp(r'^cat_(\d+)$').firstMatch(tc.glbId);
    if (catMatch == null) return;
    final catIdx = int.parse(catMatch.group(1)!);
    if (catIdx >= widget.caso.todosTornillos.length) return;

    // Descargar catálogo si no está en caché
    if (!_catCache.containsKey(catIdx)) {
      await _descargarTornilloCatalogo(catIdx);
      if (!_catCache.containsKey(catIdx)) return;
    } else {
      _jsRun("window.visor.registrarTornillo('${tc.glbId}','${_catCache[catIdx]}');");
    }

    // Esperar confirmación JS
    final completer = Completer<void>();
    _tornilloListoCompleters[tc.glbId] = completer;
    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => _tornilloListoCompleters.remove(tc.glbId),
    );
    if (!mounted) return;

    // Insertar en escena — ScrewPlaced lo añadirá a _instanciasEnEscena
    final payload = jsonEncode({
      'catId':      tc.glbId,
      'instanceId': tc.instanceId,
      'nombre':     tc.nombre,
      'x':  tc.hx,  'y':  tc.hy,  'z':  tc.hz,
      'nx': tc.hnx, 'ny': tc.hny, 'nz': tc.hnz,
      'dx': tc.hdx, 'dy': tc.hdy, 'dz': tc.hdz,
      'cilindroId': '',
      'usarTrayectoria': tc.usarTrayectoria,
    });
    _jsRun("window.visor.insertarTornillo('${payload.replaceAll("'", "\\'")}');");
  }

  void _toggleRegla(TornilloColocado tc) {
    tc.reglaVisible = !tc.reglaVisible;
    _jsRun("window.visor.toggleRegla('${tc.instanceId}',${tc.reglaVisible});");
    _colocadosVersion.value++;
  }

  void _eliminarTornillo(TornilloColocado tc) {
    _jsRun("window.visor.eliminarRegla('${tc.instanceId}');");
    _jsRun("window.visor.eliminarTornillo('${tc.instanceId}');");
    _instanciasEnEscena.remove(tc.instanceId);
    setState(() => _tornillosColocados.remove(tc));
    _colocadosVersion.value++;
  }

  void _deshacerUltimo() {
    if (_tornillosColocados.isEmpty) return;
    _eliminarTornillo(_tornillosColocados.last);
  }

  void _jsRun(String js) {
    if (Platform.isWindows) {
      _visorWindowsKey.currentState?.runJs(js);
    } else {
      _webController.runJavaScript(js);
    }
  }
  void _jsToggleGlb(int i, bool v) => _jsRun("window.visor.toggleGlb('glb_$i',$v);");
  void _jsToggleGuias(bool v) => _jsRun('window.visor.toggleGuias($v);');
  void _jsToggleTrayectoriasGlb(int i, bool v) => _jsRun("window.visor.toggleTrayectoriasGlb('glb_$i',$v);");
  void _jsSetOpacidad(int i, double o) => _jsRun("window.visor.setOpacidad('glb_$i',$o);");
  void _jsAutoRotate(bool v) => _jsRun("window.visor.setAutoRotate($v);");
  void _jsResetCamara() => _jsRun("window.visor.resetCamara();");
  void _jsVista(int v) => _jsRun("window.visor.setVista($v);");
  void _jsXray(double op) => _jsRun("window.visor.setXray($op);");
  void _jsLuz(int modo) => _jsRun("window.visor.setLuz($modo);");
  void _jsColor(int idx, Color c) {
    final r = c.red.toRadixString(16).padLeft(2, '0');
    final g = c.green.toRadixString(16).padLeft(2, '0');
    final b = c.blue.toRadixString(16).padLeft(2, '0');
    _jsRun("window.visor.setColor('glb_${idx}', 0x${r}${g}${b});");
  }
  void _jsNotaAdd(String id, double x, double y, double z, String texto) {
    final t = texto.replaceAll("'", "").replaceAll("\n", " ");
    _jsRun("window.visor.addNota('$id',$x,$y,$z,'$t');");
  }
  void _jsNotaToggle(String id, bool v) => _jsRun("window.visor.toggleNota('$id',$v);");
  void _jsNotaRemove(String id) => _jsRun("window.visor.removeNota('$id');");
  void _jsNotaModo(bool v) => _jsRun("window.visor.setModoNota($v);");
  void _jsModoRegla(bool v) => _jsRun("window.visor.setModoRegla($v);");
  void _jsToggleReglaLibre(String id, bool v) => _jsRun("window.visor.toggleReglaLibre('$id',$v);");
  void _jsEliminarReglaLibre(String id) => _jsRun("window.visor.eliminarReglaLibre('$id');");

  void _mostrarDialogoNota(double x, double y, double z) {
    setState(() => _modoNota = false);
    _jsNotaModo(false);
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.sheetBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.cardBorder, width: 1.2),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Container(width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Color(0xFFFFD60A).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.push_pin, color: Color(0xFFFFD60A), size: 16)),
                  const SizedBox(width: 10),
                  Text('Nueva nota', style: TextStyle(
                      color: AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: 3,
                  style: TextStyle(color: AppTheme.darkText, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Escribe la nota...',
                    hintStyle: TextStyle(color: AppTheme.subtitleColor, fontSize: 13),
                    filled: true,
                    fillColor: Color(0xFF2A7FF5).withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2A7FF5).withOpacity(0.2))),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Color(0xFF2A7FF5).withOpacity(0.2))),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF2A7FF5), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.darkText.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12)),
                      child: Text('Cancelar', textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.subtitleColor, fontSize: 13)),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
                    onTap: () {
                      final texto = ctrl.text.trim();
                      if (texto.isEmpty) { Navigator.pop(context); return; }
                      final id = 'nota_${_notaCounter++}';
                      final nota = Nota3D(id: id, texto: texto, x: x, y: y, z: z);
                      _notas.add(nota);
                      _jsNotaAdd(id, x, y, z, texto);
                      _notasVersion.value++;
                      _autoAvanzarEstado('modificado');
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFD60A).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Color(0xFFFFD60A).withOpacity(0.5))),
                      child: const Text('Guardar', textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFFFD60A),
                              fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                  )),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _jsPlano(bool activo, int eje, double pos) =>
      _jsRun("window.visor.setPlanoCorte($activo,$eje,$pos);");
  void _jsPlanoGlb(int idx, bool activo) =>
      _jsRun("window.visor.setPlanoGlb('glb_$idx',$activo);");

  void _toggleVisibilidad(int idx) {
    final nuevo = !(_visibles[idx] ?? true);
    setState(() => _visibles[idx] = nuevo);
    if (nuevo) {
      if (_glbCache.containsKey(idx)) {
        _jsRun("window.visor.cargarGlbBase64('glb_$idx','${_glbCache[idx]}');");
      } else if (_visorListo) {
        _descargarYCargarGlb(idx);
      }
      // Las trayectorias arrancan invisibles tras cargar — aplicar estado correcto con delay
      final trayVis = _trayectoriasVis[idx] ?? true;
      final mostrarGuias = trayVis && _guiasVisibles;
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) _jsToggleTrayectoriasGlb(idx, mostrarGuias);
      });
    } else {
      _jsToggleGlb(idx, false);
      // Ocultar también las guías de esta capa
      _jsToggleTrayectoriasGlb(idx, false);
    }
  }

  bool get _todosVisibles => _visibles.values.every((v) => v);

  /// Restaura las capas que estaban visibles la última vez.
  /// Si no hay historial, carga solo los biomodelos.
  Future<void> _autoCargarTodo() async {
    final n = widget.caso.todosGlb.length;
    if (n == 0) return;

    // Leer qué índices estaban visibles la última vez
    final prefs     = await SharedPreferences.getInstance();
    final raw       = prefs.getString('ultimo_caso_visibles') ?? '';
    final Set<int> indices;
    if (raw.isNotEmpty) {
      indices = raw.split(',').map((s) => int.tryParse(s.trim()) ?? -1)
          .where((i) => i >= 0 && i < n).toSet();
    } else {
      // Sin historial: mostrar solo biomodelos (primeros N)
      indices = { for (int i = 0; i < widget.caso.biomodelos.length; i++) i };
    }

    if (!mounted) return;
    setState(() {
      for (int i = 0; i < n; i++) _visibles[i] = indices.contains(i);
    });
    for (final i in indices) {
      if (_glbCache.containsKey(i)) {
        _jsRun("window.visor.cargarGlbBase64('glb_$i','${_glbCache[i]}');");
      } else {
        _descargarYCargarGlb(i);
      }
    }
    // Predescargar catálogos de tornillos en background
    final totalT = widget.caso.todosTornillos.length;
    if (totalT > 0) _descargarCatalogosConLimite(totalT);

    // El historial de tornillos está disponible en el botón "i" (esquina inferior izquierda)
  }

  Future<void> _restaurarSesion(Map<String, dynamic> sesion) async {
    // 1. Cargar capas visibles
    final capas = (sesion['capas_visibles'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final indices = capas.map((c) => c['indice'] as int?).whereType<int>().toSet();
    for (final i in indices) {
      if (!_visibles.containsKey(i)) continue;
      if (_glbCache.containsKey(i)) {
        _jsRun("window.visor.cargarGlbBase64('glb_$i','${_glbCache[i]}');");
      } else {
        _descargarYCargarGlb(i);
      }
    }

    // 2. Restaurar lista Dart de tornillos (aparecen en menú lateral)
    final tornillos = (sesion['tornillos_sesion_actual'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    int maxId = _screwCounter;
    for (final t in tornillos) {
      final instanceId = t['instanceId'] as String? ?? '';
      if (instanceId.isEmpty) continue;
      if (_tornillosColocados.any((tc) => tc.instanceId == instanceId)) continue;
      final numMatch = RegExp(r'screw_(\d+)').firstMatch(instanceId);
      if (numMatch != null) {
        final n = int.tryParse(numMatch.group(1)!) ?? 0;
        if (n >= maxId) maxId = n + 1;
      }
      final tc = TornilloColocado(
        instanceId: instanceId,
        glbId: t['glbId'] as String? ?? '',
        nombre: t['nombre'] as String? ?? '',
        cilindroId: t['cilindroId'] as String? ?? '',
        largo: (t['largo_mm'] as num? ?? 0).toDouble(),
        hx: (t['hx'] as num? ?? 0).toDouble(),
        hy: (t['hy'] as num? ?? 0).toDouble(),
        hz: (t['hz'] as num? ?? 0).toDouble(),
        hnx: (t['hnx'] as num? ?? 0).toDouble(),
        hny: (t['hny'] as num? ?? 0).toDouble(),
        hnz: (t['hnz'] as num? ?? 0).toDouble(),
        hdx: (t['hdx'] as num? ?? 0).toDouble(),
        hdy: (t['hdy'] as num? ?? 0).toDouble(),
        hdz: (t['hdz'] as num? ?? 0).toDouble(),
        usarTrayectoria: t['usarTrayectoria'] as bool? ?? false,
        visible: false,
      );
      setState(() => _tornillosColocados.add(tc));
      _colocadosVersion.value++;
    }
    setState(() => _screwCounter = maxId);
    // Nota: la colocación visual 3D de tornillos requiere coordenadas guardadas
    // con la versión actualizada de la app.
  }

  /// Restaura el estado de la última visita al caso (Mis Casos).
  Future<void> _restaurarEstadoCaso() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('estado_caso_${widget.caso.id}');
    if (raw == null) return; // primera vez que se abre este caso
    try {
      final sesion = json.decode(raw) as Map<String, dynamic>;
      await _restaurarSesion(sesion);
    } catch (_) {}
  }

  void _toggleTodos() {
    final nuevo = !_todosVisibles;
    setState(() { for (final k in _visibles.keys) _visibles[k] = nuevo; });
    for (int i = 0; i < widget.caso.todosGlb.length; i++) {
      if (nuevo) {
        _glbCache.containsKey(i)
            ? _jsRun("window.visor.cargarGlbBase64('glb_$i','${_glbCache[i]}');")
            : (_visorListo ? _descargarYCargarGlb(i) : null);
      } else {
        _jsToggleGlb(i, false);
      }
    }
  }

  bool get _bioTodosVisibles {
    final n = widget.caso.biomodelos.length;
    if (n == 0) return false;
    return List.generate(n, (i) => i).every((i) => _visibles[i] == true);
  }

  void _toggleBiomodelos() {
    final nuevo = !_bioTodosVisibles;
    final n = widget.caso.biomodelos.length;
    setState(() {
      for (int i = 0; i < n; i++) _visibles[i] = nuevo;
    });
    for (int i = 0; i < n; i++) {
      if (nuevo) {
        _glbCache.containsKey(i)
            ? _jsRun("window.visor.cargarGlbBase64('glb_$i','${_glbCache[i]}');")
            : (_visorListo ? _descargarYCargarGlb(i) : null);
      } else {
        _jsToggleGlb(i, false);
      }
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // HTML
  // ═════════════════════════════════════════════════════════════════════════
  String _buildHtml() => r'''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<style>
  *{
  margin:0;
  padding:0;
  box-sizing:border-box;
  -webkit-user-select:none;
  user-select:none;
  -webkit-touch-callout:none;
  -webkit-tap-highlight-color:transparent;
}
  html,body{
  width:100%;
  height:100%;
  overflow:hidden;
  background:#F0F0F3;
  touch-action:none;
  -webkit-user-select:none;
  user-select:none;
  -webkit-touch-callout:none;
}
  canvas{
  display:block;
  width:100%!important;
  height:100%!important;
  touch-action:none;
  outline:none;
  -webkit-user-select:none;
  user-select:none;
  -webkit-touch-callout:none;
}
  #loading{
    position:fixed;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;
    background:linear-gradient(160deg,#F0F0F3 0%,#DCDCE8 100%);
    color:rgba(26,26,46,0.55);font-family:-apple-system,sans-serif;font-size:13px;gap:14px;z-index:999;
  }
  #watermark{
    position:fixed;bottom:60px;left:0;right:0;
    display:flex;flex-direction:column;align-items:center;
    pointer-events:none;z-index:10;user-select:none;
  }
  #watermark .wm-nombre{
    font-family:-apple-system,sans-serif;font-size:28px;font-weight:900;
    letter-spacing:5px;color:rgba(120,120,120,0.35);text-transform:uppercase;
    text-align:center;line-height:1.1;
  }
  #watermark .wm-paciente{
    font-family:-apple-system,sans-serif;font-size:13px;font-weight:600;
    letter-spacing:3px;color:rgba(26,26,46,0.13);margin-top:6px;
    text-align:center;text-transform:uppercase;
  }
  .spinner{width:34px;height:34px;border:2.5px solid rgba(42,127,245,0.2);
    border-top-color:rgba(42,127,245,0.85);border-radius:50%;animation:spin .75s linear infinite;}
  @keyframes spin{to{transform:rotate(360deg);}}
  #hint-overlay{
    position:fixed;bottom:72px;left:50%;transform:translateX(-50%);
    display:flex;gap:18px;align-items:center;
    background:rgba(20,20,30,0.62);backdrop-filter:blur(8px);
    border-radius:20px;padding:9px 20px;
    pointer-events:none;z-index:50;
    opacity:0;transition:opacity 0.2s ease;
    white-space:nowrap;
  }
  #hint-overlay.visible{ opacity:1; }
  .hint-item{
    display:flex;align-items:center;gap:6px;
    font-family:-apple-system,sans-serif;font-size:12px;font-weight:500;
    color:rgba(255,255,255,0.88);
  }
  .hint-item .hi{font-size:16px;line-height:1;}
  .hint-sep{ width:1px;height:22px;background:rgba(255,255,255,0.18); }
</style>
</head>
<body>
<div id="hint-overlay">
  <div class="hint-item"><span class="hi">☝️</span><span>mover</span></div>
  <div class="hint-sep"></div>
  <div class="hint-item"><span class="hi">✌️</span><span>rotar</span></div>
  <div class="hint-sep"></div>
  <div class="hint-item"><span class="hi">🤏</span><span>profundidad</span></div>
</div>
<div id="loading"><div class="spinner"></div><span>Cargando modelo…</span></div>
<div id="watermark"><div class="wm-nombre" id="wm-nombre"></div><div class="wm-paciente" id="wm-paciente"></div></div>
<div id="orbes" style="position:fixed;inset:0;pointer-events:none;z-index:1;overflow:hidden;">
  <div style="position:absolute;top:-80px;right:-60px;width:320px;height:320px;border-radius:50%;background:radial-gradient(circle,rgba(42,127,245,0.13) 0%,transparent 70%);"></div>
  <div style="position:absolute;bottom:-60px;left:-80px;width:280px;height:280px;border-radius:50%;background:radial-gradient(circle,rgba(142,68,173,0.08) 0%,transparent 70%);"></div>
  <div style="position:absolute;top:40%;left:60%;width:200px;height:200px;border-radius:50%;background:radial-gradient(circle,rgba(42,127,245,0.06) 0%,transparent 70%);"></div>
</div>
<script type="importmap">
{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"}}
</script>
<script type="module">
import * as THREE from 'three';
import { GLTFLoader }      from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls }   from 'three/addons/controls/OrbitControls.js';
import { DRACOLoader }     from 'three/addons/loaders/DRACOLoader.js';
import { EffectComposer }  from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass }      from 'three/addons/postprocessing/RenderPass.js';
import { OutlinePass }     from 'three/addons/postprocessing/OutlinePass.js';
import { OutputPass }      from 'three/addons/postprocessing/OutputPass.js';

// ── Escena ─────────────────────────────────────────────────────────────────
const scene = new THREE.Scene();
const c2d = document.createElement('canvas'); c2d.width=2; c2d.height=512;
const ctx = c2d.getContext('2d');
const gr  = ctx.createLinearGradient(0,0,0,512);
gr.addColorStop(0,'#E8E8F0'); gr.addColorStop(0.5,'#DCDCE8'); gr.addColorStop(1,'#F0F0F3');
ctx.fillStyle=gr; ctx.fillRect(0,0,2,512);
scene.background = new THREE.CanvasTexture(c2d);

const camera = new THREE.PerspectiveCamera(45, innerWidth/innerHeight, 0.1, 2000);
camera.position.set(0,0,500);

const renderer = new THREE.WebGLRenderer({antialias:true, logarithmicDepthBuffer:true, preserveDrawingBuffer:true});
renderer.setPixelRatio(/iPhone|iPad|Android/i.test(navigator.userAgent)
  ? Math.min(devicePixelRatio, 1.5)  // móvil: limitar DPR para reducir carga GPU
  : Math.min(devicePixelRatio, 2));
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
renderer.outputColorSpace = THREE.SRGBColorSpace;
document.body.appendChild(renderer.domElement);

scene.add(new THREE.AmbientLight(0xffffff,1.3));
const d1=new THREE.DirectionalLight(0xffffff,1.8); d1.position.set(5,10,7); scene.add(d1);
const d2=new THREE.DirectionalLight(0xaabbff,0.5); d2.position.set(-5,-3,-5); scene.add(d2);
scene.add(new THREE.HemisphereLight(0xffffff,0x999999,0.4));

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping=true; controls.dampingFactor=0.08;
controls.minDistance=0.01; controls.maxDistance=5000;
// Fix táctil: un dedo = rotar, dos dedos = solo zoom (no rotar+zoom a la vez)
controls.touches = {
  ONE: THREE.TOUCH.ROTATE,
  TWO: THREE.TOUCH.DOLLY_PAN
};
controls.enablePan = true;
controls.panSpeed = 0.8;
controls.rotateSpeed = 0.8;
controls.zoomSpeed = 1.2;
// Evitar saltos al iniciar nuevo gesto
controls.addEventListener('start', () => { controls.saveState(); });

// ── Post-procesado: OutlinePass para glow de placa seleccionada ─────────────
const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const outlinePass = new OutlinePass(new THREE.Vector2(innerWidth, innerHeight), scene, camera);
const _isMob = /iPhone|iPad|Android/i.test(navigator.userAgent);
outlinePass.edgeStrength  = _isMob ? 3.0 : 5.0;
outlinePass.edgeGlow      = _isMob ? 0.5 : 1.5; // blur passes = principal coste GPU
outlinePass.edgeThickness = _isMob ? 1.0 : 2.0;
outlinePass.pulsePeriod   = 0;
outlinePass.visibleEdgeColor.set(0x2A7FF5);
outlinePass.hiddenEdgeColor.set(0x1A5FD8);
composer.addPass(outlinePass);
composer.addPass(new OutputPass());


const draco = new DRACOLoader();
draco.setDecoderPath('https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/libs/draco/');
const loader = new GLTFLoader(); loader.setDRACOLoader(draco);

const modelos      = {};
const catalogoGltf = {};
const _coloresGlb  = {}; // color override por id
const trayectorias = {}; // id_glb → [{pos, dir, name}]
const raycaster    = new THREE.Raycaster();
const pointer      = new THREE.Vector2();

// ── Cache de meshes para raycast (se invalida al añadir/quitar modelos) ──────
// Evita recorrer scene.traverse en cada tap, que es O(n) sobre toda la escena.
let _meshCacheGeom = null;      // meshes de geometría (no trayectoria, no tornillo)
let _meshCacheTray = null;      // solo trayectorias
let _meshCacheAll  = null;      // todos los meshes visibles

function _invalidarCacheMeshes(){
  _meshCacheGeom = null;
  _meshCacheTray = null;
  _meshCacheAll  = null;
  needsRender = true;
}

// Función auxiliar: comprueba que el mesh Y todos sus ancestros sean visibles
function _esVisible(obj){
  let o = obj;
  while(o){ if(!o.visible) return false; o = o.parent; }
  return true;
}

function _getMeshesGeom(){
  if(_meshCacheGeom) return _meshCacheGeom.filter(c=>c.visible && _esVisible(c));
  _meshCacheGeom = [];
  scene.traverse(c=>{ if(c.isMesh && !c.userData.esTrayectoria && !c.userData.esTornillo) _meshCacheGeom.push(c); });
  return _meshCacheGeom.filter(c=>c.visible && _esVisible(c));
}

function _getMeshesTray(){
  if(_meshCacheTray) return _meshCacheTray.filter(c=>c.visible && _esVisible(c));
  _meshCacheTray = [];
  scene.traverse(c=>{ if(c.isMesh && !c.userData.esTornillo && c.userData.esTrayectoria) _meshCacheTray.push(c); });
  return _meshCacheTray.filter(c=>c.visible && _esVisible(c));
}

// Distinguir tap de drag: guardamos posición del pointerdown
let pointerDownX = 0, pointerDownY = 0;
const DRAG_THRESHOLD = 6; // píxeles

// ── Snap a la trayectoria más cercana al tap ─────────────────────────────
// Busca en todas las trayectorias cargadas la más cercana al hitPoint
// Devuelve {pos, dir} con el centro y dirección exactos del agujero
// Devuelve el glbId de la placa cuya trayectoria más cercana al punto dado
function _findPlacaGlbId(x, y, z){
  const pt = new THREE.Vector3(x, y, z);
  let bestId = null, bestDist = Infinity;
  for(const id in trayectorias){
    const plate = modelos[id];
    if(plate) plate.updateWorldMatrix(true, false);
    for(const t of trayectorias[id]){
      const wp = plate ? t.pos.clone().applyMatrix4(plate.matrixWorld) : t.pos.clone();
      const d = wp.distanceTo(pt);
      if(d < bestDist){ bestDist = d; bestId = id; }
    }
  }
  return bestId;
}

// Mueve placa + tornillos asociados a lo largo del eje de la cámara
function _moverPlacaProfundidad(id, delta){
  if(!modelos[id]) return;
  const dir = camera.getWorldDirection(new THREE.Vector3());
  modelos[id].position.addScaledVector(dir, delta);
  if(_placaCenter) _placaCenter.addScaledVector(dir, delta);
  needsRender = true;
}
function _rotarAlrededorCentro(modelo, axis, angle){
  if(!_placaCenter){ modelo.rotateOnWorldAxis(axis, angle); return; }
  const a = axis.clone().normalize();
  const offset = modelo.position.clone().sub(_placaCenter);
  offset.applyAxisAngle(a, angle);
  modelo.position.copy(_placaCenter.clone().add(offset));
  modelo.rotateOnWorldAxis(a, angle);
}

// Glow de borde con OutlinePass — outline correcto sobre el mesh real
function _setPlacaGlow(id, active, modoRojo){
  if(active && modelos[id]){
    if(modoRojo){
      outlinePass.visibleEdgeColor.set(0xFF3030);
      outlinePass.hiddenEdgeColor.set(0xCC0000);
      const selected = [];
      modelos[id].traverse(c=>{ if(c.isMesh && !c.userData.esTrayectoria && !c.userData.esIndicadorFondo) selected.push(c); });
      outlinePass.selectedObjects = selected;
    } else {
      outlinePass.visibleEdgeColor.set(0x2A7FF5);
      outlinePass.hiddenEdgeColor.set(0x1A5FD8);
      const selected = [];
      modelos[id].traverse(c=>{ if(c.isMesh && !c.userData.esTrayectoria && !c.userData.esIndicadorFondo) selected.push(c); });
      outlinePass.selectedObjects = selected;
    }
  } else {
    outlinePass.visibleEdgeColor.set(0x2A7FF5);
    outlinePass.hiddenEdgeColor.set(0x1A5FD8);
    outlinePass.selectedObjects = [];
  }
  needsRender = true;
}

// Crea un indicador rojo (invisible, solo para OutlinePass) en la zona activa
function _crearIndicadorFondo(modelId, esTop, esLateral, esLeft){
  _eliminarIndicadorFondo();
  const modelo = modelos[modelId];
  if(!modelo) return;
  modelo.updateWorldMatrix(true, true);
  const localBox = new THREE.Box3();
  modelo.traverse(c=>{
    if(c.isMesh && !c.userData.esTrayectoria && !c.userData.esTornillo && !c.userData.esIndicadorFondo && c.geometry && c.geometry.attributes.position){
      c.updateWorldMatrix(true, false);
      const gb = new THREE.Box3().setFromBufferAttribute(c.geometry.attributes.position);
      const m4 = new THREE.Matrix4().copy(modelo.matrixWorld).invert().multiply(c.matrixWorld);
      gb.applyMatrix4(m4);
      localBox.union(gb);
    }
  });
  if(localBox.isEmpty()) return;
  const size = localBox.getSize(new THREE.Vector3());
  let geo, posX, posY;
  if(esLateral){
    const indicW = size.x * 0.28;
    geo = new THREE.BoxGeometry(indicW, size.y * 1.01, size.z * 1.01);
    posX = esLeft ? localBox.min.x + indicW / 2 : localBox.max.x - indicW / 2;
    posY = (localBox.min.y + localBox.max.y) / 2;
  } else {
    const indicH = size.y * 0.28;
    geo = new THREE.BoxGeometry(size.x * 1.01, indicH, size.z * 1.01);
    posX = (localBox.min.x + localBox.max.x) / 2;
    posY = esTop ? localBox.max.y - indicH / 2 : localBox.min.y + indicH / 2;
  }
  const mat = new THREE.MeshBasicMaterial({ color:0xFF3030, transparent:true, opacity:0, depthWrite:false });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.userData.esIndicadorFondo = true;
  mesh.renderOrder = 999;
  mesh.position.set(posX, posY, (localBox.min.z + localBox.max.z) / 2);
  modelo.add(mesh);
  _indicadorFondoMesh = mesh;
}

function _mostrarHint(modoRojo){
  const el = document.getElementById('hint-overlay');
  if(!el) return;
  if(modoRojo){
    el.innerHTML = '<div class="hint-item"><span class="hi">↺</span><span>péndulo</span></div>';
  } else {
    el.innerHTML = '<div class="hint-item"><span class="hi">☝️</span><span>mover</span></div><div class="hint-sep"></div><div class="hint-item"><span class="hi">✌️</span><span>rotar</span></div><div class="hint-sep"></div><div class="hint-item"><span class="hi">🤏</span><span>profundidad</span></div>';
  }
  el.classList.add('visible');
}
function _ocultarHint(){
  const el = document.getElementById('hint-overlay');
  if(el) el.classList.remove('visible');
}

function _eliminarIndicadorFondo(){
  if(_indicadorFondoMesh){
    if(_indicadorFondoMesh.parent) _indicadorFondoMesh.parent.remove(_indicadorFondoMesh);
    if(_indicadorFondoMesh.geometry) _indicadorFondoMesh.geometry.dispose();
    if(_indicadorFondoMesh.material) _indicadorFondoMesh.material.dispose();
    _indicadorFondoMesh = null;
    needsRender = true;
  }
}

function snapTrayectoriaMasCercana(hitPoint){
  let mejor = null;
  let distMin = Infinity;
  for(const id in trayectorias){
    const plate = modelos[id];
    if(plate) plate.updateWorldMatrix(true, false);
    for(const t of trayectorias[id]){
      const worldPos = plate ? t.pos.clone().applyMatrix4(plate.matrixWorld) : t.pos.clone();
      const d = worldPos.distanceTo(hitPoint);
      if(d < distMin){
        distMin = d;
        const worldDir = plate ? t.dir.clone().transformDirection(plate.matrixWorld) : t.dir.clone();
        mejor = {pos: worldPos, dir: worldDir, name: t.name};
      }
    }
  }
  return mejor;
}

function b64ToBuffer(b64){
  const bin=atob(b64), buf=new ArrayBuffer(bin.length), arr=new Uint8Array(buf);
  for(let i=0;i<bin.length;i++) arr[i]=bin.charCodeAt(i);
  return buf;
}

// ── Orientar y posicionar tornillo ─────────────────────────────────────────
// hitNormal: normal exterior de la cara (apunta hacia la cámara, hacia fuera del objeto)
// hitPoint:  punto 3D exacto del impacto
function orientarTornillo(obj, hitNormal, hitPoint){
  obj.position.set(0,0,0); obj.rotation.set(0,0,0); obj.updateMatrixWorld(true);

  const box  = new THREE.Box3().setFromObject(obj);
  const size = new THREE.Vector3(); box.getSize(size);
  const center = new THREE.Vector3(); box.getCenter(center);

  // Eje más largo del tornillo
  let ejeIdx = 1;
  if(size.x>=size.y && size.x>=size.z) ejeIdx=0;
  else if(size.z>=size.x && size.z>=size.y) ejeIdx=2;
  const largo = [size.x,size.y,size.z][ejeIdx];

  const ejesC = [new THREE.Vector3(1,0,0), new THREE.Vector3(0,1,0), new THREE.Vector3(0,0,1)];
  const ejeTornillo = ejesC[ejeIdx].clone();

  // Detectar qué extremo es la cabeza (más ancho)
  let cabezaDir = 1;
  let primerMesh = null;
  obj.traverse(c=>{ if(c.isMesh && !primerMesh) primerMesh=c; });
  if(primerMesh && primerMesh.geometry.attributes.position){
    const pos    = primerMesh.geometry.attributes.position;
    const minC   = box.min.getComponent(ejeIdx);
    const maxC   = box.max.getComponent(ejeIdx);
    const cuarto = largo * 0.2;
    let rPos=0, rNeg=0;
    const tmp = new THREE.Vector3();
    for(let i=0; i<pos.count; i++){
      tmp.set(pos.getX(i), pos.getY(i), pos.getZ(i));
      const comp = tmp.getComponent(ejeIdx);
      const dx = ejeIdx===0?0:tmp.x-center.x;
      const dy = ejeIdx===1?0:tmp.y-center.y;
      const dz = ejeIdx===2?0:tmp.z-center.z;
      const r  = Math.sqrt(dx*dx+dy*dy+dz*dz);
      if(comp >= maxC-cuarto && r>rPos) rPos=r;
      if(comp <= minC+cuarto && r>rNeg) rNeg=r;
    }
    cabezaDir = rPos>=rNeg ? 1 : -1;
  }

  // Rotar: cabeza apunta en dirección hitNormal (hacia fuera = hacia la cámara)
  // Así la rosca entra hacia dentro de la placa
  const ejeConCabeza = ejeTornillo.clone().multiplyScalar(cabezaDir);
  const q = new THREE.Quaternion();
  q.setFromUnitVectors(ejeConCabeza, hitNormal.clone().normalize());
  obj.quaternion.copy(q);
  obj.updateMatrixWorld(true);

  // El centro está en hitPoint → mover largo entero hacia dentro para que cabeza quede en hitPoint
  obj.position.copy(hitPoint).addScaledVector(hitNormal.clone().normalize(), -(largo * 0.85));
}

// ── Indicador de carga no intrusivo ──────────────────────────────────────
let _loadingCount = 0;
function _showLayerLoading(){
  _loadingCount++;
  let el = document.getElementById('layer-loading');
  if(!el){
    el = document.createElement('div');
    el.id = 'layer-loading';
    el.style.cssText = `
      position:fixed; bottom:18px; left:50%; transform:translateX(-50%);
      background:rgba(255,255,255,0.82); backdrop-filter:blur(10px);
      border:1px solid rgba(255,255,255,0.9); border-radius:20px;
      padding:7px 16px; display:flex; align-items:center; gap:8px;
      z-index:500; pointer-events:none; transition: opacity 0.2s ease;
    `;
    el.innerHTML = `
      <div style="width:12px;height:12px;border:2px solid rgba(42,127,245,0.2);
        border-top-color:rgba(42,127,245,0.85);border-radius:50%;
        animation:spin .75s linear infinite;"></div>
      <span style="color:rgba(26,26,46,0.7);font-size:11px;
        font-family:-apple-system,sans-serif;">Cargando modelo\u2026</span>
    `;
    document.body.appendChild(el);
  }
  el.style.opacity = '1';
  el.style.display = 'flex';
}
function _hideLayerLoading(){
  _loadingCount = Math.max(0, _loadingCount - 1);
  if(_loadingCount === 0){
    const el = document.getElementById('layer-loading');
    if(el){ el.style.opacity='0'; setTimeout(()=>{ el.style.display='none'; },200); }
  }
}

// ── Cargar capa ────────────────────────────────────────────────────────────
function cargarGlbBase64(id, b64){
  if(modelos[id]!=null){
    // Reactivar el nodo raíz y todos los meshes de geometría
    modelos[id].visible = true;
    modelos[id].traverse(c=>{
      if(c.isMesh && !c.userData.esTrayectoria) c.visible = true;
    });
    needsRender = true;
    return;
  }
  _showLayerLoading();
  // Usar setTimeout para no bloquear el hilo de render mientras se convierte el base64
  setTimeout(()=>{
  try{
    loader.parse(b64ToBuffer(b64),'', gltf=>{
      const esHueso = id.startsWith('glb_') && parseInt(id.replace('glb_','')) < window._numBiomodelos;

      // Detectar y guardar trayectorias (T1, T2...) — invisibles en escena
      gltf.scene.traverse(c=>{
        if(/^T\d+$/.test(c.name)){
          c.visible = true;
          c.userData.esTrayectoria = true;
          if(c.isMesh && c.material){
            c.material = c.material.clone();
            c.material.transparent = true;
            c.material.opacity = 0.45;
            c.material.color = new THREE.Color(0x2196F3);
            c.material.depthWrite = false;
          }
          // Guardar: posición mundial y dirección del eje largo (local Y → mundo)
          c.updateMatrixWorld(true);
          const pos = new THREE.Vector3();
          const dir = new THREE.Vector3();
          // Calcular eje del cilindro desde vértices (no hay transformaciones en el GLB)
          // Los vértices están en espacio mundo directamente
        if(c.isMesh && c.geometry && c.geometry.attributes.position){
            const posAttr = c.geometry.attributes.position;
            const tmp = new THREE.Vector3();

            // ── FIX: detectar el eje más largo del cilindro (no asumir siempre X) ──
            let minX=Infinity,maxX=-Infinity,minY=Infinity,maxY=-Infinity,minZ=Infinity,maxZ=-Infinity;
            for(let i=0;i<posAttr.count;i++){
              tmp.fromBufferAttribute(posAttr,i).applyMatrix4(c.matrixWorld);
              if(tmp.x<minX)minX=tmp.x; if(tmp.x>maxX)maxX=tmp.x;
              if(tmp.y<minY)minY=tmp.y; if(tmp.y>maxY)maxY=tmp.y;
              if(tmp.z<minZ)minZ=tmp.z; if(tmp.z>maxZ)maxZ=tmp.z;
            }
            const rX=maxX-minX, rY=maxY-minY, rZ=maxZ-minZ;
            // Eje principal = el más largo
            let eje; // 0=X, 1=Y, 2=Z
            if(rX>=rY && rX>=rZ) eje=0;
            else if(rY>=rX && rY>=rZ) eje=1;
            else eje=2;
            const ejeMins=[minX,minY,minZ], ejeMaxs=[maxX,maxY,maxZ];
            const largo = ejeMaxs[eje]-ejeMins[eje];

            // Recoger vértices de cada tapa (15% del largo en el eje principal)
            const vMin=[], vMax=[];
            for(let i=0;i<posAttr.count;i++){
              tmp.fromBufferAttribute(posAttr,i).applyMatrix4(c.matrixWorld);
              const comp=eje===0?tmp.x:eje===1?tmp.y:tmp.z;
              if(comp<=ejeMins[eje]+largo*0.15) vMin.push(tmp.clone());
              if(comp>=ejeMaxs[eje]-largo*0.15) vMax.push(tmp.clone());
            }
            // Centroide de cada tapa
            const tapMin=new THREE.Vector3(); vMin.forEach(v=>tapMin.add(v)); tapMin.divideScalar(vMin.length);
            const tapMax=new THREE.Vector3(); vMax.forEach(v=>tapMax.add(v)); tapMax.divideScalar(vMax.length);

            // Determinar cuál tapa está más cerca de los meshes de la placa (no trayectorias)
            let puntoEntrada=tapMax.clone(), puntoSalida=tapMin.clone(), distMin=Infinity;
            gltf.scene.traverse(m=>{
            const _reTray = /^T\d+$/;
              if(m.isMesh && !m.userData.esTrayectoria && !_reTray.test(m.name)){
                const bp=new THREE.Box3().setFromObject(m);
                const cM=new THREE.Vector3(); bp.getCenter(cM);
                const dA=tapMax.distanceTo(cM), dB=tapMin.distanceTo(cM);
                if(Math.min(dA,dB)<distMin){
                  distMin=Math.min(dA,dB);
                  if(dA<=dB){puntoEntrada=tapMax.clone();puntoSalida=tapMin.clone();}
                  else      {puntoEntrada=tapMin.clone();puntoSalida=tapMax.clone();}
                }
              }
            });
            const dirT=puntoSalida.clone().sub(puntoEntrada).normalize();
            VisorLog.postMessage(
  'DIR ' + c.name + ' = ' +
  dirT.x.toFixed(2)+','+
  dirT.y.toFixed(2)+','+
  dirT.z.toFixed(2)
);
            if(!trayectorias[id]) trayectorias[id]=[];
            trayectorias[id].push({pos:puntoEntrada.clone(),dir:dirT.clone(),name:c.name});
            VisorLog.postMessage('Tray '+c.name+' eje='+['X','Y','Z'][eje]+' pos='+puntoEntrada.x.toFixed(1)+','+puntoEntrada.y.toFixed(1)+','+puntoEntrada.z.toFixed(1));
          }
        }
      });

      gltf.scene.traverse(c=>{
        if(c.isMesh && !c.userData.esTrayectoria){
          c.castShadow=c.receiveShadow=true;
          c.material.polygonOffset=true;
          c.material.polygonOffsetFactor=1;
          c.material.polygonOffsetUnits=1;
          if(esHueso) c.userData.esHueso=true;
        }
      });
      if(esHueso) gltf.scene.userData.esHueso=true;
      scene.add(gltf.scene);
      modelos[id]=gltf.scene;
      _invalidarCacheMeshes(); // el nuevo modelo cambia la escena
      if(Object.keys(modelos).length===1){
        const box=new THREE.Box3().setFromObject(gltf.scene);
        const ctr=new THREE.Vector3(), sz=new THREE.Vector3();
        box.getCenter(ctr); box.getSize(sz);
        controls.target.copy(ctr);
        camera.position.set(ctr.x, ctr.y, ctr.z+Math.max(sz.x,sz.y,sz.z)*3.5);
        controls.update();
      }
      _hideLayerLoading();
      VisorLog.postMessage('Cargado: '+id);
      // Si el plano de corte está activo, aplicarlo al nuevo modelo
      if(_planoActivo) setPlanoCorte(true, _planoEjeActual, _planoPosActual);
      // Re-aplicar color si se había personalizado
      if(_coloresGlb[id]) setColor(id, _coloresGlb[id]);
    }, err=>{
      _hideLayerLoading();
      VisorLog.postMessage('Error: '+err);
    });
  }catch(e){
    _hideLayerLoading();
    VisorLog.postMessage('Error base64: '+e);
  }
  }, 0); // fin setTimeout — cede el hilo al render antes de parsear
}

// ── Registrar tornillo catálogo ────────────────────────────────────────────
function registrarTornillo(catId, b64){
  if(catalogoGltf[catId]){
    TornilloListo.postMessage(catId);
    return;
  }
  loader.parse(b64ToBuffer(b64),'', gltf=>{
    catalogoGltf[catId]=gltf;
    VisorLog.postMessage('Tornillo registrado: '+catId);
    TornilloListo.postMessage(catId);
  }, err=>VisorLog.postMessage('Error tornillo: '+err));
}

// ── Insertar tornillo — llamado desde Flutter ──────────────────────────────
function insertarTornillo(jsonStr){
  const d = JSON.parse(jsonStr);
  if(!catalogoGltf[d.catId]){
    VisorLog.postMessage('Catálogo no listo: '+d.catId);
    return;
  }

  // Reconstruir vectores desde los datos de Flutter
  const hitNormal = new THREE.Vector3(d.nx, d.ny, d.nz).normalize();
  const hitPoint  = new THREE.Vector3(d.x,  d.y,  d.z);

  // Clonar el GLB del tornillo
  const tornilloScene = catalogoGltf[d.catId].scene.clone(true);
  tornilloScene.traverse(c=>{
    if(c.isMesh){
      c.material = c.material.clone();
      c.castShadow = c.receiveShadow = true;
      c.material.polygonOffset      = true;
      c.material.polygonOffsetFactor = -2;
      c.material.polygonOffsetUnits  = -2;
      c.userData.esTornillo          = true;
    }
  });
  tornilloScene.userData.esTornillo = true;

  // Orientar y posicionar
  // Si viene de trayectoria, usar posición/dirección exactas del cilindro
  if(d.usarTrayectoria){
    const dirEntrada = new THREE.Vector3(d.dx, d.dy, d.dz).normalize();

    // Medir eje largo del tornillo en reposo
    tornilloScene.position.set(0,0,0); tornilloScene.rotation.set(0,0,0); tornilloScene.updateMatrixWorld(true);
    const box = new THREE.Box3().setFromObject(tornilloScene);
    const size = new THREE.Vector3(); box.getSize(size);
    let ejeIdx = 1;
    if(size.x>=size.y && size.x>=size.z) ejeIdx=0;
    else if(size.z>=size.x && size.z>=size.y) ejeIdx=2;
    const largo = [size.x,size.y,size.z][ejeIdx];
    const ejes = [new THREE.Vector3(1,0,0),new THREE.Vector3(0,1,0),new THREE.Vector3(0,0,1)];

    VisorLog.postMessage('=== TORNILLO DEBUG ===');
    VisorLog.postMessage('hitPoint='+d.x.toFixed(2)+','+d.y.toFixed(2)+','+d.z.toFixed(2));
    VisorLog.postMessage('dirEntrada='+dirEntrada.x.toFixed(3)+','+dirEntrada.y.toFixed(3)+','+dirEntrada.z.toFixed(3));
    VisorLog.postMessage('tornillo eje='+['X','Y','Z'][ejeIdx]+' largo='+largo.toFixed(2));
    VisorLog.postMessage('tornillo box min='+box.min.x.toFixed(2)+','+box.min.y.toFixed(2)+','+box.min.z.toFixed(2));
    VisorLog.postMessage('tornillo box max='+box.max.x.toFixed(2)+','+box.max.y.toFixed(2)+','+box.max.z.toFixed(2));

    // Detectar cabeza: buscar mesh HEAD, si no fallback por radio
    const center = new THREE.Vector3(); box.getCenter(center);
    let cDir = 1;
    let headMesh = null;
    tornilloScene.traverse(c => { if(c.isMesh && c.name === 'HEAD') headMesh = c; });
    if(headMesh){
      const headBox = new THREE.Box3().setFromObject(headMesh);
      const headCenter = new THREE.Vector3(); headBox.getCenter(headCenter);
      const rawDir = headCenter.getComponent(ejeIdx) >= center.getComponent(ejeIdx) ? 1 : -1;
      // rawDir=-1 significa HEAD está en X negativo
      // ejeConCabeza debe apuntar en dirección del HEAD para alinearse con cabezaDir
      // → usar rawDir directamente (no negar)
      cDir = rawDir;
      VisorLog.postMessage('HEAD encontrado: headCenter='+headCenter.x.toFixed(2)+','+headCenter.y.toFixed(2)+','+headCenter.z.toFixed(2));
      VisorLog.postMessage('tornillo center='+center.x.toFixed(2)+','+center.y.toFixed(2)+','+center.z.toFixed(2));
      VisorLog.postMessage('rawDir='+rawDir+' cDir='+cDir);
    } else {
      let primerMesh=null; tornilloScene.traverse(c=>{if(c.isMesh&&!primerMesh)primerMesh=c;});
      if(primerMesh){
        const pos=primerMesh.geometry.attributes.position;
        const mn=box.min.getComponent(ejeIdx), mx=box.max.getComponent(ejeIdx), q=largo*0.2;
        let rP=0,rN=0; const t=new THREE.Vector3();
        for(let i=0;i<pos.count;i++){
          t.set(pos.getX(i),pos.getY(i),pos.getZ(i));
          const comp=t.getComponent(ejeIdx);
          const ddx=ejeIdx===0?0:t.x-center.x, ddy=ejeIdx===1?0:t.y-center.y, ddz=ejeIdx===2?0:t.z-center.z;
          const r=Math.sqrt(ddx*ddx+ddy*ddy+ddz*ddz);
          if(comp>=mx-q&&r>rP) rP=r;
          if(comp<=mn+q&&r>rN) rN=r;
        }
        cDir=rP>=rN?1:-1;
        VisorLog.postMessage('SIN HEAD: fallback cDir='+cDir+' rP='+rP.toFixed(2)+' rN='+rN.toFixed(2));
      }
    }
    const ejeConCabeza = ejes[ejeIdx].clone().multiplyScalar(cDir);
    VisorLog.postMessage('ejeConCabeza='+ejeConCabeza.x.toFixed(2)+','+ejeConCabeza.y.toFixed(2)+','+ejeConCabeza.z.toFixed(2));

    const cabezaDir = dirEntrada.clone().negate(); // cabeza apunta hacia fuera (opuesto a dirEntrada)
    VisorLog.postMessage('cabezaDir='+cabezaDir.x.toFixed(3)+','+cabezaDir.y.toFixed(3)+','+cabezaDir.z.toFixed(3));

    const q = new THREE.Quaternion(); q.setFromUnitVectors(ejeConCabeza, cabezaDir);
    tornilloScene.quaternion.copy(q);
    tornilloScene.position.set(0,0,0);
    tornilloScene.updateMatrixWorld(true);

    // Verificar dónde queda el HEAD tras la rotación
    if(headMesh){
      const headBoxRot = new THREE.Box3().setFromObject(headMesh);
      const headCenterRot = new THREE.Vector3(); headBoxRot.getCenter(headCenterRot);
      const boxRot = new THREE.Box3().setFromObject(tornilloScene);
      const centerRot = new THREE.Vector3(); boxRot.getCenter(centerRot);
      VisorLog.postMessage('TRAS ROTACION: headCenter='+headCenterRot.x.toFixed(2)+','+headCenterRot.y.toFixed(2)+','+headCenterRot.z.toFixed(2));
      VisorLog.postMessage('TRAS ROTACION: tornilloCenter='+centerRot.x.toFixed(2)+','+centerRot.y.toFixed(2)+','+centerRot.z.toFixed(2));
      // ¿El HEAD apunta en dirección cabezaDir o en dirección contraria?
      const headOffset = headCenterRot.clone().sub(centerRot);
      const dotProduct = headOffset.dot(cabezaDir);
      VisorLog.postMessage('HEAD dot cabezaDir='+dotProduct.toFixed(3)+' (>0=mismo sentido, <0=opuesto)');
    }
let offsetCabeza = largo * 0.5;

// ajuste dinámico según largo
if(largo > 12) offsetCabeza += 1.2;
else offsetCabeza += 0.6;

VisorLog.postMessage('offsetCabeza='+offsetCabeza.toFixed(2));

tornilloScene.position.copy(hitPoint)
  .addScaledVector(cabezaDir, -largo);
  
    VisorLog.postMessage('posicion final='+tornilloScene.position.x.toFixed(2)+','+tornilloScene.position.y.toFixed(2)+','+tornilloScene.position.z.toFixed(2));
    VisorLog.postMessage('=== FIN DEBUG ===');

  } else {
    orientarTornillo(tornilloScene, hitNormal, hitPoint);
  }

  tornilloScene.userData.instanceId = d.instanceId;
  const _tGlbId = _findPlacaGlbId(d.x, d.y, d.z);
  tornilloScene.userData.placaGlbId = _tGlbId;
  // Añadir primero a la escena (posición en world space), luego reparentar a la placa.
  // attach() convierte automáticamente a espacio local de la placa preservando la posición mundo.
  scene.add(tornilloScene);
  if(_tGlbId && modelos[_tGlbId]){
    modelos[_tGlbId].attach(tornilloScene); // re-parent manteniendo world transform
  }
  // origPos/origQuat ahora en espacio local de la placa (lo que devuelve attach)
  tornilloScene.userData.origPos  = tornilloScene.position.clone();
  tornilloScene.userData.origQuat = tornilloScene.quaternion.clone();
  modelos[d.instanceId] = tornilloScene;
  _invalidarCacheMeshes();

  // Ocultar el cilindro guía que fue tocado
  if(d.cilindroId){
    scene.traverse(c => {
      if(c.uuid === d.cilindroId) c.visible = false;
    });
  }

  // Largo real desde el modelo 3D (para la regla visual)
  const boxL = new THREE.Box3().setFromObject(tornilloScene);
  const szL  = new THREE.Vector3(); boxL.getSize(szL);
  const largoReal = Math.max(szL.x, szL.y, szL.z);

  ScrewPlaced.postMessage(JSON.stringify({
    instanceId: d.instanceId,
    glbId:      d.catId,
    nombre:     d.nombre,
    cilindroId: d.cilindroId || '',
  }));

  // Crear regla 3D al lado del tornillo (texto viene del nombre desde Flutter)
  _crearRegla(d.instanceId, tornilloScene, largoReal, d.nombre);
  VisorLog.postMessage('Insertado: '+d.instanceId+' en pos='+tornilloScene.position.x.toFixed(1)+','+tornilloScene.position.y.toFixed(1)+','+tornilloScene.position.z.toFixed(1));
}

// ── Regla 3D ─────────────────────────────────────────────────────────────
const _reglas = {}; // instanceId → Group (linea + sprite)

function _parsearTornillo(nombre){
  // Quitar extensión
  const sin = nombre.replace(/\.[^.]+$/, '');
  // Patrón: XX.YY.ZZNNN Nombre → diam=YY/10, largo=NNN, nombre=resto
  const m = sin.match(/^\d\d\.(\d\d)\.\d\d(\d\d\d)\s+(.+)$/);
  if(m){ return { diam: parseInt(m[1])/10.0, largo: parseInt(m[2]), nombre: m[3].trim() }; }
  return { diam: 0, largo: 0, nombre: sin };
}

function _parseLargoNombre(nombre){
  const p = _parsearTornillo(nombre);
  if(p.largo > 0) return p.largo+'';
  const m2 = nombre.match(/(\d+)\s*mm/i);
  if(m2) return m2[1];
  return null;
}

function _parseLabelTornillo(nombre){
  const p = _parsearTornillo(nombre);
  if(p.largo > 0) return 'Ø'+p.diam+' · '+p.largo+' mm';
  const mm = _parseLargoNombre(nombre);
  return mm ? mm+' mm' : '?';
}

function _crearRegla(instanceId, tornilloObj, largoReal, nombre){
  const label = _parseLabelTornillo(nombre);
  tornilloObj.updateMatrixWorld(true);
  const box  = new THREE.Box3().setFromObject(tornilloObj);
  const size = new THREE.Vector3(); box.getSize(size);
  const center = new THREE.Vector3(); box.getCenter(center);

  // Eje largo del tornillo
  let ejeIdx = 1;
  if(size.x>=size.y && size.x>=size.z) ejeIdx=0;
  else if(size.z>=size.x && size.z>=size.y) ejeIdx=2;
  const largo = [size.x,size.y,size.z][ejeIdx];

  // Dirección perpendicular al eje para offset lateral
  const ejes = [new THREE.Vector3(1,0,0),new THREE.Vector3(0,1,0),new THREE.Vector3(0,0,1)];
  const ejeTornillo = ejes[ejeIdx].clone();
  // Obtener rotación del tornillo para transformar el eje
  const dir = ejeTornillo.clone().applyQuaternion(tornilloObj.quaternion).normalize();
  // Vector perpendicular al eje del tornillo y a la cámara
  const up = new THREE.Vector3(0,1,0);
  let perp = new THREE.Vector3().crossVectors(dir, up).normalize();
  if(perp.length() < 0.01) perp = new THREE.Vector3(1,0,0);
  const offset = perp.multiplyScalar(largo * 0.6 + 4); // offset lateral

  // Extremos del tornillo en espacio mundo
  const minPt = new THREE.Vector3();
  const maxPt = new THREE.Vector3();
  box.getCenter(minPt); box.getCenter(maxPt);
  minPt.addScaledVector(dir, -largo/2);
  maxPt.addScaledVector(dir,  largo/2);

  // Puntos de la regla (desplazados lateralmente)
  const p1 = minPt.clone().add(offset);
  const p2 = maxPt.clone().add(offset);

  const group = new THREE.Group();
  group.userData.esRegla = true;
  group.userData.reglaId = instanceId;

  // Línea principal
  const geomL = new THREE.BufferGeometry().setFromPoints([p1, p2]);
  const matL  = new THREE.LineBasicMaterial({ color: 0xFFD60A, linewidth: 2, depthTest: false });
  const linea = new THREE.Line(geomL, matL);
  linea.renderOrder = 999;
  group.add(linea);

  // Tick inicio
  const t1a = p1.clone().addScaledVector(dir,  largo*0.03);
  const t1b = p1.clone().addScaledVector(dir, -largo*0.03);
  const geomT1 = new THREE.BufferGeometry().setFromPoints([t1a, t1b]);
  group.add(new THREE.Line(geomT1, matL.clone()));

  // Tick fin
  const t2a = p2.clone().addScaledVector(dir,  largo*0.03);
  const t2b = p2.clone().addScaledVector(dir, -largo*0.03);
  const geomT2 = new THREE.BufferGeometry().setFromPoints([t2a, t2b]);
  group.add(new THREE.Line(geomT2, matL.clone()));

  // Sprite etiqueta mm
  const canvas = document.createElement('canvas');
  canvas.width = 200; canvas.height = 70;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = 'rgba(28,28,30,0.88)';
  _roundRect(ctx,0,0,200,70,14); ctx.fill();
  ctx.strokeStyle = 'rgba(255,214,10,0.9)'; ctx.lineWidth=2;
  _roundRect(ctx,1,1,198,68,13); ctx.stroke();
  ctx.fillStyle = '#FFD60A';
  ctx.font = 'bold 32px -apple-system,sans-serif';
  ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
  ctx.fillText(label, 100, 35);

  const tex = new THREE.CanvasTexture(canvas);
  const spriteMat = new THREE.SpriteMaterial({ map: tex, depthTest: false, transparent: true });
  const sprite = new THREE.Sprite(spriteMat);
  // Posición: centro de la línea, un poco más afuera
  const mid = p1.clone().lerp(p2, 0.5).add(perp.clone().normalize().multiplyScalar(largo*0.15+3));
  sprite.position.copy(mid);
  sprite.scale.set(9, 3, 1);
  sprite.renderOrder = 1000;
  group.add(sprite);

  scene.add(group);
  _reglas[instanceId] = group;
  needsRender = true;
}

function toggleRegla(instanceId, v){
  if(_reglas[instanceId]) _reglas[instanceId].visible = v;
  needsRender = true;
}

function eliminarRegla(instanceId){
  const g = _reglas[instanceId]; if(!g) return;
  scene.remove(g);
  g.traverse(c=>{
    if(c.geometry) c.geometry.dispose();
    if(c.material){ if(c.material.map) c.material.map.dispose(); c.material.dispose(); }
  });
  delete _reglas[instanceId];
  needsRender = true;
}

// ── Eliminar tornillo ──────────────────────────────────────────────────────
function eliminarTornillo(instanceId){
  const obj = modelos[instanceId]; if(!obj) return;
  obj.removeFromParent();
  obj.traverse(c=>{ if(c.isMesh){ c.geometry.dispose(); c.material.dispose(); } });
  delete modelos[instanceId];
  _invalidarCacheMeshes();
}

// ── Standard ──────────────────────────────────────────────────────────────
// Oculta/muestra solo la geometría de la placa, respetando visibilidad de trayectorias
function toggleGlb(id,v){
  if(!modelos[id]) return;
  if(v){
    modelos[id].visible = true;
    modelos[id].traverse(c=>{ c.visible = true; });
  } else {
    modelos[id].traverse(c=>{
      if(c.isMesh && !c.userData.esTrayectoria) c.visible = false;
    });
  }
  _invalidarCacheMeshes();
}
function toggleGuias(v){
  scene.traverse(c=>{ if(c.userData.esTrayectoria) c.visible=v; });
  _invalidarCacheMeshes();
}
function toggleTrayectoriasGlb(id, v){
  if(!modelos[id]) return;
  modelos[id].traverse(c=>{ if(c.userData.esTrayectoria) c.visible=v; });
  _invalidarCacheMeshes();
}
function setOpacidad(id,op){
  if(!modelos[id]) return;
  modelos[id].traverse(c=>{
    if(c.isMesh){ c.material.transparent=op<1; c.material.opacity=op; c.material.needsUpdate=true; }
  });
  needsRender = true;
}
function setAutoRotate(v){ controls.autoRotate=v; controls.autoRotateSpeed=1.5; needsRender = true; }

// ── Modo Rayos X: transparenta todos los huesos ──────────────────────────
function setXray(op){
  for(const id in modelos){
    const m = modelos[id];
    if(!m || !m.userData.esHueso) continue;
    m.traverse(c=>{
      if(c.isMesh){
        c.material.transparent = op < 1;
        c.material.opacity = op;
        c.material.needsUpdate = true;
      }
    });
  }
  needsRender = true;
}

// ── Iluminación ──────────────────────────────────────────────────────────
const _luces = { ambient: null, d1: null, d2: null };
function _initLuces(){
  scene.traverse(o=>{
    if(o.isAmbientLight) _luces.ambient=o;
    if(o.isDirectionalLight && !_luces.d1) _luces.d1=o;
    else if(o.isDirectionalLight) _luces.d2=o;
  });
}
function setLuz(modo){
  _initLuces();
  if(modo===0){ // quirúrgica (default)
    if(_luces.ambient) _luces.ambient.intensity=1.3;
    if(_luces.d1){ _luces.d1.position.set(5,10,7); _luces.d1.intensity=1.8; }
    if(_luces.d2){ _luces.d2.position.set(-5,-3,-5); _luces.d2.intensity=0.5; }
  } else if(modo===1){ // cenital
    if(_luces.ambient) _luces.ambient.intensity=0.8;
    if(_luces.d1){ _luces.d1.position.set(0,20,0); _luces.d1.intensity=2.5; }
    if(_luces.d2){ _luces.d2.position.set(0,-10,0); _luces.d2.intensity=0.3; }
  } else if(modo===2){ // lateral dramática
    if(_luces.ambient) _luces.ambient.intensity=0.4;
    if(_luces.d1){ _luces.d1.position.set(20,2,0); _luces.d1.intensity=3.0; }
    if(_luces.d2){ _luces.d2.position.set(-20,0,5); _luces.d2.intensity=0.8; }
  }
}

// ── Color personalizado por capa ─────────────────────────────────────────
function setColor(id, hexColor){
  VisorLog.postMessage('setColor id='+id+' hex='+hexColor+' modeloExiste='+(!!modelos[id]));
  if(!modelos[id]) return;
  _coloresGlb[id] = hexColor; // guardar para re-aplicar si se recarga
  modelos[id].traverse(c=>{
    if(c.isMesh && !c.userData.esTrayectoria && !c.userData.esTornillo){
      const oldMat = Array.isArray(c.material) ? c.material[0] : c.material;
      const newMat = new THREE.MeshStandardMaterial({
        color: new THREE.Color(hexColor),
        roughness: oldMat.roughness !== undefined ? oldMat.roughness : 0.6,
        metalness: oldMat.metalness !== undefined ? oldMat.metalness : 0.1,
        transparent: oldMat.transparent || false,
        opacity: oldMat.opacity !== undefined ? oldMat.opacity : 1.0,
        side: oldMat.side !== undefined ? oldMat.side : THREE.FrontSide,
        // Quitar textura y vertex colors para que el color sólido sea visible
        map: null,
        vertexColors: false,
      });
      // Si el modelo tenía clipping planes aplicados, mantenerlos
      if(oldMat.clippingPlanes) newMat.clippingPlanes = oldMat.clippingPlanes;
      newMat.needsUpdate = true;
      c.material = Array.isArray(c.material) ? [newMat] : newMat;
    }
  });
}
// ── Plano de corte ───────────────────────────────────────────────────────
const _planoCorte = new THREE.Plane();
let   _planoActivo = false;
let   _planoEjeActual = 1;
let   _planoPosActual = 0.5;

function setPlanoCorte(activo, eje, posNorm){
  _planoActivo = activo;
  _planoEjeActual = eje;
  _planoPosActual = posNorm;
  renderer.localClippingEnabled = true; // siempre true, controlamos por material

  if(!activo){
    // Desactivar: quitar plano de todos los materiales y deshabilitar renderer
    scene.traverse(c=>{
      if(c.isMesh){
        c.material.clippingPlanes = [];
        c.material.needsUpdate = true;
      }
    });
    renderer.localClippingEnabled = false;
    needsRender = true;
    return;
  }

  // Calcular bounding box global de la escena
  const box = new THREE.Box3();
  scene.traverse(c=>{ if(c.isMesh && !c.userData.esTrayectoria) box.expandByObject(c); });
  if(box.isEmpty()) return;
  const mn = box.min, mx = box.max;

  // Actualizar normal y constante del plano según eje
  if(eje===0){
    _planoCorte.normal.set(-1, 0, 0);
    _planoCorte.constant = mn.x + (mx.x - mn.x) * posNorm;
  } else if(eje===1){
    _planoCorte.normal.set(0, -1, 0);
    _planoCorte.constant = mn.y + (mx.y - mn.y) * posNorm;
  } else {
    _planoCorte.normal.set(0, 0, -1);
    _planoCorte.constant = mn.z + (mx.z - mn.z) * posNorm;
  }

  // Asignar plano a todos los meshes (excepto sprites de notas y trayectorias)
  scene.traverse(c=>{
    if(c.isMesh && !c.userData.esTrayectoria && !c.userData.esNota){
      c.material.clippingPlanes = [_planoCorte];
      c.material.clipShadows    = true;
      c.material.needsUpdate    = true;
    }
  });
  needsRender = true;
}

// Activar/desactivar plano en un GLB concreto
function setPlanoGlb(id, activo){
  if(!modelos[id]) return;
  modelos[id].traverse(c=>{
    if(c.isMesh && !c.userData.esTrayectoria){
      c.material.clippingPlanes = activo ? [_planoCorte] : [];
      c.material.needsUpdate = true;
    }
  });
  needsRender = true;
}

// ── Regla libre ──────────────────────────────────────────────────────────
let _modoReglaActivo = false;
let _reglaP1 = null;
let _reglaGroup = null;

const _reglasGuardadas = {};

function setModoRegla(v){
  _modoReglaActivo = v;
  if(!v){ _reglaP1 = null; }
  // NO limpiar: la regla se queda en pantalla hasta que el usuario la elimine
}

function etiquetarRegla(id){
  if(_reglaGroup){ _reglasGuardadas[id] = _reglaGroup; _reglaGroup = null; }
}

function toggleReglaLibre(id, visible){
  if(_reglasGuardadas[id]) _reglasGuardadas[id].visible = visible;
}

function eliminarReglaLibre(id){
  if(_reglasGuardadas[id]){ scene.remove(_reglasGuardadas[id]); delete _reglasGuardadas[id]; }
}

function _limpiarReglaLibre(){
  if(_reglaGroup){ scene.remove(_reglaGroup); _reglaGroup=null; }
}

function _dibujarReglaLibre(p1, p2){
  _limpiarReglaLibre();
  const group = new THREE.Group();
  // Línea
  const mat = new THREE.LineBasicMaterial({color:0x64D2FF, depthTest:false, linewidth:2});
  const geo = new THREE.BufferGeometry().setFromPoints([p1,p2]);
  const line = new THREE.Line(geo, mat);
  line.renderOrder=999; group.add(line);
  // Esferas en extremos
  const sGeo = new THREE.SphereGeometry(0.8,8,8);
  const sMat = new THREE.MeshBasicMaterial({color:0x64D2FF, depthTest:false});
  const s1=new THREE.Mesh(sGeo,sMat); s1.position.copy(p1); s1.renderOrder=1000; group.add(s1);
  const s2=new THREE.Mesh(sGeo,sMat.clone()); s2.position.copy(p2); s2.renderOrder=1000; group.add(s2);
  // Sprite medida
  const mm = p1.distanceTo(p2);
  const mid = p1.clone().lerp(p2,0.5);
  const canvas=document.createElement('canvas'); canvas.width=160; canvas.height=44;
  const ctx=canvas.getContext('2d');
  _roundRect(ctx,0,0,160,44,10); ctx.fillStyle='rgba(10,10,12,0.75)'; ctx.fill();
  ctx.strokeStyle='rgba(100,210,255,0.6)'; ctx.lineWidth=1.5;
  _roundRect(ctx,1,1,158,42,9); ctx.stroke();
  ctx.fillStyle='#64D2FF'; ctx.font='bold 20px -apple-system,sans-serif';
  ctx.textAlign='center'; ctx.textBaseline='middle';
  ctx.fillText(mm.toFixed(1)+' mm',80,22);
  const tex=new THREE.CanvasTexture(canvas);
  const sp=new THREE.Sprite(new THREE.SpriteMaterial({map:tex,depthTest:false,transparent:true}));
  sp.position.copy(mid); sp.scale.set(8, 2.5, 1); sp.renderOrder=1001; group.add(sp);
  scene.add(group); _reglaGroup=group;
  return mm;
}

// ── Notas 3D ─────────────────────────────────────────────────────────────
let _modoNotaActivo = false;
const _notas3D = {}; // id → { sprite, texto }

function setModoNota(v){ _modoNotaActivo = v; }

function addNota(id, x, y, z, texto){
  // Crear sprite con canvas
  const canvas = document.createElement('canvas');
  canvas.width = 320; canvas.height = 140;
  const ctx = canvas.getContext('2d');

  // Fondo píldora amarilla
  ctx.fillStyle = 'rgba(28,28,30,0.92)';
  _roundRect(ctx, 0, 0, 320, 140, 18);
  ctx.fill();
  ctx.strokeStyle = 'rgba(255,214,10,0.8)';
  ctx.lineWidth = 3;
  _roundRect(ctx, 0, 0, 320, 140, 18);
  ctx.stroke();

  // Pin icon simulado
  ctx.fillStyle = '#FFD60A';
  ctx.beginPath();
  ctx.arc(28, 28, 10, 0, Math.PI*2);
  ctx.fill();
  ctx.fillStyle = '#1C1C1E';
  ctx.font = 'bold 14px sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText('📌', 28, 33);

  // Texto
  ctx.fillStyle = '#FFFFFF';
  ctx.font = '600 18px -apple-system, sans-serif';
  ctx.textAlign = 'left';
  // Wrap texto a 2 líneas
  const words = texto.split(' ');
  let line='', lines=[], maxW=270;
  for(const w of words){
    const test = line ? line+' '+w : w;
    if(ctx.measureText(test).width > maxW && line){ lines.push(line); line=w; }
    else line=test;
  }
  lines.push(line);
  lines = lines.slice(0,3);
  lines.forEach((l,i)=> ctx.fillText(l, 50, 38 + i*34));

  const tex = new THREE.CanvasTexture(canvas);
  const mat = new THREE.SpriteMaterial({ map: tex, depthTest: false, transparent: true });
  const sprite = new THREE.Sprite(mat);
  sprite.position.set(x, y, z);
  sprite.scale.set(30, 13, 1);
  sprite.userData.esNota = true;
  sprite.userData.notaId = id;
  scene.add(sprite);
  _notas3D[id] = sprite;
  needsRender = true;
}

function _roundRect(ctx, x, y, w, h, r){
  ctx.beginPath();
  ctx.moveTo(x+r,y); ctx.lineTo(x+w-r,y);
  ctx.arcTo(x+w,y,x+w,y+r,r); ctx.lineTo(x+w,y+h-r);
  ctx.arcTo(x+w,y+h,x+w-r,y+h,r); ctx.lineTo(x+r,y+h);
  ctx.arcTo(x,y+h,x,y+h-r,r); ctx.lineTo(x,y+r);
  ctx.arcTo(x,y,x+r,y,r); ctx.closePath();
}

function toggleNota(id, v){
  if(_notas3D[id]) _notas3D[id].visible = v;
  needsRender = true;
}

function removeNota(id){
  const s = _notas3D[id]; if(!s) return;
  scene.remove(s);
  s.material.map.dispose(); s.material.dispose();
  delete _notas3D[id];
  needsRender = true;
}

// ── Vistas rápidas con animación suave ───────────────────────────────────
function setVista(vista){
  // Calcular bounding box usando el mapa de modelos (evita scene.traverse completo)
  const box = new THREE.Box3();
  for(const id in modelos){
    const m = modelos[id];
    if(m && m.visible) m.traverse(c=>{ if(c.isMesh && !c.userData.esTrayectoria && c.visible) box.expandByObject(c); });
  }
  if(box.isEmpty()){ resetCamara(); return; }

  const center = new THREE.Vector3(); box.getCenter(center);
  const size   = new THREE.Vector3(); box.getSize(size);
  const dist   = Math.max(size.x, size.y, size.z) * 2.2;

  let targetPos;
  if(vista===0)      targetPos = new THREE.Vector3(center.x + dist, center.y, center.z); // Frontal
  else if(vista===1) targetPos = new THREE.Vector3(center.x, center.y, center.z + dist); // Lateral D
  else if(vista===2) targetPos = new THREE.Vector3(center.x, center.y, center.z - dist); // Lateral I
  else if(vista===3) targetPos = new THREE.Vector3(center.x, center.y + dist, center.z); // Superior
  else if(vista===4) targetPos = new THREE.Vector3(center.x, center.y - dist, center.z); // Inferior
  else               targetPos = new THREE.Vector3(center.x - dist, center.y, center.z); // Posterior

  // Animación suave: interpolamos posición en 30 frames
  const startPos = camera.position.clone();
  const startTarget = controls.target.clone();
  let frame = 0; const totalFrames = 25;
  const anim = setInterval(()=>{
    const t = 1 - Math.pow(1 - frame/totalFrames, 3); // ease out cubic
    camera.position.lerpVectors(startPos, targetPos, t);
    controls.target.lerpVectors(startTarget, center, t);
    controls.update();
    needsRender = true;
    frame++;
    if(frame > totalFrames){ clearInterval(anim); controls.update(); needsRender = true; }
  }, 16);
}

function resetCamara(){
  setVista(0);
}

function limpiarTodo(){
  // 1. Eliminar todos los GLBs cargados (los tornillos son hijos de sus placas, se limpian con ellas)
  for(const id in modelos){
    const obj = modelos[id];
    if(obj.userData.instanceId && String(obj.userData.instanceId).startsWith('screw_')){
      delete modelos[id]; continue; // ya se elimina al quitar la placa padre
    }
    obj.removeFromParent();
    obj.traverse(c=>{
      if(c.geometry) c.geometry.dispose();
      if(c.material){
        if(Array.isArray(c.material)) c.material.forEach(m=>m.dispose());
        else c.material.dispose();
      }
    });
    delete modelos[id];
  }
  // 2. Limpiar trayectorias
  for(const id in trayectorias) delete trayectorias[id];
  // 3. Eliminar reglas de tornillos (_reglas)
  for(const id in _reglas){
    scene.remove(_reglas[id]);
    _reglas[id].traverse(c=>{ if(c.geometry) c.geometry.dispose(); if(c.material) c.material.dispose(); });
    delete _reglas[id];
  }
  // 4. Eliminar regla libre activa
  if(_reglaGroup){ scene.remove(_reglaGroup); _reglaGroup=null; }
  // 5. Eliminar reglas libres guardadas
  for(const id in _reglasGuardadas){
    scene.remove(_reglasGuardadas[id]);
    delete _reglasGuardadas[id];
  }
  // 6. Forzar render limpio
  needsRender = true;
}

window.visor={
  cargarGlbBase64, registrarTornillo, insertarTornillo,
  toggleGlb, toggleGuias, toggleTrayectoriasGlb, setOpacidad, setAutoRotate, resetCamara, eliminarTornillo,
  setXray, setLuz, setColor, setPlanoCorte, setPlanoGlb, setVista,
  setModoNota, addNota, toggleNota, removeNota,
  setModoRegla, etiquetarRegla, toggleReglaLibre, eliminarReglaLibre,
  toggleRegla, eliminarRegla, limpiarTodo,
  setBackground: function(dark){
    const c=document.createElement('canvas'); c.width=2; c.height=512;
    const cx=c.getContext('2d');
    const g=cx.createLinearGradient(0,0,0,512);
    if(dark){
      g.addColorStop(0,'#0D0D1A'); g.addColorStop(0.5,'#16213E'); g.addColorStop(1,'#0D0D1A');
      document.body.style.background='#0D0D1A';
    } else {
      g.addColorStop(0,'#E8E8F0'); g.addColorStop(0.5,'#DCDCE8'); g.addColorStop(1,'#F0F0F3');
      document.body.style.background='#F0F0F3';
    }
    cx.fillStyle=g; cx.fillRect(0,0,2,512);
    scene.background=new THREE.CanvasTexture(c);
    needsRender = true;
  },
  capturarVista: function(v){
    setVista(v);
    setTimeout(function(){
      const prev = outlinePass.selectedObjects.slice();
      outlinePass.selectedObjects = [];
      renderer.render(scene, camera); // render directo sin outline para captura limpia
      const dataUrl = renderer.domElement.toDataURL('image/png');
      outlinePass.selectedObjects = prev;
      CapturaVista.postMessage(dataUrl);
    }, 500);
  },
  capturarPantalla: function(){
    const prev = outlinePass.selectedObjects.slice();
    outlinePass.selectedObjects = [];
    renderer.render(scene, camera);
    const dataUrl = renderer.domElement.toDataURL('image/png');
    outlinePass.selectedObjects = prev;
    Captura.postMessage(dataUrl);
  },
};

// ── Detectar tap (no drag) sobre cualquier mesh ────────────────────────────
let _longPressTimer = null;

// ── Arrastrar placa ─────────────────────────────────────────────────────────
let _placaArrastrandoId = null;
let _planoArrastre = new THREE.Plane();
let _arrastreOffset = new THREE.Vector3();
let _arrastrandoTimer = null;
let _twoFingerTimer = null;  // tap de 2 dedos con delay para no interferir con pinch
let _touchDragTimer = null;  // timer táctil de respaldo (no lo mata pointercancel en iOS)
let _touchDragStartX = 0, _touchDragStartY = 0;
let _arrastreMaxDist = 0; // máximo desplazamiento durante el timer
let _lastPointerX = 0, _lastPointerY = 0; // posición actual del puntero
const _arrastreTarget = new THREE.Vector3(); // buffer reutilizable para intersección
let _dblTapModelId = null, _dblTapTime = 0; // doble tap para reset
const _glowMeshes = []; // (ya no se usa con OutlinePass, se mantiene por compatibilidad)
let   _glowMat    = null;

// ── Multi-pointer para rotación/profundidad de placa ────────────────────────
const _ptrMap  = new Map(); // pointerId → {x,y} posición actual
const _prevPtr = new Map(); // pointerId → {x,y} posición anterior frame
let _prevPinchDist = 0;    // distancia anterior entre dos dedos (pinch)
let _modoGiroZ = false;          // toca zona inferior/superior → péndulo
let _giroZEsTop = false;         // true = toca cabeza, false = toca culo
let _indicadorFondoMesh = null;  // mesh rojo indicador zona activa
let _giroZPivot = null;          // punto de pivote para péndulo
let _modoGiroY = false;          // toca zona lateral → péndulo lateral
let _giroYEsLeft = false;        // true = toca lado izquierdo
let _giroYPivot = null;          // pivote para péndulo lateral
let _placaCenter = null;         // centro geométrico de la placa (para rotar sobre sí misma)

// Activa el arrastre de placa desde coordenadas de pantalla (screenX, screenY).
// Usado tanto por el long-press timer como por el tap de 2 dedos.
function _tryActivateDrag(screenX, screenY){
  const rect = renderer.domElement.getBoundingClientRect();
  const px = ((screenX-rect.left)/rect.width)*2-1;
  const py = -((screenY-rect.top)/rect.height)*2+1;
  const rc = new THREE.Raycaster();
  rc.setFromCamera({x:px,y:py}, camera);
  const plateMeshes = [];
  for(const id in modelos){
    const m = modelos[id];
    if(!m.userData.esHueso && !(m.userData.instanceId && String(m.userData.instanceId).startsWith('screw_'))){
      m.traverse(c=>{if(c.isMesh && !c.userData.esTrayectoria && c.visible) plateMeshes.push(c);});
    }
  }
  const hits = rc.intersectObjects(plateMeshes, false);
  if(hits.length===0) return;
  let modelId = null;
  for(const id in modelos){
    let found = false;
    modelos[id].traverse(c=>{ if(c===hits[0].object) found=true; });
    if(found){ modelId=id; break; }
  }
  if(!modelId) return;
  _placaArrastrandoId = modelId;
  const camDir = camera.getWorldDirection(new THREE.Vector3());
  _planoArrastre.setFromNormalAndCoplanarPoint(camDir.negate(), hits[0].point);
  _arrastreOffset.copy(hits[0].point).sub(modelos[modelId].position);
  controls.enabled = false;
  modelos[modelId].updateWorldMatrix(true, true);
  const _lBox = new THREE.Box3();
  modelos[modelId].traverse(c=>{
    if(c.isMesh && !c.userData.esTrayectoria && !c.userData.esTornillo && c.geometry && c.geometry.attributes.position){
      c.updateWorldMatrix(true, false);
      const _gb = new THREE.Box3().setFromBufferAttribute(c.geometry.attributes.position);
      _gb.applyMatrix4(new THREE.Matrix4().copy(modelos[modelId].matrixWorld).invert().multiply(c.matrixWorld));
      _lBox.union(_gb);
    }
  });
  const _localHit = modelos[modelId].worldToLocal(hits[0].point.clone());
  const _lH = _lBox.max.y - _lBox.min.y;
  const _relY = _lH > 0 ? (_localHit.y - _lBox.min.y) / _lH : 0.5;
  const _esBottom = _relY < 0.28;
  const _esTop    = _relY > 0.72;
  _placaCenter = modelos[modelId].localToWorld(new THREE.Vector3(
    (_lBox.min.x + _lBox.max.x) / 2,
    (_lBox.min.y + _lBox.max.y) / 2,
    (_lBox.min.z + _lBox.max.z) / 2
  ));
  _modoGiroZ  = _esBottom || _esTop;
  _giroZEsTop = _esTop;
  const _rr = renderer.domElement.getBoundingClientRect();
  const _bCorn = [];
  for(let xi=0;xi<=1;xi++) for(let yi=0;yi<=1;yi++) for(let zi=0;zi<=1;zi++){
    const wc = modelos[modelId].localToWorld(new THREE.Vector3(
      xi?_lBox.max.x:_lBox.min.x, yi?_lBox.max.y:_lBox.min.y, zi?_lBox.max.z:_lBox.min.z));
    const sc = wc.clone().project(camera);
    _bCorn.push({ sx:(sc.x+1)/2*_rr.width, w:wc.clone() });
  }
  const _sSX = Math.min(..._bCorn.map(c=>c.sx));
  const _sEX = Math.max(..._bCorn.map(c=>c.sx));
  const _touchSX = screenX - _rr.left;
  const _screenRelX = _sEX>_sSX ? (_touchSX-_sSX)/(_sEX-_sSX) : 0.5;
  const _esLeft  = !_modoGiroZ && _screenRelX < 0.28;
  const _esRight = !_modoGiroZ && _screenRelX > 0.72;
  _modoGiroY  = _esLeft || _esRight;
  _giroYEsLeft = _esLeft;
  if(_modoGiroZ){
    _crearIndicadorFondo(modelId, _giroZEsTop, false, false);
    _setPlacaGlow(modelId, true, true);
    _mostrarHint(true);
    const _localPivot = new THREE.Vector3(
      (_lBox.min.x + _lBox.max.x) / 2,
      _giroZEsTop ? _lBox.min.y : _lBox.max.y,
      (_lBox.min.z + _lBox.max.z) / 2
    );
    _giroZPivot = modelos[modelId].localToWorld(_localPivot.clone());
  } else if(_modoGiroY){
    _setPlacaGlow(modelId, true, true);
    _mostrarHint(true);
    const _midSX = (_sSX + _sEX) / 2;
    const _pivCorn = _bCorn.filter(c => _esLeft ? c.sx > _midSX : c.sx < _midSX);
    const _src = _pivCorn.length > 0 ? _pivCorn : _bCorn;
    _giroYPivot = _src.reduce((a,c)=>a.add(c.w), new THREE.Vector3()).divideScalar(_src.length);
  } else {
    _setPlacaGlow(modelId, true, false);
    _mostrarHint(false);
  }
  PlacaArrastrando.postMessage(JSON.stringify({id:modelId,active:true}));
  _iniciarOverlayColision(modelId);
}

// ── Colisión placa-hueso: overlay rojo en zona de intersección ───────────────
const _overlayColMeshes = []; // { mesh: THREE.Mesh, src: THREE.Mesh }
let   _colCheckPending  = false;

const _overlayColMat = new THREE.MeshBasicMaterial({
  color: 0xFF2200, transparent: true, opacity: 0.55,
  side: THREE.DoubleSide, depthTest: true, depthWrite: false,
  polygonOffset: true, polygonOffsetFactor: -2, polygonOffsetUnits: -2,
});

function _iniciarOverlayColision(modelId){
  _eliminarOverlayColision();
  modelos[modelId].traverse(c=>{
    if(!c.isMesh || c.userData.esTrayectoria || c.userData.esTornillo
       || c.userData.esOverlayColision || !c.geometry?.attributes?.position) return;
    const geo = new THREE.BufferGeometry();
    geo.setAttribute('position', c.geometry.attributes.position); // shared, read-only
    if(c.geometry.index) geo.setIndex(c.geometry.index); // needed for proper bbox
    geo.setDrawRange(0, 0); // invisible hasta primer check
    const m = new THREE.Mesh(geo, _overlayColMat);
    m.userData.esOverlayColision = true;
    m.renderOrder = 2;
    c.add(m);
    _overlayColMeshes.push({ mesh: m, src: c });
  });
}

function _eliminarOverlayColision(){
  for(const { mesh, src } of _overlayColMeshes){
    src.remove(mesh);
    mesh.geometry.dispose();
  }
  _overlayColMeshes.length = 0;
  _colCheckPending = false;
}

function _puntoEnHueso(pt, meshes){
  // 3 direcciones → mayoría de votos (robusto ante mallas no perfectas)
  const dirs=[
    new THREE.Vector3(1,0.17,0.09).normalize(),
    new THREE.Vector3(-0.09,1,0.17).normalize(),
    new THREE.Vector3(0.17,-0.09,1).normalize(),
  ];
  const rc = new THREE.Raycaster();
  let v=0;
  for(const d of dirs){ rc.set(pt,d); if(rc.intersectObjects(meshes,false).length%2===1) v++; }
  return v>=2;
}

function _ejecutarColisionCheck(modelId){
  _colCheckPending = false;
  if(!_placaArrastrandoId || !_overlayColMeshes.length) return;

  // Recoger meshes del hueso
  const huesoMeshes=[];
  for(const id in modelos){
    if(modelos[id].userData.esHueso){
      modelos[id].traverse(c=>{
        if(c.isMesh && c.visible && !c.userData.esOverlayColision) huesoMeshes.push(c);
      });
    }
  }
  if(!huesoMeshes.length) return;

  // AABB hueso + margen para pre-filtrado rápido
  const boneBbox = new THREE.Box3();
  for(const m of huesoMeshes) boneBbox.expandByObject(m);
  boneBbox.expandByScalar(3);

  const _v0=new THREE.Vector3(), _v1=new THREE.Vector3(),
        _v2=new THREE.Vector3(), _cen=new THREE.Vector3();

  for(const { mesh, src } of _overlayColMeshes){
    const pos = src.geometry.attributes.position;
    const idxArr = src.geometry.index?.array ?? null;
    const triCount = idxArr ? idxArr.length/3 : pos.count/3;
    const redIdx = [];

    for(let t=0; t<triCount; t++){
      const i0 = idxArr ? idxArr[t*3]   : t*3;
      const i1 = idxArr ? idxArr[t*3+1] : t*3+1;
      const i2 = idxArr ? idxArr[t*3+2] : t*3+2;
      _v0.fromBufferAttribute(pos,i0).applyMatrix4(src.matrixWorld);
      _v1.fromBufferAttribute(pos,i1).applyMatrix4(src.matrixWorld);
      _v2.fromBufferAttribute(pos,i2).applyMatrix4(src.matrixWorld);
      _cen.copy(_v0).add(_v1).add(_v2).divideScalar(3);
      if(!boneBbox.containsPoint(_cen)) continue; // pre-filtro O(1)
      if(_puntoEnHueso(_cen, huesoMeshes)) redIdx.push(i0,i1,i2);
    }

    if(redIdx.length){
      mesh.geometry.setIndex(new THREE.BufferAttribute(new Uint32Array(redIdx),1));
      mesh.geometry.index.needsUpdate = true;
      mesh.geometry.setDrawRange(0, Infinity);
    } else {
      mesh.geometry.setDrawRange(0, 0);
    }
  }
  needsRender = true;
}

function _actualizarOverlayColision(modelId){
  if(_colCheckPending) return;
  _colCheckPending = true;
  setTimeout(()=>_ejecutarColisionCheck(modelId), 150);
}

renderer.domElement.addEventListener('pointerdown', e=>{
  _ptrMap.set(e.pointerId, {x:e.clientX, y:e.clientY});
  _prevPtr.set(e.pointerId, {x:e.clientX, y:e.clientY});
  // Si ya arrastramos placa: segundo dedo o click derecho → rotación, no reiniciar timer
  if(_placaArrastrandoId) return;
  pointerDownX=e.clientX; pointerDownY=e.clientY;
  // Tap de 2 dedos sobre placa → activar arrastre inmediatamente (sin long press)
  if(_ptrMap.size === 2 && !_modoNotaActivo){
    if(_arrastrandoTimer){ clearTimeout(_arrastrandoTimer); _arrastrandoTimer=null; }
    const ptrs = Array.from(_ptrMap.values());
    const midX = (ptrs[0].x + ptrs[1].x) / 2;
    const midY = (ptrs[0].y + ptrs[1].y) / 2;
    _tryActivateDrag(midX, midY);
    return;
  }
  if(_modoNotaActivo){
    _longPressTimer = setTimeout(()=>{
      const rect = renderer.domElement.getBoundingClientRect();
      const px = ((e.clientX-rect.left)/rect.width)*2-1;
      const py = -((e.clientY-rect.top)/rect.height)*2+1;
      const rc = new THREE.Raycaster();
      rc.setFromCamera({x:px,y:py}, camera);
      const hits = rc.intersectObjects(_getMeshesGeom(), false);
      if(hits.length>0){
        const p = hits[0].point;
        NotaTap.postMessage(JSON.stringify({x:p.x,y:p.y,z:p.z}));
      }
    }, 600);
  } else {
    _arrastreMaxDist = 0;
    _lastPointerX = e.clientX; _lastPointerY = e.clientY;
    _arrastrandoTimer = setTimeout(()=>{
      if(_arrastreMaxDist > 40){ _arrastrandoTimer=null; return; }
      _tryActivateDrag(_lastPointerX, _lastPointerY);
    }, 600);
  }
});
renderer.domElement.addEventListener('pointermove', e=>{
  _lastPointerX = e.clientX; _lastPointerY = e.clientY;
  // Actualizar mapa de punteros
  const prev = _ptrMap.get(e.pointerId);
  if(prev) _prevPtr.set(e.pointerId, {x:prev.x, y:prev.y});
  _ptrMap.set(e.pointerId, {x:e.clientX, y:e.clientY});

  if(_arrastrandoTimer){
    const d = Math.sqrt((e.clientX-pointerDownX)**2+(e.clientY-pointerDownY)**2);
    if(d > _arrastreMaxDist) _arrastreMaxDist = d;
  }
  if(!_placaArrastrandoId) return;
  _actualizarOverlayColision(_placaArrastrandoId);

  const modelo = modelos[_placaArrastrandoId];
  if(!modelo) return;

  const modoRotar = _ptrMap.size >= 2 || (e.buttons & 2);

  if(modoRotar && _ptrMap.size >= 2){
    // ── Dos dedos táctiles: descomposición en traslación + profundidad + rotación ──
    // Procesar solo una vez por par de eventos (puntero primario = id más bajo)
    const ptrIds = [..._ptrMap.keys()].sort((a,b)=>a-b);
    if(e.pointerId !== ptrIds[0]){ needsRender = true; return; }

    const pts     = ptrIds.map(id => _ptrMap.get(id));
    const prevPts = ptrIds.map(id => _prevPtr.get(id) || _ptrMap.get(id));

    // Midpoint actual y anterior
    const midCurX  = (pts[0].x  + pts[1].x)  / 2;
    const midCurY  = (pts[0].y  + pts[1].y)  / 2;
    const midPrevX = (prevPts[0].x + prevPts[1].x) / 2;
    const midPrevY = (prevPts[0].y + prevPts[1].y) / 2;
    const dMidX = midCurX - midPrevX;
    const dMidY = midCurY - midPrevY;

    // Traslación lateral: ambos dedos moviéndose en la misma dirección (midpoint delta)
    if(Math.hypot(dMidX, dMidY) > 0.3){
      const distCam = camera.position.distanceTo(modelo.position);
      const tanHFov = Math.tan((camera.fov / 2) * Math.PI / 180);
      const scr2world = (distCam * tanHFov * 2) / renderer.domElement.clientHeight;
      const camRight = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 0);
      const camUp    = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 1);
      modelo.position.addScaledVector(camRight,  dMidX * scr2world);
      modelo.position.addScaledVector(camUp,    -dMidY * scr2world);
      if(_placaCenter){ _placaCenter.addScaledVector(camRight, dMidX * scr2world); _placaCenter.addScaledVector(camUp, -dMidY * scr2world); }
    }

    // Profundidad: pinch (distancia entre dedos)
    const distCur = Math.hypot(pts[1].x-pts[0].x, pts[1].y-pts[0].y);
    if(_prevPinchDist > 0){
      _moverPlacaProfundidad(_placaArrastrandoId, (distCur - _prevPinchDist) * 0.0065);
    }
    _prevPinchDist = distCur;

    // Rotación: movimiento relativo de cada dedo respecto al midpoint
    // (dedos moviéndose en direcciones opuestas o con ángulo diferente)
    const f0dx = pts[0].x - prevPts[0].x - dMidX;
    const f0dy = pts[0].y - prevPts[0].y - dMidY;
    const sensibilidad = 0.0014;
    const camRight2 = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 0).normalize();
    const localUp2 = new THREE.Vector3(0,1,0).transformDirection(modelo.matrixWorld).normalize();
    _rotarAlrededorCentro(modelo, localUp2, f0dx * sensibilidad);
    _rotarAlrededorCentro(modelo, camRight2, f0dy * sensibilidad);

    needsRender = true;
  } else if(modoRotar && (e.buttons & 2)){
    // ── Click derecho ratón: rotar sobre el centro de la placa ──────────────
    let dx = e.movementX || 0;
    let dy = e.movementY || 0;
    if(!dx && !dy){
      const prevP = _prevPtr.get(e.pointerId);
      if(prevP){ dx = e.clientX - prevP.x; dy = e.clientY - prevP.y; }
    }
    const sensibilidad = 0.0014;
    const camRight = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 0).normalize();
    const localUp = new THREE.Vector3(0,1,0).transformDirection(modelo.matrixWorld).normalize();
    _rotarAlrededorCentro(modelo, localUp, dx * sensibilidad);
    _rotarAlrededorCentro(modelo, camRight, dy * sensibilidad);
    needsRender = true;
  } else if(e.buttons & 1 || _ptrMap.size === 1){
    if(_modoGiroZ){
      // ── Péndulo vertical: pivota desde la punta, el extremo libre balancea ──
      const prevP = _prevPtr.get(e.pointerId);
      if(prevP && _giroZPivot){
        const dx = e.clientX - prevP.x;
        const sensibilidad = 0.00067;
        const angle = (_giroZEsTop ? 1 : -1) * dx * sensibilidad;
        const camFwd = camera.getWorldDirection(new THREE.Vector3());
        const quat = new THREE.Quaternion().setFromAxisAngle(camFwd, angle);
        const toModel = modelo.position.clone().sub(_giroZPivot);
        toModel.applyQuaternion(quat);
        modelo.position.copy(_giroZPivot.clone().add(toModel));
        if(_placaCenter){ const tc = _placaCenter.clone().sub(_giroZPivot); tc.applyQuaternion(quat); _placaCenter.copy(_giroZPivot.clone().add(tc)); }
        modelo.rotateOnWorldAxis(camFwd, angle);
        needsRender = true;
      }
    } else if(_modoGiroY){
      // ── Péndulo lateral: pivota desde el borde, el lado libre balancea ──
      const prevP = _prevPtr.get(e.pointerId);
      if(prevP && _giroYPivot){
        const dx = e.clientX - prevP.x;
        const sensibilidad = 0.00067;
        const angle = (_giroYEsLeft ? 1 : -1) * dx * sensibilidad;
        const camUp = new THREE.Vector3().setFromMatrixColumn(camera.matrixWorld, 1).normalize();
        const quat = new THREE.Quaternion().setFromAxisAngle(camUp, angle);
        const toModel = modelo.position.clone().sub(_giroYPivot);
        toModel.applyQuaternion(quat);
        modelo.position.copy(_giroYPivot.clone().add(toModel));
        if(_placaCenter){ const tc = _placaCenter.clone().sub(_giroYPivot); tc.applyQuaternion(quat); _placaCenter.copy(_giroYPivot.clone().add(tc)); }
        modelo.rotateOnWorldAxis(camUp, angle);
        needsRender = true;
      }
    } else {
      // ── Un dedo / click izquierdo: trasladar placa ──────────────────────
      const rect = renderer.domElement.getBoundingClientRect();
      const px = ((e.clientX-rect.left)/rect.width)*2-1;
      const py = -((e.clientY-rect.top)/rect.height)*2+1;
      raycaster.setFromCamera({x:px,y:py}, camera);
      if(raycaster.ray.intersectPlane(_planoArrastre, _arrastreTarget)){
        const newPos = _arrastreTarget.clone().sub(_arrastreOffset);
        if(_placaCenter) _placaCenter.add(newPos.clone().sub(modelo.position));
        modelo.position.copy(newPos);
        needsRender = true;
      }
    }
  }
});
renderer.domElement.addEventListener('contextmenu', e=>e.preventDefault());
// Rueda del ratón durante drag → profundidad (adelante/atrás)
renderer.domElement.addEventListener('wheel', e=>{
  if(!_placaArrastrandoId) return;
  e.preventDefault();
  _moverPlacaProfundidad(_placaArrastrandoId, -e.deltaY * 0.002);
}, {passive:false});
renderer.domElement.addEventListener('pointercancel', e=>{
  _ptrMap.delete(e.pointerId); _prevPtr.delete(e.pointerId);
  if(_ptrMap.size < 2) _prevPinchDist = 0;
  VisorLog.postMessage('pointercancel fired');
  if(_twoFingerTimer){ clearTimeout(_twoFingerTimer); _twoFingerTimer=null; }
  // No limpiar _arrastrandoTimer ni _touchDragTimer ni _placaArrastrandoId aquí:
  // en iOS pointercancel lo dispara el reconocedor nativo ANTES de que el timer active
  // el arrastre. El cleanup lo gestiona touchend, que sí sabe si el dedo se levantó.
});
renderer.domElement.addEventListener('pointerup', e=>{
  _ptrMap.delete(e.pointerId); _prevPtr.delete(e.pointerId);
  if(_ptrMap.size < 2) _prevPinchDist = 0;
  if(_arrastrandoTimer){ clearTimeout(_arrastrandoTimer); _arrastrandoTimer=null; }
  if(_placaArrastrandoId){
    if(_ptrMap.size > 0){ needsRender=true; return; } // queda otro dedo en pantalla
    _setPlacaGlow(_placaArrastrandoId, false);
    _eliminarIndicadorFondo();
    _ocultarHint();
    _eliminarOverlayColision();
    _modoGiroZ = false; _giroZEsTop = false; _giroZPivot = null;
    _modoGiroY = false; _giroYEsLeft = false; _giroYPivot = null;
    _placaCenter = null;
    controls.enabled=true;
    PlacaArrastrando.postMessage(JSON.stringify({id:_placaArrastrandoId,active:false}));
    _placaArrastrandoId=null;
    return;
  }
  if(_longPressTimer){ clearTimeout(_longPressTimer); _longPressTimer=null; }
  // Ignorar si fue un drag
  const dx = e.clientX-pointerDownX, dy = e.clientY-pointerDownY;
  if(Math.sqrt(dx*dx+dy*dy) > DRAG_THRESHOLD) return;
  if(_modoNotaActivo) return; // en modo nota el tap lo gestiona el longpress

  // Modo regla libre: primer tap = P1, segundo tap = P2 + medir
  if(_modoReglaActivo){
    const rect2 = renderer.domElement.getBoundingClientRect();
    const px2 = ((e.clientX-rect2.left)/rect2.width)*2-1;
    const py2 = -((e.clientY-rect2.top)/rect2.height)*2+1;
    const rc2 = new THREE.Raycaster(); rc2.setFromCamera({x:px2,y:py2}, camera);
    const hits2 = rc2.intersectObjects(_getMeshesGeom(),false);
    if(hits2.length>0){
      const pt = hits2[0].point;
      if(!_reglaP1){
        _reglaP1 = pt.clone();
        // Marcar P1 visualmente
        _dibujarReglaLibre(_reglaP1, _reglaP1);
      } else {
        const mm = _dibujarReglaLibre(_reglaP1, pt);
        const rid = 'med_' + Date.now();
        etiquetarRegla(rid);
        ReglaLibre.postMessage(JSON.stringify({mm: Math.round(mm*10)/10, id: rid}));
        _reglaP1 = null;
      }
    }
    return;
  }

  const rect = renderer.domElement.getBoundingClientRect();
  pointer.x  =  ((e.clientX-rect.left)/rect.width )*2-1;
  pointer.y  = -((e.clientY-rect.top) /rect.height)*2+1;

  // Doble tap sobre placa → volver a posición original
  {
    const nowDt = Date.now();
    const rcDt = new THREE.Raycaster(); rcDt.setFromCamera({x:pointer.x,y:pointer.y}, camera);
    const plateMeshesDt = [];
    for(const id in modelos){
      const m = modelos[id];
      if(!m.userData.esHueso && !(m.userData.instanceId && String(m.userData.instanceId).startsWith('screw_'))){
        m.traverse(c=>{if(c.isMesh && !c.userData.esTrayectoria && c.visible) plateMeshesDt.push(c);});
      }
    }
    const hitsDt = rcDt.intersectObjects(plateMeshesDt, false);
    if(hitsDt.length > 0){
      let tappedId = null;
      for(const id in modelos){
        let found=false; modelos[id].traverse(c=>{if(c===hitsDt[0].object) found=true;});
        if(found){tappedId=id; break;}
      }
      if(tappedId && tappedId===_dblTapModelId && nowDt-_dblTapTime<350){
        // Reset placa a origen — tornillos (hijos) vuelven a sus posiciones locales originales
        modelos[tappedId].position.set(0,0,0);
        modelos[tappedId].quaternion.set(0,0,0,1);
        needsRender=true; _dblTapModelId=null; _dblTapTime=0;
        PlacaArrastrando.postMessage(JSON.stringify({id:tappedId,active:false,reset:true}));
        return;
      }
      _dblTapModelId = tappedId; _dblTapTime = nowDt;
    }
  }

  // Detectar tap sobre tornillo colocado → mostrar etiqueta info
  const screwMeshes = [];
  for(const id in modelos){
    const m = modelos[id];
    if(m.userData && m.userData.instanceId && String(m.userData.instanceId).startsWith('screw_')){
      m.traverse(c=>{ if(c.isMesh && c.visible) screwMeshes.push(c); });
    }
  }
  if(screwMeshes.length > 0){
    const rcS = new THREE.Raycaster();
    rcS.setFromCamera({x:pointer.x, y:pointer.y}, camera);
    const screwHits = rcS.intersectObjects(screwMeshes, false);
    if(screwHits.length > 0){
      let hitId = null;
      let node = screwHits[0].object;
      while(node){ if(node.userData && node.userData.instanceId){ hitId = node.userData.instanceId; break; } node=node.parent; }
      if(hitId){
        ScrewTapped.postMessage(JSON.stringify({instanceId: hitId, sx: e.clientX, sy: e.clientY}));
        return;
      }
    }
  }

  raycaster.setFromCamera(pointer, camera);

  // Solo trayectorias cuyo modelo padre esté completamente visible — usa caché
  const meshes = _getMeshesTray();
  const hits = raycaster.intersectObjects(meshes, false);

  // Filtrar hits demasiado lejanos a la cámara: descartar trayectorias que estén
  // detrás de otro modelo o a más de 3× el tamaño de la escena desde el centro
  let hit = null;
  if(hits.length > 0){
    // Calcular distancia máxima razonable: tamaño de la escena × 3 (usa meshes de geometría cacheados)
    const sceneBox = new THREE.Box3();
    for(const c of _getMeshesGeom()){ if(c.visible) sceneBox.expandByObject(c); }
    const sceneSize = new THREE.Vector3(); sceneBox.getSize(sceneSize);
    const maxDist = Math.max(sceneSize.x, sceneSize.y, sceneSize.z) * 3;

    // Tomar el hit más cercano que esté dentro del rango aceptable
    for(const h of hits){
      if(h.distance <= maxDist){ hit = h; break; }
    }
  }
  if(!hit) return;

  // Normal exterior de la cara en espacio mundo
  // Si face.normal existe la usamos; si no, tomamos la dirección cámara→hit invertida
  let nx=0,ny=1,nz=0;
  if(hit.face){
    const n = hit.face.normal.clone().transformDirection(hit.object.matrixWorld).normalize();
    // Asegurar que la normal apunta hacia la cámara (hacia fuera)
    const rayDir = hit.point.clone().sub(camera.position).normalize();
    if(n.dot(rayDir) > 0) n.negate(); // si apuntaba hacia dentro, invertir
    nx=n.x; ny=n.y; nz=n.z;
  } else {
    // Fallback: normal = dirección opuesta al rayo
    const rayDir = hit.point.clone().sub(camera.position).normalize();
    nx=-rayDir.x; ny=-rayDir.y; nz=-rayDir.z;
  }

  // ── Si tocó un cilindro guía usar su posición/dirección exactas ────────
  let px = hit.point.x, py = hit.point.y, pz = hit.point.z;
  let fnx = nx, fny = ny, fnz = nz;
  let cilindroId = null;

  if(hit.object.userData.esTrayectoria){
    const obj = hit.object;
    // Buscar el GLB propietario del cilindro tocado
    let glbId = null;
    let p = obj.parent;
    while(p){ if(modelos[p.userData.glbId || ''] === p || Object.keys(modelos).find(k=>modelos[k]===p)){ glbId = Object.keys(modelos).find(k=>modelos[k]===p); break; } p=p.parent; }
    // Buscar en trayectorias SOLO del GLB propietario (evitar captar trayectorias de otras placas)
    let trayData = null;
    const idsToSearch = glbId ? [glbId] : Object.keys(trayectorias);
    for(const id of idsToSearch){
      if(!trayectorias[id]) continue;
      trayData = trayectorias[id].find(t => t.name === obj.name);
      if(trayData) break;
    }
    // Fallback: buscar en todos si no se encontró por GLB (compatibilidad)
    if(!trayData){
      for(const id in trayectorias){
        trayData = trayectorias[id].find(t => t.name === obj.name);
        if(trayData) break;
      }
    }
    if(trayData){
      if(glbId && modelos[glbId]){
        // Aplicar matriz completa del modelo (traslación + rotación) para que los
        // tornillos sigan correctamente tanto si la placa se arrastró como si se rotó
        modelos[glbId].updateWorldMatrix(true, false);
        const mat = modelos[glbId].matrixWorld;
        const wp = trayData.pos.clone().applyMatrix4(mat);
        px = wp.x; py = wp.y; pz = wp.z;
        const wd = trayData.dir.clone().transformDirection(mat);
        fnx = wd.x; fny = wd.y; fnz = wd.z;
      } else {
        px = trayData.pos.x; py = trayData.pos.y; pz = trayData.pos.z;
        fnx = trayData.dir.x; fny = trayData.dir.y; fnz = trayData.dir.z;
      }
    }
    VisorLog.postMessage(
  'TRAY TAP ' + obj.name +
  ' pos=' + trayData.pos.x.toFixed(2) + ',' + trayData.pos.y.toFixed(2) + ',' + trayData.pos.z.toFixed(2) +
  ' dir=' + trayData.dir.x.toFixed(3) + ',' + trayData.dir.y.toFixed(3) + ',' + trayData.dir.z.toFixed(3)
);
    cilindroId = obj.uuid;
    VisorLog.postMessage('Cilindro tocado: ' + obj.name + ' pos=' + px.toFixed(1)+','+py.toFixed(1)+','+pz.toFixed(1));
  }

  // Enviar a Flutter: punto 3D + normal + posición pantalla del tap
  PlateTapped.postMessage(JSON.stringify({
    x: px, y: py, z: pz,
    nx: fnx, ny: fny, nz: fnz,
    dx: fnx, dy: fny, dz: fnz, // dirección de inserción = opuesto a normal
    cilindroId: cilindroId,
    usarTrayectoria: cilindroId !== null,
    sx: e.clientX, sy: e.clientY,
  }));
});

let needsRender = true;
// iOS/iPad: limitar a 30fps para evitar sobrecalentamiento (OutlinePass es costoso)
const _isMobile = /iPhone|iPad|Android/i.test(navigator.userAgent);
const _frameMs  = _isMobile ? 33 : 16; // 30fps móvil, 60fps desktop
let   _lastFrameT = 0;
function animate(now){
  requestAnimationFrame(animate);
  controls.update();
  if(!needsRender) return;
  if(now - _lastFrameT < _frameMs) return; // throttle framerate
  _lastFrameT = now;
  composer.render();
  needsRender = false;
}
document.addEventListener('contextmenu', e => e.preventDefault());
document.addEventListener('selectstart', e => e.preventDefault());
// Reactive: borrar selección de texto en el instante en que iOS la crea
document.addEventListener('selectionchange', () => { try{ window.getSelection().removeAllRanges(); }catch(_){} });
// iOS/WKWebView: preventDefault en touchstart a nivel document evita que UITextInteraction
// nativo active la selección de texto en long press. Sólo iOS: en Android esto cancela pointer events.
// Detección amplia para cubrir iPhone, iPad antiguo (UA "iPad") e iPad moderno (UA "MacIntel" + maxTouchPoints).
const _isIOS = /iPhone|iPad|iPod/.test(navigator.userAgent) ||
               (/MacIntel|MacARM/.test(navigator.platform) && navigator.maxTouchPoints > 1) ||
               (navigator.vendor === 'Apple Computer, Inc.' && 'ontouchstart' in window);
// Pinch de profundidad + traslación táctil (passive=true)
let _prevPinchDistTouch = 0;
// Timer de respaldo para activar arrastre de placa vía touch events.
// A diferencia de _arrastrandoTimer (pointer), éste NO se cancela en pointercancel,
// lo que permite que iOS active el arrastre aunque su reconocedor nativo dispare pointercancel.
renderer.domElement.addEventListener('touchstart', e=>{
  if(_isIOS) e.preventDefault();
  if(e.touches.length === 2 && _touchDragTimer){ clearTimeout(_touchDragTimer); _touchDragTimer=null; }
  if(e.touches.length !== 1 || _modoNotaActivo || _placaArrastrandoId) return;
  const t = e.touches[0];
  _touchDragStartX = t.clientX; _touchDragStartY = t.clientY;
  if(_touchDragTimer) clearTimeout(_touchDragTimer);
  _touchDragTimer = setTimeout(()=>{
    _touchDragTimer = null;
    if(_placaArrastrandoId) return; // ya activado por otro camino
    _tryActivateDrag(_touchDragStartX, _touchDragStartY);
  }, 600);
}, {passive:false});
renderer.domElement.addEventListener('touchmove', e=>{
  if(_isIOS && (_placaArrastrandoId || _touchDragTimer || e.touches.length > 1)) e.preventDefault();
  // Cancelar timer táctil si el dedo se ha movido demasiado (el usuario hace scroll/pan)
  if(_touchDragTimer && e.touches.length === 1){
    const t = e.touches[0];
    if(Math.hypot(t.clientX-_touchDragStartX, t.clientY-_touchDragStartY) > 10){
      clearTimeout(_touchDragTimer); _touchDragTimer = null;
    }
  }
  if(!_placaArrastrandoId) return;
  if(e.touches.length === 1){
    // 1 dedo: trasladar placa (path táctil para iOS tras pointercancel)
    const t = e.touches[0];
    const rect = renderer.domElement.getBoundingClientRect();
    const px = ((t.clientX-rect.left)/rect.width)*2-1;
    const py = -((t.clientY-rect.top)/rect.height)*2+1;
    raycaster.setFromCamera({x:px,y:py}, camera);
    const _tgt = new THREE.Vector3();
    const modelo = modelos[_placaArrastrandoId];
    if(modelo && raycaster.ray.intersectPlane(_planoArrastre, _tgt)){
      const newPos = _tgt.clone().sub(_arrastreOffset);
      if(_placaCenter) _placaCenter.add(newPos.clone().sub(modelo.position));
      modelo.position.copy(newPos);
      needsRender = true;
    }
  } else if(e.touches.length >= 2){
    // 2+ dedos: pinch → profundidad
    const t0=e.touches[0], t1=e.touches[1];
    const d = Math.hypot(t1.clientX-t0.clientX, t1.clientY-t0.clientY);
    if(_prevPinchDistTouch > 0) _moverPlacaProfundidad(_placaArrastrandoId, (d-_prevPinchDistTouch)*0.0065);
    _prevPinchDistTouch = d;
  }
}, {passive:false});
renderer.domElement.addEventListener('touchend', e=>{
  if(_isIOS) e.preventDefault();
  if(e.touches.length<2) _prevPinchDistTouch=0;
  if(_arrastrandoTimer){ clearTimeout(_arrastrandoTimer); _arrastrandoTimer=null; }
  if(_touchDragTimer){ clearTimeout(_touchDragTimer); _touchDragTimer=null; }
  if(_placaArrastrandoId && e.touches.length===0){
    _setPlacaGlow(_placaArrastrandoId,false); _eliminarIndicadorFondo(); _ocultarHint(); _eliminarOverlayColision();
    _modoGiroZ=false; _giroZEsTop=false; _giroZPivot=null; _modoGiroY=false; _giroYEsLeft=false; _giroYPivot=null; _placaCenter=null;
    controls.enabled=true;
    PlacaArrastrando.postMessage(JSON.stringify({id:_placaArrastrandoId,active:false}));
    _placaArrastrandoId=null;
  }
}, {passive:false});
renderer.domElement.addEventListener('touchcancel', e=>{
  if(_isIOS) e.preventDefault();
  _prevPinchDistTouch=0;
  if(_touchDragTimer){ clearTimeout(_touchDragTimer); _touchDragTimer=null; }
}, {passive:false});
animate();
controls.addEventListener('change', ()=>{ needsRender = true; });
window.addEventListener('resize',()=>{
  camera.aspect=innerWidth/innerHeight; camera.updateProjectionMatrix();
  renderer.setSize(innerWidth,innerHeight);
  composer.setSize(innerWidth,innerHeight);
  outlinePass.resolution.set(innerWidth,innerHeight);
  needsRender = true;
});
window._numBiomodelos = 0; // se sobreescribe desde Flutter antes de cargar GLBs
setTimeout(()=>{ document.getElementById('loading').style.display='none'; VisorReady.postMessage('ready'); },500);
</script>
</body>
</html>
''';

  /// HTML igual que _buildHtml pero con los canales JS adaptados para webview_windows.
  /// Aplica tema oscuro/claro al HTML del visor inyectando un <style> override.
  String _patchHtmlTheme(String html) {
    if (!AppTheme.isDark.value) return html;
    const darkCss = '''
<style id="theme-dark">
  html,body { background:#0D0D1A !important; }
  #loading   { background:linear-gradient(160deg,#0D0D1A 0%,#16213E 100%) !important;
               color:rgba(236,236,244,0.55) !important; }
</style>
</head>''';
    return html.replaceFirst('</head>', darkCss);
  }

  String _buildHtmlWindows() {
    final html = _patchHtmlTheme(_buildHtml());
    // Inyectar adaptador de canales justo antes de </head>
    const patch = '''
<script>
// Adaptador: convierte XYZ.postMessage(msg) en window.chrome.webview.postMessage({channel:'XYZ',msg:msg})
(function(){
  const channels = ['VisorReady','PlateTapped','ScrewPlaced','VisorLog','TornilloListo',
                    'CapturaVista','Captura','ReglaLibre','NotaTap','ScrewTapped','PlacaArrastrando'];
  channels.forEach(function(ch){
    window[ch] = { postMessage: function(m){ window.chrome.webview.postMessage(JSON.stringify({channel:ch,msg:m})); } };
  });
})();
</script>
</head>''';
    return html.replaceFirst('</head>', patch);
  }


  // ═════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final _dark = AppTheme.darkText;
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
          child: Stack(children: [
            Positioned.fill(
              top: 64,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Platform.isWindows
                    ? VisorWindows(
                        key: _visorWindowsKey,
                        htmlContent: _buildHtmlWindows(),
                        onVisorReady: _onVisorReadyWindows,
                        onPlateTapped: (msg) {
                          if (!mounted) return;
                          try { setState(() => _tapPendiente = _TapData.fromJson(jsonDecode(msg))); } catch (_) {}
                        },
                        onScrewPlaced: (msg) {
                          try {
                            final data = jsonDecode(msg) as Map<String, dynamic>;
                            final instanceId = data['instanceId'] as String? ?? '';
                            final nombre = data['nombre'] as String? ?? '';
                            _instanciasEnEscena.add(instanceId);
                            if (_tornillosColocados.any((t) => t.instanceId == instanceId)) return;
                            final tap = _tapPorInstancia.remove(instanceId) ?? _tapPendiente;
                            setState(() {
                              _tornillosColocados.add(TornilloColocado(
                                instanceId: instanceId,
                                glbId: data['glbId'] ?? '',
                                nombre: nombre,
                                cilindroId: data['cilindroId'] as String? ?? '',
                                largo: _largoDesdeNombre(nombre),
                                hx: tap?.x ?? 0, hy: tap?.y ?? 0, hz: tap?.z ?? 0,
                                hnx: tap?.nx ?? 0, hny: tap?.ny ?? 0, hnz: tap?.nz ?? 0,
                                hdx: tap?.dx ?? 0, hdy: tap?.dy ?? 0, hdz: tap?.dz ?? 0,
                                usarTrayectoria: tap?.usarTrayectoria ?? false,
                              ));
                              _screwCounter++;
                            });
                            _colocadosVersion.value++;
                            _guardarVisiblesAlSalir();
                            _autoAvanzarEstado('modificado');
                          } catch (_) {}
                        },
                        onLog: (msg) => debugPrint('\u{1F535} $msg'),
                        onTornilloListo: (catId) {
                          _tornilloListoCompleters[catId]?.complete();
                          _tornilloListoCompleters.remove(catId);
                        },
                  onPlacaArrastrando: (msg) {
                    if (!mounted) return;

                    try {
                      final d = jsonDecode(msg) as Map<String, dynamic>;
                      final activa = d['active'] == true;

                      if (activa && !_placaArrastrandoActiva) {
                        HapticFeedback.lightImpact();
                      }

                      setState(() => _placaArrastrandoActiva = activa);

                    } catch (_) {}
                  },
                      )
                    : WebViewWidget(
                  controller: _webController,
                  gestureRecognizers: {
                    Factory<OneSequenceGestureRecognizer>(
                          () => EagerGestureRecognizer(),
                    ),
                  },
                ),
              ),
            ),
            // Orbe azul decorativo (esquina superior derecha, fuera del WebView)
            Positioned(
              top: -60, right: -50,
              child: IgnorePointer(
                child: Container(
                  width: 220, height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Color(0xFF2A7FF5).withOpacity(0.10),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
            ),
            // Watermark se renderiza dentro del WebView
            // Doble tap para abrir el panel lateral
            if (!_panelAbierto && !Platform.isAndroid && !Platform.isIOS)
              Positioned(
                top: 64, left: 0, right: 0, bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onDoubleTap: () => setState(() => _panelAbierto = true),
                ),
              ),
            _buildTopBar(),
            _buildBtnLimpiar(),
            // Overlay para cerrar el panel lateral al tocar fuera (excluye topbar)
            if (_panelAbierto && !Platform.isAndroid && !Platform.isIOS)
              Positioned(
                top: 64, left: 0, right: 0, bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _panelAbierto = false),
                ),
              ),
            _buildPanelLateral(),
            // Hint inferior
            Positioned(
              bottom: 16, left: 0, right: 0,
              child: RepaintBoundary(
                child: Center(
                  child: _glassChip(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(_placaArrastrandoActiva ? Icons.open_with : _modoRegla ? Icons.straighten : _modoNota ? Icons.push_pin : Icons.touch_app,
                          color: _placaArrastrandoActiva ? const Color(0xFF34C759) : _modoRegla ? const Color(0xFF2A7FF5) : _modoNota ? const Color(0xFFF5A623) : AppTheme.subtitleColor, size: 12),
                      const SizedBox(width: 6),
                      Text(_placaArrastrandoActiva
                          ? 'Mover · Der/2dedos: rotar · Rueda/pinch: profundidad'
                          : _modoRegla
                          ? (_reglaLibreMm != null
                              ? 'Distancia: ${_reglaLibreMm!.toStringAsFixed(1)} mm'
                              : 'Toca 2 puntos para medir')
                          : _modoNota
                              ? 'Toca el modelo para clavar una nota'
                              : 'Mantén pulsada una placa para moverla',
                          style: TextStyle(
                              color: _placaArrastrandoActiva ? const Color(0xFF34C759) : _modoRegla ? const Color(0xFF2A7FF5) : _modoNota ? const Color(0xFFF5A623) : AppTheme.subtitleColor,
                              fontSize: 10.5)),
                    ]),
                  ),
                ),
              ),
            ),
            // Vistas rápidas
            if (_vistasPanelVisible) _buildVistaPanel(),
            // Botón notas de voz
            Positioned(
              bottom: 42, left: 102,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: _abrirNotasVoz,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg1,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Center(child: Icon(Icons.mic_outlined,
                            size: 17, color: AppTheme.darkText.withOpacity(0.7))),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Botón PDF documentación
            Positioned(
              bottom: 42, left: 58,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: _abrirPdfCaso,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg1,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Center(child: Icon(Icons.picture_as_pdf_outlined,
                            size: 17, color: AppTheme.darkText.withOpacity(0.7))),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Botón info esquina inferior izquierda
            Positioned(
              bottom: 42, left: 14,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: () => _mostrarInfoCaso(context),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg1,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Center(child: Text('i',
                            style: TextStyle(color: AppTheme.darkText.withOpacity(0.7),
                                fontSize: 16, fontWeight: FontWeight.w800, fontStyle: FontStyle.italic))),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Botón Exportar (visible siempre excepto modoGenérico sin plan ni sesión)
            if (!widget.modoGenerico || widget.planLocal != null || widget.sesionGuardada != null)
            Positioned(
              bottom: 88, right: 14,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: _exportarJSON,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg1,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.upload_outlined, size: 14, color: AppTheme.darkText.withOpacity(0.7)),
                          const SizedBox(width: 6),
                          Text('Exportar', style: TextStyle(
                              color: AppTheme.darkText.withOpacity(0.7),
                              fontSize: 12, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Botón Guardar / Actualizar
            Positioned(
              bottom: 42, right: 14,
              child: RepaintBoundary(
                child: GestureDetector(
                  onTap: widget.autoCargar && widget.planLocal != null
                      ? (_planGuardado ? null : _guardarEnMisPlanificaciones)
                      : widget.autoCargar && widget.planLocal == null
                          ? _guardarEnCaso
                          : widget.sesionGuardada != null
                              ? _actualizarSesion
                              : _guardarSesion,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: (widget.autoCargar
                              ? const Color(0xFF8E44AD)
                              : const Color(0xFF34A853)).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (widget.autoCargar
                                ? const Color(0xFF8E44AD)
                                : const Color(0xFF34A853)).withOpacity(0.45),
                            width: 1.5,
                          ),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(
                            (widget.autoCargar && widget.planLocal != null)
                                ? (_planGuardado ? Icons.check_circle_outline : Icons.save_outlined)
                                : Icons.save_outlined,
                            size: 14,
                            color: (widget.autoCargar && widget.planLocal != null)
                                ? const Color(0xFF8E44AD)
                                : const Color(0xFF34A853),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (widget.autoCargar && widget.planLocal != null)
                                ? (_planGuardado ? 'Guardado' : 'Guardar')
                                : (widget.sesionGuardada != null ? 'Actualizar' : 'Guardar'),
                            style: TextStyle(
                              color: (widget.autoCargar && widget.planLocal != null)
                                  ? const Color(0xFF8E44AD)
                                  : const Color(0xFF34A853),
                              fontSize: 12, fontWeight: FontWeight.w700,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Panel plano de corte
            if (_planoCortando) _buildPanelCorte(),
            // Popup de selección de tornillo
            if (_tapPendiente != null) _buildScrewPopup(context),
            // Etiqueta info tornillo — oculta temporalmente
            // if (_screwInfoTc != null) ...[
            //   Positioned.fill(
            //     child: GestureDetector(
            //       behavior: HitTestBehavior.translucent,
            //       onTap: () => setState(() => _screwInfoTc = null),
            //     ),
            //   ),
            //   _buildScrewInfoLabel(context),
            // ],
          ]),
        ),
      ),
    );
  }

  // ── Etiqueta info tornillo (tap sobre tornillo colocado) ──────────────────
  Widget _buildScrewInfoLabel(BuildContext context) {
    final tc = _screwInfoTc!;
    final screen = MediaQuery.of(context).size;
    const topBarH = 64.0;
    const cardW = 180.0;
    const cardH = 72.0;
    const margin = 12.0;

    double left = _screwInfoSx - cardW / 2;
    double top  = _screwInfoSy + topBarH + 12;

    left = left.clamp(margin, screen.width  - cardW - margin);
    if (top + cardH > screen.height - margin) top = _screwInfoSy + topBarH - cardH - 12;
    top  = top.clamp(topBarH + margin, screen.height - cardH - margin);

    return Positioned(
      left: left, top: top,
      child: GestureDetector(
        onTap: () => setState(() => _screwInfoTc = null),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: cardW,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.sheetBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _C.accentScrew.withOpacity(0.45), width: 1.5),
                boxShadow: [BoxShadow(color: _C.accentScrew.withOpacity(0.12), blurRadius: 16, offset: const Offset(0, 4))],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.hardware_outlined, size: 13, color: _C.accentScrew),
                  const SizedBox(width: 6),
                  Expanded(child: _marqueeText(_nombreCorto(tc.nombre),
                      TextStyle(color: AppTheme.darkText, fontSize: 12, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 6),
                Text(_labelDiamLargo(tc.nombre),
                    style: TextStyle(color: _C.accentScrew, fontSize: 11, fontWeight: FontWeight.w600)),
                if (tc.largo > 0) ...[
                  const SizedBox(height: 2),
                  Text('Largo: ${tc.largo.toStringAsFixed(0)} mm',
                      style: TextStyle(color: AppTheme.subtitleColor, fontSize: 10)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Popup selector de tornillo ────────────────────────────────────────────
  Widget _buildScrewPopup(BuildContext context) {
    final screen  = MediaQuery.of(context).size;
    // El tap viene en coordenadas CSS del WebView (0,0 = top-left del WebView).
    // El WebView empieza en y=64 (debajo del topbar) dentro del SafeArea.
    // Sumamos el offset del topbar para convertir a coordenadas de pantalla Flutter.
    const topBarH = 88.0;
    final tapX = _tapPendiente!.sx;
    final tapY = _tapPendiente!.sy + topBarH;

    const popupW    = 240.0;
    const popupMaxH = 340.0;
    const margin    = 12.0;

    double left = tapX - popupW / 2;
    left = left.clamp(8.0, screen.width - popupW - 8);

    // Si hay espacio suficiente debajo del tap → abrir hacia abajo, si no → hacia arriba
    final spaceBelow = screen.height - tapY - margin;
    double top;
    if (spaceBelow >= popupMaxH + margin) {
      top = tapY + margin;
    } else {
      top = tapY - popupMaxH - margin;
    }
    top = top.clamp(topBarH + 8, screen.height - popupMaxH - 8);

    return Positioned(
      left: left, top: top,
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: popupW,
              constraints: const BoxConstraints(maxHeight: popupMaxH),
              decoration: BoxDecoration(
                color: AppTheme.sheetBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                boxShadow: [
                  BoxShadow(color: Color(0xFF2A7FF5).withOpacity(0.14), blurRadius: 36, offset: const Offset(0,8)),
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _C.accentScrew.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.settings, color: _C.accentScrew, size: 15),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text('¿Qué tornillo insertar?',
                          style: TextStyle(color: AppTheme.darkText, fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _tapPendiente = null),
                      child: Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: AppTheme.darkText.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close, color: AppTheme.subtitleColor, size: 14),
                      ),
                    ),
                  ]),
                ),
                Divider(height: 1, color: AppTheme.handleColor),
                // Lista
                widget.caso.tornillos.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No hay tornillos en el catálogo',
                          style: TextStyle(color: AppTheme.subtitleColor, fontSize: 11)),
                    )
                  : Flexible(
                      child: ValueListenableBuilder<int>(
                        valueListenable: _catCacheVersion,
                        builder: (_, __, ___) => ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      shrinkWrap: true,
                      itemCount: widget.caso.tornillos.length,
                      itemBuilder: (_, gi) {
                        final grupo = widget.caso.tornillos[gi];
                        final exp   = _grupoTornilloExp[gi] ?? false;
                        int offset = 0;
                        for (int k = 0; k < gi; k++) offset += widget.caso.tornillos[k].tornillos.length;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Cabecera grupo ──
                            GestureDetector(
                              onTap: () => setState(() => _grupoTornilloExp[gi] = !exp),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                decoration: BoxDecoration(
                                  color: _C.accentScrew.withOpacity(0.07),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _C.accentScrew.withOpacity(0.25)),
                                ),
                                child: Row(children: [
                                  Icon(Icons.folder_outlined, size: 13, color: _C.accentScrew),
                                  const SizedBox(width: 8),
                                  Expanded(child: _marqueeText(grupo.nombre,
                                      TextStyle(color: AppTheme.darkText,
                                          fontSize: 11, fontWeight: FontWeight.w700))),
                                  Text('${grupo.tornillos.length}',
                                      style: TextStyle(color: _C.accentScrew.withOpacity(0.7), fontSize: 10)),
                                  const SizedBox(width: 4),
                                  AnimatedRotation(
                                    turns: exp ? 0.5 : 0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(Icons.keyboard_arrow_down,
                                        color: AppTheme.subtitleColor, size: 15),
                                  ),
                                ]),
                              ),
                            ),
                            // ── Tornillos del grupo ──
                            AnimatedCrossFade(
                              duration: const Duration(milliseconds: 200),
                              crossFadeState: exp ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                              firstChild: const SizedBox.shrink(),
                              secondChild: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: Column(
                                  children: List.generate(grupo.tornillos.length, (ti) {
                                    final idx  = offset + ti;
                                    final t    = grupo.tornillos[ti];
                                    final carg = _catCargando[idx] ?? ValueNotifier(false);
                                    return ValueListenableBuilder<bool>(
                                      valueListenable: carg,
                                      builder: (_, isLoading, __) => GestureDetector(
                                        // Siempre tapeable: si no está en caché lo descarga y luego inserta
                                        onTap: isLoading ? null : () => _insertarTornillo(idx),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 120),
                                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                          decoration: BoxDecoration(
                                            color: isLoading ? Colors.transparent : _C.accentScrew.withOpacity(0.05),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isLoading
                                                  ? AppTheme.handleColor
                                                  : _C.accentScrew.withOpacity(0.35),
                                            ),
                                          ),
                                          child: Row(children: [
                                            SizedBox(width: 20, height: 20,
                                              child: isLoading
                                                ? CircularProgressIndicator(strokeWidth: 2, color: _C.accentScrew.withOpacity(0.6))
                                                : Icon(Icons.settings, size: 14, color: _C.accentScrew),
                                            ),
                                            const SizedBox(width: 9),
                                            Expanded(child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _marqueeText(
                                                    _nombreCorto(t.archivo.isNotEmpty ? t.archivo : t.nombre),
                                                    TextStyle(
                                                        color: isLoading ? AppTheme.subtitleColor : AppTheme.darkText,
                                                        fontSize: 10, fontWeight: FontWeight.w600)),
                                                Text(_labelDiamLargo(t.archivo.isNotEmpty ? t.archivo : t.nombre),
                                                    style: TextStyle(
                                                        color: isLoading
                                                            ? AppTheme.subtitleColor2
                                                            : _C.accentScrew.withOpacity(0.7),
                                                        fontSize: 9)),
                                                if (isLoading)
                                                  Text('Descargando…',
                                                      style: TextStyle(color: AppTheme.subtitleColor, fontSize: 9)),
                                              ],
                                            )),
                                            if (!isLoading)
                                              Icon(Icons.arrow_forward_ios, size: 10,
                                                  color: _C.accentScrew.withOpacity(0.7)),
                                          ]),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ), // ValueListenableBuilder
                ), // Flexible
                const SizedBox(height: 8),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widget vistas rápidas ───────────────────────────────────────────────────
  Widget _buildVistaPanel() {
    final vistas = [
      (0, 'Frontal',    Icons.crop_portrait,          'Eje Z'),
      (1, 'Lat. Der',   Icons.arrow_circle_right,     'Eje X+'),
      (2, 'Lat. Izq',   Icons.arrow_circle_left,      'Eje X-'),
      (3, 'Superior',   Icons.keyboard_arrow_up,      'Eje Y+'),
      (4, 'Inferior',   Icons.keyboard_arrow_down,    'Eje Y-'),
    ];
    return Positioned(
      top: 68, left: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            width: 170,
            decoration: BoxDecoration(
              color: AppTheme.cardBg1,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder, width: 1.5),
              boxShadow: [BoxShadow(color: Color(0xFF2A7FF5).withOpacity(0.10), blurRadius: 28, offset: const Offset(0, 8))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: _C.accentBone.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.center_focus_strong, size: 14, color: _C.accentBone),
                  ),
                  const SizedBox(width: 8),
                  Text('Vistas', style: TextStyle(
                      color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _vistasPanelVisible = false),
                    child: Icon(Icons.close, size: 15, color: AppTheme.subtitleColor),
                  ),
                ]),
              ),
              Divider(height: 1, color: AppTheme.handleColor),
              const SizedBox(height: 6),
              // Botones de vista
              ...List.generate(vistas.length, (i) {
                final v = vistas[i];
                return GestureDetector(
                  onTap: () { _jsVista(v.$1); setState(() => _vistasPanelVisible = false); },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    decoration: BoxDecoration(
                      color: Color(0xFF2A7FF5).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Color(0xFF2A7FF5).withOpacity(0.15)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: Color(0xFF2A7FF5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(v.$3, size: 14, color: const Color(0xFF2A7FF5)),
                      ),
                      const SizedBox(width: 9),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.$2, style: TextStyle(
                              color: AppTheme.darkText, fontSize: 11, fontWeight: FontWeight.w600)),
                          Text(v.$4, style: TextStyle(
                              color: AppTheme.subtitleColor, fontSize: 9)),
                        ],
                      )),
                    ]),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Botón Limpiar (debajo de la flecha atrás) ────────────────────────────
  Widget _buildBtnLimpiar() {
    return Positioned(
      top: 72, left: 8,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: GestureDetector(
            onTap: _limpiarVisor,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.cardBg1,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.cardBorder, width: 1.2),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.layers_clear_outlined, size: 14, color: AppTheme.darkText.withOpacity(0.55)),
                const SizedBox(width: 5),
                Text('Limpiar', style: TextStyle(
                    color: AppTheme.darkText.withOpacity(0.65),
                    fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ── URL destino exportación ── CONFIGURA AQUÍ ─────────────────────────────
  // Cambia esta URL por el endpoint donde quieras recibir el multipart.
  // Si la dejas vacía ('') solo se mostrará el JSON en pantalla sin enviarlo.
  static const String _exportarUrl = 'https://n8n.srv1089937.hstgr.cloud/webhook/adf721aa-c593-42e0-a40e-93d32b0c9d60';
  static const String _apiCambioEstado =
      'https://profesional.planificacionquirurgica.com/cambiar_estado_caso.php';

  // ── Captura auxiliar: mueve cámara a vista v y devuelve los bytes PNG ─────
  Future<Uint8List?> _capturarVista(int v) async {
    _capturaVistaCompleter = Completer<Uint8List>();
    _jsRun('window.visor.capturarVista($v);');
    try {
      return await _capturaVistaCompleter!.future.timeout(const Duration(seconds: 3));
    } catch (_) {
      _capturaVistaCompleter = null;
      return null;
    }
  }

  // ── Guardar en mis planificaciones (flujo IA) ─────────────────────────────
  Future<void> _guardarEnMisPlanificaciones() async {
    if (widget.planLocal == null) return;

    final nombreCtrl = TextEditingController(
      text: widget.planLocal!.nombrePaciente == 'Nueva planificación'
          ? ''
          : widget.planLocal!.nombrePaciente,
    );

    final nombre = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              decoration: BoxDecoration(
                color: AppTheme.sheetBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cardBorder, width: 1.5),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.save_outlined, size: 32, color: Color(0xFF8E44AD)),
                const SizedBox(height: 12),
                Text('Guardar planificación',
                    style: TextStyle(color: AppTheme.darkText,
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('¿Cómo se llama el paciente?',
                    style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextField(
                  controller: nombreCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Nombre del paciente',
                    hintStyle: TextStyle(color: AppTheme.subtitleColor, fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.darkText.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  style: TextStyle(color: AppTheme.darkText,
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar',
                          style: TextStyle(color: AppTheme.subtitleColor,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final n = nombreCtrl.text.trim();
                        Navigator.pop(context,
                            n.isNotEmpty ? n : 'Paciente sin nombre');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E44AD),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Guardar',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );

    if (nombre == null || !mounted) return;

    final planActualizado = widget.planLocal!.copyWith(
      nombrePaciente: nombre,
      estadoIA:       EstadoIA.listo,
      modeloUrl:      widget.caso.biomodelos.isNotEmpty
          ? widget.caso.biomodelos.first.url
          : null,
    );

    await PlanificacionRepository.guardar(planActualizado);
    if (!mounted) return;

    setState(() => _planGuardado = true);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        const Text('Guardado en "Mis planificaciones"',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ]),
      backgroundColor: const Color(0xFF8E44AD),
      duration: const Duration(seconds: 3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Exportar JSON + capturas ───────────────────────────────────────────────
  // ── Guardar sesión (solo modoGenérico) ─────────────────────────────────────
  Future<void> _guardarSesion() async {
    final nombreCtrl = TextEditingController();
    final nombreConfirmado = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              decoration: BoxDecoration(
                color: AppTheme.sheetBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cardBorder, width: 1.5),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bookmark_add_outlined,
                    size: 32, color: Color(0xFF34A853)),
                const SizedBox(height: 12),
                Text('Guardar sesión',
                    style: TextStyle(color: AppTheme.darkText,
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Dale un nombre para identificar esta planificación',
                    style: TextStyle(color: AppTheme.subtitleColor,
                        fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                TextField(
                  controller: nombreCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Ej: Tobillo derecho paciente X',
                    hintStyle: TextStyle(color: AppTheme.subtitleColor,
                        fontSize: 13),
                    filled: true,
                    fillColor: AppTheme.darkText.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  style: TextStyle(color: AppTheme.darkText,
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancelar',
                          style: TextStyle(
                              color: AppTheme.subtitleColor,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final n = nombreCtrl.text.trim();
                        if (n.isNotEmpty) Navigator.pop(context, n);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF34A853),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('Guardar',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );

    if (nombreConfirmado == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    // Solo guardamos los tornillos de ESTA sesión (no el historial global del médico)
    final sesionActual = _tornillosColocados.map((t) => {
      'instanceId': t.instanceId,
      'glbId':      t.glbId,
      'nombre':     t.nombre,
      'cilindroId': t.cilindroId,
      'largo_mm':   t.largo,
      'hx': t.hx, 'hy': t.hy, 'hz': t.hz,
      'hnx': t.hnx, 'hny': t.hny, 'hnz': t.hnz,
      'hdx': t.hdx, 'hdy': t.hdy, 'hdz': t.hdz,
      'usarTrayectoria': t.usarTrayectoria,
    }).toList();
    final capasVisibles = <Map<String, dynamic>>[];
    for (final entry in _visibles.entries) {
      if (entry.value && entry.key < widget.caso.todosGlb.length) {
        final glb = widget.caso.todosGlb[entry.key];
        capasVisibles.add({
          'indice': entry.key, 'nombre': glb.nombre,
          'archivo': glb.archivo, 'tipo': glb.tipo, 'url': glb.url,
        });
      }
    }

    final sesionData = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'nombre': nombreConfirmado,
      'fecha': DateTime.now().toIso8601String(),
      'caso_origen': widget.caso.nombre,
      'num_tornillos': sesionActual.length,
      'num_capas': capasVisibles.length,
      'capas_visibles': capasVisibles,
      'tornillos_sesion_actual': sesionActual,
      'audio_notas_id': _sessionAudioId,
      'caso': {
        'id':       widget.caso.id,
        'nombre':   widget.caso.nombre,
        'paciente': widget.caso.paciente,
        'fechaOp':  widget.caso.fechaOp,
        'estado':   widget.caso.estado,
      },
    };
    _sesionAudioGuardada = true;

    final listaRaw = prefs.getString('listados_sesiones') ?? '[]';
    final List<dynamic> lista = json.decode(listaRaw);
    lista.insert(0, sesionData);
    await prefs.setString('listados_sesiones', json.encode(lista));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('«$nombreConfirmado» guardado en Listados'),
      backgroundColor: const Color(0xFF34A853),
      duration: const Duration(seconds: 2),
    ));
  }

  /// Guarda el estado actual del visor en el caso del servidor (sin dialog).
  Future<void> _guardarEnCaso() async {
    final capasVisibles = <Map<String, dynamic>>[];
    for (final entry in _visibles.entries) {
      if (entry.value && entry.key < widget.caso.todosGlb.length) {
        final glb = widget.caso.todosGlb[entry.key];
        capasVisibles.add({
          'indice': entry.key, 'nombre': glb.nombre,
          'archivo': glb.archivo, 'tipo': glb.tipo, 'url': glb.url,
        });
      }
    }
    final tornillos = _tornillosColocados.map((t) => {
      'instanceId': t.instanceId, 'glbId': t.glbId, 'nombre': t.nombre,
      'cilindroId': t.cilindroId, 'largo_mm': t.largo,
      'hx': t.hx, 'hy': t.hy, 'hz': t.hz,
      'hnx': t.hnx, 'hny': t.hny, 'hnz': t.hnz,
      'hdx': t.hdx, 'hdy': t.hdy, 'hdz': t.hdz,
      'usarTrayectoria': t.usarTrayectoria,
    }).toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('estado_caso_${widget.caso.id}', json.encode({
      'capas_visibles': capasVisibles,
      'tornillos_sesion_actual': tornillos,
    }));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Caso guardado'),
      backgroundColor: Color(0xFF34A853),
      duration: Duration(seconds: 2),
    ));
  }

  /// Sobrescribe la sesión existente (sin diálogo de nombre).
  Future<void> _actualizarSesion() async {
    final sesionId = widget.sesionGuardada?['id'] as String?;
    if (sesionId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final sesionActual = _tornillosColocados.map((t) => {
      'instanceId': t.instanceId,
      'glbId':      t.glbId,
      'nombre':     t.nombre,
      'cilindroId': t.cilindroId,
      'largo_mm':   t.largo,
      'hx': t.hx, 'hy': t.hy, 'hz': t.hz,
      'hnx': t.hnx, 'hny': t.hny, 'hnz': t.hnz,
      'hdx': t.hdx, 'hdy': t.hdy, 'hdz': t.hdz,
      'usarTrayectoria': t.usarTrayectoria,
    }).toList();
    final capasVisibles = <Map<String, dynamic>>[];
    for (final entry in _visibles.entries) {
      if (entry.value && entry.key < widget.caso.todosGlb.length) {
        final glb = widget.caso.todosGlb[entry.key];
        capasVisibles.add({
          'indice': entry.key, 'nombre': glb.nombre,
          'archivo': glb.archivo, 'tipo': glb.tipo, 'url': glb.url,
        });
      }
    }

    final sesionData = {
      ...widget.sesionGuardada!, // mantiene id, nombre y caso_origen originales
      'fecha': DateTime.now().toIso8601String(),
      'num_tornillos': sesionActual.length,
      'num_capas': capasVisibles.length,
      'capas_visibles': capasVisibles,
      'tornillos_sesion_actual': sesionActual,
    };

    final listaRaw = prefs.getString('listados_sesiones') ?? '[]';
    final List<dynamic> lista = json.decode(listaRaw);
    final idx = lista.indexWhere((s) => s['id'] == sesionId);
    if (idx >= 0) {
      lista[idx] = sesionData;
    } else {
      lista.insert(0, sesionData);
    }
    await prefs.setString('listados_sesiones', json.encode(lista));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Sesión actualizada'),
      backgroundColor: Color(0xFF34A853),
      duration: Duration(seconds: 2),
    ));
  }

  Future<void> _exportarJSON() async {
    final prefs = await SharedPreferences.getInstance();

    // Tornillos de la sesión actual (en vivo)
    final sesionActual = _tornillosColocados.map((t) => {
      'instanceId':  t.instanceId,
      'glbId':       t.glbId,
      'nombre':      t.nombre,
      'cilindroId':  t.cilindroId,
      'largo_mm':    t.largo,
    }).toList();

    // Capas visibles actualmente
    final capasVisibles = <Map<String, dynamic>>[];
    for (final entry in _visibles.entries) {
      if (entry.value && entry.key < widget.caso.todosGlb.length) {
        final glb = widget.caso.todosGlb[entry.key];
        capasVisibles.add({
          'indice': entry.key,
          'nombre': glb.nombre,
          'archivo': glb.archivo,
          'tipo': glb.tipo,
          'url': glb.url,
        });
      }
    }

    // Payload JSON
    final payload = {
      'caso': {
        'id':       widget.caso.id,
        'nombre':   widget.caso.nombre,
        'paciente': widget.caso.paciente,
        'fechaOp':  widget.caso.fechaOp,
        'estado':   widget.caso.estado,
      },
      'capas_visibles': capasVisibles,
      'tornillos': sesionActual,
      'exportado_en': DateTime.now().toIso8601String(),
    };
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

    // Si no hay URL configurada: mostrar JSON en bottom sheet
    if (_exportarUrl.isEmpty) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          minChildSize: 0.35,
          builder: (_, ctrl) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.sheetBg,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                ),
                child: Column(children: [
                  const SizedBox(height: 10),
                  Container(width: 40, height: 4,
                      decoration: BoxDecoration(color: AppTheme.handleColor,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(children: [
                      const Icon(Icons.data_object, size: 18, color: Color(0xFF2A7FF5)),
                      const SizedBox(width: 8),
                      Text('JSON exportado',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                              color: AppTheme.darkText)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(Icons.close, size: 20, color: AppTheme.subtitleColor),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Configura _exportarUrl en el código para enviar a tu endpoint.',
                        style: TextStyle(fontSize: 11, color: AppTheme.subtitleColor)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.darkText.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF2A7FF5).withOpacity(0.12)),
                        ),
                        child: SelectableText(jsonStr,
                            style: TextStyle(
                                fontFamily: 'monospace', fontSize: 11,
                                color: AppTheme.darkText, height: 1.6)),
                      ),
                    ],
                  )),
                ]),
              ),
            ),
          ),
        ),
      );
      return;
    }

    // Con URL configurada: capturar vistas y enviar multipart
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Capturando vistas…'),
      backgroundColor: Colors.black87,
      duration: Duration(seconds: 5),
    ));

    // Capturar las 3 vistas secuencialmente
    final frontal   = await _capturarVista(0); // Frontal
    final lateralD  = await _capturarVista(1); // Lateral derecha
    final lateralI  = await _capturarVista(2); // Lateral izquierda

    // Volver a frontal al terminar
    _jsRun('window.visor.setVista(0);');

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_exportarUrl))
        ..fields['datos'] = jsonStr;

      if (frontal  != null) request.files.add(http.MultipartFile.fromBytes('frontal',   frontal,  filename: 'frontal.png',    contentType: MediaType('image', 'png')));
      if (lateralD != null) request.files.add(http.MultipartFile.fromBytes('lateral_d', lateralD, filename: 'lateral_d.png', contentType: MediaType('image', 'png')));
      if (lateralI != null) request.files.add(http.MultipartFile.fromBytes('lateral_i', lateralI, filename: 'lateral_i.png', contentType: MediaType('image', 'png')));

      final resp = await request.send().timeout(const Duration(seconds: 30));
      final ok = resp.statusCode >= 200 && resp.statusCode < 300;
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Exportado correctamente'
              : 'Error al exportar (${resp.statusCode})'),
          backgroundColor: ok ? const Color(0xFF34A853) : Colors.redAccent,
          duration: const Duration(seconds: 3),
        ));
        if (ok) _cambiarEstadoAEnviado(prefs);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error de conexión: $e'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 3),
        ));
      }
    }
  }

  // ── Avance automático de estado según acción del usuario ────────────────────
  // Solo avanza si el nuevo estado tiene más peso que el actual (no retrocede).
  static const List<String> _ordenEstados = ['pendiente', 'validado', 'modificado', 'firmado', 'enviado'];
  Future<void> _autoAvanzarEstado(String nuevo) async {
    if (widget.modoGenerico) return;
    final idxActual = _ordenEstados.indexOf(_estadoActual);
    final idxNuevo  = _ordenEstados.indexOf(nuevo);
    if (idxNuevo <= idxActual) return; // no retroceder ni repetir
    try {
      final prefs    = await SharedPreferences.getInstance();
      final email    = prefs.getString('login_email')    ?? '';
      final password = prefs.getString('login_password') ?? '';
      await http.post(
        Uri.parse(_apiCambioEstado),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$email:$password'))}',
          'Content-Type': 'application/json',
        },
        body: json.encode({'id': widget.caso.id, 'estado': nuevo}),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() => _estadoActual = nuevo);
      final fechaHoy = DateTime.now().toIso8601String();
      await prefs.setString('estado_fecha_${widget.caso.id}', fechaHoy);
      final ultimoId = prefs.getString('ultimo_caso_id');
      if (ultimoId == widget.caso.id) await prefs.setString('ultimo_caso_estado', nuevo);
      widget.onEstadoCambiado?.call(nuevo);
    } catch (_) {
      // Fallo silencioso: la planificación sigue funcionando
    }
  }

  // ── Cambia el estado del caso a 'enviado' tras exportar correctamente ───────
  Future<void> _cambiarEstadoAEnviado(SharedPreferences prefs) async {
    try {
      final email    = prefs.getString('login_email')    ?? '';
      final password = prefs.getString('login_password') ?? '';
      final credentials = base64Encode(utf8.encode('$email:$password'));

      await http.post(
        Uri.parse(_apiCambioEstado),
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/json',
        },
        body: json.encode({'id': widget.caso.id, 'estado': 'enviado'}),
      ).timeout(const Duration(seconds: 10));

      final fechaHoy = DateTime.now().toIso8601String();
      await prefs.setString('estado_fecha_${widget.caso.id}', fechaHoy);
      final ultimoId = prefs.getString('ultimo_caso_id');
      if (ultimoId == widget.caso.id) {
        await prefs.setString('ultimo_caso_estado', 'enviado');
      }

      // Actualizar estado local y notificar a CasosScreen
      if (mounted) setState(() => _estadoActual = 'enviado');
      widget.onEstadoCambiado?.call('enviado');
    } catch (_) {
      // Fallo silencioso: el export ya fue correcto
    }
  }

  void _limpiarVisor() {
    // Limpiar
    // estado Dart
    setState(() {
      for (final k in _visibles.keys) _visibles[k] = false;
      for (final k in _trayectoriasVis.keys) _trayectoriasVis[k] = true;
      _tornillosColocados.clear();
      _screwCounter = 0;
      _reglaLibreMm = null;
      _guiasVisibles = false;
      _modoRegla = false;
      _modoNota = false;
    });
    _colocadosVersion.value++;
    // Llama a limpiarTodo() en Three.js: borra modelos, trayectorias y reglas
    _jsRun('if(window.visor && window.visor.limpiarTodo) window.visor.limpiarTodo();');
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Future<void> _abrirPdfCaso() async {
    final todosGlb = [
      ...widget.caso.biomodelos,
      ...widget.caso.placas.expand((g) => g.placas),
      ...widget.caso.tornillos.expand((g) => g.tornillos),
    ];
    if (todosGlb.isEmpty) { _sinDocumentacion(); return; }

    // Derivar carpeta relativa del caso desde la URL del primer GLB
    final uri = Uri.parse(todosGlb.first.url);
    final segments = uri.pathSegments;
    if (segments.length < 2) { _sinDocumentacion(); return; }
    // Ruta relativa desde public_html/profesional/ → carpeta raíz del caso + documentacion
    final casoRelPath = segments.take(segments.length - 2).join('/');
    final carpetaParam = Uri.encodeComponent('$casoRelPath/documentacion');

    final prefs = await SharedPreferences.getInstance();
    final email    = prefs.getString('login_email')    ?? '';
    final password = prefs.getString('login_password') ?? '';
    final credentials = base64Encode(utf8.encode('$email:$password'));

    final apiUrl = 'https://profesional.planificacionquirurgica.com/listar_docs.php?carpeta=$carpetaParam';
    debugPrint('📄 PDF apiUrl: $apiUrl');

    List<String> pdfs = [];
    try {
      final resp = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Basic $credentials'},
      ).timeout(const Duration(seconds: 10));

      debugPrint('📄 PDF status: ${resp.statusCode} body: ${resp.body}');

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        pdfs = List<String>.from(data['pdfs'] ?? []);
      }
    } catch (e) { debugPrint('📄 PDF error: $e'); }

    // URL base para construir enlaces directos a los PDFs
    final rootPath = '/' + segments.take(segments.length - 2).join('/') + '/';
    final docUrl = Uri.encodeFull(uri.scheme + '://' + uri.host + rootPath + 'documentacion/');

    if (pdfs.isEmpty) { _sinDocumentacion(); return; }
    if (!mounted) return;

    // Panel de selección
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: 320,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              decoration: BoxDecoration(
                color: AppTheme.sheetBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.cardBorder, width: 1.5),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.folder_open_outlined, size: 32,
                    color: const Color(0xFF2A7FF5)),
                const SizedBox(height: 10),
                Text('Documentación',
                    style: TextStyle(color: AppTheme.darkText,
                        fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Selecciona un documento para abrirlo',
                    style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
                    textAlign: TextAlign.center),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: pdfs.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1, color: AppTheme.cardBorder),
                    itemBuilder: (ctx, i) {
                      final nombre = pdfs[i];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final pdfUrl = nombre.startsWith('http')
                              ? nombre
                              : docUrl + nombre;
                          if (!mounted) return;
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                          try {
                            final resp = await http.get(
                              Uri.parse(pdfUrl),
                              headers: {'Authorization': 'Basic $credentials'},
                            ).timeout(const Duration(seconds: 30));
                            if (!mounted) return;
                            Navigator.of(context, rootNavigator: true).pop();
                            if (resp.statusCode == 200) {
                              final tmpDir  = await getTemporaryDirectory();
                              final ext     = nombre.contains('.') ? nombre.split('.').last.toLowerCase() : 'pdf';
                              final tmpFile = File('${tmpDir.path}/${const Uuid().v4()}.$ext');
                              await tmpFile.writeAsBytes(resp.bodyBytes);
                              if (!mounted) return;
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => VisorPdfScreen(
                                  rutaLocal: tmpFile.path,
                                  nombre: nombre,
                                ),
                              ));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error al descargar PDF (${resp.statusCode})')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              Navigator.of(context, rootNavigator: true).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 4),
                          child: Row(children: [
                            Icon(Icons.picture_as_pdf_outlined,
                                size: 20, color: const Color(0xFFE53935)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _marqueeText(nombre, TextStyle(
                                  color: AppTheme.darkText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                            ),
                            Icon(Icons.chevron_right,
                                size: 18, color: AppTheme.subtitleColor),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cerrar',
                      style: TextStyle(
                          color: AppTheme.subtitleColor,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _abrirNotasVoz() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: AudioNotasPanel(casoId: _audioNotasId),
      ),
    );
  }

  void _sinDocumentacion() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Aún no hay documentación generada'),
      backgroundColor: Colors.black87,
      duration: Duration(seconds: 3),
    ));
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.cardBg1,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF2A7FF5).withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(children: [
              _topBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context), size: 17),
              const Spacer(),
              _topBtn(Icons.undo,
                () { if (_tornillosColocados.isNotEmpty) _eliminarTornillo(_tornillosColocados.last); }),
              _topBtn(Icons.straighten,
                () { setState(() { _modoRegla = !_modoRegla; _reglaLibreMm = null; }); _jsModoRegla(_modoRegla); },
                active: _modoRegla),
              _topBtn(Icons.comment_outlined,
                () { setState(() => _modoNota = !_modoNota); _jsNotaModo(_modoNota); },
                active: _modoNota),
              _topBtn(_autoRotate ? Icons.pause_circle_outline : Icons.rotate_right,
                () { setState(() => _autoRotate = !_autoRotate); _jsAutoRotate(_autoRotate); },
                active: _autoRotate),
              _topBtn(Icons.biotech_outlined,
                () { setState(() { _modoXray = !_modoXray; _xrayOpacity = _modoXray ? 0.12 : 1.0; }); _jsXray(_xrayOpacity); },
                active: _modoXray),
              _topBtn(Icons.content_cut,
                () { setState(() => _planoCortando = !_planoCortando); _jsPlano(_planoCortando, _planoEje, _planoPos); },
                active: _planoCortando),
              _topBtn(Icons.center_focus_strong,
                () => setState(() => _vistasPanelVisible = !_vistasPanelVisible),
                active: _vistasPanelVisible),
              _topBtn(Icons.layers_outlined,
                () => setState(() => _panelAbierto = !_panelAbierto),
                active: _panelAbierto),
              const SizedBox(width: 4),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _topBtn(IconData icon, VoidCallback onTap, {bool active = false, double size = 20}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 38, height: 38,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? Color(0xFF2A7FF5).withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: Color(0xFF2A7FF5).withOpacity(0.5)) : null,
        ),
        child: Icon(icon, color: active ? const Color(0xFF2A7FF5) : AppTheme.darkText.withOpacity(0.6), size: size),
      ),
    );
  }

  // ── Panel lateral ─────────────────────────────────────────────────────────
  Widget _buildPanelLateral() {
    final size    = MediaQuery.of(context).size;
    final padding = MediaQuery.of(context).padding;
    if (_panelLeftOffset < 0) _panelLeftOffset = size.width - 260 - 12;

    return AnimatedPositioned(
      duration: _panelArrastrando
          ? Duration.zero          // sin animación mientras arrastramos
          : const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: _panelTopOffset,
      left: _panelAbierto ? _panelLeftOffset : size.width + 20,
      child: GestureDetector(
        onLongPressStart: (d) {
          HapticFeedback.mediumImpact();
          setState(() {
            _panelArrastrando = true;
            _panelDragLastPos = d.globalPosition;
          });
        },
        onLongPressMoveUpdate: (d) {
          if (!_panelArrastrando) return;
          final delta = d.globalPosition - _panelDragLastPos;
          setState(() {
            _panelDragLastPos = d.globalPosition;
            _panelTopOffset = (_panelTopOffset + delta.dy).clamp(
              padding.top + 8.0,
              size.height - 160.0,
            );
            _panelLeftOffset = (_panelLeftOffset + delta.dx).clamp(
              8.0,
              size.width - 260 - 8.0,
            );
          });
        },
        onLongPressEnd: (_) {
          HapticFeedback.lightImpact();
          setState(() => _panelArrastrando = false);
        },
        onLongPressCancel: () => setState(() => _panelArrastrando = false),
        onDoubleTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _panelTopOffset  = 74.0;
            _panelLeftOffset = size.width - 260 - 12;
            _panelHeight     = 680.0;
          });
        },
        behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: _panelArrastrando
              ? [BoxShadow(color: const Color(0xFF2A7FF5).withOpacity(0.35), blurRadius: 32, offset: const Offset(0, 8))]
              : [BoxShadow(color: const Color(0xFF2A7FF5).withOpacity(0.10), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: 260,
                  height: _panelHeight,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg1,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _panelArrastrando
                          ? const Color(0xFF2A7FF5).withOpacity(0.6)
                          : AppTheme.cardBorder,
                      width: 1.5,
                    ),
                  ),
                  child: Column(children: [
                    _buildTabs(),
                    Divider(height: 1, color: AppTheme.handleColor),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                        layoutBuilder: (currentChild, previousChildren) => Stack(
                          alignment: Alignment.topCenter,
                          children: [...previousChildren, if (currentChild != null) currentChild],
                        ),
                        child: SingleChildScrollView(
                          key: ValueKey(_tabPanel),
                          padding: const EdgeInsets.only(bottom: 8),
                          physics: const BouncingScrollPhysics(),
                          child: _tabPanel == 'capas'
                              ? _buildContenidoCapas()
                              : _tabPanel == 'tornillos'
                                  ? _buildContenidoColocados()
                                  : _tabPanel == 'notas'
                                      ? _buildContenidoNotas()
                                      : _buildContenidoMediciones(),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            // ── Handle de redimensionado ──────────────────────────────
            GestureDetector(
              onVerticalDragUpdate: (d) {
                setState(() {
                  _panelHeight = (_panelHeight + d.delta.dy).clamp(160.0, size.height - _panelTopOffset - 80.0);
                });
              },
              child: Container(
                width: 260,
                height: 20,
                color: Colors.transparent,
                child: Center(
                  child: Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.handleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Row(children: [
        _tab('Capas', Icons.layers, 'capas'),
        const SizedBox(width: 4),
        _tab('Tornillos', Icons.settings, 'tornillos', color: _C.accentScrew),
        const SizedBox(width: 4),
        _tab('Notas', Icons.push_pin, 'notas', color: const Color(0xFFFFD60A)),
        const SizedBox(width: 4),
        _tab('Medic.', Icons.straighten, 'mediciones', color: const Color(0xFF64D2FF)),
      ]),
    );
  }

  Widget _tab(String label, IconData icon, String key, {Color? color}) {
    final active = _tabPanel == key;
    final c = color ?? _C.accentBone;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabPanel = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? c.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: c.withOpacity(0.5)) : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: active ? c : AppTheme.subtitleColor),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
                color: active ? c : AppTheme.subtitleColor,
                fontSize: 9, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }

  Widget _buildContenidoCapas() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 6),
        child: Row(children: [
          Icon(Icons.layers, color: AppTheme.darkText.withOpacity(0.8), size: 13),
          const SizedBox(width: 5),
          Text('Modelos', style: TextStyle(color: AppTheme.darkText,
              fontWeight: FontWeight.w700, fontSize: 12)),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() => _guiasVisibles = !_guiasVisibles);
              _jsToggleGuias(_guiasVisibles);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _guiasVisibles ? _C.accentScrew.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _guiasVisibles ? _C.accentScrew.withOpacity(0.5) : AppTheme.handleColor),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.linear_scale, size: 10, color: _guiasVisibles ? _C.accentScrew : AppTheme.subtitleColor),
                const SizedBox(width: 4),
                Text('Guías', style: TextStyle(
                  color: _guiasVisibles ? _C.accentScrew : AppTheme.subtitleColor,
                  fontSize: 9, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
      if (widget.caso.biomodelos.isNotEmpty) ...[
        // Grupo Biomodelos colapsable
        _StaggerItem(key: ValueKey('capas-bio'), index: 0, child: GestureDetector(
          onTap: () => setState(() => _bioExpanded = !_bioExpanded),
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 6, 10, 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: _C.accentBone.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.accentBone.withOpacity(0.25)),
            ),
            child: Row(children: [
              Icon(Icons.folder_outlined, size: 13, color: _C.accentBone),
              const SizedBox(width: 6),
              Expanded(child: Text('Biomodelos',
                  style: TextStyle(color: _C.accentBone,
                      fontSize: 11, fontWeight: FontWeight.w700))),
              // Botón Ver todo / Ocultar todo — solo actúa sobre biomodelos
              GestureDetector(
                onTap: () {
                  _toggleBiomodelos();
                  if (!_bioExpanded) setState(() => _bioExpanded = true);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Text(
                    _bioTodosVisibles ? 'Ocultar' : 'Ver todo',
                    style: TextStyle(
                      color: _C.accentBone.withOpacity(0.85),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Icon(_bioExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16, color: _C.accentBone.withOpacity(0.7)),
            ]),
          ),
        )),
        if (_bioExpanded)
          ...widget.caso.biomodelos.asMap().entries.map((e) =>
              _StaggerItem(key: ValueKey('capas-bio-${e.key}'), index: e.key + 1, child: _capaItem(e.key, e.value))),
      ],
      if (widget.caso.placas.isNotEmpty) ...[
        _StaggerItem(key: const ValueKey('capas-placas-hdr'), index: 1, child:
          _seccionHeader('PLACAS E IMPLANTES', Icons.hardware, _C.accentImplant)),
        ...widget.caso.placas.asMap().entries.map((entry) {
          final gi = entry.key; final gr = entry.value;
          int off = widget.caso.biomodelos.length;
          for (int k = 0; k < gi; k++) off += widget.caso.placas[k].placas.length;
          return _StaggerItem(key: ValueKey('capas-placa-$gi'), index: gi + 2, child: _grupoPlacas(gi, gr, off));
        }),
      ],
      if (widget.caso.todosGlb.isEmpty)
        Padding(padding: const EdgeInsets.all(16),
            child: Text('Sin modelos', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12))),
      const SizedBox(height: 10),
    ]);
  }

  Widget _buildContenidoColocados() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _seccionHeader('TORNILLOS COLOCADOS', Icons.check_circle_outline, _C.accentScrew),
      ValueListenableBuilder<int>(
        valueListenable: _colocadosVersion,
        builder: (_, __, ___) => _tornillosColocados.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Text('Toca la placa sobre un agujero para insertar.',
                    style: TextStyle(color: AppTheme.subtitleColor, fontSize: 11)),
              )
            : Column(children: _tornillosColocados.asMap().entries.map((e) =>
                  _StaggerItem(key: ValueKey('col-${e.key}'), index: e.key, child: _tornilloColocadoItem(e.value))
                ).toList()),
      ),
      const SizedBox(height: 10),
    ]);
  }

  Widget _tornilloColocadoItem(TornilloColocado tc) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tc.visible ? Color(0xFF2A7FF5).withOpacity(0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tc.visible ? Color(0xFF2A7FF5).withOpacity(0.2) : AppTheme.handleColor),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => _toggleVisibilidadTornillo(tc),
          child: Icon(
            tc.visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            size: 14, color: tc.visible ? _C.accentScrew : AppTheme.subtitleColor),
        ),
        const SizedBox(width: 7),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_nombreCorto(tc.nombre),
                style: TextStyle(
                    color: tc.visible ? AppTheme.darkText : AppTheme.subtitleColor,
                    fontSize: 10, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
            Text(_labelDiamLargo(tc.nombre), style: TextStyle(color: _C.accentScrew.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.w600)),
          ],
        )),
        // Botón regla
        GestureDetector(
          onTap: () => _toggleRegla(tc),
          child: Container(
            padding: const EdgeInsets.all(4),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: tc.reglaVisible ? Color(0xFFFFD60A).withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: tc.reglaVisible
                  ? Color(0xFFFFD60A).withOpacity(0.5)
                  : AppTheme.handleColor),
            ),
            child: Icon(Icons.straighten, size: 13,
                color: tc.reglaVisible ? const Color(0xFFFFD60A) : AppTheme.subtitleColor),
          ),
        ),
        GestureDetector(
          onTap: () => _eliminarTornillo(tc),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
            child: const Icon(Icons.delete_outline, size: 13, color: Colors.redAccent),
          ),
        ),
      ]),
    );
  }

  Widget _seccionHeader(String label, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 3),
    child: Row(children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
    ]),
  );

  Widget _grupoPlacas(int gi, GrupoPlagas grupo, int off) {
    final exp = _grupoExpandido[gi] ?? false;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () => setState(() => _grupoExpandido[gi] = !exp),
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _C.accentImplant.withOpacity(0.07), borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.accentImplant.withOpacity(0.25)),
          ),
          child: Row(children: [
            Icon(Icons.folder_outlined, size: 13, color: _C.accentImplant),
            const SizedBox(width: 7),
            Expanded(child: _marqueeText(_limpiarNombre(grupo.nombre),
                TextStyle(color: AppTheme.darkText, fontSize: 11, fontWeight: FontWeight.w600))),
            AnimatedRotation(turns: exp?0.5:0, duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down, color: AppTheme.subtitleColor, size: 15)),
          ]),
        ),
      ),
      AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        crossFadeState: exp ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: const SizedBox.shrink(),
        secondChild: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Column(children: grupo.placas.asMap().entries.map((e) => _capaItem(off+e.key, e.value)).toList()),
        ),
      ),
    ]);
  }

  Widget _capaItem(int idx, GlbArchivo glb) {
    final visible  = _visibles[idx] ?? false;
    final color    = glb.tipo == 'biomodelo' ? _C.accentBone : _C.accentImplant;
    final expanded = _capaExpandida[idx] ?? false;
    final trayVis  = _trayectoriasVis[idx] ?? true;
    final esPlaca  = glb.tipo == 'placa';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: expanded ? Color(0xFF2A7FF5).withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: expanded ? Border.all(color: Color(0xFF2A7FF5).withOpacity(0.18)) : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Fila principal: nombre + flecha ──
        GestureDetector(
          onTap: () => setState(() => _capaExpandida[idx] = !expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(children: [
              // Indicador de estado (punto de color)
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: visible ? color : AppTheme.subtitleColor2,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(child: _marqueeText(_limpiarNombre(glb.nombre),
                  TextStyle(
                      color: visible ? AppTheme.darkText : AppTheme.subtitleColor,
                      fontSize: 11, fontWeight: FontWeight.w500))),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down,
                    size: 16, color: AppTheme.subtitleColor),
              ),
            ]),
          ),
        ),
        // ── Panel expandido ──
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(children: [
              // Botones: ojo + guías + plano + color
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  // Ojo — visibilidad geometría
                  GestureDetector(
                    onTap: () => _toggleVisibilidad(idx),
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: visible ? color.withOpacity(0.18) : AppTheme.darkText.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: visible ? color.withOpacity(0.5) : AppTheme.handleColor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        ValueListenableBuilder<bool>(
                          valueListenable: _cargandoNotifiers[idx] ?? ValueNotifier(false),
                          builder: (_, cargando, __) => cargando
                              ? SizedBox(width: 12, height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: color))
                              : Icon(
                                  visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                  size: 12,
                                  color: visible ? color : AppTheme.subtitleColor),
                        ),
                        const SizedBox(width: 4),
                        Text(visible ? 'Visible' : 'Oculto',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w600,
                                color: visible ? color : AppTheme.subtitleColor)),
                      ]),
                    ),
                  ),
                  // Guías (solo placas)
                  if (esPlaca) GestureDetector(
                    onTap: () {
                      setState(() => _trayectoriasVis[idx] = !trayVis);
                      _jsToggleTrayectoriasGlb(idx, !trayVis);
                    },
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: trayVis
                            ? const Color(0xFF2196F3).withOpacity(0.18)
                            : AppTheme.darkText.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: trayVis
                                ? const Color(0xFF2196F3).withOpacity(0.5)
                                : AppTheme.handleColor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.linear_scale, size: 12,
                            color: trayVis
                                ? const Color(0xFF2196F3)
                                : AppTheme.subtitleColor),
                        const SizedBox(width: 4),
                        Text('Guías',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w600,
                                color: trayVis
                                    ? const Color(0xFF2196F3)
                                    : AppTheme.subtitleColor)),
                      ]),
                    ),
                  ),
                  // Plano de corte
                  if (visible) GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_planoCapas.contains(idx)) {
                          _planoCapas.remove(idx);
                          _jsPlanoGlb(idx, false);
                        } else {
                          _planoCapas.add(idx);
                          _jsPlanoGlb(idx, true);
                        }
                      });
                    },
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _planoCapas.contains(idx)
                            ? Color(0xFF64D2FF).withOpacity(0.2)
                            : AppTheme.darkText.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _planoCapas.contains(idx)
                                ? Color(0xFF64D2FF).withOpacity(0.6)
                                : AppTheme.handleColor),
                      ),
                      child: Icon(Icons.content_cut, size: 13,
                          color: _planoCapas.contains(idx)
                              ? const Color(0xFF64D2FF)
                              : AppTheme.subtitleColor),
                    ),
                  ),
                  // Color picker
                  if (visible) GestureDetector(
                    onTap: () => _mostrarColorPicker(idx),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: _colores[idx] ?? color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              // Slider opacidad (solo si visible)
              if (visible) ...[
                const SizedBox(height: 6),
                Row(children: [
                  SizedBox(width: 28,
                    child: Text('${((_opacidades[idx]??1.0)*100).round()}%',
                        style: TextStyle(color: AppTheme.subtitleColor, fontSize: 9),
                        textAlign: TextAlign.center)),
                  Expanded(child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      activeTrackColor: Color(0xFF2A7FF5).withOpacity(0.8),
                      inactiveTrackColor: AppTheme.handleColor,
                      thumbColor: const Color(0xFF2A7FF5),
                      overlayShape: SliderComponentShape.noOverlay,
                    ),
                    child: Slider(
                      value: _opacidades[idx] ?? 1.0, min: 0.05, max: 1.0,
                      onChanged: (val) {
                        setState(() => _opacidades[idx] = val);
                        _jsSetOpacidad(idx, val);
                      },
                    ),
                  )),
                ]),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  void _mostrarColorPicker(int idx) {
    final colores = [
      Colors.white,
      const Color(0xFFE8D5B7), // hueso natural
      const Color(0xFF90CAF9), // azul claro
      const Color(0xFFA5D6A7), // verde claro
      const Color(0xFFFFCC80), // naranja claro
      const Color(0xFFEF9A9A), // rojo claro
      const Color(0xFFCE93D8), // morado
      const Color(0xFF80DEEA), // cyan
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 1.2)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Color del modelo', style: TextStyle(color: AppTheme.darkText,
                  fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: colores.map((c) {
                final sel = (_colores[idx] ?? Colors.white) == c;
                return GestureDetector(
                  onTap: () {
                    setState(() => _colores[idx] = c);
                    _jsColor(idx, c);
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: c, shape: BoxShape.circle,
                      border: Border.all(
                        color: sel ? Colors.white : Colors.white.withOpacity(0.2),
                        width: sel ? 3 : 1),
                      boxShadow: sel ? [BoxShadow(color: c.withOpacity(0.6), blurRadius: 8)] : null,
                    ),
                  ),
                );
              }).toList()),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelCorte() {
    final ejesLabels = ['X', 'Y', 'Z'];
    final ejesIcons  = [Icons.swap_horiz, Icons.swap_vert, Icons.open_in_full];
    return Positioned(
      bottom: 56, left: 16, right: 16,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.sheetBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.cardBorder, width: 1.2),
              boxShadow: [BoxShadow(color: Color(0xFF2A7FF5).withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 6))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Row(children: [
                const Icon(Icons.content_cut, color: Color(0xFF2A7FF5), size: 14),
                const SizedBox(width: 8),
                Text('Plano de corte',
                    style: TextStyle(color: AppTheme.darkText, fontSize: 12, fontWeight: FontWeight.w700)),
                const Spacer(),
                // Selectores de eje
                ...List.generate(3, (i) {
                  final sel = _planoEje == i;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _planoEje = i);
                      _jsPlano(true, i, _planoPos);
                      for (final ci in _planoCapas) _jsPlanoGlb(ci, true);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: sel ? Color(0xFF64D2FF).withOpacity(0.20) : AppTheme.darkText.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: sel ? Color(0xFF64D2FF).withOpacity(0.7) : AppTheme.handleColor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(ejesIcons[i], size: 11,
                            color: sel ? const Color(0xFF64D2FF) : AppTheme.subtitleColor),
                        const SizedBox(width: 3),
                        Text(ejesLabels[i], style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: sel ? const Color(0xFF64D2FF) : AppTheme.subtitleColor)),
                      ]),
                    ),
                  );
                }),
              ]),
              const SizedBox(height: 10),
              // Slider posición
              Row(children: [
                Text('0%', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 9)),
                Expanded(child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    activeTrackColor: Color(0xFF64D2FF).withOpacity(0.8),
                    inactiveTrackColor: AppTheme.handleColor,
                    thumbColor: const Color(0xFF64D2FF),
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _planoPos, min: 0.0, max: 1.0,
                    onChanged: (val) {
                      setState(() => _planoPos = val);
                      _jsPlano(true, _planoEje, val);
                      // Re-aplicar a capas individuales marcadas
                      for (final i in _planoCapas) _jsPlanoGlb(i, true);
                    },
                  ),
                )),
                Text('100%', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 9)),
                const SizedBox(width: 8),
                Text('${(_planoPos * 100).round()}%',
                    style: const TextStyle(color: Color(0xFF64D2FF), fontSize: 11, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _mostrarInfoCaso(BuildContext context) async {
    final prefs    = await SharedPreferences.getInstance();
    // Leer historial acumulado: sesiones separadas por ||
    final rawH     = prefs.getString('historial_tornillos_\${widget.caso.id}') ?? '';
    // Cada sesión es una lista de entradas separadas por |
    final sesiones = rawH.isNotEmpty
        ? rawH.split('||').where((s) => s.isNotEmpty).toList()
        : <String>[];

    // Placas activas en la sesión actual
    final offsetPlacas = widget.caso.biomodelos.length;
    final placasActivas = <String>[];
    for (int i = offsetPlacas; i < widget.caso.todosGlb.length; i++) {
      if (_visibles[i] == true) placasActivas.add(widget.caso.todosGlb[i].nombre);
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: AppTheme.sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(top: BorderSide(color: AppTheme.handleColor)),
            ),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Handle
              Center(child: Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: AppTheme.handleColor,
                      borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              // Título + botón borrar
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _C.accentScrew.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.history, color: _C.accentScrew, size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Text('Resumen de sesión',
                    style: TextStyle(color: AppTheme.darkText, fontSize: 16, fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 20),

              // ─ Placas activas ─
              _historialSeccion(
                titulo: 'PLACAS ACTIVAS',
                icono: Icons.layers_outlined,
                color: const Color(0xFF2A7FF5),
                items: placasActivas.isEmpty
                    ? [_historialItemVacio('Sin placas cargadas')]
                    : placasActivas.asMap().entries.map((e) => _historialItem(
                        numero: e.key + 1,
                        nombre: e.value,
                        largo: '',
                        color: const Color(0xFF2A7FF5),
                      )).toList(),
              ),

              const SizedBox(height: 16),

              // ─ Tornillos sesión actual ─
              _historialSeccion(
                titulo: 'TORNILLOS — SESIÓN ACTUAL',
                icono: Icons.bolt_rounded,
                color: _C.accentBone,
                items: _tornillosColocados.isEmpty
                    ? [_historialItemVacio('Sin tornillos colocados aún')]
                    : _tornillosColocados.asMap().entries.map((e) {
                        final t = e.value;
                        return _historialItem(
                          numero: e.key + 1,
                          nombre: _nombreCorto(t.nombre),
                          largo: t.largo > 0 ? '${t.largo.toStringAsFixed(0)} mm' : '',
                          color: _C.accentBone,
                        );
                      }).toList(),
              ),

            ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _historialSeccion({required String titulo, required IconData icono, required Color color, required List<Widget> items}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icono, size: 11, color: color.withOpacity(0.7)),
        const SizedBox(width: 5),
        Text(titulo, style: TextStyle(color: color.withOpacity(0.7), fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ]),
      const SizedBox(height: 8),
      ...items,
    ]);
  }

  Widget _historialItem({required int numero, required String nombre, required String largo, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Center(child: Text('$numero',
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(nombre,
            style: TextStyle(color: AppTheme.darkText, fontSize: 13, fontWeight: FontWeight.w600))),
        if (largo.isNotEmpty)
          Text(largo, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _historialItemVacio(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(msg, style: TextStyle(color: AppTheme.subtitleColor,
          fontSize: 12, fontStyle: FontStyle.italic)),
    );
  }

  Widget _infoFila(IconData icon, String label, String valor) {
    if (valor.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 14, color: AppTheme.subtitleColor),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
        const Spacer(),
        Text(valor, style: TextStyle(color: AppTheme.darkText, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildContenidoMediciones() {
    const azul = Color(0xFF64D2FF);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 6),
        child: Row(children: [
          const Icon(Icons.straighten, color: azul, size: 13),
          const SizedBox(width: 5),
          const Text('Mediciones', style: TextStyle(color: azul, fontWeight: FontWeight.w700, fontSize: 12)),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                _modoRegla = true;
                _reglaLibreMm = null;
                _panelAbierto = false;
              });
              _jsModoRegla(true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: azul.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: azul.withOpacity(0.4))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 11, color: azul),
                SizedBox(width: 3),
                Text('Medir', style: TextStyle(color: azul, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
      ValueListenableBuilder<int>(
        valueListenable: _medicionesVersion,
        builder: (_, __, ___) {
          if (_mediciones.isEmpty) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Text('Activa la regla y toca 2 puntos del modelo.',
                  style: TextStyle(color: AppTheme.subtitleColor, fontSize: 11)),
            );
          }
          return Column(
            children: _mediciones.asMap().entries.map((e) {
              final m = e.value;
              return _StaggerItem(
                key: ValueKey('med-${e.key}'),
                index: e.key,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: m.visible ? azul.withOpacity(0.08) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: m.visible ? azul.withOpacity(0.3) : AppTheme.handleColor)),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () {
                        setState(() => m.visible = !m.visible);
                        _jsToggleReglaLibre(m.id, m.visible);
                        _medicionesVersion.value++;
                      },
                      child: Icon(
                        m.visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        size: 14,
                        color: m.visible ? azul : AppTheme.subtitleColor),
                    ),
                    const SizedBox(width: 7),
                    Expanded(child: Text('${m.mm.toStringAsFixed(1)} mm',
                        style: TextStyle(
                            color: m.visible ? AppTheme.darkText : AppTheme.subtitleColor,
                            fontSize: 12, fontWeight: FontWeight.w700))),
                    GestureDetector(
                      onTap: () {
                        _jsEliminarReglaLibre(m.id);
                        setState(() => _mediciones.remove(m));
                        _medicionesVersion.value++;
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.close, size: 11, color: Colors.redAccent)),
                    ),
                  ]),
                ),
              );
            }).toList(),
          );
        },
      ),
      const SizedBox(height: 10),
    ]);
  }

  Widget _buildContenidoNotas() {
    const amarillo = Color(0xFFFFD60A);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 6),
        child: Row(children: [
          const Icon(Icons.push_pin, color: amarillo, size: 13),
          const SizedBox(width: 5),
          const Text('Notas 3D', style: TextStyle(color: amarillo,
              fontWeight: FontWeight.w700, fontSize: 12)),
          const Spacer(),
          // Botón añadir nota
          GestureDetector(
            onTap: () {
              setState(() {
                _modoNota = true;
                _panelAbierto = false;
              });
              _jsNotaModo(true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: amarillo.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: amarillo.withOpacity(0.4))),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, size: 11, color: amarillo),
                SizedBox(width: 3),
                Text('Añadir', style: TextStyle(color: amarillo, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
      ValueListenableBuilder<int>(
        valueListenable: _notasVersion,
        builder: (_, __, ___) => _notas.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                child: Text('Mantén pulsado el modelo\npara clavar una nota.',
                    style: TextStyle(color: AppTheme.subtitleColor, fontSize: 11)),
              )
            : Column(children: _notas.asMap().entries.map((e) {
                final n = e.value;
                return _StaggerItem(
                  key: ValueKey('nota-${e.key}'),
                  index: e.key,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: n.visible ? amarillo.withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: n.visible ? amarillo.withOpacity(0.3) : AppTheme.handleColor)),
                    child: Row(children: [
                      GestureDetector(
                        onTap: () {
                          setState(() => n.visible = !n.visible);
                          _jsNotaToggle(n.id, n.visible);
                          _notasVersion.value++;
                        },
                        child: Icon(
                          n.visible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                          size: 14, color: n.visible ? amarillo : AppTheme.subtitleColor),
                      ),
                      const SizedBox(width: 7),
                      Expanded(child: Text(n.texto,
                          style: TextStyle(
                              color: n.visible ? AppTheme.darkText : AppTheme.subtitleColor,
                              fontSize: 10, fontWeight: FontWeight.w500),
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                      GestureDetector(
                        onTap: () {
                          _jsNotaRemove(n.id);
                          setState(() => _notas.remove(n));
                          _notasVersion.value++;
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.delete_outline, size: 13, color: Colors.redAccent),
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList()),
      ),
      const SizedBox(height: 10),
    ]);
  }

  Widget _marqueeText(String text, TextStyle style) =>
      _MarqueeText(text: text, style: style);

  Widget _glassChip({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.cardBg1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Stagger item ─────────────────────────────────────────────────────────────
class _StaggerItem extends StatefulWidget {
  final int index;
  final Widget child;
  const _StaggerItem({required this.index, required this.child, super.key});
  @override
  State<_StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<_StaggerItem> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 260), vsync: this);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.index * 55), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ── Marquee text widget ───────────────────────────────────────────────────
class _MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  const _MarqueeText({required this.text, required this.style});

  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scroll;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startIfNeeded());
  }

  void _startIfNeeded() {
    if (!mounted) return;
    if (_scroll.hasClients &&
        _scroll.position.maxScrollExtent > 0) {
      setState(() => _needsScroll = true);
      _animate();
    }
  }

  Future<void> _animate() async {
    while (mounted && _needsScroll) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted || !_scroll.hasClients) break;
      final max = _scroll.position.maxScrollExtent;
      if (max <= 0) break;
      await _scroll.animateTo(max,
          duration: Duration(milliseconds: (max * 18).round()),
          curve: Curves.linear);
      if (!mounted) break;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_scroll.hasClients) break;
      await _scroll.animateTo(0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(widget.text, style: widget.style, maxLines: 1),
    );
  }
}
