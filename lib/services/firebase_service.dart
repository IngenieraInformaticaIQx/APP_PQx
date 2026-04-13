import 'dart:io';

class FirebaseService {
  static bool get isAvailable => !Platform.isWindows;
}