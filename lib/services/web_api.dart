import 'package:flutter/foundation.dart' show kIsWeb;

class WebApi {
  static const String _baseUrl =
      'https://profesional.planificacionquirurgica.com';

  static Uri get loginUri => Uri.parse(
    kIsWeb
        ? '$_baseUrl/web_login_proxy.php'
        : '$_baseUrl/ocs/v2.php/cloud/user',
  );

  static Uri get casesUri => Uri.parse(
    kIsWeb
        ? '$_baseUrl/web_listar_casos_proxy.php'
        : '$_baseUrl/listar_casos.php',
  );

  static String connectionError(Object error) {
    if (!kIsWeb) return 'Error de conexion con el servidor';

    final text = '$error';
    if (text.contains('XMLHttpRequest') ||
        text.contains('ClientException') ||
        text.contains('Failed to fetch')) {
      return 'El navegador bloqueo la peticion por CORS. Sube los proxy Web al servidor o ejecuta la web desde el mismo dominio.';
    }
    return 'No se pudo conectar con el servidor Web.';
  }
}
