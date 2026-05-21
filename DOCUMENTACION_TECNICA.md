# PQx – Planificación Quirúrgica
## Documentación Técnica Completa

**Versión:** 1.0 Beta  
**Fecha:** 2026-05-21  
**Plataformas:** Android · iOS · macOS · Windows · Linux · Web  
**Backend:** PHP en `profesional.planificacionquirurgica.com`

---

## ÍNDICE

1. [Visión general de la aplicación](#1-visión-general)
2. [Arquitectura del sistema](#2-arquitectura-del-sistema)
3. [Estructura de carpetas del proyecto](#3-estructura-de-carpetas)
4. [Frontend – Flutter (Dart)](#4-frontend--flutter)
   - 4.1 Punto de entrada y bootstrap
   - 4.2 Flujo de pantallas
   - 4.3 Pantalla de Login
   - 4.4 Onboarding
   - 4.5 Menú principal
   - 4.6 Gestión de casos (CasosScreen)
   - 4.7 Visor 3D (VisorCasoScreen)
   - 4.8 Captura y procesamiento de RX
   - 4.9 Archivos por caso
   - 4.10 Planificaciones locales
   - 4.11 Visor selector y Varval
   - 4.12 Servicios transversales
5. [Backend – PHP](#5-backend--php)
   - 5.1 listar_casos.php
   - 5.2 detectar_cambios.php
   - 5.3 web_login_proxy.php / web_listar_casos_proxy.php
   - 5.4 listar_varval.php / listar_visores_genericos.php
   - 5.5 Estructura de directorios en servidor
6. [Firebase y notificaciones push](#6-firebase-y-notificaciones-push)
7. [Almacenamiento local](#7-almacenamiento-local)
8. [Sistema de temas (claro/oscuro)](#8-sistema-de-temas)
9. [Assets y modelos 3D](#9-assets-y-modelos-3d)
10. [Dependencias principales](#10-dependencias-principales)
11. [Flujo completo paso a paso](#11-flujo-completo-paso-a-paso)
12. [Diagrama de arquitectura](#12-diagrama-de-arquitectura)

---

## 1. Visión general

**PQx** es una aplicación médica multiplataforma para **planificación quirúrgica ortopédica**. Permite a los cirujanos:

- Visualizar modelos 3D de huesos y prótesis en formato GLB/GLTF
- Gestionar casos de pacientes con metadatos (nombre, fecha de operación, estado)
- Capturar y procesar radiografías con asistencia de IA (Gemini)
- Añadir notas de audio a cada caso
- Recibir notificaciones push cuando se actualicen modelos en el servidor
- Planificar procedimientos y guardar configuraciones localmente

La aplicación se conecta a un servidor propio donde los modelos 3D están organizados por médico (UID) y por caso.

---

## 2. Arquitectura del sistema

```
┌─────────────────────────────────────────────────────┐
│                  CLIENTE (Flutter)                  │
│  Android · iOS · macOS · Windows · Linux · Web      │
│                                                     │
│  ┌────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │  Screens   │  │   Services   │  │   Widgets   │ │
│  │ (UI/UX)    │  │ (lógica)     │  │ (reutiliz.) │ │
│  └─────┬──────┘  └──────┬───────┘  └─────────────┘ │
│        │                │                           │
│        └────────────────┤                           │
│                         ▼                           │
│              HTTP (http package)                    │
└─────────────────────────┬───────────────────────────┘
                          │  HTTPS
          ┌───────────────┴───────────────┐
          │                               │
          ▼                               ▼
┌─────────────────────┐       ┌──────────────────────┐
│   Backend PHP       │       │   Firebase (Cloud)   │
│  planificacion-     │       │  Proyecto: pqxapp    │
│  quirurgica.com     │       │  FCM Push Notif.     │
│                     │       │  ProjectId:          │
│  /profesional/3D/   │       │  pqxpush-77004       │
│  - listar_casos.php │       └──────────────────────┘
│  - detectar_cambios │
│  - guardar_token    │
│  - proxies web      │
└─────────────────────┘
          │
          ▼
┌─────────────────────┐
│  Sistema de         │
│  archivos del       │
│  servidor           │
│  /3D/{uid}/{caso}/  │
│  *.glb models       │
└─────────────────────┘
```

### Diferencia Mobile vs Web

| Aspecto | Mobile / Desktop | Web |
|---|---|---|
| Login endpoint | `/ocs/v2.php/cloud/user` (GET + Basic Auth) | `/web_login_proxy.php` (POST) |
| Casos endpoint | `/listar_casos.php` (GET + Basic Auth) | `/web_listar_casos_proxy.php` (POST) |
| Firebase | Disponible (Android, iOS, macOS) | No disponible |
| Notificaciones push | Sí (FCM) | No |
| Visor 3D | WebView + model-viewer | WebView + model-viewer |
| Visor Windows | Componente nativo `webview_windows` | - |

---

## 3. Estructura de carpetas del proyecto

```
C:\untitled\
│
├── lib/                          # Código fuente Dart/Flutter
│   ├── main.dart                 # Punto de entrada (5 líneas)
│   ├── app_bootstrap_mobile.dart # Init Firebase + FCM + app (mobile/desktop)
│   ├── app_bootstrap_web.dart    # Init app web (sin Firebase)
│   ├── firebase_options.dart     # Config Firebase multi-plataforma
│   ├── firebase_stub.dart        # Stub para plataformas sin Firebase
│   │
│   ├── screens/                  # Pantallas de la UI
│   │   ├── splash_screen.dart          # Pantalla de inicio
│   │   ├── login_screen.dart           # Autenticación (775 líneas)
│   │   ├── onboarding_screen.dart      # Tutorial inicial (695 líneas)
│   │   ├── menu_screen.dart            # Menú principal mobile (1601 líneas)
│   │   ├── menu_screen_web.dart        # Menú principal web (600 líneas)
│   │   ├── casos_screen.dart           # Listado de casos (794 líneas)
│   │   ├── detalle_caso_screen.dart    # Detalle de un caso (558 líneas)
│   │   ├── nuevo_caso_screen.dart      # Crear nuevo caso
│   │   ├── formulario_caso_screen.dart # Formulario edición (1957 líneas)
│   │   ├── visor_caso_screen.dart      # Visor 3D principal (8871 líneas)
│   │   ├── visor_windows.dart          # Visor específico Windows
│   │   ├── visor_selector_screen.dart  # Selector de visores (800 líneas)
│   │   ├── visor_pdf_screen.dart       # Visor de PDF
│   │   ├── captura_rx_screen.dart      # Captura RX (841 líneas)
│   │   ├── rx_processor_service.dart   # Procesamiento IA RX (1793 líneas)
│   │   ├── archivos_caso_screen.dart   # Archivos por caso (905 líneas)
│   │   ├── listados_screen.dart        # Listados (1000 líneas)
│   │   ├── varval_submenu_screen.dart  # Submenú Varval (985 líneas)
│   │   ├── mis_planificaciones_locales_screen.dart (1042 líneas)
│   │   └── planificacion_local.dart    # Gestión planificaciones locales
│   │
│   ├── services/                 # Servicios y lógica de negocio
│   │   ├── web_api.dart          # URLs de API y gestión de errores CORS
│   │   ├── app_theme.dart        # Gestor de tema claro/oscuro
│   │   ├── firebase_service.dart # Servicio abstracto Firebase
│   │   ├── firebase_stub.dart    # Implementación stub Firebase
│   │   ├── fcm_service.dart      # Interfaz FCM
│   │   ├── fcm_real.dart         # Implementación real FCM
│   │   ├── fcm_stub.dart         # Stub FCM
│   │   ├── audio_notas_service.dart # Grabación de audio por caso
│   │   └── notas_caso_service.dart  # Gestión de notas de texto
│   │
│   └── widgets/                  # Componentes reutilizables
│       ├── menu_visor_3d.dart    # Menú flotante del visor 3D
│       └── audio_notas_panel.dart # Panel de notas de audio
│
├── server/                       # Scripts PHP del backend
│   ├── listar_casos.php          # API REST principal de casos
│   ├── listar_varval.php         # API listado Varval
│   ├── listar_visores_genericos.php # API visores genéricos
│   ├── detectar_cambios.php      # Monitoreo de cambios + FCM
│   ├── web_cors_test.php         # Test de CORS
│   ├── web_listar_casos_proxy.php # Proxy CORS para web
│   └── web_login_proxy.php       # Proxy CORS para login web
│
├── assets/
│   ├── images/                   # Logos, imágenes de referencia
│   ├── models/                   # Modelos 3D locales (femur.glb, rodilla.glb)
│   ├── RX/                       # Modelos 3D para visualización RX
│   │   ├── Astragalo.glb
│   │   ├── Calcaneo.glb
│   │   ├── Perone.glb
│   │   └── Tibia.glb
│   └── icon/                     # Icono de la aplicación
│
├── web/                          # Archivos de la versión PWA
│   ├── index.html
│   ├── manifest.json
│   └── icons/
│
├── android/                      # Configuración nativa Android
├── ios/                          # Configuración nativa iOS
├── macos/                        # Configuración nativa macOS
├── windows/                      # Configuración nativa Windows
├── linux/                        # Configuración nativa Linux
├── test/                         # Tests (widget_test.dart)
├── pubspec.yaml                  # Dependencias Flutter
├── firebase.json                 # Config Firebase
└── design-tokens.css             # Tokens de diseño CSS
```

---

## 4. Frontend – Flutter

### 4.1 Punto de entrada y bootstrap

**Archivo:** `lib/main.dart`

```dart
import 'app_bootstrap_mobile.dart'
    if (dart.library.html) 'app_bootstrap_web.dart'
    as app;

Future<void> main() => app.bootstrap();
```

Flutter elige en tiempo de compilación si usar el bootstrap mobile o web. Esta es la única lógica en `main.dart`.

**`app_bootstrap_mobile.dart`** – secuencia de inicialización:

1. `WidgetsFlutterBinding.ensureInitialized()` — inicializa bindings Flutter
2. `AppTheme.load()` — carga preferencia de tema (claro/oscuro) desde SharedPreferences
3. `Firebase.initializeApp()` — solo en plataformas disponibles (Android/iOS/macOS)
4. `initNotificaciones()` — configura canal `pqx_channel` en Android + permisos iOS
5. `FirebaseMessaging.onBackgroundMessage(handler)` — registra handler de background
6. `initFCM()` — solicita permisos, obtiene token FCM, escucha `onMessage` y `onMessageOpenedApp`
7. `runApp(MyApp())` — lanza la app

**`MyApp`** — `MaterialApp` con:
- Título: `PQx - Planificacion Quirurgica`
- Tema claro y oscuro definidos (`ThemeData`)
- `home: SplashScreen()`
- Escucha cambios de `AppTheme.isDark` mediante `ValueListenableBuilder`

---

### 4.2 Flujo de pantallas

```
SplashScreen
    │
    ├─── (auto-login con credenciales guardadas)
    │         │
    │         ├── onboarding_visto = false → OnboardingScreen → MenuScreen
    │         └── onboarding_visto = true  → MenuScreen
    │
    └─── (sin credenciales guardadas)
              │
              └── LoginScreen
                       │
                       ├── (login exitoso)
                       │         ├── onboarding_visto = false → OnboardingScreen → MenuScreen
                       │         └── onboarding_visto = true  → MenuScreen
                       │
                       └── (error) → muestra mensaje

MenuScreen
    ├── CasosScreen        → VisorCasoScreen (visor 3D)
    ├── VisorSelectorScreen → visores genéricos/Varval
    ├── ListadosScreen     → listados médicos
    ├── NuevoCasoScreen    → crear caso
    ├── MisPlanificaciones → planificaciones guardadas localmente
    ├── ArchivosScreen     → archivos adjuntos por caso
    └── CapturaRxScreen    → captura + procesamiento radiografías
```

---

### 4.3 Pantalla de Login (`login_screen.dart`)

**Funcionalidad:**
- Campos de texto para usuario y contraseña con diseño glass morphism
- Checkbox "Recuérdame" que persiste credenciales en `SharedPreferences`
- Animaciones: 3 orbes animados en el fondo, fade+slide del formulario

**Flujo de autenticación:**

```
Usuario escribe credenciales → tap "Entrar"
    │
    ├── [Web]    POST a /web_login_proxy.php  (body: usuario, password)
    └── [Mobile] GET  a /ocs/v2.php/cloud/user (header: Basic Auth base64)

    ├── HTTP 200 → guarda en SharedPreferences, redirige a MenuScreen/OnboardingScreen
    └── otro     → muestra error "Usuario o contraseña incorrectos"
```

**Registro de token FCM:** Al hacer login exitoso, llama a `guardar_token.php` con el token FCM actual para recibir notificaciones push.

**Normalización de usuario:** Si el email contiene `@`, extrae solo la parte antes de `@` como `grupo` para el token FCM.

---

### 4.4 Onboarding (`onboarding_screen.dart`)

Se muestra **una sola vez** tras el primer login. Explica las funcionalidades principales de la app. Al finalizar, guarda `onboarding_visto = true` en SharedPreferences para no volver a mostrarse.

---

### 4.5 Menú principal (`menu_screen.dart` / `menu_screen_web.dart`)

Hay dos versiones:
- **Mobile** (`menu_screen.dart`, 1601 líneas): diseño vertical con cards animadas
- **Web** (`menu_screen_web.dart`, 600 líneas): diseño adaptado para navegador

Características comunes:
- Muestra el email del usuario logueado
- Muestra el "último caso" accedido con su estado
- **Slider de frases inspiracionales** (25 frases, rotan automáticamente, orden aleatorio)
- Tarjetas de acceso a cada módulo con animaciones de entrada escalonadas (staggered)
- Botón de logout que borra credenciales de SharedPreferences
- Detección de plataforma: `_esPlataformaEscritorio` → true en Windows, macOS, Linux, Web

**En desktop**, implementa navegación con panel lateral (`NavigationRail` o similar).

---

### 4.6 Gestión de casos (`casos_screen.dart`)

Carga los casos del médico autenticado desde el servidor:

```
GET /listar_casos.php
Headers: Authorization: Basic base64(email:password)

Respuesta JSON:
{
  "success": true,
  "uid": "usuario",
  "total": 3,
  "casos": [
    {
      "id": "caso_001",
      "nombre": "Tobillo Derecho - García",
      "paciente": "José García",
      "fecha_op": "2026-03-15",
      "estado": "pendiente",
      "notas": "",
      "biomodelos": [...],
      "placas": [...],
      "tornillos": [...],
      "carpetas": [...],
      "fecha": "21/05/2026"
    }
  ]
}
```

Los casos se ordenan por fecha descendente (más reciente primero).

---

### 4.7 Visor 3D (`visor_caso_screen.dart` – 8.871 líneas)

Es el **módulo más complejo** de la aplicación. Renderiza modelos 3D usando `model-viewer` (Google) dentro de un `WebView`.

#### Modelos de datos:

```dart
class GlbArchivo    { nombre, archivo, url, tipo }
class GrupoPlagas   { nombre, List<GlbArchivo> placas }
class GrupoTornillos{ nombre, List<GlbArchivo> tornillos }
class SubgrupoGlb   { nombre, List<GlbArchivo> archivos }
class CarpetaGlb    { nombre, List<SubgrupoGlb> grupos }

class CasoMedico {
  id, nombre, paciente, fechaOp, estado
  biomodelos: List<GlbArchivo>
  placas:     List<GrupoPlagas>
  tornillos:  List<GrupoTornillos>
  carpetas:   List<CarpetaGlb>     // carpetas dinámicas del servidor
}
```

#### Estructura de modelos en el servidor (mapeo a carpetas):

```
caso/
├── Biomodelos/          → caso.biomodelos (modelos del hueso del paciente)
├── Placas/
│   └── {grupo}/         → caso.placas[n].placas (implantes/placas)
├── Tornillos/
│   └── {grupo}/         → caso.tornillos[n].tornillos (catálogo, oculto en UI)
└── {carpeta_dinamica}/  → caso.carpetas[n] (ej: PreOperatorio, PostOperatorio)
    └── {subgrupo}/
```

#### Tecnología de renderizado 3D:

- Usa `WebView` (webview_flutter en mobile, webview_windows en Windows)
- Carga HTML con `<model-viewer>` de Google
- El HTML se genera dinámicamente en Dart y se carga como `loadHtmlString()`
- Soporte de gestos táctiles y mouse para rotar/zoom
- Toggle de trayectorias con control de opacidad
- Capturas de pantalla guardadas en galería (`gal` package)

#### Funcionalidades del visor:
- Sidebar con listado de modelos por categoría
- Carga/descarga dinámica de modelos en la escena
- Controles de visibilidad por modelo
- Ajuste de opacidad por modelo/grupo
- Panel de notas de audio (`AudioNotasPanel`)
- Exportación de planificación como JSON
- Apertura de PDFs adjuntos al caso (`VisorPdfScreen`)

---

### 4.8 Captura y procesamiento de RX (`captura_rx_screen.dart` + `rx_processor_service.dart`)

Permite al cirujano fotografiar una radiografía y procesarla con IA (Google Gemini).

**Flujo:**
1. El usuario captura/selecciona una imagen de radiografía (`image_picker`)
2. La imagen se envía al servicio `rx_processor_service.dart`
3. El servicio llama a la API de Gemini con la imagen
4. Gemini analiza la RX y devuelve datos estructurados (ángulos, medidas, escala GLB)
5. Los resultados se superponen con los modelos 3D de `assets/RX/` (Astragalo, Calcaneo, Perone, Tibia)
6. El cirujano puede ajustar la superposición manualmente

---

### 4.9 Archivos por caso (`archivos_caso_screen.dart`)

Muestra y gestiona los archivos adjuntos a un caso específico:
- PDFs de informes
- Imágenes
- Modelos 3D adicionales

---

### 4.10 Planificaciones locales (`mis_planificaciones_locales_screen.dart`)

Permite guardar y cargar configuraciones del visor 3D localmente:
- Qué modelos están visibles
- Posiciones y opacidades
- Notas del cirujano

Se almacenan como JSON en el almacenamiento local del dispositivo (`path_provider`).

---

### 4.11 Visor selector y Varval (`visor_selector_screen.dart`, `varval_submenu_screen.dart`)

- **VisorSelector**: catálogo de visores genéricos disponibles (modelos de referencia, implantes estándar)
- **Varval**: submódulo específico para visualización de sistemas de fijación tipo Varval, con su propio endpoint `/listar_varval.php`

---

### 4.12 Servicios transversales

#### `web_api.dart`
Centraliza URLs de la API:

```dart
class WebApi {
  static const String _baseUrl = 'https://profesional.planificacionquirurgica.com';

  // Mobile: /ocs/v2.php/cloud/user  |  Web: /web_login_proxy.php
  static Uri get loginUri => ...

  // Mobile: /listar_casos.php  |  Web: /web_listar_casos_proxy.php
  static Uri get casesUri => ...

  // Manejo de errores CORS en web
  static String connectionError(Object error) => ...
}
```

#### `app_theme.dart`
Gestor de tema con `ValueNotifier<bool>`:
- `AppTheme.isDark` — notifier escuchado en toda la app
- `AppTheme.load()` — carga preferencia desde SharedPreferences
- Propiedades de color: `bgTop`, `bgBottom`, `cardBg1`, `cardBg2`, `cardBorder`, etc.

#### `audio_notas_service.dart`
- Grabación de audio por caso usando `record` package
- Reproducción con `audioplayers`
- Archivos almacenados en directorio temporal del dispositivo

---

## 5. Backend – PHP

Servidor: `/home/admin/domains/planificacionquirurgica.com/public_html/profesional/3D/`  
URL base: `https://profesional.planificacionquirurgica.com`

Todos los endpoints tienen CORS habilitado para `*`:
```php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
```

---

### 5.1 `listar_casos.php`

**Método:** GET (o OPTIONS para preflight CORS)

**Autenticación:** `Authorization: Basic base64(uid:password)` o `?uid=xxx`

**Lógica paso a paso:**

```
1. Lee header Authorization → extrae uid del Basic Auth
2. Si no hay header, lee ?uid= de query string
3. Si uid vacío → HTTP 401

4. Construye ruta: /3D/{uid}/
5. Si carpeta no existe → devuelve casos:[]

6. Escanea subdirectorios de /3D/{uid}/
   Para cada directorio (caso):
   
   a. Excluye: Tabal, Rodilla, Cadera, Columna, vendor, old

   b. Lee info.json si existe:
      { nombre, paciente, fecha_op, estado, notas }

   c. Escanea subcarpetas del caso:
      - "Biomodelo/s" → lista GLBs directamente
      - "Placa/s"     → sublistas por grupo
      - "Tornillo/s"  → sublistas por grupo (catálogo, visible solo en datos)
      - Cualquier otra → carpeta dinámica con grupos y subgrupos

7. Ordena casos por fecha de modificación (desc)
8. Devuelve JSON:
   { success, uid, total, casos: [...] }
```

**Codificación:** Convierte nombres de archivo de ISO-8859-1 a UTF-8 automáticamente.

**URLs de modelos:** Construidas como `https://profesional.planificacionquirurgica.com/3D/{uid}/{caso}/{subcarpeta}/{archivo.glb}` con URL encoding de caracteres especiales.

---

### 5.2 `detectar_cambios.php`

Monitorea cambios en las carpetas de los médicos y envía notificaciones push via FCM.

**Funcionalidad:**
- Escanea recursivamente las carpetas de `/3D/`
- Compara hash/timestamp con snapshot anterior
- Si detecta cambios, obtiene tokens FCM del grupo afectado
- Envía notificación push via Firebase Cloud Messaging (proyecto `pqxpush-77004`)

---

### 5.3 `web_login_proxy.php` / `web_listar_casos_proxy.php`

Proxies necesarios para la versión web (evitan restricciones CORS del navegador):

```
Navegador web → POST /web_login_proxy.php
                     { usuario, password }
                          │
                          ▼
              GET /ocs/v2.php/cloud/user
              Headers: Authorization: Basic base64(usuario:password)
                          │
                          ▼
              Respuesta → devuelta al navegador con headers CORS
```

Mismo patrón para `web_listar_casos_proxy.php` → `listar_casos.php`.

---

### 5.4 `listar_varval.php` / `listar_visores_genericos.php`

Endpoints similares a `listar_casos.php` pero para:
- **Varval**: sistemas de fijación específicos
- **Visores genéricos**: catálogo de modelos de referencia compartidos entre todos los médicos

---

### 5.5 Estructura de directorios en servidor

```
/3D/
└── {uid}/                          # Por médico (uid = parte del email antes de @)
    └── {caso_id}/                  # Nombre del caso (= nombre de carpeta)
        ├── info.json               # Metadatos opcionales del caso
        │   { nombre, paciente, fecha_op, estado, notas }
        │
        ├── Biomodelos/             # Modelos 3D del hueso/anatomía
        │   └── modelo.glb
        │
        ├── Placas/                 # Implantes y placas
        │   └── {grupo}/
        │       └── placa.glb
        │
        ├── Tornillos/              # Catálogo de tornillos (no visible en sidebar)
        │   └── {grupo}/
        │       └── tornillo.glb
        │
        └── {carpeta_dinamica}/     # Cualquier otra carpeta (ej: PreOp, PostOp)
            ├── modelo_raiz.glb     # GLBs en raíz de carpeta
            └── {subgrupo}/
                └── modelo.glb
```

---

## 6. Firebase y notificaciones push

**Proyecto Firebase:** `pqxapp` (ID: `277005442878`)  
**Proyecto FCM:** `pqxpush-77004`

### Configuración por plataforma:

| Plataforma | App ID |
|---|---|
| Android | `1:277005442878:android:e0afabd04c61913432966f` |
| iOS | `1:277005442878:ios:d603744d8320b81932966f` |
| macOS | `1:277005442878:ios:d603744d8320b81932966f` |
| Web | `1:277005442878:web:be2ec6274187a7a732966f` |
| Windows | `1:277005442878:web:637f435073379dfa32966f` |

### Flujo de notificaciones:

```
1. Al hacer login → app obtiene token FCM de FirebaseMessaging
2. Token se envía a guardar_token.php junto con el grupo del usuario
3. Servidor monitorea cambios (detectar_cambios.php)
4. Si hay cambios → busca tokens FCM del grupo → envía push via FCM
5. App recibe notificación:
   - Foreground: mostrarNotificacion() vía flutter_local_notifications
   - Background: firebaseMessagingBackgroundHandler() (registrado con @pragma vm:entry-point)
   - App cerrada: sistema operativo la muestra
```

### Canal Android: `pqx_channel` ("PQx Notificaciones")
- Importance: MAX
- Descripción: "Avisos de casos medicos"

### Disponibilidad de Firebase:
```dart
// Firebase solo disponible en:
// - Android: sí
// - iOS: sí
// - macOS: sí
// - Windows: NO (usa stub)
// - Web: NO (usa stub)
```

---

## 7. Almacenamiento local

Usa `SharedPreferences` para persistir:

| Clave | Tipo | Descripción |
|---|---|---|
| `login_email` | String | Email del usuario logueado |
| `login_password` | String | Contraseña del usuario |
| `remember_me` | bool | Si debe auto-loguear al iniciar |
| `onboarding_visto` | bool | Si ya vio el tutorial inicial |
| `theme_dark` | bool | Preferencia de tema oscuro |

**Almacenamiento de archivos locales** (`path_provider`):
- Planificaciones guardadas: JSON en directorio de documentos del dispositivo
- Notas de audio: archivos `.m4a` o `.aac` en directorio temporal
- UUID generados con `uuid` package para nombres únicos

---

## 8. Sistema de temas

**Archivo:** `lib/services/app_theme.dart`

```dart
class AppTheme {
  static final ValueNotifier<bool> isDark = ValueNotifier(false);
  
  static Future<void> load() async {
    // Lee 'theme_dark' de SharedPreferences
  }
  
  // Colores adaptativos:
  static Color get bgTop    => isDark.value ? Color(0xFF0D1117) : Color(0xFFEEF2F8)
  static Color get bgBottom => isDark.value ? Color(0xFF161B22) : Color(0xFFDDE3EE)
  static Color get darkText => isDark.value ? Colors.white     : Color(0xFF1A2035)
  static Color get cardBg1  => ...
  static Color get cardBg2  => ...
  static Color get cardBorder => ...
  static Color get cardGlowWhite => ...
  static Color get handleColor => ...
  
  // Logos por tema:
  // Oscuro:  assets/images/logo2.png
  // Claro:   assets/images/logo.png
}
```

El `ValueListenable<bool>` permite que todos los widgets se reconstruyan automáticamente al cambiar el tema sin necesidad de un state manager externo.

---

## 9. Assets y modelos 3D

### Modelos 3D locales (bundled con la app):

| Archivo | Descripción | Uso |
|---|---|---|
| `assets/models/femur.glb` | Fémur | Referencia/demo |
| `assets/models/femur_hueso2.glb` | Fémur alternativo | Referencia/demo |
| `assets/models/rodilla.glb` | Rodilla | Referencia/demo |
| `assets/models/tibia.stl` | Tibia (formato STL) | Referencia/demo |
| `assets/RX/Astragalo.glb` | Astrágalo | Superposición en RX |
| `assets/RX/Calcaneo.glb` | Calcáneo | Superposición en RX |
| `assets/RX/Perone.glb` | Peroné | Superposición en RX |
| `assets/RX/Tibia.glb` | Tibia | Superposición en RX |

### Imágenes:

| Archivo | Descripción |
|---|---|
| `assets/images/logo.png` | Logo tema claro |
| `assets/images/logo2.png` | Logo tema oscuro |
| `assets/images/tobillo_3d.png` | Referencia visual tobillo |
| `assets/images/adicion femoral.png` | Referencia movimiento femoral |
| `assets/images/adicion tibial.png` | Referencia movimiento tibial |
| `assets/images/rotacion femoral.png` | Rotación femoral |
| `assets/images/rotacion tibial.png` | Rotación tibial |
| `assets/images/sustracion femoral.png` | Sustracción femoral |
| `assets/images/sustracion tibial.png` | Sustracción tibial |
| `assets/images/caja.jpeg` | Equipamiento |
| `assets/images/impactor.jpeg` | Impactor quirúrgico |

---

## 10. Dependencias principales

**`pubspec.yaml` — dependencias de producción:**

| Paquete | Versión | Uso |
|---|---|---|
| `flutter` | SDK | Framework base |
| `http` | ^0.13.6 | Peticiones HTTP al servidor |
| `shared_preferences` | ^2.3.0 | Almacenamiento local clave-valor |
| `webview_flutter` | ^4.9.0 | WebView para visor 3D (mobile/macOS) |
| `webview_windows` | ^0.4.0 | WebView nativo Windows |
| `model_viewer_plus` | ^1.7.0 | Componente model-viewer en Flutter |
| `url_launcher` | ^6.3.0 | Abrir URLs externas |
| `file_picker` | ^8.0.0 | Seleccionar archivos del dispositivo |
| `image_picker` | ^1.1.2 | Capturar/seleccionar imágenes |
| `path_provider` | ^2.1.0 | Directorios del sistema de archivos |
| `uuid` | ^4.4.0 | Generación de IDs únicos |
| `gal` | ^2.3.0 | Guardar imágenes en galería |
| `video_player` | ^2.8.0 | Reproducción de video |
| `flutter_pdfview` | ^1.3.2 | Visor de PDF |
| `record` | ^6.2.0 | Grabación de audio |
| `audioplayers` | ^6.1.0 | Reproducción de audio |
| `flutter_colorpicker` | ^1.0.3 | Selector de color |
| `vector_math` | ^2.1.4 | Matemáticas vectoriales 3D |
| `flutter_local_notifications` | ^17.0.0 | Notificaciones locales |
| `firebase_messaging` | ^16.1.3 | Notificaciones push FCM |
| `firebase_core` | (implícita) | Core de Firebase |

**Dev dependencies:**

| Paquete | Uso |
|---|---|
| `flutter_launcher_icons` | Generación de iconos de app |
| `flutter_lints` | Reglas de estilo de código |
| `web` | Soporte web en Dart |

---

## 11. Flujo completo paso a paso

### Paso 1 – Inicio de la aplicación

```
Usuario abre la app
    │
    ▼
main.dart → detecta plataforma (web/mobile)
    │
    ▼
bootstrap():
    ├── Carga tema (SharedPreferences)
    ├── Inicializa Firebase (si disponible)
    ├── Configura canal de notificaciones Android
    ├── Solicita permisos de notificaciones iOS
    ├── Obtiene token FCM
    └── Lanza MyApp → SplashScreen
```

### Paso 2 – Splash y auto-login

```
SplashScreen (breve animación del logo)
    │
    ▼
Comprueba SharedPreferences:
    ├── remember_me = true + email + password → intenta auto-login
    │       ├── Actualiza token FCM en servidor
    │       ├── onboarding_visto = false → OnboardingScreen
    │       └── onboarding_visto = true  → MenuScreen
    └── Sin credenciales → LoginScreen (con animación de entrada del formulario)
```

### Paso 3 – Login manual

```
Usuario introduce usuario + contraseña → "Entrar"
    │
    ▼
_login():
    ├── Valida campos no vacíos
    ├── [Web]    POST /web_login_proxy.php
    │            body: { usuario, password }
    ├── [Mobile] GET  /ocs/v2.php/cloud/user
    │            header: Authorization: Basic base64(email:pass)
    │
    ├── HTTP 200:
    │       ├── Guarda email, password, remember_me en SharedPreferences
    │       ├── Registra token FCM en /guardar_token.php
    │       └── Navega a OnboardingScreen o MenuScreen
    └── Error: muestra mensaje de error en el formulario
```

### Paso 4 – Menú principal

```
MenuScreen (detecta plataforma):
    │
    ├── Carga email desde SharedPreferences
    ├── Carga último caso accedido
    ├── Inicia slider de frases (timer de rotación automática)
    ├── Anima entrada de tarjetas (staggered animation)
    │
    └── El médico selecciona módulo:
        ├── "Mis Casos"        → CasosScreen
        ├── "Visores"          → VisorSelectorScreen
        ├── "Radiografías"     → CapturaRxScreen
        ├── "Planificaciones"  → MisPlanificacionesLocalesScreen
        ├── "Archivos"         → ArchivosScreen
        ├── "Listados"         → ListadosScreen
        └── "Cerrar sesión"    → limpia SharedPreferences → LoginScreen
```

### Paso 5 – Carga de casos

```
CasosScreen:
    │
    ▼
Lee email + password de SharedPreferences
    │
    ▼
HTTP GET /listar_casos.php
    Header: Authorization: Basic base64(email:pass)
    │
    ▼
Servidor PHP:
    ├── Valida autenticación
    ├── Construye uid = email (o parte antes de @)
    ├── Escanea /3D/{uid}/
    ├── Para cada carpeta de caso:
    │       ├── Lee info.json (metadatos)
    │       ├── Clasifica subcarpetas (biomodelos, placas, tornillos, dinámicas)
    │       └── Construye URLs de cada .glb
    └── Devuelve JSON con array de casos
    │
    ▼
Flutter parsea respuesta → lista de CasoMedico
    │
    ▼
Muestra lista de casos con nombre, paciente, estado, fecha
```

### Paso 6 – Abrir el Visor 3D

```
Usuario pulsa un caso → VisorCasoScreen(caso: CasoMedico)
    │
    ▼
Construye HTML dinámico con model-viewer:
    <model-viewer src="{url_glb}" ...>
    │
    ▼
WebView.loadHtmlString(html)
    │
    ▼ (en background)
WebView descarga el .glb desde la URL del servidor
    │
    ▼
Renderiza modelo 3D interactivo:
    ├── Rotación con gestos táctiles / mouse
    ├── Zoom con pellizco / rueda del mouse
    │
    ├── Sidebar izquierdo: lista de modelos por categoría
    │   ├── Biomodelos (huesos del paciente)
    │   ├── Placas por grupo
    │   └── Carpetas dinámicas (PreOp, PostOp, etc.)
    │
    ├── Toggle visibilidad de cada modelo
    ├── Control de opacidad (trayectorias ocultas por defecto)
    ├── Panel de notas de audio (grabar/reproducir)
    └── Botón captura → guarda screenshot en galería
```

### Paso 7 – Guardar planificación

```
Dentro del visor → "Guardar planificación"
    │
    ▼
Serializa estado actual:
    { modelos_visibles, opacidades, configuracion }
    │
    ▼
Genera UUID como nombre del archivo
    │
    ▼
Guarda JSON en path_provider → directorio documentos
    │
    ▼
Accesible desde MisPlanificacionesLocalesScreen
```

### Paso 8 – Notificaciones push

```
Servidor (proceso periódico):
    │
    ▼
detectar_cambios.php:
    ├── Escanea /3D/ recursivamente
    ├── Compara con snapshot anterior
    │
    └── Si hay cambios:
            ├── Busca tokens FCM del grupo afectado
            └── POST a Firebase FCM API
                    { title: "PQx", body: "Nuevo modelo disponible" }
    │
    ▼
Firebase FCM → dispositivos del médico
    │
    ▼
App Flutter (firebaseMessagingBackgroundHandler / onMessage):
    └── flutter_local_notifications.show() → notificación en sistema operativo
```

---

## 12. Diagrama de arquitectura

```
┌────────────────────────────────────────────────────────────────────┐
│                     APLICACIÓN PQx                                 │
│                                                                    │
│  ┌──────────────┐   ┌──────────────┐   ┌────────────────────────┐ │
│  │  PANTALLAS   │   │  SERVICIOS   │   │       WIDGETS          │ │
│  │              │   │              │   │                        │ │
│  │ SplashScreen │   │  WebApi      │   │  MenuVisor3D           │ │
│  │ LoginScreen  │   │  AppTheme    │   │  AudioNotasPanel       │ │
│  │ OnboardScreen│   │  Firebase    │   │                        │ │
│  │ MenuScreen   │   │  FCM         │   └────────────────────────┘ │
│  │ CasosScreen  │   │  AudioNotas  │                              │
│  │ VisorCaso    │   │  NotasCaso   │   ┌────────────────────────┐ │
│  │ CapturaRx    │   │              │   │  ALMACENAMIENTO LOCAL  │ │
│  │ ArchivosScreen│  └──────────────┘   │                        │ │
│  │ Planificacion│                      │  SharedPreferences     │ │
│  │ ListadoScreen│  ┌──────────────┐   │  path_provider (JSON)  │ │
│  │ VisorSelector│  │    ASSETS    │   │  Archivos audio        │ │
│  │ VarvalScreen │  │              │   └────────────────────────┘ │
│  └──────────────┘  │  images/     │                              │
│                    │  models/ GLB │                              │
│                    │  RX/ GLB     │                              │
│                    └──────────────┘                              │
└───────────────────────────┬────────────────────────────────────────┘
                            │ HTTPS
              ┌─────────────┴──────────────┐
              │                            │
              ▼                            ▼
┌─────────────────────┐      ┌─────────────────────────────┐
│   BACKEND PHP       │      │      FIREBASE               │
│                     │      │                             │
│ listar_casos.php    │      │  FCM (push notifications)   │
│ detectar_cambios.php│      │  Proyecto: pqxapp           │
│ guardar_token.php   │      │  Android + iOS + macOS      │
│ web_login_proxy.php │      └─────────────────────────────┘
│ web_listar_casos_   │
│   proxy.php         │
│ listar_varval.php   │
│ listar_visores_     │
│   genericos.php     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────────────────────────────┐
│   SISTEMA DE ARCHIVOS (servidor)            │
│                                             │
│   /3D/                                      │
│   └── {uid}/                               │
│       └── {caso}/                          │
│           ├── info.json                     │
│           ├── Biomodelos/*.glb             │
│           ├── Placas/{grupo}/*.glb         │
│           ├── Tornillos/{grupo}/*.glb      │
│           └── {carpeta_dinamica}/          │
│               └── {subgrupo}/*.glb         │
└─────────────────────────────────────────────┘
```

---

## Notas técnicas adicionales

### Manejo multiplataforma en Dart
El proyecto usa importaciones condicionales para separar código por plataforma:
```dart
// main.dart
import 'app_bootstrap_mobile.dart'
    if (dart.library.html) 'app_bootstrap_web.dart' as app;

// login_screen.dart
import 'menu_screen.dart' 
    if (dart.library.html) 'menu_screen_web.dart';
```

### Seguridad de credenciales
- Las credenciales se guardan en `SharedPreferences` en texto plano cuando el usuario activa "Recuérdame"
- Las peticiones HTTP usan `Basic Auth` con base64 (no cifrado fuerte)
- Se recomienda en versiones futuras: migrar a tokens JWT o Keychain/Keystore del SO

### Codificación de caracteres
El servidor PHP convierte automáticamente nombres de carpetas de ISO-8859-1 a UTF-8 (`mb_convert_encoding`) para soportar nombres con tildes y caracteres especiales en el sistema de archivos del servidor.

### Modelos 3D en WebView
El renderizado 3D usa `<model-viewer>` de Google, una librería web estándar. Flutter lo embebe en un `WebView`, lo que permite compatibilidad multiplataforma sin necesidad de un motor 3D nativo.

---


