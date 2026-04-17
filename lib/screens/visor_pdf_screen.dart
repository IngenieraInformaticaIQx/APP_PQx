import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:untitled/services/app_theme.dart';

class VisorPdfScreen extends StatefulWidget {
  final String rutaLocal;
  final String nombre;

  const VisorPdfScreen({
    super.key,
    required this.rutaLocal,
    required this.nombre,
  });

  @override
  State<VisorPdfScreen> createState() => _VisorPdfScreenState();
}

class _VisorPdfScreenState extends State<VisorPdfScreen> {
  int  _paginas      = 0;
  int  _paginaActual = 0;
  bool _listo        = false;
  String? _errorMsg;
  PDFViewController? _ctrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [

        // Fondo
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.bgTop, AppTheme.bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        SafeArea(
          child: Column(children: [

            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(children: [
                _glassBtn(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.nombre,
                    style: TextStyle(
                        color: AppTheme.darkText,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_paginas > 0)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg1,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Text(
                          '${_paginaActual + 1} / $_paginas',
                          style: TextStyle(
                              color: AppTheme.subtitleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),

            // ── PDF viewer ────────────────────────────────────────────────
            Expanded(
              child: _errorMsg != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.picture_as_pdf_outlined,
                            size: 48, color: Colors.redAccent.withOpacity(0.6)),
                        const SizedBox(height: 16),
                        Text(_errorMsg!,
                            style: TextStyle(color: AppTheme.subtitleColor, fontSize: 13),
                            textAlign: TextAlign.center),
                      ]),
                    ),
                  )
                : Stack(children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: PDFView(
                    filePath: widget.rutaLocal,
                    enableSwipe: true,
                    swipeHorizontal: false,
                    autoSpacing: true,
                    pageFling: true,
                    fitPolicy: FitPolicy.BOTH,
                    onRender: (pages) {
                      if (mounted) setState(() { _paginas = pages ?? 0; _listo = true; });
                    },
                    onViewCreated: (ctrl) => _ctrl = ctrl,
                    onPageChanged: (page, _) {
                      if (mounted) setState(() => _paginaActual = page ?? 0);
                    },
                    onError: (e) {
                      debugPrint('PDF error: $e');
                      if (mounted) setState(() => _errorMsg = 'No se pudo cargar el PDF.\n$e');
                    },
                    onPageError: (page, e) {
                      if (mounted) setState(() => _errorMsg = 'Error en página $page.\n$e');
                    },
                  ),
                ),
                if (!_listo)
                  Center(
                    child: CircularProgressIndicator(
                        color: const Color(0xFF2A7FF5), strokeWidth: 2.5),
                  ),
              ]),  // Stack
            ),    // Expanded
          ]),
        ),
      ]),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.lockedCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder, width: 1.2),
            ),
            child: Icon(icon, color: AppTheme.darkText, size: 18),
          ),
        ),
      ),
    );
  }
}
