// rx_processor_service.dart
//
// Procesamiento completo en la app (sin backend):
//   1. Llama a Gemini con las fotos -> obtiene medidas en mm
//   2. Descarga los GLB base desde el servidor (cache local)
//   3. Escala los GLB modificando vertices float32 directamente en Dart
//      (requiere GLBs SIN compresion Draco)
//   4. Devuelve Uint8List por hueso, listo para model_viewer_plus
//
// Dependencias a añadir en pubspec.yaml:
//   http: ^1.2.0
//   path_provider: ^2.1.0

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ---------------------------------------------------------------------------
// CONFIGURACION — ajusta estas constantes
// ---------------------------------------------------------------------------

const String _geminiApiKey =
    'AIzaSyDPTaPXw3SR9NjjQ0uGzS0WpDpSzKBMaUk'; // muevela a .env en produccion

const String _geminiUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/'
    'gemini-2.0-flash:generateContent?key=$_geminiApiKey';

const double _ballDiameterMm = 9.98;

// Medidas reales de los modelos GLB base (en mm)
const Map<String, double> _glbBaseMm = {
  'tibia_longitud_mm':    154.4,
  'tibia_anchura_mm':      72.7,
  'perone_longitud_mm':   171.5,
  'perone_anchura_mm':     42.5,
  'astragalo_anchura_mm':  47.1,
  'astragalo_altura_mm':   46.4,
  'calcaneo_longitud_mm':  86.5,
  'calcaneo_altura_mm':    52.8,
};

// URLs publicas de los GLB base en tu servidor (archivos estaticos, sin Draco)
const Map<String, String> _glbUrls = {
  'tibia':
      'https://profesional.planificacionquirurgica.com/3D/Tabal/Biomodelo/Tibia.glb',
  'perone':
      'https://profesional.planificacionquirurgica.com/3D/Tabal/Biomodelo/Perone.glb',
  'astragalo':
      'https://profesional.planificacionquirurgica.com/3D/Tabal/Biomodelo/Astragalo.glb',
  'calcaneo':
      'https://profesional.planificacionquirurgica.com/3D/Tabal/Biomodelo/Calcaneo.glb',
};

// ---------------------------------------------------------------------------
// RESULTADO
// ---------------------------------------------------------------------------

class RxProcessorResult {
  final Map<String, Uint8List> glbBytes; // clave: 'tibia' | 'perone' | 'astragalo' | 'calcaneo'
  final Map<String, double> medidas;
  final String confianza;
  final String metodoEscala;
  final List<String> errores;

  const RxProcessorResult({
    required this.glbBytes,
    required this.medidas,
    required this.confianza,
    required this.metodoEscala,
    required this.errores,
  });
}

// ---------------------------------------------------------------------------
// SERVICIO PRINCIPAL
// ---------------------------------------------------------------------------

class RxProcessorService {
  // Punto de entrada principal
  // frontalImage: bytes de la foto frontal (jpg/png)
  // lateralImage: bytes de la foto lateral (opcional)
  static Future<RxProcessorResult> procesar({
    required Uint8List frontalImage,
    Uint8List? lateralImage,
    String frontalMime = 'image/jpeg',
    String lateralMime = 'image/jpeg',
  }) async {
    // Fase 1: medir huesos con Gemini
    final medidas = await _medirConGemini(
      frontalImage: frontalImage,
      lateralImage: lateralImage,
      frontalMime: frontalMime,
      lateralMime: lateralMime,
    );

    final confianza = medidas['confianza'] as String? ?? 'referencia';

    // Fase 2: calcular factores de escala
    final config = _calcularEscalas(medidas);

    // Fase 3: descargar GLBs base (con cache) y escalar
    final glbBytes = <String, Uint8List>{};
    final errores   = <String>[];

    for (final entry in config.entries) {
      final nombre = entry.key;
      final sx = entry.value[0];
      final sy = entry.value[1];
      final sz = entry.value[2];

      try {
        final baseBytes = await _obtenerGlbBase(nombre);
        final escalado  = escalarGlb(baseBytes, sx, sy, sz);
        glbBytes[nombre] = escalado;
      } catch (e) {
        errores.add('$nombre: $e');
      }
    }

    return RxProcessorResult(
      glbBytes:     glbBytes,
      medidas:      medidas.cast<String, double>()
          ..removeWhere((k, v) => k == 'confianza' || k == 'notas'),
      confianza:    confianza,
      metodoEscala: 'gemini_directo',
      errores:      errores,
    );
  }

  // -------------------------------------------------------------------------
  // FASE 1 — Gemini
  // -------------------------------------------------------------------------

  static Future<Map<String, dynamic>> _medirConGemini({
    required Uint8List frontalImage,
    Uint8List? lateralImage,
    required String frontalMime,
    required String lateralMime,
  }) async {
    final parts = <Map<String, dynamic>>[];

    parts.add({
      'inline_data': {
        'mime_type': frontalMime,
        'data': base64Encode(frontalImage),
      }
    });

    if (lateralImage != null) {
      parts.add({
        'inline_data': {
          'mime_type': lateralMime,
          'data': base64Encode(lateralImage),
        }
      });
    }

    parts.add({
      'text': '''Eres un experto en analisis de radiografias de tobillo para planificacion quirurgica.

La imagen tiene 3 bolas de calibracion blancas (diametro exacto ${_ballDiameterMm}mm) en el lateral izquierdo.
Usaelas para calcular la escala en mm/pixel.
Si no puedes verlas claramente, usa proporciones anatomicas estandar de adulto.

Mide en la radiografia FRONTAL:
- Tibia distal: longitud visible (superior hasta linea articular) y anchura maxima
- Perone distal: longitud visible y anchura maxima
- Astragalo: anchura maxima y altura
- Calcaneo: longitud maxima y altura

${lateralImage != null ? 'Usa la vista LATERAL para confirmar proporciones si es util.' : ''}

Responde SOLO con este JSON, sin texto adicional ni markdown:
{"tibia_longitud_mm":0,"tibia_anchura_mm":0,"perone_longitud_mm":0,"perone_anchura_mm":0,"astragalo_anchura_mm":0,"astragalo_altura_mm":0,"calcaneo_longitud_mm":0,"calcaneo_altura_mm":0,"confianza":"media","notas":""}'''
    });

    try {
      final response = await http.post(
        Uri.parse(_geminiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': parts}],
          'generationConfig': {'temperature': 0.1, 'maxOutputTokens': 512},
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception('Gemini error ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);
      final texto = data['candidates'][0]['content']['parts'][0]['text'] as String;
      return _extraerJson(texto);
    } catch (e) {
      // Si Gemini falla, devolvemos mapa vacio -> se usaran referencias anatomicas
      return {};
    }
  }

  static Map<String, dynamic> _extraerJson(String texto) {
    // Intentar parseo directo
    try {
      return jsonDecode(texto) as Map<String, dynamic>;
    } catch (_) {}

    // Buscar bloque ```json ... ```
    final re1 = RegExp(r'```(?:json)?\s*(\{.*?\})\s*```', dotAll: true);
    final m1  = re1.firstMatch(texto);
    if (m1 != null) {
      try { return jsonDecode(m1.group(1)!) as Map<String, dynamic>; } catch (_) {}
    }

    // Buscar cualquier { ... }
    final re2 = RegExp(r'\{.*\}', dotAll: true);
    final m2  = re2.firstMatch(texto);
    if (m2 != null) {
      try { return jsonDecode(m2.group(0)!) as Map<String, dynamic>; } catch (_) {}
    }

    return {};
  }

  // -------------------------------------------------------------------------
  // FASE 2 — Calcular factores de escala
  // -------------------------------------------------------------------------

  static Map<String, List<double>> _calcularEscalas(Map<String, dynamic> medidas) {
    double get(String key) {
      final val = medidas[key];
      if (val is num && val > 0) return val.toDouble();
      return _glbBaseMm[key]!; // fallback a referencia anatomica
    }

    return {
      'tibia': [
        get('tibia_anchura_mm')  / _glbBaseMm['tibia_anchura_mm']!,
        get('tibia_longitud_mm') / _glbBaseMm['tibia_longitud_mm']!,
        get('tibia_anchura_mm')  / _glbBaseMm['tibia_anchura_mm']!,
      ],
      'perone': [
        get('perone_anchura_mm')  / _glbBaseMm['perone_anchura_mm']!,
        get('perone_longitud_mm') / _glbBaseMm['perone_longitud_mm']!,
        get('perone_anchura_mm')  / _glbBaseMm['perone_anchura_mm']!,
      ],
      'astragalo': [
        get('astragalo_anchura_mm') / _glbBaseMm['astragalo_anchura_mm']!,
        get('astragalo_altura_mm')  / _glbBaseMm['astragalo_altura_mm']!,
        get('astragalo_anchura_mm') / _glbBaseMm['astragalo_anchura_mm']!,
      ],
      'calcaneo': [
        get('calcaneo_longitud_mm') / _glbBaseMm['calcaneo_longitud_mm']!,
        get('calcaneo_altura_mm')   / _glbBaseMm['calcaneo_altura_mm']!,
        get('calcaneo_longitud_mm') / _glbBaseMm['calcaneo_longitud_mm']!,
      ],
    };
  }

  // -------------------------------------------------------------------------
  // FASE 3 — Cache de GLBs base
  // -------------------------------------------------------------------------

  static Future<Uint8List> _obtenerGlbBase(String nombre) async {
    // Intentar desde cache local primero
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/glb_base_$nombre.glb');
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (_) {}

    // Descargar desde servidor
    final url = _glbUrls[nombre]!;
    final response = await http.get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Error descargando $nombre: ${response.statusCode}');
    }

    final bytes = response.bodyBytes;

    // Guardar en cache
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/glb_base_$nombre.glb');
      await file.writeAsBytes(bytes);
    } catch (_) {}

    return bytes;
  }
}

// ---------------------------------------------------------------------------
// ESCALADO GLB EN DART PURO
// Formato GLB:
//   [12 bytes header] [chunk0: JSON] [chunk1: BIN]
// Modificamos los atributos POSITION (VEC3 float32) en el buffer binario.
// ---------------------------------------------------------------------------

Uint8List escalarGlb(Uint8List input, double sx, double sy, double sz) {
  final data = ByteData.sublistView(input);

  // Validar magic 'glTF'
  final magic = data.getUint32(0, Endian.little);
  if (magic != 0x46546C67) throw Exception('No es un GLB valido');

  // Leer chunks
  int offset = 12;
  Uint8List? jsonChunkData;
  Uint8List? binChunkData;
  int jsonChunkOffset = -1;
  int binChunkOffset  = -1;

  while (offset < input.length) {
    final chunkLen  = data.getUint32(offset,     Endian.little);
    final chunkType = data.getUint32(offset + 4, Endian.little);
    final chunkStart = offset + 8;

    if (chunkType == 0x4E4F534A) { // JSON
      jsonChunkData   = input.sublist(chunkStart, chunkStart + chunkLen);
      jsonChunkOffset = chunkStart;
    } else if (chunkType == 0x004E4942) { // BIN
      binChunkData   = input.sublist(chunkStart, chunkStart + chunkLen);
      binChunkOffset = chunkStart;
    }
    offset += 8 + chunkLen;
  }

  if (jsonChunkData == null) throw Exception('GLB sin chunk JSON');

  // Parsear JSON del GLTF
  final gltfJson = jsonDecode(utf8.decode(jsonChunkData)) as Map<String, dynamic>;

  // Modificar vertices en el buffer binario
  if (binChunkData != null) {
    final binCopy = Uint8List.fromList(binChunkData);
    _escalarVertices(gltfJson, binCopy, sx, sy, sz);

    // Reconstruir GLB con el bin modificado
    return _reconstruirGlb(jsonChunkData, binCopy);
  }

  // Si no hay buffer binario, aplicar escala via nodo (fallback)
  _escalarViaNodo(gltfJson, sx, sy, sz);
  final jsonModificado = utf8.encode(jsonEncode(gltfJson));
  return _reconstruirGlb(Uint8List.fromList(jsonModificado), null);
}

void _escalarVertices(
  Map<String, dynamic> gltf,
  Uint8List binData,
  double sx, double sy, double sz,
) {
  final accessors   = gltf['accessors']   as List<dynamic>? ?? [];
  final bufferViews = gltf['bufferViews'] as List<dynamic>? ?? [];

  // Recopilar IDs de accessors POSITION
  final posIds = <int>{};
  for (final mesh in gltf['meshes'] as List<dynamic>? ?? []) {
    for (final prim in (mesh as Map)['primitives'] as List<dynamic>? ?? []) {
      final attrs = (prim as Map)['attributes'] as Map<dynamic, dynamic>?;
      if (attrs != null && attrs.containsKey('POSITION')) {
        posIds.add(attrs['POSITION'] as int);
      }
    }
  }

  final binView = ByteData.sublistView(binData);

  for (final accId in posIds) {
    final acc  = accessors[accId] as Map<dynamic, dynamic>;
    if (acc['type'] != 'VEC3') continue;
    if (acc['componentType'] != 5126) continue; // 5126 = FLOAT

    final count   = acc['count'] as int;
    final bvId    = acc['bufferView'] as int;
    final bv      = bufferViews[bvId] as Map<dynamic, dynamic>;
    final base    = (bv['byteOffset'] as int? ?? 0) + (acc['byteOffset'] as int? ?? 0);
    final stride  = bv['byteStride'] as int? ?? 12; // 3 * 4 bytes

    for (int i = 0; i < count; i++) {
      final off = base + i * stride;
      final x = binView.getFloat32(off,      Endian.little);
      final y = binView.getFloat32(off + 4,  Endian.little);
      final z = binView.getFloat32(off + 8,  Endian.little);
      binView.setFloat32(off,     x * sx, Endian.little);
      binView.setFloat32(off + 4, y * sy, Endian.little);
      binView.setFloat32(off + 8, z * sz, Endian.little);
    }

    // Actualizar min/max del accessor
    if (acc['min'] != null) {
      final mn = acc['min'] as List<dynamic>;
      acc['min'] = [(mn[0] as num) * sx, (mn[1] as num) * sy, (mn[2] as num) * sz];
    }
    if (acc['max'] != null) {
      final mx = acc['max'] as List<dynamic>;
      acc['max'] = [(mx[0] as num) * sx, (mx[1] as num) * sy, (mx[2] as num) * sz];
    }
  }
}

void _escalarViaNodo(
  Map<String, dynamic> gltf,
  double sx, double sy, double sz,
) {
  final nodes  = gltf['nodes']  as List<dynamic>? ?? [];
  final scenes = gltf['scenes'] as List<dynamic>? ?? [];
  final sceneIdx  = gltf['scene'] as int? ?? 0;
  final rootNodes = sceneIdx < scenes.length
      ? ((scenes[sceneIdx] as Map)['nodes'] as List<dynamic>? ?? [])
      : (nodes.isNotEmpty ? [0] : []);

  for (final ni in rootNodes) {
    final node = nodes[ni as int] as Map<dynamic, dynamic>;
    node.remove('matrix');
    final old = (node['scale'] as List<dynamic>?) ?? [1.0, 1.0, 1.0];
    node['scale'] = [
      (old[0] as num) * sx,
      (old[1] as num) * sy,
      (old[2] as num) * sz,
    ];
  }
}

Uint8List _reconstruirGlb(Uint8List jsonBytes, Uint8List? binBytes) {
  // Padding JSON a multiplo de 4 con espacios
  final jsonPadded = _padTo4(jsonBytes, 0x20);
  // Padding BIN a multiplo de 4 con ceros
  final binPadded  = binBytes != null ? _padTo4(binBytes, 0x00) : null;

  final totalLength = 12
      + 8 + jsonPadded.length
      + (binPadded != null ? 8 + binPadded.length : 0);

  final out = ByteData(totalLength);
  int pos = 0;

  // Header
  out.setUint32(pos,     0x46546C67, Endian.little); pos += 4; // magic 'glTF'
  out.setUint32(pos,     2,          Endian.little); pos += 4; // version
  out.setUint32(pos,     totalLength, Endian.little); pos += 4;

  // Chunk JSON
  out.setUint32(pos,     jsonPadded.length, Endian.little); pos += 4;
  out.setUint32(pos,     0x4E4F534A,        Endian.little); pos += 4; // 'JSON'
  for (final b in jsonPadded) { out.setUint8(pos++, b); }

  // Chunk BIN
  if (binPadded != null) {
    out.setUint32(pos, binPadded.length, Endian.little); pos += 4;
    out.setUint32(pos, 0x004E4942,       Endian.little); pos += 4; // 'BIN\0'
    for (final b in binPadded) { out.setUint8(pos++, b); }
  }

  return out.buffer.asUint8List();
}

Uint8List _padTo4(Uint8List data, int padByte) {
  final rem = data.length % 4;
  if (rem == 0) return data;
  final result = Uint8List(data.length + (4 - rem));
  result.setAll(0, data);
  result.fillRange(data.length, result.length, padByte);
  return result;
}
