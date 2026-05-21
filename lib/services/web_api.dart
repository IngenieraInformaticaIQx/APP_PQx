import 'package:flutter/foundation.dart' show kIsWeb;

/// Centraliza las URLs del backend y la detección de errores de red.
///
/// En web se usan proxies PHP para evitar restricciones CORS del navegador.
/// En mobile/desktop se llama directamente al servidor con Basic Auth.
class WebApi {
  static const String _baseUrl =
      'https://profesional.planificacionquirurgica.com';

  /// URI de login: proxy en web, OCS directo en mobile/desktop.
  static Uri get loginUri => Uri.parse(
    kIsWeb
        ? '$_baseUrl/web_login_proxy.php'
        : '$_baseUrl/ocs/v2.php/cloud/user',
  );

  /// URI para listar casos: proxy en web, endpoint directo en mobile/desktop.
  static Uri get casesUri => Uri.parse(
    kIsWeb
        ? '$_baseUrl/web_listar_casos_proxy.php'
        : '$_baseUrl/listar_casos.php',
  );

  /// Devuelve un mensaje de error legible para el usuario.
  /// En web distingue errores CORS de otros errores de red.
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
