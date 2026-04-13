import 'package:firebase_messaging/firebase_messaging.dart';

class FCMServiceImpl {
  static Future<void> init() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    String? token = await messaging.getToken();
    print('FCM TOKEN: $token');

    FirebaseMessaging.onMessage.listen((message) {
      print('Notificación: ${message.notification?.title}');
    });
  }
}