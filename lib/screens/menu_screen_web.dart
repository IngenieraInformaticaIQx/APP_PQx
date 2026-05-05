import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/screens/login_screen.dart';
import 'package:untitled/services/app_theme.dart';
import 'package:untitled/services/web_api.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenWebState();
}

class _MenuScreenWebState extends State<MenuScreen> {
  String _userEmail = '';

  static const List<_WebMenuItem> _items = [
    _WebMenuItem(
      icon: Icons.view_in_ar_rounded,
      title: 'Catalogo 3D',
      subtitle:
          'Disponible en la app nativa. Requiere adaptar visor 3D para navegador.',
      color: Color(0xFF2A7FF5),
      route: _WebRoute.placeholder,
    ),
    _WebMenuItem(
      icon: Icons.manage_accounts_outlined,
      title: 'Nuevo caso',
      subtitle: 'Captura RX y procesado local permanecen en la version nativa.',
      color: Color(0xFF8E44AD),
      route: _WebRoute.placeholder,
    ),
    _WebMenuItem(
      icon: Icons.biotech,
      title: 'Mis Casos',
      subtitle: 'Consulta los casos asignados desde el servidor.',
      color: Color(0xFF34A853),
      route: _WebRoute.cases,
    ),
    _WebMenuItem(
      icon: Icons.assignment_outlined,
      title: 'Mis planificaciones',
      subtitle:
          'Las planificaciones locales dependen de archivos del dispositivo.',
      color: Color(0xFFE8840A),
      route: _WebRoute.placeholder,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted)
      setState(() => _userEmail = prefs.getString('login_email') ?? '');
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('login_email');
    await prefs.remove('login_password');
    await prefs.setBool('remember_me', false);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _open(_WebMenuItem item) {
    if (item.route == _WebRoute.cases) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const _WebCasesScreen()),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _WebPlaceholderScreen(item: item)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 820;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.bgTop, AppTheme.bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    wide ? 34 : 18,
                    22,
                    wide ? 34 : 18,
                    12,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 54,
                        height: 54,
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PQx',
                              style: TextStyle(
                                color: AppTheme.darkText,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              _userEmail.isEmpty ? 'Sesion activa' : _userEmail,
                              style: TextStyle(color: AppTheme.subtitleColor),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tema',
                        onPressed: AppTheme.toggle,
                        icon: Icon(
                          AppTheme.isDark.value
                              ? Icons.light_mode
                              : Icons.dark_mode,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Cerrar sesion',
                        onPressed: _logout,
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 34 : 18,
                  12,
                  wide ? 34 : 18,
                  28,
                ),
                sliver: SliverGrid.builder(
                  itemCount: _items.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: wide ? 4 : 1,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: wide ? 0.95 : 2.65,
                  ),
                  itemBuilder: (_, index) => _WebMenuCard(
                    item: _items[index],
                    onTap: () => _open(_items[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebCasesScreen extends StatefulWidget {
  const _WebCasesScreen();

  @override
  State<_WebCasesScreen> createState() => _WebCasesScreenState();
}

class _WebCasesScreenState extends State<_WebCasesScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cases = const [];

  @override
  void initState() {
    super.initState();
    _loadCases();
  }

  Future<void> _loadCases() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('login_email') ?? '';
      final pass = prefs.getString('login_password') ?? '';
      final response = await http
          .post(WebApi.casesUri, body: {'usuario': email, 'password': pass})
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        setState(() {
          _error = 'Error HTTP ${response.statusCode}';
          _loading = false;
        });
        return;
      }

      final decoded = json.decode(response.body);
      final data = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      if (data['success'] != true) {
        setState(() {
          _error = '${data['message'] ?? 'No se pudieron cargar los casos'}';
          _loading = false;
        });
        return;
      }

      final rawCases = data['casos'];
      setState(() {
        _cases = rawCases is List
            ? rawCases
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : const [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = WebApi.connectionError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _WebPageShell(
      title: 'Mis Casos',
      action: IconButton(
        tooltip: 'Actualizar',
        onPressed: _loadCases,
        icon: const Icon(Icons.refresh),
      ),
      child: Builder(
        builder: (_) {
          if (_loading) return const Center(child: CircularProgressIndicator());
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _GlassBox(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFE8840A),
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.darkText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadCases,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          if (_cases.isEmpty) {
            return Center(
              child: Text(
                'No hay casos disponibles',
                style: TextStyle(color: AppTheme.subtitleColor),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: _cases.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) => _CaseRow(data: _cases[index]),
          );
        },
      ),
    );
  }
}

class _WebPlaceholderScreen extends StatelessWidget {
  const _WebPlaceholderScreen({required this.item});

  final _WebMenuItem item;

  @override
  Widget build(BuildContext context) {
    return _WebPageShell(
      title: item.title,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: _GlassBox(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 54, color: item.color),
                  const SizedBox(height: 16),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.darkText,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.subtitleColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebPageShell extends StatelessWidget {
  const _WebPageShell({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.bgTop, AppTheme.bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Volver',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: AppTheme.darkText,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (action != null) action!,
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _WebMenuCard extends StatelessWidget {
  const _WebMenuCard({required this.item, required this.onTap});

  final _WebMenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
            gradient: LinearGradient(
              colors: [item.color.withOpacity(0.18), AppTheme.cardBg1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: item.color, size: 32),
                const Spacer(),
                Text(
                  item.title,
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppTheme.subtitleColor, height: 1.35),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerRight,
                  child: Icon(Icons.arrow_forward),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CaseRow extends StatelessWidget {
  const _CaseRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final id = _text(data['id']);
    final name = _text(data['nombre']);
    final patient = _text(data['paciente']);
    final state = _text(data['estado']);
    final date = _text(data['fecha_op']);
    return _GlassBox(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.biotech_outlined, color: _stateColor(state), size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? id : name,
                  style: TextStyle(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (patient.isNotEmpty) patient,
                    if (date.isNotEmpty) date,
                    if (id.isNotEmpty) id,
                  ].join(' - '),
                  style: TextStyle(color: AppTheme.subtitleColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Chip(label: Text(state.isEmpty ? 'pendiente' : state)),
        ],
      ),
    );
  }
}

class _GlassBox extends StatelessWidget {
  const _GlassBox({
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppTheme.cardBg1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

enum _WebRoute { placeholder, cases }

class _WebMenuItem {
  const _WebMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final _WebRoute route;
}

String _text(dynamic value) => value == null ? '' : '$value'.trim();

Color _stateColor(String state) {
  switch (state) {
    case 'validado':
    case 'enviado':
      return const Color(0xFF34A853);
    case 'modificado':
      return const Color(0xFFE8840A);
    case 'firmado':
      return const Color(0xFF2A7FF5);
    default:
      return const Color(0xFF6969DD);
  }
}
