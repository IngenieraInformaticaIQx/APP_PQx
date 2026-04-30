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
import 'dart:math' as math;
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

// Fallback anatómico cuando Gemini no puede calibrar:
// coincide con los GLB base → escala 1:1 → visor carga sin reescalado.
const Map<String, dynamic> _medidasAnatomicoEstandar = {
  'tibia_longitud_mm':    154.4,
  'tibia_anchura_mm':      72.7,
  'perone_longitud_mm':   171.5,
  'perone_anchura_mm':     42.5,
  'astragalo_anchura_mm':  47.1,
  'astragalo_altura_mm':   46.4,
  'calcaneo_longitud_mm':  86.5,
  'calcaneo_altura_mm':    52.8,
  'confianza':            'baja',
  'calibrado_con_bolas':  false,
  'notas':                'Medidas anatómicas estándar (fallback sin calibración)',
  'diametro_bola_px':     0.0,
  'mm_por_px':            0.0,
};

// Rangos anatómicos aceptables (mm). Si una medida sale de aquí asumimos que
// la calibración (bola, magnificación, alucinación de la IA) está rota.
// Bordes laxos para cubrir variabilidad real (pediatría → adulto grande).
const Map<String, List<double>> _rangosAnatomicosMm = {
  'tibia_longitud_mm':    [55.0, 290.0],
  'tibia_anchura_mm':     [30.0, 110.0],
  'perone_longitud_mm':   [55.0, 290.0],
  'perone_anchura_mm':    [10.0, 65.0],
  'astragalo_anchura_mm': [22.0, 75.0],
  'astragalo_altura_mm':  [18.0, 70.0],
  'calcaneo_longitud_mm': [40.0, 125.0],
  'calcaneo_altura_mm':   [22.0, 85.0],
};

// Límite de seguridad sobre el factor de escala isotrópico final.
// Fuera de este rango asumimos error de calibración: clamp + confianza baja.
const double _factorEscalaMin = 0.65;
const double _factorEscalaMax = 1.45;

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

  // Diagnóstico estructurado: explica al cirujano de qué calidad fue la
  // medición. La UI debería mostrarlo en la confirmación previa al visor.
  // Claves típicas:
  //   - bola_cv: float, dispersión entre las 3 bolas (ideal < 0.05)
  //   - bolas_detectadas: 0..3
  //   - cv_pasadas: float, dispersión entre las 3 pasadas de Gemini
  //   - usa_lateral_calc_long: bool, calcáneo medido en lateral
  //   - discrepancias: List<String>, frontal vs lateral si difieren > 25 %
  //   - factores_escala: Map<String, double>, factor isotrópico aplicado
  //   - mm_por_px: float, escala calculada
  //   - intentos: int, pasadas válidas (1..3)
  final Map<String, dynamic> diagnostico;

  const RxProcessorResult({
    required this.glbBytes,
    required this.medidas,
    required this.confianza,
    required this.metodoEscala,
    required this.errores,
    this.diagnostico = const {},
  });
}

// ---------------------------------------------------------------------------
// SERVICIO PRINCIPAL
// ---------------------------------------------------------------------------

class RxProcessorService {
  static bool _boolFlexible(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      return s == 'true' || s == '1' || s == 'si' || s == 'sí' || s == 'yes';
    }
    return false;
  }

  static double? _numFlexible(Map<String, dynamic> raw, String key, {List<String> aliases = const []}) {
    dynamic v = raw[key];
    if (v == null) {
      for (final a in aliases) {
        if (raw[a] != null) {
          v = raw[a];
          break;
        }
      }
    }
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }
  // Punto de entrada principal.
  // Nunca lanza excepción: si Gemini falla usa medidas anatómicas estándar
  // y añade el motivo a RxProcessorResult.errores para que la UI lo muestre.
  static Future<RxProcessorResult> procesar({
    required Uint8List frontalImage,
    Uint8List? lateralImage,
    String frontalMime = 'image/jpeg',
    String lateralMime = 'image/jpeg',
  }) async {
    final errores       = <String>[];
    final diagnostico   = <String, dynamic>{};
    final stopwatch     = Stopwatch()..start();
    Map<String, dynamic>? medidas;
    String confianza    = 'desconocida';
    String metodoEscala = 'gemini_calibrado_mediana';
    Map<String, dynamic>? rawConsenso;

    // Fase 1: caché por hash de imágenes — evita repagar pasadas si el usuario
    // reentra al mismo caso o lanza el procesado dos veces seguidas.
    final cacheKey = _imageCacheKey(frontalImage, lateralImage);
    diagnostico['image_hash'] = cacheKey;

    final cached = await _leerCacheGemini(cacheKey);
    if (cached != null) {
      diagnostico['cache_hit'] = true;
      rawConsenso = cached;
    } else {
      diagnostico['cache_hit'] = false;
    }

    // Fase 2: medir con Gemini (3 pasadas en paralelo → mediana por clave).
    // Una sola pasada de un vision-LLM mide píxeles con ruido del 10-20 %;
    // la mediana de 3 colapsa la mayor parte de ese error.
    try {
      final raw = rawConsenso ?? await _medirConGeminiMediana(
        frontalImage: frontalImage,
        lateralImage: lateralImage,
        frontalMime:  frontalMime,
        lateralMime:  lateralMime,
      );
      if (raw.isNotEmpty) {
        _validarPayloadCalibracionRaw(raw);
        final mm = _medidasMmDesdePixeles(raw);
        _validarMedidasEstrictas(mm);
        _validarRangosAnatomicos(mm);   // 1ª capa: rangos absolutos por hueso
        _validarRatiosAnatomicos(mm);   // 2ª capa: proporciones inter-óseas
        confianza = (raw['confianza'] as String?) ?? 'media';
        medidas   = mm;

        if (rawConsenso == null) {
          // Sólo cacheamos si pasó todas las validaciones.
          await _escribirCacheGemini(cacheKey, raw);
        }

        diagnostico['bola_cv']                = mm['bola_cv'];
        diagnostico['bolas_detectadas']       = mm['bolas_detectadas'];
        diagnostico['mm_por_px']              = mm['mm_por_px'];
        diagnostico['usa_lateral_calc_long']  = mm['usa_lateral_calc_long'];
        diagnostico['discrepancias']          = mm['discrepancias_frontal_lateral'];
        diagnostico['notas_ia']               = raw['notas'];
      }
    } catch (e) {
      errores.add(e.toString().replaceAll('Exception: ', ''));
    }

    // Fallback anatómico: carga modelos base sin reescalado en lugar de crashear.
    if (medidas == null) {
      errores.add(
        'No se pudo medir con IA. Se cargan biomodelos base sin reescalado paciente-específico.',
      );
      medidas     = Map<String, dynamic>.from(_medidasAnatomicoEstandar);
      confianza   = 'baja';
      metodoEscala = 'anatomico_estandar';
      diagnostico['fallback'] = 'anatomico_estandar';
    }

    // Fase 3: calcular factores de escala
    final config = _calcularEscalas(medidas);
    diagnostico['factores_escala'] = {
      for (final e in config.entries) e.key: e.value[0],
    };

    // Fase 4: descargar GLBs base (con cache) y escalar
    final glbBytes = <String, Uint8List>{};

    for (final entry in config.entries) {
      final nombre = entry.key;
      final sx = entry.value[0];
      final sy = entry.value[1];
      final sz = entry.value[2];

      try {
        final baseBytes = await _obtenerGlbBase(nombre);
        glbBytes[nombre] = escalarGlb(baseBytes, sx, sy, sz);
      } catch (e) {
        errores.add('$nombre: ${e.toString().replaceAll('Exception: ', '')}');
      }
    }

    stopwatch.stop();
    diagnostico['ms_total'] = stopwatch.elapsedMilliseconds;

    return RxProcessorResult(
      glbBytes: glbBytes,
      medidas: {
        for (final e in medidas.entries)
          if (e.value is num) e.key: (e.value as num).toDouble(),
      },
      confianza:    confianza,
      metodoEscala: metodoEscala,
      errores:      errores,
      diagnostico:  diagnostico,
    );
  }

  // -------------------------------------------------------------------------
  // FASE 1 — Gemini
  // -------------------------------------------------------------------------

  // Lanza 3 mediciones en paralelo y devuelve un payload "consenso" donde
  // cada clave numérica es la mediana de los valores válidos. Reduce el
  // ruido típico de un vision-LLM (10-20 % por pasada) sin multiplicar
  // tiempo de espera (las llamadas son concurrentes).
  static Future<Map<String, dynamic>> _medirConGeminiMediana({
    required Uint8List frontalImage,
    Uint8List? lateralImage,
    required String frontalMime,
    required String lateralMime,
  }) async {
    final futuros = List.generate(3, (_) => _medirConGemini(
      frontalImage: frontalImage,
      lateralImage: lateralImage,
      frontalMime:  frontalMime,
      lateralMime:  lateralMime,
    ));

    final resultados = await Future.wait(futuros, eagerError: false);
    final validos = resultados
        .map(_normalizarPayloadGemini)
        .where((r) => r.isNotEmpty)
        .toList();

    if (validos.isEmpty) return {};
    if (validos.length == 1) return validos.first;
    return _consensoMediana(validos);
  }

  static const List<String> _clavesPx = <String>[
    'bola1_diametro_px',
    'bola2_diametro_px',
    'bola3_diametro_px',
    'diametro_bola_px',
    'tibia_longitud_px',
    'tibia_anchura_px',
    'perone_longitud_px',
    'perone_anchura_px',
    'astragalo_anchura_px',
    'astragalo_altura_px',
    'calcaneo_longitud_px',
    'calcaneo_altura_px',
    'calcaneo_longitud_lateral_px',
    'astragalo_altura_lateral_px',
    'calcaneo_altura_lateral_px',
  ];

  static Map<String, dynamic> _consensoMediana(
      List<Map<String, dynamic>> payloads) {
    final out = <String, dynamic>{};
    double maxCv = 0.0;

    for (final clave in _clavesPx) {
      final vals = <double>[];
      for (final p in payloads) {
        final v = _numFlexible(p, clave);
        if (v != null && v > 0) vals.add(v);
      }
      if (vals.isEmpty) continue;
      vals.sort();
      final mediana = vals.length.isOdd
          ? vals[vals.length ~/ 2]
          : (vals[vals.length ~/ 2 - 1] + vals[vals.length ~/ 2]) / 2.0;
      out[clave] = mediana;

      if (vals.length >= 2 && mediana > 0) {
        final media = vals.reduce((a, b) => a + b) / vals.length;
        final varianza =
            vals.map((v) => (v - media) * (v - media)).reduce((a, b) => a + b) /
                vals.length;
        final cv = math.sqrt(varianza) / media;
        if (cv > maxCv) maxCv = cv;
      }
    }

    // CV alto entre pasadas → la IA no se pone de acuerdo consigo misma.
    final String confianza;
    if (maxCv < 0.08) {
      confianza = 'alta';
    } else if (maxCv < 0.18) {
      confianza = 'media';
    } else {
      confianza = 'baja';
    }
    out['confianza'] = confianza;
    out['calibrado_con_bolas'] = true;
    out['notas'] = 'Mediana de ${payloads.length} pasadas (CV máx ${(maxCv * 100).toStringAsFixed(1)}%)';
    return out;
  }

  // Segunda capa de defensa: aunque cada hueso esté en rango, sus relaciones
  // entre sí deben ser anatómicamente plausibles. Esto pilla casos donde
  // Gemini confunde unos huesos con otros o mide la rx de un implante distinto.
  static void _validarRatiosAnatomicos(Map<String, dynamic> mm) {
    double v(String k) => (mm[k] as num).toDouble();
    final problemas = <String>[];

    void check(String etiqueta, double valor, double minR, double maxR) {
      if (valor < minR || valor > maxR) {
        problemas.add(
            '$etiqueta=${valor.toStringAsFixed(2)} fuera de [$minR, $maxR]');
      }
    }

    final tibiaLong  = v('tibia_longitud_mm');
    final tibiaAnch  = v('tibia_anchura_mm');
    final peroneLong = v('perone_longitud_mm');
    final peroneAnch = v('perone_anchura_mm');
    final calcLong   = v('calcaneo_longitud_mm');
    final calcAlt    = v('calcaneo_altura_mm');
    final astAnch    = v('astragalo_anchura_mm');
    final astAlt     = v('astragalo_altura_mm');

    check('tibia long/anch',  tibiaLong / tibiaAnch,    1.4, 5.0);
    check('calcáneo long/alt', calcLong / calcAlt,      1.0, 2.3);
    check('peroné/tibia anch', peroneAnch / tibiaAnch,  0.20, 0.95);
    check('peroné/tibia long', peroneLong / tibiaLong,  0.80, 1.25);
    check('astrágalo anch/alt', astAnch / astAlt,       0.55, 1.80);

    if (problemas.isNotEmpty) {
      throw Exception(
        'Proporciones inter-óseas implausibles: ${problemas.join('; ')}',
      );
    }
  }

  // Sanity-check anatómico: si Gemini se equivoca en la calibración (típicamente
  // por confundir un artefacto con la bola), las medidas en mm explotan.
  // Lanzar excepción aquí desencadena el fallback anatómico estándar.
  static void _validarRangosAnatomicos(Map<String, dynamic> mm) {
    final fueraDeRango = <String>[];
    _rangosAnatomicosMm.forEach((k, range) {
      final v = mm[k];
      if (v is num) {
        if (v < range[0] || v > range[1]) {
          fueraDeRango.add(
              '$k=${v.toStringAsFixed(1)}mm (fuera de ${range[0]}-${range[1]})');
        }
      }
    });
    if (fueraDeRango.isNotEmpty) {
      throw Exception(
        'Medidas fuera de rango anatómico — calibración probablemente errónea: ${fueraDeRango.join('; ')}',
      );
    }
  }

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

    final lateralBlock = lateralImage != null
        ? '''

VISTA LATERAL (segunda imagen): mide TAMBIÉN en la lateral, en píxeles:
- "calcaneo_longitud_lateral_px": longitud antero-posterior del calcáneo (esta vista es MÁS fiable que la frontal para esta medida).
- "astragalo_altura_lateral_px": altura del astrágalo en perfil.
- "calcaneo_altura_lateral_px": altura del calcáneo en perfil (debería coincidir ±10% con la frontal).

Si no logras medirlas con seguridad en la lateral, devuélvelas como 0.'''
        : '';

    final lateralFields = lateralImage != null
        ? ',"calcaneo_longitud_lateral_px":0,"astragalo_altura_lateral_px":0,"calcaneo_altura_lateral_px":0'
        : '';

    parts.add({
      'text': '''Eres un experto en análisis de radiografías de tobillo para planificación quirúrgica.

CALIBRACIÓN: En el lateral izquierdo de la imagen FRONTAL hay típicamente 3 bolas de calibración radiopacas (esferas brillantes/blancas) de diámetro exacto ${_ballDiameterMm}mm cada una.

Tu tarea respecto a las bolas:
1. Inspecciona el borde izquierdo de la radiografía buscando círculos brillantes.
2. Para CADA bola que veas con seguridad, mide su diámetro en píxeles.
3. Si NO ves las bolas, NO inventes valores: pon los diámetros a 0 y "bolas_detectadas":0.
4. Las 3 bolas son idénticas, así que sus diámetros deben coincidir entre sí (±5%).

Mide en la radiografía FRONTAL (en píxeles):
- Tibia distal: longitud visible (extremo superior visible hasta línea articular) y anchura máxima.
- Peroné distal: longitud visible y anchura máxima.
- Astrágalo: anchura máxima y altura.
- Calcáneo: longitud máxima y altura.$lateralBlock

Responde SOLO con este JSON, sin texto adicional ni markdown:
{"bola1_diametro_px":0,"bola2_diametro_px":0,"bola3_diametro_px":0,"bolas_detectadas":0,"diametro_bola_px":0,"tibia_longitud_px":0,"tibia_anchura_px":0,"perone_longitud_px":0,"perone_anchura_px":0,"astragalo_anchura_px":0,"astragalo_altura_px":0,"calcaneo_longitud_px":0,"calcaneo_altura_px":0$lateralFields,"calibrado_con_bolas":true,"confianza":"alta","notas":""}

Reglas estrictas:
- "bola1/2/3_diametro_px" valen 0 si NO ves esa bola con seguridad. NO INVENTES.
- "bolas_detectadas" = 0..3 según cuántas viste.
- "diametro_bola_px" = mediana de las bolas detectadas (>0 sólo si "bolas_detectadas" >= 2).
- "calibrado_con_bolas" = true sólo si "bolas_detectadas" >= 2.
- Las medidas de huesos deben ser >0; si no estás segura de alguna, deja 0 y baja "confianza" a "baja".'''
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
      return {}; // red/timeout; procesar() usará fallback anatómico
    }
  }

  // -------------------------------------------------------------------------
  // CACHÉ por hash de imágenes
  // -------------------------------------------------------------------------
  // Hash NO criptográfico (suficiente para identificar imágenes en disco).
  // Versionamos con _cacheVersion: si cambia el prompt o el algoritmo,
  // sube el número y los entries antiguos se ignoran.
  static const int _cacheVersion = 2;

  static String _imageCacheKey(Uint8List frontal, Uint8List? lateral) {
    int h = _cacheVersion * 0x01000193;
    h = _hashBytes(frontal, h);
    if (lateral != null) h = _hashBytes(lateral, h);
    return h.toUnsigned(32).toRadixString(16).padLeft(8, '0');
  }

  // FNV-1a sobre una muestra (no todos los bytes — para imágenes grandes
  // bastan algunas regiones representativas).
  static int _hashBytes(Uint8List data, int seed) {
    int h = seed;
    final n = data.length;
    h = _fnv1a(h, n & 0xFF);
    h = _fnv1a(h, (n >> 8) & 0xFF);
    h = _fnv1a(h, (n >> 16) & 0xFF);
    h = _fnv1a(h, (n >> 24) & 0xFF);
    final muestra = math.min(4096, n);
    for (int i = 0; i < muestra; i++) {
      h = _fnv1a(h, data[i]);
    }
    if (n > 8192) {
      for (int i = n - 4096; i < n; i++) {
        h = _fnv1a(h, data[i]);
      }
    }
    return h;
  }

  static int _fnv1a(int h, int b) {
    h = (h ^ b) & 0xFFFFFFFF;
    h = (h * 0x01000193) & 0xFFFFFFFF;
    return h;
  }

  static Future<Map<String, dynamic>?> _leerCacheGemini(String key) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/rx_gemini_$key.json');
      if (!await f.exists()) return null;
      final txt = await f.readAsString();
      final json = jsonDecode(txt);
      if (json is Map<String, dynamic>) return json;
    } catch (_) {}
    return null;
  }

  static Future<void> _escribirCacheGemini(
      String key, Map<String, dynamic> raw) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/rx_gemini_$key.json');
      await f.writeAsString(jsonEncode(raw));
    } catch (_) {}
  }

  /// Borra todas las respuestas cacheadas de Gemini. Llamar desde la UI si el
  /// cirujano quiere forzar una re-medición (p.ej. tras retomar la rx).
  static Future<int> limpiarCacheGemini() async {
    int borrados = 0;
    try {
      final dir = await getTemporaryDirectory();
      await for (final f in dir.list()) {
        final name = f.path.split(Platform.pathSeparator).last;
        if (f is File && name.startsWith('rx_gemini_') && name.endsWith('.json')) {
          try { await f.delete(); borrados++; } catch (_) {}
        }
      }
    } catch (_) {}
    return borrados;
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

  // Escala isotrópica por hueso.
  //
  // Por qué isotrópica y no anisotrópica:
  //   - Sólo tenemos 2 medidas 2D por hueso (anchura + longitud/altura).
  //   - La anchura AP de la rx no equivale ni al eje X ni al eje Z del GLB;
  //     usar el mismo factor para X y Z deformaba la sección del hueso.
  //   - Un único factor preserva la forma anatómica original (que ya viene
  //     de un escaneo correcto), aceptando que el tamaño paciente-específico
  //     es una aproximación.
  //
  // Combinación: media geométrica ponderada de los ratios disponibles.
  // Damos más peso a la dimensión más larga (mejor relación señal/ruido al
  // medir en píxeles) y clamp final dentro de un rango fisiológico.
  static Map<String, List<double>> _calcularEscalas(Map<String, dynamic> medidas) {
    double get(String key) {
      final val = medidas[key];
      if (val is num && val > 0) return val.toDouble();
      throw Exception('Medida inválida o ausente para "$key"');
    }

    double iso(double rA, double rB, {double wA = 0.7, double wB = 0.3}) {
      final f = math.pow(rA, wA) * math.pow(rB, wB);
      return f.toDouble().clamp(_factorEscalaMin, _factorEscalaMax);
    }

    final rTibLong  = get('tibia_longitud_mm')   / _glbBaseMm['tibia_longitud_mm']!;
    final rTibAnch  = get('tibia_anchura_mm')    / _glbBaseMm['tibia_anchura_mm']!;
    final rPerLong  = get('perone_longitud_mm')  / _glbBaseMm['perone_longitud_mm']!;
    final rPerAnch  = get('perone_anchura_mm')   / _glbBaseMm['perone_anchura_mm']!;
    final rAstAnch  = get('astragalo_anchura_mm') / _glbBaseMm['astragalo_anchura_mm']!;
    final rAstAlt   = get('astragalo_altura_mm')  / _glbBaseMm['astragalo_altura_mm']!;
    final rCalLong  = get('calcaneo_longitud_mm') / _glbBaseMm['calcaneo_longitud_mm']!;
    final rCalAlt   = get('calcaneo_altura_mm')   / _glbBaseMm['calcaneo_altura_mm']!;

    // Tibia / peroné: dominio claro de la longitud → peso 0.7 / 0.3.
    final fTibia  = iso(rTibLong, rTibAnch);
    final fPerone = iso(rPerLong, rPerAnch);
    // Astrágalo: ancho y alto son del mismo orden → 0.5 / 0.5.
    final fAstragalo = iso(rAstAlt, rAstAnch, wA: 0.5, wB: 0.5);
    // Calcáneo: longitud (eje AP) domina sobre altura.
    final fCalcaneo  = iso(rCalLong, rCalAlt);

    return {
      'tibia':     [fTibia,     fTibia,     fTibia],
      'perone':    [fPerone,    fPerone,    fPerone],
      'astragalo': [fAstragalo, fAstragalo, fAstragalo],
      'calcaneo':  [fCalcaneo,  fCalcaneo,  fCalcaneo],
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

  static void _validarMedidasEstrictas(Map<String, dynamic> medidas) {
    const keys = <String>[
      'tibia_longitud_mm',
      'tibia_anchura_mm',
      'perone_longitud_mm',
      'perone_anchura_mm',
      'astragalo_anchura_mm',
      'astragalo_altura_mm',
      'calcaneo_longitud_mm',
      'calcaneo_altura_mm',
    ];
    final faltantes = <String>[];
    for (final key in keys) {
      final v = medidas[key];
      if (v is! num || v <= 0) faltantes.add(key);
    }
    if (faltantes.isNotEmpty) {
      throw Exception(
        'Medidas inválidas o ausentes en respuesta IA: ${faltantes.join(', ')}',
      );
    }
  }

  static Map<String, dynamic> _medidasMmDesdePixeles(Map<String, dynamic> raw) {
    double n(String key, {List<String> aliases = const []}) {
      final v = _numFlexible(raw, key, aliases: aliases);
      if (v != null) return v;
      throw Exception('Falta "$key" en respuesta IA (aliases: ${aliases.join(', ')})');
    }

    final bolaPx = n('diametro_bola_px', aliases: const [
      'diametro_bola_pixels',
      'bola_diametro_px',
      'ball_diameter_px',
    ]);
    if (bolaPx <= 0) {
      throw Exception('Calibración inválida: diametro_bola_px <= 0');
    }
    final mmPorPx = _ballDiameterMm / bolaPx;

    // Helpers para medidas que pueden venir tanto de la frontal como de la
    // lateral. Para el calcáneo, la lateral es claramente mejor (vista
    // sagital sin solapamiento con astrágalo) → si está, la usamos.
    // Para alturas, hacemos media ponderada cuando hay 2 fuentes.
    double? optional(String key) {
      final v = _numFlexible(raw, key);
      return (v != null && v > 0) ? v * mmPorPx : null;
    }

    final calcLongFront  = optional('calcaneo_longitud_px');
    final calcLongLat    = optional('calcaneo_longitud_lateral_px');
    final calcLongMm = calcLongLat ?? calcLongFront;
    if (calcLongMm == null) {
      throw Exception('Falta calcáneo longitud en ambas vistas');
    }

    final calcAltFront = optional('calcaneo_altura_px');
    final calcAltLat   = optional('calcaneo_altura_lateral_px');
    final calcAltMm = (calcAltFront != null && calcAltLat != null)
        ? (calcAltFront + calcAltLat) / 2.0
        : (calcAltFront ?? calcAltLat);
    if (calcAltMm == null) {
      throw Exception('Falta calcáneo altura en ambas vistas');
    }

    final astAltFront = optional('astragalo_altura_px');
    final astAltLat   = optional('astragalo_altura_lateral_px');
    final astAltMm = (astAltFront != null && astAltLat != null)
        ? (astAltFront + astAltLat) / 2.0
        : (astAltFront ?? astAltLat);
    if (astAltMm == null) {
      throw Exception('Falta astrágalo altura en ambas vistas');
    }

    // Coherencia frontal vs lateral (alarma si difieren > 25 %).
    final discrepancias = <String>[];
    void chequearCoherencia(String etiqueta, double? a, double? b) {
      if (a == null || b == null) return;
      final media = (a + b) / 2.0;
      if (media <= 0) return;
      final diff = (a - b).abs() / media;
      if (diff > 0.25) {
        discrepancias.add('$etiqueta frontal=${a.toStringAsFixed(1)}mm vs '
            'lateral=${b.toStringAsFixed(1)}mm (∆${(diff * 100).toStringAsFixed(0)}%)');
      }
    }
    chequearCoherencia('calcáneo altura', calcAltFront, calcAltLat);
    chequearCoherencia('astrágalo altura', astAltFront, astAltLat);

    return {
      'tibia_longitud_mm': n('tibia_longitud_px', aliases: const ['tibia_largo_px']) * mmPorPx,
      'tibia_anchura_mm': n('tibia_anchura_px', aliases: const ['tibia_ancho_px']) * mmPorPx,
      'perone_longitud_mm': n('perone_longitud_px', aliases: const ['perone_largo_px']) * mmPorPx,
      'perone_anchura_mm': n('perone_anchura_px', aliases: const ['perone_ancho_px']) * mmPorPx,
      'astragalo_anchura_mm': n('astragalo_anchura_px', aliases: const ['astragalo_ancho_px']) * mmPorPx,
      'astragalo_altura_mm': astAltMm,
      'calcaneo_longitud_mm': calcLongMm,
      'calcaneo_altura_mm': calcAltMm,
      'confianza': raw['confianza'] ?? 'desconocida',
      'calibrado_con_bolas': _boolFlexible(raw['calibrado_con_bolas']) || bolaPx > 0,
      'notas': raw['notas'] ?? '',
      'diametro_bola_px': bolaPx,
      'mm_por_px': mmPorPx,
      'bola_cv': _numFlexible(raw, 'bola_cv'),
      'bolas_detectadas': _numFlexible(raw, 'bolas_detectadas'),
      'usa_lateral_calc_long': calcLongLat != null,
      'discrepancias_frontal_lateral': discrepancias,
    };
  }

  static void _validarPayloadCalibracionRaw(Map<String, dynamic> raw) {
    final bolaPx = (_numFlexible(raw, 'diametro_bola_px', aliases: const [
      'diametro_bola_pixels',
      'bola_diametro_px',
      'ball_diameter_px',
    ]) ?? 0);
    if (bolaPx <= 0) {
      throw Exception('La IA no midió las bolas de calibración (diametro_bola_px = 0)');
    }

    // Si tenemos diámetros individuales, deben coincidir entre sí
    // (las bolas son fabricadas idénticas).
    final bolaCv = _numFlexible(raw, 'bola_cv');
    if (bolaCv != null && bolaCv > 0.15) {
      throw Exception(
          'Las 3 bolas de calibración miden tamaños distintos (CV ${(bolaCv * 100).toStringAsFixed(1)}%) — '
          'la IA probablemente confundió artefactos con bolas');
    }
    final detectadas = _numFlexible(raw, 'bolas_detectadas');
    if (detectadas != null && detectadas < 2) {
      throw Exception(
          'IA solo detectó ${detectadas.toInt()} bolas — calibración insuficiente');
    }

    const keys = <String>[
      'tibia_longitud_px',
      'tibia_anchura_px',
      'perone_longitud_px',
      'perone_anchura_px',
      'astragalo_anchura_px',
      'astragalo_altura_px',
      'calcaneo_longitud_px',
      'calcaneo_altura_px',
    ];
    final faltantes = keys.where((k) {
      final v = _numFlexible(raw, k);
      return v == null || v <= 0;
    }).toList();
    if (faltantes.isNotEmpty) {
      throw Exception('Payload IA incompleto: ${faltantes.join(', ')}');
    }
  }

  static Map<String, dynamic> _normalizarPayloadGemini(Map<String, dynamic> raw) {
    if (raw.isEmpty) return raw;
    final out = Map<String, dynamic>.from(raw);

    dynamic pick(List<String> keys) {
      for (final k in keys) {
        if (out[k] != null) return out[k];
      }
      return null;
    }

    final medidasPx = out['medidas_px'];
    if (medidasPx is Map) {
      for (final e in medidasPx.entries) {
        out[e.key.toString()] ??= e.value;
      }
    }

    final bola = out['bola'];
    if (bola is Map) {
      out['diametro_bola_px'] ??= bola['diametro_px'] ?? bola['diametro_bola_px'];
      out['calibrado_con_bolas'] ??= bola['detectada'] ?? bola['calibrada'];
    }

    // Si la IA dio diámetros individuales por bola, derivamos un consenso.
    final bolasIndividuales = <double>[
      for (final k in const ['bola1_diametro_px',
                              'bola2_diametro_px',
                              'bola3_diametro_px'])
        if ((_numFlexible(out, k) ?? 0) > 0) _numFlexible(out, k)!,
    ];

    if (bolasIndividuales.length >= 2) {
      bolasIndividuales.sort();
      final median = bolasIndividuales.length.isOdd
          ? bolasIndividuales[bolasIndividuales.length ~/ 2]
          : (bolasIndividuales[bolasIndividuales.length ~/ 2 - 1] +
                  bolasIndividuales[bolasIndividuales.length ~/ 2]) /
              2.0;
      out['diametro_bola_px'] = median;
      out['bolas_detectadas'] = bolasIndividuales.length;

      // Coeficiente de variación entre bolas (idénticamente fabricadas).
      final media = bolasIndividuales.reduce((a, b) => a + b) /
          bolasIndividuales.length;
      final varianza = bolasIndividuales
              .map((v) => (v - media) * (v - media))
              .reduce((a, b) => a + b) /
          bolasIndividuales.length;
      out['bola_cv'] = media > 0 ? math.sqrt(varianza) / media : 1.0;
    }

    out['diametro_bola_px'] ??= pick([
      'diametro_bola_pixels',
      'bola_diametro_px',
      'ball_diameter_px',
      'diametro_bola',
      'diametro_px_bola',
    ]);

    out['tibia_longitud_px'] ??= pick(['tibia_largo_px', 'tibia_length_px']);
    out['tibia_anchura_px'] ??= pick(['tibia_ancho_px', 'tibia_width_px']);
    out['perone_longitud_px'] ??= pick(['perone_largo_px', 'perone_length_px']);
    out['perone_anchura_px'] ??= pick(['perone_ancho_px', 'perone_width_px']);
    out['astragalo_anchura_px'] ??= pick(['astragalo_ancho_px', 'astragalo_width_px']);
    out['astragalo_altura_px'] ??= pick(['astragalo_alto_px', 'astragalo_height_px']);
    out['calcaneo_longitud_px'] ??= pick(['calcaneo_largo_px', 'calcaneo_length_px']);
    out['calcaneo_altura_px'] ??= pick(['calcaneo_alto_px', 'calcaneo_height_px']);

    if (out['calibrado_con_bolas'] == null) {
      final notas = (out['notas'] ?? '').toString().toLowerCase();
      if (notas.contains('bola') && (notas.contains('calibr') || notas.contains('referencia'))) {
        out['calibrado_con_bolas'] = true;
      }
    }

    return out;
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

  while (offset < input.length) {
    final chunkLen  = data.getUint32(offset,     Endian.little);
    final chunkType = data.getUint32(offset + 4, Endian.little);
    final chunkStart = offset + 8;

    if (chunkType == 0x4E4F534A) { // JSON
      jsonChunkData = input.sublist(chunkStart, chunkStart + chunkLen);
    } else if (chunkType == 0x004E4942) { // BIN
      binChunkData = input.sublist(chunkStart, chunkStart + chunkLen);
    }
    offset += 8 + chunkLen;
  }

  if (jsonChunkData == null) throw Exception('GLB sin chunk JSON');

  // Parsear JSON del GLTF
  final gltfJson = jsonDecode(utf8.decode(jsonChunkData)) as Map<String, dynamic>;

  // Modificar vertices en el buffer binario
  if (binChunkData != null) {
    final binCopy = Uint8List.fromList(binChunkData);
    final escaladoVertices = _escalarVertices(gltfJson, binCopy, sx, sy, sz);
    if (!escaladoVertices) {
      // Fallback: algunos GLB no exponen POSITION float32 escalable.
      // En ese caso, aplicar escala a nivel de nodo para que el modelo sí cambie.
      _escalarViaNodo(gltfJson, sx, sy, sz);
    }

    // Reconstruir GLB con JSON actualizado y bin modificado
    final jsonModificado = utf8.encode(jsonEncode(gltfJson));
    return _reconstruirGlb(Uint8List.fromList(jsonModificado), binCopy);
  }

  // Si no hay buffer binario, aplicar escala via nodo (fallback)
  _escalarViaNodo(gltfJson, sx, sy, sz);
  final jsonModificado = utf8.encode(jsonEncode(gltfJson));
  return _reconstruirGlb(Uint8List.fromList(jsonModificado), null);
}

bool _escalarVertices(
  Map<String, dynamic> gltf,
  Uint8List binData,
  double sx, double sy, double sz,
) {
  int? asInt(dynamic v) => v is num ? v.toInt() : null;
  final accessors   = gltf['accessors']   as List<dynamic>? ?? [];
  final bufferViews = gltf['bufferViews'] as List<dynamic>? ?? [];

  // Recopilar IDs de accessors POSITION
  final posIds = <int>{};
  for (final mesh in gltf['meshes'] as List<dynamic>? ?? []) {
    for (final prim in (mesh as Map)['primitives'] as List<dynamic>? ?? []) {
      final attrs = (prim as Map)['attributes'] as Map<dynamic, dynamic>?;
      if (attrs != null && attrs.containsKey('POSITION')) {
        final posId = asInt(attrs['POSITION']);
        if (posId != null) posIds.add(posId);
      }
    }
  }

  final binView = ByteData.sublistView(binData);
  var escaladoAlMenosUno = false;

  for (final accId in posIds) {
    if (accId < 0 || accId >= accessors.length) continue;
    final acc  = accessors[accId] as Map<dynamic, dynamic>;
    if (acc['type'] != 'VEC3') continue;
    if (asInt(acc['componentType']) != 5126) continue; // 5126 = FLOAT

    final count   = asInt(acc['count']);
    final bvId    = asInt(acc['bufferView']);
    if (count == null || count <= 0 || bvId == null) continue;
    if (bvId < 0 || bvId >= bufferViews.length) continue;
    final bv      = bufferViews[bvId] as Map<dynamic, dynamic>;
    final base    = (asInt(bv['byteOffset']) ?? 0) + (asInt(acc['byteOffset']) ?? 0);
    final stride  = asInt(bv['byteStride']) ?? 12; // 3 * 4 bytes

    for (int i = 0; i < count; i++) {
      final off = base + i * stride;
      if (off < 0 || off + 11 >= binData.length) break;
      final x = binView.getFloat32(off,      Endian.little);
      final y = binView.getFloat32(off + 4,  Endian.little);
      final z = binView.getFloat32(off + 8,  Endian.little);
      binView.setFloat32(off,     x * sx, Endian.little);
      binView.setFloat32(off + 4, y * sy, Endian.little);
      binView.setFloat32(off + 8, z * sz, Endian.little);
      escaladoAlMenosUno = true;
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
  return escaladoAlMenosUno;
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
