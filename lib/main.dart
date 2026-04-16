import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:untitled/services/firebase_service.dart';
import 'package:untitled/services/app_theme.dart';
import 'package:untitled/services/notificaciones_service.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.load();

  try {
    if (FirebaseService.isAvailable) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  await initNotificaciones();

  if (FirebaseService.isAvailable) {
    try {
      await initFCM();
    } catch (e) {
      debugPrint('FCM init error (ignorado en iOS): $e');
    }
  }

  runApp(const MyApp());
}

Future<void> mostrarNotificacion(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'pqx_channel',
    'PQx Notificaciones',
    channelDescription: 'Avisos de casos médicos',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
  );

  await flutterLocalNotificationsPlugin.show(
    0,
    message.notification?.title ?? 'PQx',
    message.notification?.body ?? '',
    details,
  );
}

Future<void> initFCM() async {
  if (!FirebaseService.isAvailable) return;

  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  await messaging.requestPermission();

  String? token;
  if (Platform.isIOS) {
    await Future.delayed(const Duration(seconds: 3));
  }
  token = await messaging.getToken();
  debugPrint('FCM TOKEN: $token');

  if (!Platform.isAndroid && !Platform.isIOS) return;

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('Notificación recibida: ${message.notification?.title}');
    mostrarNotificacion(message);
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.isDark,
      builder: (_, isDark, __) => MaterialApp(
        title: 'PQx - Planificación Quirúrgica',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
        ),
        darkTheme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
        ),
        themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
