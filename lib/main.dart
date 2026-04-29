import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/services/app_theme.dart';
import 'package:untitled/services/firebase_service.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel pqxChannel = AndroidNotificationChannel(
  'pqx_channel',
  'PQx Notificaciones',
  description: 'Avisos de casos medicos',
  importance: Importance.max,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (FirebaseService.isAvailable) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }
  }
  await mostrarNotificacion(message);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.load();

  if (FirebaseService.isAvailable) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }
  }

  await initNotificaciones();

  if (FirebaseService.isAvailable) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await initFCM();
    } catch (e) {
      debugPrint('FCM init error (ignorado en iOS): $e');
    }
  }

  runApp(const MyApp());
}

Future<void> initNotificaciones() async {
  const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const InitializationSettings settings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(settings);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(pqxChannel);
}

Future<void> mostrarNotificacion(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'pqx_channel',
    'PQx Notificaciones',
    channelDescription: 'Avisos de casos medicos',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const NotificationDetails details = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(),
  );

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    message.notification?.title ?? 'PQx',
    message.notification?.body ?? '',
    details,
  );
}

Future<void> initFCM() async {
  if (!FirebaseService.isAvailable) return;

  final FirebaseMessaging messaging = FirebaseMessaging.instance;

  try {
    await messaging.requestPermission().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('FCM requestPermission error: $e');
    return;
  }

  String? token;
  try {
    if (Platform.isIOS) {
      await Future.delayed(const Duration(seconds: 3));
    }
    token = await messaging.getToken().timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('FCM getToken error: $e');
  }
  debugPrint('FCM TOKEN: $token');

  messaging.onTokenRefresh.listen((newToken) {
    debugPrint('FCM TOKEN REFRESH: $newToken');
    registrarTokenRefrescado(newToken);
  });

  if (!Platform.isAndroid && !Platform.isIOS) return;

  await messaging.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    debugPrint('Notificacion recibida en foreground: ${message.notification?.title}');
    await mostrarNotificacion(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    debugPrint('Notificacion abierta desde background');
  });
}

Future<void> registrarTokenRefrescado(String token) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final email = (prefs.getString('login_email') ?? '').trim();
    if (email.isEmpty) return;
    final grupo = email.contains('@') ? email.split('@').first.trim() : email;
    if (grupo.isEmpty) return;

    await http.post(
      Uri.parse('https://profesional.planificacionquirurgica.com/guardar_token.php'),
      body: {'grupo': grupo, 'token': token},
    );
  } catch (_) {}
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppTheme.isDark,
      builder: (_, isDark, __) => MaterialApp(
        title: 'PQx - Planificacion Quirurgica',
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
