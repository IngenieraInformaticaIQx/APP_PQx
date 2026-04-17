import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class NotaCaso {
  final String id;
  final String casoId;
  final String texto;
  final DateTime fecha;

  const NotaCaso({
    required this.id,
    required this.casoId,
    required this.texto,
    required this.fecha,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'casoId': casoId, 'texto': texto, 'fecha': fecha.toIso8601String(),
  };

  factory NotaCaso.fromJson(Map<String, dynamic> j) => NotaCaso(
    id:     j['id']    as String,
    casoId: j['casoId'] as String,
    texto:  j['texto'] as String,
    fecha:  DateTime.parse(j['fecha'] as String),
  );
}

class NotasCasoService {
  static const _key = 'notas_caso';

  static Future<List<NotaCaso>> cargar(String casoId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${_key}_$casoId') ?? '[]';
    final list = jsonDecode(raw) as List;
    return list.map((e) => NotaCaso.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
  }

  static Future<void> guardar(NotaCaso nota) async {
    final prefs = await SharedPreferences.getInstance();
    final notas = await cargar(nota.casoId);
    notas.insert(0, nota);
    await prefs.setString(
      '${_key}_${nota.casoId}',
      jsonEncode(notas.map((n) => n.toJson()).toList()),
    );
  }

  static Future<void> eliminar(String casoId, String notaId) async {
    final prefs = await SharedPreferences.getInstance();
    final notas = await cargar(casoId);
    notas.removeWhere((n) => n.id == notaId);
    await prefs.setString(
      '${_key}_$casoId',
      jsonEncode(notas.map((n) => n.toJson()).toList()),
    );
  }
}
