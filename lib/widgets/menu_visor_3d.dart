import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:untitled/services/app_theme.dart';

class MenuVisor3D extends StatefulWidget {
  const MenuVisor3D({super.key});

  @override
  State<MenuVisor3D> createState() => _MenuVisor3DState();
}

class _MenuVisor3DState extends State<MenuVisor3D> {
  WebViewController? _wc;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
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
  }

  @override
  Widget build(BuildContext context) {
    if (_wc == null) {
      return Container(
        color: AppTheme.isDark.value
            ? const Color(0xFF0B1426)
            : const Color(0xFFF4F7FB),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return WebViewWidget(controller: _wc!);
  }

  static String _buildHtml(Map<String, String> glbs, bool dark) {
    final bg1 = dark ? '#0B1426' : '#F4F7FB';
    final bg2 = dark ? '#17223B' : '#E2EAF5';
    final accentCss = dark ? '#7EC8FF' : '#2A7FF5';

    final glbJsSb = StringBuffer('{');
    var first = true;
    for (final e in glbs.entries) {
      if (!first) glbJsSb.write(',');
      glbJsSb.write('"${e.key}":"${e.value}"');
      first = false;
    }
    glbJsSb.write('}');

    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
*{margin:0;padding:0;box-sizing:border-box;}
html,body{width:100%;height:100%;overflow:hidden;background:linear-gradient(135deg,$bg1,$bg2);}
canvas{display:block;width:100%!important;height:100%!important;}
#loader{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;
  color:$accentCss;font-family:system-ui,sans-serif;font-size:12px;letter-spacing:1px;opacity:.7;}
</style>
</head>
<body>
<div id="loader">Cargando modelos…</div>
<script type="importmap">
{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"}}
</script>
<script type="module">
import * as THREE from 'three';
import { GLTFLoader }    from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';

const dark = ${dark ? 'true' : 'false'};

const renderer = new THREE.WebGLRenderer({antialias:true, alpha:true});
renderer.setPixelRatio(devicePixelRatio);
renderer.setSize(innerWidth, innerHeight);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
document.body.appendChild(renderer.domElement);

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(38, innerWidth/innerHeight, 0.1, 10000);

scene.add(new THREE.AmbientLight(0xffffff, dark ? 0.6 : 0.9));
const key = new THREE.DirectionalLight(0xffffff, dark ? 1.4 : 1.2);
key.position.set(200, 400, 300);
key.castShadow = true;
scene.add(key);
const fill = new THREE.DirectionalLight(dark ? 0x8ab4f8 : 0xd0e4ff, 0.45);
fill.position.set(-200, -100, -200);
scene.add(fill);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.dampingFactor = 0.07;
controls.autoRotate = true;
controls.autoRotateSpeed = 0.5;

const boneMat = new THREE.MeshStandardMaterial({
  color: dark ? 0xc8d5e8 : 0xdde5f0,
  roughness: 0.48,
  metalness: 0.08,
});

const group = new THREE.Group();
scene.add(group);

function b64ToBuffer(b64) {
  const bin = atob(b64);
  const buf = new ArrayBuffer(bin.length);
  const u8  = new Uint8Array(buf);
  for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
  return buf;
}

const glbData = $glbJsSb;
const names   = Object.keys(glbData);
const loader  = new GLTFLoader();
let loaded = 0;

for (const name of names) {
  const buf = b64ToBuffer(glbData[name]);
  loader.parse(buf, '', gltf => {
    gltf.scene.traverse(n => {
      if (n.isMesh) {
        n.material = boneMat.clone();
        n.castShadow = true;
        n.receiveShadow = true;
      }
    });
    group.add(gltf.scene);
    if (++loaded === names.length) _onAllLoaded();
  }, err => {
    console.error(name, err);
    if (++loaded === names.length) _onAllLoaded();
  });
}

function _onAllLoaded() {
  document.getElementById('loader').style.display = 'none';
  const box    = new THREE.Box3().setFromObject(group);
  const center = box.getCenter(new THREE.Vector3());
  const size   = box.getSize(new THREE.Vector3());
  group.position.sub(center);
  const maxDim = Math.max(size.x, size.y, size.z);
  camera.position.set(maxDim * 0.35, maxDim * 0.15, maxDim * 1.55);
  controls.target.set(0, 0, 0);
  controls.update();
}

window.addEventListener('resize', () => {
  camera.aspect = innerWidth / innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(innerWidth, innerHeight);
});

(function loop() {
  requestAnimationFrame(loop);
  controls.update();
  renderer.render(scene, camera);
})();
</script>
</body>
</html>''';
  }
}
