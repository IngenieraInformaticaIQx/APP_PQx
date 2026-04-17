import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class AudioNotasService {
  static const _prefsKey = 'audio_notas';

  static Future<String> _dirPath() async {
    final dir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${dir.path}/audio_notas');
    if (!audioDir.existsSync()) audioDir.createSync(recursive: true);
    return audioDir.path;
  }

  static Future<String> nuevaRuta(String casoId, String id) async {
    final dir = await _dirPath();
    return '$dir/${casoId}_$id.m4a';
  }

  static Future<List<AudioNota>> cargar(String casoId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_prefsKey}_$casoId') ?? '[]';
    final list = jsonDecode(raw) as List;
    return list.map((e) => AudioNota.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  static Future<void> guardar(AudioNota nota) async {
    final prefs = await SharedPreferences.getInstance();
    final notas = await cargar(nota.casoId);
    notas.insert(0, nota);
    await prefs.setString(
      '${_prefsKey}_${nota.casoId}',
      jsonEncode(notas.map((n) => n.toJson()).toList()),
    );
  }

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
}
