import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modelo de datos para una nota de audio vinculada a un caso quirúrgico.
/// Se serializa a JSON y se persiste en SharedPreferences.
class AudioNota {
  final String id;
  final String casoId;
  final String path;
  final DateTime fecha;
  final int duracionSegundos;

  const AudioNota({
    required this.id,
    required this.casoId,
    required this.path,
    required this.fecha,
    required this.duracionSegundos,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'casoId': casoId,
    'path': path,
    'fecha': fecha.toIso8601String(),
    'duracion': duracionSegundos,
  };

  factory AudioNota.fromJson(Map<String, dynamic> j) => AudioNota(
    id: j['id'] as String,
    casoId: j['casoId'] as String,
    path: j['path'] as String,
    fecha: DateTime.parse(j['fecha'] as String),
    duracionSegundos: j['duracion'] as int? ?? 0,
  );
}

/// Servicio estático para gestionar notas de audio por caso.
///
/// Los metadatos se persisten en SharedPreferences bajo la clave
/// `audio_notas_{casoId}`. Los archivos de audio (.m4a) se almacenan
/// en el directorio de documentos de la app via [path_provider].
class AudioNotasService {
  static const _prefsKey = 'audio_notas';

  /// Devuelve la ruta al directorio de audio, creándolo si no existe.
  static Future<String> _dirPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/audio_notas');
    if (!audioDir.existsSync()) audioDir.createSync(recursive: true);
    return audioDir.path;
  }

  /// Genera la ruta completa para un nuevo archivo de audio de un caso.
  static Future<String> nuevaRuta(String casoId, String id) async {
    final dir = await _dirPath();
    return '$dir/${casoId}_$id.m4a';
  }

  /// Carga todas las notas de audio de un caso, ordenadas por fecha descendente.
  static Future<List<AudioNota>> cargar(String casoId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_prefsKey}_$casoId') ?? '[]';
    final list = jsonDecode(raw) as List;
    return list.map((e) => AudioNota.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  /// Inserta una nueva nota al principio de la lista y persiste en SharedPreferences.
  static Future<void> guardar(AudioNota nota) async {
    final prefs = await SharedPreferences.getInstance();
    final notas = await cargar(nota.casoId);
    notas.insert(0, nota);
    await prefs.setString(
      '${_prefsKey}_${nota.casoId}',
      jsonEncode(notas.map((n) => n.toJson()).toList()),
    );
  }

  /// Elimina la nota de SharedPreferences y borra el archivo de audio del disco.
  static Future<void> eliminar(AudioNota nota) async {
    final prefs = await SharedPreferences.getInstance();
    final notas = await cargar(nota.casoId);
    notas.removeWhere((n) => n.id == nota.id);
    await prefs.setString(
      '${_prefsKey}_${nota.casoId}',
      jsonEncode(notas.map((n) => n.toJson()).toList()),
    );
    final file = File(nota.path);
    if (file.existsSync()) file.deleteSync();
  }

  /// Elimina todas las notas y archivos de audio de un caso completo.
  static Future<void> eliminarSesion(String casoId) async {
    final prefs = await SharedPreferences.getInstance();
    final notas = await cargar(casoId);
    for (final nota in notas) {
      final file = File(nota.path);
      if (file.existsSync()) file.deleteSync();
    }
    await prefs.remove('${_prefsKey}_$casoId');
  }
}
