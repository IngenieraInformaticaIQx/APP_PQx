import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:untitled/services/app_theme.dart';

/// Widget de menú contextual del visor 3D mostrado como overlay flotante.
///
/// Contiene un hero animado con scanner HUD y un WebView opcional para
/// renderizar controles avanzados. Se usa dentro de [VisorCasoScreen].
class MenuVisor3D extends StatefulWidget {
  const MenuVisor3D({super.key});

  @override
  State<MenuVisor3D> createState() => _MenuVisor3DState();
}

class _MenuVisor3DState extends State<MenuVisor3D>
    with TickerProviderStateMixin {
  WebViewController? _wc;
  bool _wcError = false;

  late final AnimationController _scanCtrl;
  late final AnimationController _orbitCtrl;
  late final AnimationController _pulseCtrl;

  static const Color _accent = Color(0xFF2A7FF5);

  bool get _isWindows => !kIsWeb && Platform.isWindows;

  @override
  void initState() {
    super.initState();
    _scanCtrl  = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _orbitCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

    if (!_isWindows) _initWebView();
  }

  /// Carga los modelos GLB de assets/RX/ en base64 y los inyecta en el WebView
  /// para renderizar el visor de referencia anatómica sin peticiones de red.
  Future<void> _initWebView() async {
    try {
      final glbs = <String, String>{};
      for (final name in ['Tibia', 'Perone', 'Astragalo', 'Calcaneo']) {
        final data = await rootBundle.load('assets/RX/$name.glb');
        glbs[name] = base64Encode(data.buffer.asUint8List());
      }
      if (!mounted) return;
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..loadHtmlString(_buildHtml(glbs, AppTheme.isDark.value));
      setState(() => _wc = c);
    } catch (_) {
      if (mounted) setState(() => _wcError = true);
    }
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _orbitCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isWindows) return _buildScannerHero();
    if (_wcError || _wc == null) return _buildScannerHero();
    return WebViewWidget(controller: _wc!);
  }

  // ── Visor médico animado (Windows / fallback) ────────────────────────────
  Widget _buildScannerHero() {
    final dark = AppTheme.isDark.value;
    return AnimatedBuilder(
      animation: Listenable.merge([_scanCtrl, _orbitCtrl, _pulseCtrl]),
      builder: (_, __) => CustomPaint(
        painter: _ScannerPainter(
          scan:   _scanCtrl.value,
          orbit:  _orbitCtrl.value,
          pulse:  _pulseCtrl.value,
          dark:   dark,
          accent: _accent,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }

  // ── HTML three.js (web / mobile) ─────────────────────────────────────────
  static String _buildHtml(Map<String, String> glbs, bool dark) {
    final bg1 = dark ? '#0B1426' : '#F4F7FB';
    final bg2 = dark ? '#17223B' : '#E2EAF5';
    final accentCss = dark ? '#7EC8FF' : '#2A7FF5';

    final sb = StringBuffer('{');
    var first = true;
    for (final e in glbs.entries) {
      if (!first) sb.write(',');
      sb.write('"${e.key}":"${e.value}"');
      first = false;
    }
    sb.write('}');

    return '''<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>
*{margin:0;padding:0;box-sizing:border-box;}
html,body{width:100%;height:100%;overflow:hidden;background:linear-gradient(135deg,$bg1,$bg2);}
canvas{display:block;width:100%!important;height:100%!important;}
#loader{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;
  color:$accentCss;font-family:system-ui,sans-serif;font-size:12px;letter-spacing:1px;opacity:.7;}
</style></head><body>
<div id="loader">Cargando modelos…</div>
<script type="importmap">
{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"}}
</script>
<script type="module">
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
const dark=${dark ? 'true' : 'false'};
const renderer=new THREE.WebGLRenderer({antialias:true,alpha:true});
renderer.setPixelRatio(devicePixelRatio);renderer.setSize(innerWidth,innerHeight);
renderer.shadowMap.enabled=true;document.body.appendChild(renderer.domElement);
const scene=new THREE.Scene();
const camera=new THREE.PerspectiveCamera(38,innerWidth/innerHeight,0.1,10000);
scene.add(new THREE.AmbientLight(0xffffff,dark?0.6:0.9));
const key=new THREE.DirectionalLight(0xffffff,dark?1.4:1.2);
key.position.set(200,400,300);key.castShadow=true;scene.add(key);
const fill=new THREE.DirectionalLight(dark?0x8ab4f8:0xd0e4ff,0.45);
fill.position.set(-200,-100,-200);scene.add(fill);
const controls=new OrbitControls(camera,renderer.domElement);
controls.enableDamping=true;controls.dampingFactor=0.07;
controls.autoRotate=true;controls.autoRotateSpeed=0.5;
const mat=new THREE.MeshStandardMaterial({color:dark?0xc8d5e8:0xdde5f0,roughness:0.48,metalness:0.08});
const group=new THREE.Group();scene.add(group);
function b64(b){const bin=atob(b);const buf=new ArrayBuffer(bin.length);const u8=new Uint8Array(buf);for(let i=0;i<bin.length;i++)u8[i]=bin.charCodeAt(i);return buf;}
const data=$sb;const names=Object.keys(data);const loader=new GLTFLoader();let n=0;
for(const k of names){loader.parse(b64(data[k]),'',gltf=>{gltf.scene.traverse(x=>{if(x.isMesh){x.material=mat.clone();x.castShadow=true;}});group.add(gltf.scene);if(++n===names.length)done();},_=>{if(++n===names.length)done();});}
function done(){document.getElementById('loader').style.display='none';const box=new THREE.Box3().setFromObject(group);const c=box.getCenter(new THREE.Vector3());const s=box.getSize(new THREE.Vector3());group.position.sub(c);const m=Math.max(s.x,s.y,s.z);camera.position.set(m*0.35,m*0.15,m*1.55);controls.update();}
window.addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);});
(function loop(){requestAnimationFrame(loop);controls.update();renderer.render(scene,camera);})();
</script></body></html>''';
  }
}

// ── Painter: visor médico ─────────────────────────────────────────────────
class _ScannerPainter extends CustomPainter {
  final double scan;
  final double orbit;
  final double pulse;
  final bool   dark;
  final Color  accent;

  const _ScannerPainter({
    required this.scan,
    required this.orbit,
    required this.pulse,
    required this.dark,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width  / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) * 0.72;

    // Fondo
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? [const Color(0xFF0B1426), const Color(0xFF17223B)]
            : [const Color(0xFFE8F0FB), const Color(0xFFD2E4F8)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Rejilla de puntos de fondo
    _drawDotGrid(canvas, size);

    // Círculos concéntricos
    _drawRings(canvas, cx, cy, r);

    // Línea de escaneo giratoria
    _drawScanLine(canvas, cx, cy, r);

    // Órbitas con puntos
    _drawOrbits(canvas, cx, cy, r);

    // Cruz central
    _drawCrosshair(canvas, cx, cy);

    // Etiquetas de esquina HUD
    _drawHudLabels(canvas, size);
  }

  void _drawDotGrid(Canvas canvas, Size size) {
    final p = Paint()
      ..color = accent.withValues(alpha: dark ? 0.06 : 0.08)
      ..style = PaintingStyle.fill;
    const step = 28.0;
    for (double x = step; x < size.width; x += step) {
      for (double y = step; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1.2, p);
      }
    }
  }

  void _drawRings(Canvas canvas, double cx, double cy, double r) {
    for (int i = 1; i <= 4; i++) {
      final frac  = i / 4.0;
      final alpha = (0.10 + (1 - frac) * 0.08) * (dark ? 1.0 : 0.7);
      final p = Paint()
        ..color  = accent.withValues(alpha: alpha)
        ..style  = PaintingStyle.stroke
        ..strokeWidth = i == 4 ? 1.2 : 0.8;
      canvas.drawCircle(Offset(cx, cy), r * frac, p);
    }
    // Relleno suave del círculo exterior
    final fillP = Paint()
      ..shader = RadialGradient(colors: [
        accent.withValues(alpha: dark ? 0.07 : 0.05),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    canvas.drawCircle(Offset(cx, cy), r, fillP);
  }

  void _drawScanLine(Canvas canvas, double cx, double cy, double r) {
    final angle = scan * 2 * math.pi - math.pi / 2;

    // Sector de barrido
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: angle - 1.1,
        endAngle: angle,
        colors: [
          Colors.transparent,
          accent.withValues(alpha: dark ? 0.18 : 0.13),
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(cx, cy), r, sweepPaint);

    // Línea del frente de barrido
    final linePaint = Paint()
      ..color = accent.withValues(alpha: 0.55)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)),
      linePaint,
    );

    // Punto brillante en el extremo
    final dotPaint = Paint()
      ..color = accent.withValues(alpha: 0.80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(cx + r * math.cos(angle), cy + r * math.sin(angle)),
      5,
      dotPaint,
    );
  }

  void _drawOrbits(Canvas canvas, double cx, double cy, double r) {
    final orbitAngles = [0.0, math.pi * 2 / 3, math.pi * 4 / 3];
    for (int i = 0; i < orbitAngles.length; i++) {
      final base  = orbitAngles[i];
      final angle = orbit * 2 * math.pi + base;
      final nr    = r * (0.45 + i * 0.18);
      final px    = cx + nr * math.cos(angle);
      final py    = cy + nr * math.sin(angle);
      final alpha = 0.55 + pulse * 0.25;

      // Halo
      final haloPaint = Paint()
        ..color = accent.withValues(alpha: alpha * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(px, py), 7, haloPaint);

      // Punto
      final dotPaint = Paint()
        ..color = accent.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), 3.5, dotPaint);
    }
  }

  void _drawCrosshair(Canvas canvas, double cx, double cy) {
    const len   = 14.0;
    const gap   = 5.0;
    final alpha = 0.50 + pulse * 0.20;
    final p = Paint()
      ..color = accent.withValues(alpha: alpha)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(cx - len - gap, cy), Offset(cx - gap, cy), p);
    canvas.drawLine(Offset(cx + gap, cy), Offset(cx + len + gap, cy), p);
    canvas.drawLine(Offset(cx, cy - len - gap), Offset(cx, cy - gap), p);
    canvas.drawLine(Offset(cx, cy + gap), Offset(cx, cy + len + gap), p);

    // Cuadrado central
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: gap * 2, height: gap * 2),
      p,
    );
  }

  void _drawHudLabels(Canvas canvas, Size size) {
    final color = accent.withValues(alpha: dark ? 0.30 : 0.22);
    final lp = Paint()..color = color..strokeWidth = 0.8..style = PaintingStyle.stroke;
    const m = 20.0;
    const len = 14.0;

    for (final corner in [
      [m, m, 1.0, 1.0],
      [size.width - m, m, -1.0, 1.0],
      [m, size.height - m, 1.0, -1.0],
      [size.width - m, size.height - m, -1.0, -1.0],
    ]) {
      final x = corner[0];
      final y = corner[1];
      final sx = corner[2];
      final sy = corner[3];
      canvas.drawLine(Offset(x, y), Offset(x + sx * len, y), lp);
      canvas.drawLine(Offset(x, y), Offset(x, y + sy * len), lp);
    }
  }

  @override
  bool shouldRepaint(_ScannerPainter old) =>
      old.scan != scan || old.orbit != orbit || old.pulse != pulse;
}
