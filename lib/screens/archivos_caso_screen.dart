import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:untitled/services/app_theme.dart';
import 'package:untitled/services/notas_caso_service.dart';
import 'visor_caso_screen.dart';
import 'visor_pdf_screen.dart';

class ArchivosCasoScreen extends StatefulWidget {
  final CasoMedico caso;
  const ArchivosCasoScreen({super.key, required this.caso});

  @override
  State<ArchivosCasoScreen> createState() => _ArchivosCasoScreenState();
}

class _ArchivosCasoScreenState extends State<ArchivosCasoScreen>
    with TickerProviderStateMixin {

  static const _apiBase = 'https://profesional.planificacionquirurgica.com';
  static const _accent  = Color(0xFF8E44AD);

  late AnimationController _bgCtrl;
  late AnimationController _headerCtrl;
  late Animation<double>   _headerFade;
  late Animation<Offset>   _headerSlide;

  List<_Archivo>  _archivos = [];
  List<NotaCaso>  _notas    = [];
  bool   _loading = true;
  String? _error;
  String _credentials = '';

  void _onThemeChanged() { if (mounted) setState(() {}); }

  @override
  void initState() {
    super.initState();
    AppTheme.isDark.addListener(_onThemeChanged);

    _bgCtrl = AnimationController(duration: const Duration(seconds: 60), vsync: this)..repeat();

    _headerCtrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _headerFade  = CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOut);
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _headerCtrl, curve: Curves.easeOutCubic));
    _headerCtrl.forward();

    _cargar();
    _cargarNotas();
  }

  @override
  void dispose() {
    AppTheme.isDark.removeListener(_onThemeChanged);
    _bgCtrl.dispose();
    _headerCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarNotas() async {
    final notas = await NotasCasoService.cargar(widget.caso.id);
    if (mounted) setState(() => _notas = notas);
  }

  Future<void> _nuevaNota() async {
    final texto = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (_) => const _NuevaNotaDialog(),
    );

    if (texto != null && texto.isNotEmpty && mounted) {
      final nota = NotaCaso(
        id:     const Uuid().v4(),
        casoId: widget.caso.id,
        texto:  texto,
        fecha:  DateTime.now(),
      );
      await NotasCasoService.guardar(nota);
      if (mounted) await _cargarNotas();
    }
  }

  Future<void> _eliminarNota(NotaCaso nota) async {
    await NotasCasoService.eliminar(widget.caso.id, nota.id);
    await _cargarNotas();
  }

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}  '
      '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';

  String? _derivarCarpeta() {
    final todosGlb = [
      ...widget.caso.biomodelos,
      ...widget.caso.placas.expand((g) => g.placas),
      ...widget.caso.tornillos.expand((g) => g.tornillos),
    ];
    if (todosGlb.isEmpty) return null;
    final uri = Uri.parse(todosGlb.first.url);
    final segments = uri.pathSegments;
    if (segments.length < 2) return null;
    final casoRelPath = segments.take(segments.length - 2).join('/');
    return '$casoRelPath/archivos';
  }

  Future<void> _cargar() async {
    setState(() { _loading = true; _error = null; });

    final carpeta = _derivarCarpeta();
    if (carpeta == null) {
      setState(() { _loading = false; _error = 'No se pudo determinar la carpeta del caso.'; });
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final email    = prefs.getString('login_email')    ?? '';
    final password = prefs.getString('login_password') ?? '';
    _credentials = base64Encode(utf8.encode('$email:$password'));

    final carpetaParam = Uri.encodeComponent(carpeta);
    final url = '$_apiBase/listar_archivos.php?carpeta=$carpetaParam';

    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Basic $_credentials'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 404) {
        setState(() { _error = 'Endpoint no encontrado (404).\nSube listar_archivos.php al servidor.'; _loading = false; });
        return;
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        setState(() { _error = 'Sin permisos (${resp.statusCode}). Comprueba las credenciales.'; _loading = false; });
        return;
      }
      if (resp.statusCode != 200) {
        setState(() { _error = 'Error del servidor (${resp.statusCode}).'; _loading = false; });
        return;
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        setState(() { _error = 'Respuesta inválida del servidor.\nComprueba listar_archivos.php.'; _loading = false; });
        return;
      }

      final lista = (data['archivos'] as List? ?? [])
          .map((e) => _Archivo.fromJson(e as Map<String, dynamic>))
          .toList();
      setState(() { _archivos = lista; _loading = false; });

    } on Exception catch (e) {
      setState(() { _error = 'Error de conexión:\n$e'; _loading = false; });
    }
  }

  Future<void> _abrirArchivo(_Archivo archivo) async {
    if (!mounted) return;

    // Usamos rootNavigator para que pop() cierre siempre el diálogo
    // independientemente del estado del widget
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.sheetBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text('Descargando...', style: TextStyle(color: AppTheme.darkText, fontSize: 13)),
            ]),
          ),
        ),
      ),
    );

    void cerrarDialogo() {
      // rootNavigator: true garantiza que cerramos el diálogo y no la pantalla
      Navigator.of(context, rootNavigator: true).pop();
    }

    try {
      final resp = await http.get(
        Uri.parse(archivo.url),
        headers: {'Authorization': 'Basic $_credentials'},
      ).timeout(const Duration(seconds: 20));

      cerrarDialogo();
      if (!mounted) return;

      if (resp.statusCode != 200) {
        _mostrarError('Error ${resp.statusCode} al descargar.');
        return;
      }

      final tmpDir  = await getTemporaryDirectory();
      final ext     = archivo.nombre.contains('.')
          ? archivo.nombre.split('.').last.toLowerCase() : '';
      final tmpFile = File('${tmpDir.path}/${const Uuid().v4()}.$ext');
      await tmpFile.writeAsBytes(resp.bodyBytes);
      if (!mounted) return;

      if (ext == 'pdf') {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => VisorPdfScreen(rutaLocal: tmpFile.path, nombre: archivo.nombre),
        ));
      } else if (ext == 'txt') {
        // Decodificar directo de bytes para evitar problemas de encoding en disco
        final texto = _decodificarTexto(resp.bodyBytes);
        if (!mounted) return;
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => _VisorTextoScreen(texto: texto, nombre: archivo.nombre),
        ));
      } else {
        _mostrarError('Formato .$ext no compatible con el visor.');
      }
    } catch (e) {
      cerrarDialogo();
      if (mounted) _mostrarError('Error al descargar: $e');
    }
  }

  // Intenta UTF-8, si falla usa latin1 (cubre la mayoría de TXTs de Windows)
  String _decodificarTexto(List<int> bytes) {
    try {
      return const Utf8Decoder().convert(bytes);
    } catch (_) {
      return String.fromCharCodes(bytes); // latin1 fallback
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      duration: const Duration(seconds: 4),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.bgTop, AppTheme.bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        Positioned(
          top: -80, right: -60,
          child: AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => Transform.rotate(
              angle: _bgCtrl.value * 2 * math.pi,
              child: Container(
                width: 280, height: 280,
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

        SafeArea(
          child: Column(children: [

            SlideTransition(
              position: _headerSlide,
              child: FadeTransition(
                opacity: _headerFade,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Row(children: [
                    _glassIconBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Archivos',
                            style: TextStyle(color: AppTheme.darkText, fontSize: 26,
                                fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                        Text(widget.caso.nombre,
                            style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
                      ]),
                    ),
                    _glassIconBtn(Icons.refresh_rounded, _cargar),
                    const SizedBox(width: 8),
                    _glassIconBtn(Icons.sticky_note_2_outlined, _nuevaNota),
                  ]),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
          ]),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: _accent, strokeWidth: 2.5),
          const SizedBox(height: 16),
          Text('Cargando archivos...', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 14)),
        ]),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.08),
                border: Border.all(color: Colors.red.withOpacity(0.18)),
              ),
              child: Icon(Icons.error_outline, color: Colors.red.withOpacity(0.6), size: 30),
            ),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: AppTheme.subtitleColor, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            _glassIconBtn(Icons.refresh_rounded, _cargar),
          ]),
        ),
      );
    }

    if (_archivos.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withOpacity(0.07),
              border: Border.all(color: _accent.withOpacity(0.15)),
            ),
            child: Icon(Icons.folder_open_outlined, color: _accent.withOpacity(0.4), size: 32),
          ),
          const SizedBox(height: 16),
          Text('Sin archivos compartidos',
              style: TextStyle(color: AppTheme.darkText, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Sube archivos a la carpeta "archivos/" del caso en el servidor.',
              style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12),
              textAlign: TextAlign.center),
        ]),
      );
    }

    final pdfs  = _archivos.where((a) => a.tipo == 'pdf').toList();
    final imgs  = _archivos.where((a) => a.tipo == 'imagen').toList();
    final otros = _archivos.where((a) => a.tipo == 'otro').toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [

        _sectionLabel('Notas del caso', Icons.sticky_note_2_outlined, _accent),
        const SizedBox(height: 10),
        if (_notas.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg1,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(children: [
                Icon(Icons.add_circle_outline, size: 16, color: _accent.withOpacity(0.5)),
                const SizedBox(width: 10),
                Text('Pulsa el icono de nota para añadir',
                    style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
              ]),
            ),
          )
        else
          ..._notas.map((n) => _notaTile(n)),

        const SizedBox(height: 20),

        if (_archivos.isEmpty)
          Column(children: [
            _sectionLabel('Archivos', Icons.folder_open_outlined, AppTheme.subtitleColor),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.cardBg1,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(children: [
                Icon(Icons.cloud_off_outlined, size: 16, color: AppTheme.subtitleColor.withOpacity(0.5)),
                const SizedBox(width: 10),
                Expanded(child: Text('Sin archivos en el servidor',
                    style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12))),
              ]),
            ),
          ]),

        if (pdfs.isNotEmpty) ...[
          _sectionLabel('Documentos PDF', Icons.picture_as_pdf_rounded, const Color(0xFFE53935)),
          const SizedBox(height: 10),
          ...pdfs.map((a) => _archivoTile(a)),
          const SizedBox(height: 20),
        ],
        if (imgs.isNotEmpty) ...[
          _sectionLabel('Imágenes', Icons.image_outlined, const Color(0xFF2A7FF5)),
          const SizedBox(height: 10),
          _imageGrid(imgs),
          const SizedBox(height: 20),
        ],
        if (otros.isNotEmpty) ...[
          _sectionLabel('Otros archivos', Icons.insert_drive_file_outlined, AppTheme.subtitleColor),
          const SizedBox(height: 10),
          ...otros.map((a) => _archivoTile(a)),
        ],
      ],
    );
  }

  Widget _notaTile(NotaCaso nota) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: _accent.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _accent.withOpacity(0.18)),
        ),
        child: Stack(children: [
          Positioned(
            left: 0, top: 8, bottom: 8,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
                color: _accent.withOpacity(0.6),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 40, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nota.texto,
                  style: TextStyle(color: AppTheme.darkText, fontSize: 13, height: 1.4)),
              const SizedBox(height: 5),
              Text(_fmtFecha(nota.fecha),
                  style: TextStyle(color: AppTheme.subtitleColor, fontSize: 10)),
            ]),
          ),
          Positioned(
            right: 6, top: 6,
            child: GestureDetector(
              onTap: () => _eliminarNota(nota),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.cardBg1,
                ),
                child: Icon(Icons.close, size: 13, color: AppTheme.subtitleColor),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: AppTheme.darkText, fontSize: 13,
          fontWeight: FontWeight.w700, letterSpacing: -0.2)),
    ]);
  }

  // Sin BackdropFilter
  Widget _archivoTile(_Archivo archivo) {
    final isPdf = archivo.tipo == 'pdf';
    final color = isPdf ? const Color(0xFFE53935) : AppTheme.subtitleColor;
    final icon  = isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_outlined;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _abrirArchivo(archivo),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardBg1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(0.1),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(archivo.nombre,
                  style: TextStyle(color: AppTheme.darkText, fontSize: 13,
                      fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new_rounded, size: 16, color: AppTheme.subtitleColor),
          ]),
        ),
      ),
    );
  }

  Widget _imageGrid(List<_Archivo> imgs) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8,
      ),
      itemCount: imgs.length,
      itemBuilder: (_, i) {
        final img = imgs[i];
        return GestureDetector(
          onTap: () => _verImagen(img),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(fit: StackFit.expand, children: [
              Image.network(
                img.url,
                headers: {'Authorization': 'Basic $_credentials'},
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.cardBg1,
                  child: Icon(Icons.broken_image_outlined, color: AppTheme.subtitleColor),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(color: AppTheme.cardBg1,
                      child: Center(child: CircularProgressIndicator(
                          color: _accent, strokeWidth: 2,
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null)));
                },
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Text(img.nombre,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center),
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  void _verImagen(_Archivo img) {
    Navigator.push(context, MaterialPageRoute(
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          Hero(
            tag: img.url,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 6.0,
              child: SizedBox.expand(
                child: Image.network(
                  img.url,
                  headers: {'Authorization': 'Basic $_credentials'},
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                      const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 64)),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
        ]),
      ),
    ));
  }

  // Sin BackdropFilter
  Widget _glassIconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.lockedCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder, width: 1.2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, color: AppTheme.darkText, size: 18),
      ),
    );
  }
}

class _Archivo {
  final String nombre;
  final String url;
  final String tipo; // 'pdf' | 'imagen' | 'otro'

  const _Archivo({required this.nombre, required this.url, required this.tipo});

  factory _Archivo.fromJson(Map<String, dynamic> j) => _Archivo(
    nombre: j['nombre'] as String? ?? '',
    url:    j['url']    as String? ?? '',
    tipo:   j['tipo']   as String? ?? 'otro',
  );
}

// ── Visor de texto plano ────────────────────────────────────────────────────
class _VisorTextoScreen extends StatelessWidget {
  final String texto;
  final String nombre;
  const _VisorTextoScreen({required this.texto, required this.nombre});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgTop,
      appBar: AppBar(
        backgroundColor: AppTheme.bgTop,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.lockedCardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Icon(Icons.arrow_back_ios_new, color: AppTheme.darkText, size: 16),
          ),
        ),
        title: Text(nombre,
            style: TextStyle(color: AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis),
      ),
      body: texto.isEmpty
          ? Center(child: Text('Archivo vacío', style: TextStyle(color: AppTheme.subtitleColor)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg1,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Text(texto,
                    style: TextStyle(color: AppTheme.darkText, fontSize: 13, height: 1.6)),
              ),
            ),
    );
  }
}

// ── Dialog de nueva nota como StatefulWidget independiente ──────────────────
// El TextEditingController vive en su propio State y se dispone en dispose(),
// evitando que se llame dispose() mientras el árbol de widgets aún lo referencia.
class _NuevaNotaDialog extends StatefulWidget {
  const _NuevaNotaDialog();

  @override
  State<_NuevaNotaDialog> createState() => _NuevaNotaDialogState();
}

class _NuevaNotaDialogState extends State<_NuevaNotaDialog> {
  static const _accent = Color(0xFF8E44AD);
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.sheetBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.sheetBorder, width: 1.5),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(children: [
        const Icon(Icons.sticky_note_2_outlined, size: 16, color: _accent),
        const SizedBox(width: 8),
        Text('Nueva nota', style: TextStyle(
            color: AppTheme.darkText, fontSize: 15, fontWeight: FontWeight.w800)),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.close, size: 18, color: AppTheme.subtitleColor),
        ),
      ]),
      content: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg1,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: TextField(
          controller: _ctrl,
          autofocus: true,
          maxLines: 4,
          minLines: 3,
          style: TextStyle(color: AppTheme.darkText, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Escribe tu nota...',
            hintStyle: TextStyle(color: AppTheme.subtitleColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: GestureDetector(
            onTap: () {
              final t = _ctrl.text.trim();
              if (t.isNotEmpty) Navigator.pop(context, t);
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_accent, Color(0xFFBE90D4)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: Text('Guardar nota',
                    style: TextStyle(color: Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
