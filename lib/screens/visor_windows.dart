import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

class VisorWindows extends StatefulWidget {
  final String? url;
  final String? htmlContent;

  // Callbacks equivalentes a los JavaScriptChannels de webview_flutter
  final void Function()? onVisorReady;
  final void Function(String)? onPlateTapped;
  final void Function(String)? onScrewPlaced;
  final void Function(String)? onLog;
  final void Function(String)? onTornilloListo;
  final void Function(String)? onCapturaVista;
  final void Function(String)? onCaptura;
  final void Function(String)? onReglaLibre;
  final void Function(String)? onNotaTap;

  const VisorWindows({
    super.key,
    this.url,
    this.htmlContent,
    this.onVisorReady,
    this.onPlateTapped,
    this.onScrewPlaced,
    this.onLog,
    this.onTornilloListo,
    this.onCapturaVista,
    this.onCaptura,
    this.onReglaLibre,
    this.onNotaTap,
  }) : assert(url != null || htmlContent != null,
            'Debe proporcionar url o htmlContent');

  @override
  State<VisorWindows> createState() => VisorWindowsState();
}

class VisorWindowsState extends State<VisorWindows> {
  final _controller = WebviewController();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _controller.initialize();

    // Escuchar mensajes del JS
    _controller.webMessage.listen((dynamic raw) {
      try {
        final map = jsonDecode(raw.toString()) as Map<String, dynamic>;
        final channel = map['channel'] as String? ?? '';
        final msg     = map['msg']?.toString() ?? '';
        switch (channel) {
          case 'VisorReady':     widget.onVisorReady?.call(); break;
          case 'PlateTapped':    widget.onPlateTapped?.call(msg); break;
          case 'ScrewPlaced':    widget.onScrewPlaced?.call(msg); break;
          case 'VisorLog':       widget.onLog?.call(msg); break;
          case 'TornilloListo':  widget.onTornilloListo?.call(msg); break;
          case 'CapturaVista':   widget.onCapturaVista?.call(msg); break;
          case 'Captura':        widget.onCaptura?.call(msg); break;
          case 'ReglaLibre':     widget.onReglaLibre?.call(msg); break;
          case 'NotaTap':        widget.onNotaTap?.call(msg); break;
        }
      } catch (_) {}
    });

    if (widget.htmlContent != null) {
      await _controller.loadStringContent(widget.htmlContent!);
    } else {
      await _controller.loadUrl(widget.url!);
    }

    setState(() => _ready = true);
  }

  /// Ejecutar JavaScript en el WebView de Windows
  Future<void> runJs(String js) async {
    if (_ready) await _controller.executeScript(js);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Webview(_controller);
  }
}
