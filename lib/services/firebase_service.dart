import 'dart:io';

/// Utilidad para comprobar si Firebase está disponible en la plataforma actual.
///
/// Firebase solo está operativo en Android, iOS y macOS.
/// En Windows y Web se usan stubs para evitar errores de compilación.
class FirebaseService {
  /// Devuelve true si Firebase puede inicializarse en esta plataforma.
  static bool get isAvailable => !Platform.isWindows;
}