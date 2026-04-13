import 'dart:io';

class FCMService {
  static bool get isAvailable => !Platform.isWindows;
}