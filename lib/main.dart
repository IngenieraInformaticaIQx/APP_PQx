import 'app_bootstrap_mobile.dart'
    if (dart.library.html) 'app_bootstrap_web.dart'
    as app;

Future<void> main() => app.bootstrap();
