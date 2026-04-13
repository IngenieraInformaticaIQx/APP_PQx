import 'package:flutter/material.dart';
import 'menu_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:untitled/services/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final emailController    = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading       = false;
  String? errorMessage;
  bool _obscurePassword = true;
  bool _rememberMe      = false;

  late AnimationController _bgController;
  late AnimationController _orb1;
  late AnimationController _orb2;
  late AnimationController _formController;
  late Animation<double>  _formFade;
  late Animation<Offset>  _formSlide;

  // ── Paleta idéntica al resto de la app ────────────────────────────────────
  static const Color _accent   = Color(0xFF2A7FF5);

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);

    _bgController = AnimationController(
        duration: const Duration(seconds: 60), vsync: this)..repeat();

    _orb1 = AnimationController(
        duration: const Duration(seconds: 9), vsync: this)..repeat(reverse: true);
    _orb2 = AnimationController(
        duration: const Duration(seconds: 13), vsync: this)..repeat(reverse: true);

    _formController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _formFade  = CurvedAnimation(parent: _formController, curve: Curves.easeOut);
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(CurvedAnimation(parent: _formController, curve: Curves.easeOutCubic));

    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs   = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;

    if (remember) {
      final email = prefs.getString('login_email') ?? '';
      final pass  = prefs.getString('login_password') ?? '';
      if (email.isNotEmpty && pass.isNotEmpty) {
        if (mounted) {
          await _guardarTokenEnServidor();
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const MenuScreen()));
          return;
        }
      }
      setState(() {
        emailController.text    = email;
        passwordController.text = pass;
        _rememberMe             = remember;
      });
    }

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _formController.forward();
    });
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    emailController.dispose();
    passwordController.dispose();
    _bgController.dispose();
    _orb1.dispose();
    _orb2.dispose();
    _formController.dispose();
    super.dispose();
  }

  Future<void> _guardarTokenEnServidor() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await http.post(
        Uri.parse('https://profesional.planificacionquirurgica.com/guardar_token.php'),
        body: {'token': token},
      );
    } catch (_) {}
  }

  void _login() async {
    setState(() { _isLoading = true; errorMessage = null; });

    final email = emailController.text.trim();
    final pass  = passwordController.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() { _isLoading = false; errorMessage = 'Rellena todos los campos'; });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://profesional.planificacionquirurgica.com/ocs/v2.php/cloud/user'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$email:$pass'))}',
          'OCS-APIRequest': 'true',
        },
      );

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('login_email', email);
        await prefs.setString('login_password', pass);
        await prefs.setBool('remember_me', _rememberMe);
        await _guardarTokenEnServidor();
        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const MenuScreen()));
        }
      } else {
        setState(() { errorMessage = 'Usuario o contraseña incorrectos'; });
      }
    } catch (_) {
      setState(() { errorMessage = 'Error de conexión con el servidor'; });
    }

    setState(() { _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final _bgTop    = AppTheme.bgTop;
    final _bgBottom = AppTheme.bgBottom;
    final _dark     = AppTheme.darkText;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgTop,
      body: Stack(children: [

        // ── Fondo degradado ────────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_bgTop, _bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        // ── Orbe azul arriba derecha ───────────────────────────────────────
        AnimatedBuilder(animation: _orb1, builder: (_, __) {
          final t = Curves.easeInOut.transform(_orb1.value);
          return Positioned(
            top: -80 + t * 50, right: -70 + t * 30,
            child: Container(
              width: 340, height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  _accent.withOpacity(0.15),
                  const Color(0xFF5BA8FF).withOpacity(0.05),
                  Colors.transparent,
                ], stops: const [0.0, 0.5, 1.0]),
              ),
            ),
          );
        }),

        // ── Orbe lila abajo izquierda ──────────────────────────────────────
        AnimatedBuilder(animation: _orb2, builder: (_, __) {
          final t = Curves.easeInOut.transform(_orb2.value);
          return Positioned(
            bottom: -60 + t * 55, left: -80 + t * 28,
            child: Container(
              width: 290, height: 290,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFF8E44AD).withOpacity(0.11),
                  Colors.transparent,
                ]),
              ),
            ),
          );
        }),

        // ── Orbe fijo giratorio fondo ──────────────────────────────────────
        Positioned(
          top: -60, right: -50,
          child: AnimatedBuilder(
            animation: _bgController,
            builder: (_, __) => Transform.rotate(
              angle: _bgController.value * 2 * math.pi,
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _accent.withOpacity(0.07),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),
          ),
        ),

        // ── Formulario ────────────────────────────────────────────────────
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: FadeTransition(
                    opacity: _formFade,
                    child: SlideTransition(
                      position: _formSlide,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          // Logo glass
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                                child: Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      AppTheme.cardBg1,
                                      AppTheme.cardBg2,
                                    ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                        color: AppTheme.cardBorder, width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _accent.withOpacity(0.13),
                                        blurRadius: 32, offset: const Offset(0, 8)),
                                      BoxShadow(color: AppTheme.cardGlowWhite, blurRadius: 0),
                                    ],
                                  ),
                                  child: Image.asset(
                                      AppTheme.isDark.value
                                          ? 'assets/images/logo2.png'
                                          : 'assets/images/logo.png',
                                      width: 110, height: 110, fit: BoxFit.contain),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Título
                          Text('Acceso',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _dark,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5)),
                          const SizedBox(height: 4),
                          Text('Planificación Quirúrgica',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: _accent.withOpacity(0.75),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),

                          const SizedBox(height: 28),

                          // Tarjeta glass del formulario
                          ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [
                                    AppTheme.cardBg1,
                                    AppTheme.cardBg2,
                                    _accent.withOpacity(0.04),
                                  ], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.circular(26),
                                  border: Border.all(
                                      color: AppTheme.cardBorder, width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _accent.withOpacity(0.10),
                                      blurRadius: 30, offset: const Offset(0, 10),
                                      spreadRadius: -4),
                                    BoxShadow(color: AppTheme.cardGlowWhite, blurRadius: 0),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [

                                    // Campo usuario
                                    _buildField(
                                      controller: emailController,
                                      label: 'Usuario',
                                      icon: Icons.person_outline_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                    const SizedBox(height: 14),

                                    // Campo contraseña
                                    _buildField(
                                      controller: passwordController,
                                      label: 'Contraseña',
                                      icon: Icons.lock_outline_rounded,
                                      obscureText: _obscurePassword,
                                      isPassword: true,
                                    ),
                                    const SizedBox(height: 16),

                                    // Recuérdame
                                    GestureDetector(
                                      onTap: () => setState(() => _rememberMe = !_rememberMe),
                                      child: Row(children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 180),
                                          width: 22, height: 22,
                                          decoration: BoxDecoration(
                                            color: _rememberMe
                                                ? _accent
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: _rememberMe
                                                  ? _accent
                                                  : AppTheme.handleColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: _rememberMe
                                              ? const Icon(Icons.check_rounded,
                                                  size: 15, color: Colors.white)
                                              : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Text('Recuérdame',
                                            style: TextStyle(
                                                color: _dark.withOpacity(0.65),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500)),
                                      ]),
                                    ),

                                    const SizedBox(height: 16),

                                    // Error
                                    if (errorMessage != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.07),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                                color: Colors.red.withOpacity(0.22)),
                                          ),
                                          child: Row(children: [
                                            Icon(Icons.error_outline_rounded,
                                                color: Colors.red.withOpacity(0.7), size: 18),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(errorMessage!,
                                                  style: TextStyle(
                                                      color: Colors.red.withOpacity(0.75),
                                                      fontSize: 13)),
                                            ),
                                          ]),
                                        ),
                                      ),

                                    // Botón entrar
                                    SizedBox(
                                      height: 52,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [_accent, const Color(0xFF5BA8FF)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _accent.withOpacity(0.35),
                                              blurRadius: 18,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(16)),
                                          ),
                                          child: _isLoading
                                              ? const SizedBox(width: 22, height: 22,
                                                  child: CircularProgressIndicator(
                                                      color: Colors.white, strokeWidth: 2.5))
                                              : const Text('Entrar',
                                                  style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: 0.3)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // ¿Olvidaste la contraseña?
                          TextButton(
                            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text(
                                  'Contacta con PQx para crear un acceso o recuperar contraseña')),
                            ),
                            child: Text('¿No tienes acceso u olvidaste la contraseña?',
                                style: TextStyle(
                                    color: _dark.withOpacity(0.45),
                                    fontSize: 13),
                                textAlign: TextAlign.center),
                          ),

                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Campo de texto glass ──────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    bool isPassword  = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final dark = AppTheme.darkText;
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: (_) => _login(),
      textInputAction: TextInputAction.done,
      style: TextStyle(color: dark, fontSize: 15),
      cursorColor: _accent,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: dark.withOpacity(0.45), fontSize: 14),
        prefixIcon: Icon(icon, color: _accent.withOpacity(0.70), size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: dark.withOpacity(0.35), size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
        filled: true,
        fillColor: AppTheme.cardBg2,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.handleColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _accent.withOpacity(0.60), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
