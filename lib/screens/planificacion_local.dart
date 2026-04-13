import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// ── Tipos ─────────────────────────────────────────────────────────────────────

enum TipoVisor { tabal, varval, radiografia }

enum EstadoIA { ninguno, pendiente, procesando, listo, error }

// ── Zonas ─────────────────────────────────────────────────────────────────────

class ZonaImplante {
  final String id;
  final String nombre;
  final String icono;

  const ZonaImplante({
    required this.id,
    required this.nombre,
    required this.icono,
  });
}

const List<ZonaImplante> kZonasImplante = [
  ZonaImplante(id: 'tobillo',   nombre: 'Tobillo',           icono: ''),
  ZonaImplante(id: 'rodilla',   nombre: 'Rodilla',           icono: ''),
  ZonaImplante(id: 'cadera',    nombre: 'Cadera',            icono: ''),
  ZonaImplante(id: 'columna',   nombre: 'Columna vertebral', icono: ''),
  ZonaImplante(id: 'hombro',    nombre: 'Hombro',            icono: ''),
  ZonaImplante(id: 'muneca',    nombre: 'Muñeca / Mano',     icono: ''),
  ZonaImplante(id: 'codo',      nombre: 'Codo',              icono: ''),
  ZonaImplante(id: 'pie',       nombre: 'Pie / Metatarso',   icono: ''),
  ZonaImplante(id: 'otro',      nombre: 'Otro',              icono: '⚕'),
];

// ── Modelo ────────────────────────────────────────────────────────────────────

class PlanificacionLocal {
  final String id;
  final String nombrePaciente;
  final String notas;
  final DateTime fechaCirugia;
  final String zonaImplanteId;
  final TipoVisor tipoVisor;

  final String? fotoPath;          // frontal
  final String? fotoLateralPath;   // 👈 NUEVO

  final EstadoIA estadoIA;
  final String? modeloUrl;
  final DateTime fechaCreacion;

  PlanificacionLocal({
    required this.id,
    required this.nombrePaciente,
    required this.notas,
    required this.fechaCirugia,
    required this.zonaImplanteId,
    required this.tipoVisor,
    this.fotoPath,
    this.fotoLateralPath, // 👈 NUEVO
    this.estadoIA = EstadoIA.ninguno,
    this.modeloUrl,
    required this.fechaCreacion,
  });

  // ── JSON ───────────────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombrePaciente': nombrePaciente,
    'notas': notas,
    'fechaCirugia': fechaCirugia.toIso8601String(),
    'zonaImplanteId': zonaImplanteId,
    'tipoVisor': tipoVisor.name,
    'fotoPath': fotoPath,
    'fotoLateralPath': fotoLateralPath, // 👈 NUEVO
    'estadoIA': estadoIA.name,
    'modeloUrl': modeloUrl,
    'fechaCreacion': fechaCreacion.toIso8601String(),
  };

  factory PlanificacionLocal.fromJson(Map<String, dynamic> j) {
    return PlanificacionLocal(
      id: j['id'] as String,
      nombrePaciente: j['nombrePaciente'] as String,
      notas: j['notas'] as String? ?? '',
      fechaCirugia: DateTime.parse(j['fechaCirugia'] as String),
      zonaImplanteId: j['zonaImplanteId'] as String,
      tipoVisor: TipoVisor.values.firstWhere(
            (e) => e.name == j['tipoVisor'],
        orElse: () => TipoVisor.tabal,
      ),
      fotoPath: j['fotoPath'] as String?,
      fotoLateralPath: j['fotoLateralPath'] as String?, // 👈 NUEVO
      estadoIA: EstadoIA.values.firstWhere(
            (e) => e.name == j['estadoIA'],
        orElse: () => EstadoIA.ninguno,
      ),
      modeloUrl: j['modeloUrl'] as String?,
      fechaCreacion: DateTime.parse(j['fechaCreacion'] as String),
    );
  }

  PlanificacionLocal copyWith({
    String? nombrePaciente,
    String? notas,
    DateTime? fechaCirugia,
    String? zonaImplanteId,
    TipoVisor? tipoVisor,
    String? fotoPath,
    String? fotoLateralPath, // 👈 NUEVO
    EstadoIA? estadoIA,
    String? modeloUrl,
  }) {
    return PlanificacionLocal(
      id: id,
      nombrePaciente: nombrePaciente ?? this.nombrePaciente,
      notas: notas ?? this.notas,
      fechaCirugia: fechaCirugia ?? this.fechaCirugia,
      zonaImplanteId: zonaImplanteId ?? this.zonaImplanteId,
      tipoVisor: tipoVisor ?? this.tipoVisor,
      fotoPath: fotoPath ?? this.fotoPath,
      fotoLateralPath: fotoLateralPath ?? this.fotoLateralPath, // 👈 NUEVO
      estadoIA: estadoIA ?? this.estadoIA,
      modeloUrl: modeloUrl ?? this.modeloUrl,
      fechaCreacion: fechaCreacion,
    );
  }

  // ── Helpers UI ─────────────────────────────────────────────────────────────

  String get zonaLabel =>
      kZonasImplante.firstWhere(
            (z) => z.id == zonaImplanteId,
        orElse: () => kZonasImplante.last,
      ).nombre;

  String get zonaIcono =>
      kZonasImplante.firstWhere(
            (z) => z.id == zonaImplanteId,
        orElse: () => kZonasImplante.last,
      ).icono;

  String get visorLabel {
    switch (tipoVisor) {
      case TipoVisor.tabal:
        return 'Visor Tabal';
      case TipoVisor.varval:
        return 'Visor Varval';
      case TipoVisor.radiografia:
        return 'Desde radiografía';
    }
  }
}

// ── Repository ────────────────────────────────────────────────────────────────

class PlanificacionRepository {
  static const _key = 'planificaciones_locales';

  static Future<List<PlanificacionLocal>> cargarTodas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];

    return raw
        .map((s) {
      try {
        return PlanificacionLocal.fromJson(
          json.decode(s) as Map<String, dynamic>,
        );
      } catch (_) {
        return null;
      }
    })
        .whereType<PlanificacionLocal>()
        .toList()
      ..sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
  }

  static Future<void> guardar(PlanificacionLocal plan) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await cargarTodas();

    final idx = lista.indexWhere((p) => p.id == plan.id);

    if (idx >= 0) {
      lista[idx] = plan;
    } else {
      lista.insert(0, plan);
    }

    await prefs.setStringList(
      _key,
      lista.map((p) => json.encode(p.toJson())).toList(),
    );
  }

  static Future<void> eliminar(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final lista = await cargarTodas();

    lista.removeWhere((p) => p.id == id);

    await prefs.setStringList(
      _key,
      lista.map((p) => json.encode(p.toJson())).toList(),
    );
  }
}