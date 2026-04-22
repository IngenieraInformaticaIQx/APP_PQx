import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled/services/app_theme.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final bool fromPerfil;
  const OnboardingScreen({super.key, this.fromPerfil = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _page = 0;

  static const _accent = Color(0xFF2A7FF5);

  static const _slides = [
    _Slide(
      icon: Icons.waving_hand_rounded,
      color: Color(0xFF2A7FF5),
      title: 'Bienvenido a PQx',
      desc: 'Tu herramienta de planificación quirúrgica. Gestiona casos, visualiza modelos 3D y planifica intervenciones desde un solo lugar.',
    ),
    _Slide(
      icon: Icons.folder_open_rounded,
      color: Color(0xFF2A7FF5),
      title: 'Mis Casos',
      desc: 'Cada caso almacena modelos óseos, placas y tornillos. El estado avanza automáticamente según tus acciones.',
      hints: [
        _Hint(icon: Icons.radio_button_unchecked, label: 'Pendiente',  color: Color(0xFF9E9E9E)),
        _Hint(icon: Icons.check_circle_outline,   label: 'Validado',   color: Color(0xFF2A7FF5)),
        _Hint(icon: Icons.edit_outlined,           label: 'Modificado', color: Color(0xFFFF9500)),
        _Hint(icon: Icons.verified_outlined,       label: 'Firmado',    color: Color(0xFF34A853)),
        _Hint(icon: Icons.send_outlined,           label: 'Enviado',    color: Color(0xFF8E44AD)),
      ],
    ),
    _Slide(
      icon: Icons.touch_app_rounded,
      color: Color(0xFF5BA8FF),
      title: 'Navegación 3D',
      desc: 'Controla el modelo con gestos táctiles para examinar cualquier ángulo.',
      hints: [
        _Hint(icon: Icons.fingerprint,         label: '1 dedo',     sublabel: 'Rotar modelo'),
        _Hint(icon: Icons.pinch_rounded,        label: 'Pellizco',   sublabel: 'Zoom +/−'),
        _Hint(icon: Icons.open_with_rounded,    label: '2 dedos',    sublabel: 'Desplazar'),
        _Hint(icon: Icons.touch_app_outlined,   label: 'Doble tap',  sublabel: 'Abrir panel'),
      ],
    ),
    _Slide(
      icon: Icons.layers_rounded,
      color: Color(0xFF5BA8FF),
      title: 'Panel lateral',
      desc: 'Agrupa todas las herramientas en 4 pestañas. Arrástralo libremente por la pantalla para dejarlo donde mejor te venga. Toca fuera para cerrarlo.',
      hints: [
        _Hint(icon: Icons.layers_outlined,    label: 'Capas',      sublabel: 'Visibilidad'),
        _Hint(icon: Icons.settings_outlined,  label: 'Tornillos',  sublabel: 'Implantes'),
        _Hint(icon: Icons.push_pin_outlined,  label: 'Notas',      sublabel: 'Voz'),
        _Hint(icon: Icons.straighten_outlined,label: 'Medic.',     sublabel: 'Regla'),
      ],
    ),
    _Slide(
      icon: Icons.visibility_rounded,
      color: Color(0xFF5BA8FF),
      title: 'Pestaña Capas',
      desc: 'Activa o desactiva individualmente cada modelo 3D del caso. Despliega una capa para ver y controlar sus trayectorias de tornillo.',
      hints: [
        _Hint(icon: Icons.visibility_outlined,      label: 'Ojo activo',   sublabel: 'Capa visible'),
        _Hint(icon: Icons.visibility_off_outlined,  label: 'Ojo apagado',  sublabel: 'Capa oculta'),
        _Hint(icon: Icons.expand_more_rounded,      label: 'Desplegable',  sublabel: 'Trayectorias'),
      ],
    ),
    _Slide(
      icon: Icons.hardware_rounded,
      color: Color(0xFF8E44AD),
      title: 'Pestaña Tornillos',
      desc: 'Coloca tornillos sobre la placa tocando un hueco disponible en el visor. Selecciona el implante del catálogo y confirma.',
      hints: [
        _Hint(icon: Icons.touch_app_outlined,    label: 'Tap en hueco',   sublabel: 'Abre catálogo'),
        _Hint(icon: Icons.check_rounded,          label: 'Confirmar',      sublabel: 'Coloca tornillo'),
        _Hint(icon: Icons.info_outline_rounded,   label: 'Tap tornillo',   sublabel: 'Ver medidas'),
        _Hint(icon: Icons.delete_outline_rounded, label: 'Papelera',       sublabel: 'Eliminar'),
      ],
    ),
    _Slide(
      icon: Icons.mic_rounded,
      color: Color(0xFF2A7FF5),
      title: 'Pestaña Notas de voz',
      desc: 'Graba observaciones rápidas vinculadas al caso. Quedan guardadas para reproducirlas o eliminarlas cuando quieras.',
      hints: [
        _Hint(icon: Icons.mic_outlined,           label: 'Grabar',      sublabel: 'Mantén pulsado'),
        _Hint(icon: Icons.play_arrow_outlined,    label: 'Reproducir',  sublabel: 'Escuchar nota'),
        _Hint(icon: Icons.delete_outline_rounded, label: 'Eliminar',    sublabel: 'Borrar nota'),
      ],
    ),
    _Slide(
      icon: Icons.straighten_rounded,
      color: Color(0xFF64D2FF),
      title: 'Pestaña Mediciones',
      desc: 'Mide distancias en el modelo 3D con la regla libre o consulta las medidas exactas de cada tornillo colocado.',
      hints: [
        _Hint(icon: Icons.straighten_outlined,  label: 'Regla libre',  sublabel: 'Toca 2 puntos'),
        _Hint(icon: Icons.hardware_outlined,    label: 'Tornillo',     sublabel: 'Largo en mm'),
        _Hint(icon: Icons.close_rounded,        label: 'Salir regla',  sublabel: 'Vuelve al visor'),
      ],
    ),
    _Slide(
      icon: Icons.space_dashboard_rounded,
      color: Color(0xFF34C759),
      title: 'Barra de herramientas',
      desc: 'La barra superior da acceso rápido a las funciones principales del visor.',
      hints: [
        _Hint(icon: Icons.photo_camera_outlined,              label: 'Captura',      sublabel: 'Foto del visor'),
        _Hint(icon: Icons.picture_as_pdf_outlined,            label: 'PDF',          sublabel: 'Docs del caso'),
        _Hint(icon: Icons.view_in_ar_outlined,                label: 'Vistas',       sublabel: 'Frontal/lateral'),
        _Hint(icon: Icons.rotate_90_degrees_ccw_outlined,     label: 'Autorotación', sublabel: 'Giro continuo'),
        _Hint(icon: Icons.wb_sunny_outlined,                  label: 'Iluminación',  sublabel: 'Modo de luz'),
        _Hint(icon: Icons.content_cut_outlined,               label: 'Plano corte',  sublabel: 'Sección 3D'),
      ],
    ),
    _Slide(
      icon: Icons.upload_rounded,
      color: Color(0xFF8E44AD),
      title: 'Exportar caso',
      desc: 'Pulsa Exportar cuando termines. Se capturan 3 vistas automáticamente y el caso se envía al servidor. El estado pasa a "Enviado".',
      hints: [
        _Hint(icon: Icons.upload_outlined,      label: 'Exportar',       sublabel: 'Botón visor'),
        _Hint(icon: Icons.camera_alt_outlined,  label: 'Capturas auto',  sublabel: '3 vistas PNG'),
        _Hint(icon: Icons.send_outlined,        label: 'Estado auto',    sublabel: 'Cambia a Enviado'),
      ],
    ),
    _Slide(
      icon: Icons.save_rounded,
      color: Color(0xFF34A853),
      title: 'Guardar sesión',
      desc: 'Guarda tu planificación en el dispositivo para continuar más tarde. Se restaura automáticamente al abrir el mismo caso.',
      hints: [
        _Hint(icon: Icons.save_outlined,           label: 'Guardar',         sublabel: 'Botón del visor'),
        _Hint(icon: Icons.history_rounded,         label: 'Restaurar auto',  sublabel: 'Al abrir el caso'),
        _Hint(icon: Icons.folder_special_outlined, label: 'Mis planif.',     sublabel: 'Acceso desde menú'),
      ],
    ),
  ];

  Future<void> _finalizar() async {
    if (!widget.fromPerfil) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_visto', true);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;

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
          child: Column(children: [
            // ── Top bar ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                if (widget.fromPerfil)
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.cardBg1,
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Icon(Icons.close, size: 18, color: AppTheme.subtitleColor),
                    ),
                  )
                else
                  const SizedBox(width: 36),
                const Spacer(),
                // Contador de página
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg1,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Text(
                    '${_page + 1} / ${_slides.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.subtitleColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (!isLast)
                  GestureDetector(
                    onTap: _finalizar,
                    child: Text('Saltar',
                        style: TextStyle(
                            color: AppTheme.subtitleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  )
                else
                  const SizedBox(width: 36),
              ]),
            ),

            // ── PageView ──────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _ctrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _buildSlide(_slides[i]),
              ),
            ),

            // ── Indicadores ───────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: active ? _accent : AppTheme.cardBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),

            // ── Botones ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              child: Row(children: [
                // Botón anterior (visible desde slide 1)
                if (_page > 0)
                  GestureDetector(
                    onTap: () => _ctrl.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg1,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppTheme.cardBorder, width: 1.5),
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded,
                              size: 18, color: AppTheme.darkText),
                        ),
                      ),
                    ),
                  ),
                if (_page > 0) const SizedBox(width: 12),
                // Botón siguiente / empezar
                Expanded(
                  child: GestureDetector(
                    onTap: isLast
                        ? _finalizar
                        : () => _ctrl.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: isLast
                                ? const LinearGradient(
                                    colors: [_accent, Color(0xFF5BA8FF)],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight)
                                : null,
                            color: isLast ? null : AppTheme.cardBg1,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isLast
                                  ? _accent.withOpacity(0.6)
                                  : AppTheme.cardBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              isLast ? 'Empezar' : 'Siguiente',
                              style: TextStyle(
                                color: isLast ? Colors.white : AppTheme.darkText,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildSlide(_Slide slide) {
    final hasHints = slide.hints != null && slide.hints!.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icono
          ClipRRect(
            borderRadius: BorderRadius.circular(hasHints ? 28 : 36),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: hasHints ? 86 : 110,
                height: hasHints ? 86 : 110,
                decoration: BoxDecoration(
                  color: slide.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(hasHints ? 28 : 36),
                  border: Border.all(color: slide.color.withOpacity(0.25), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: slide.color.withOpacity(0.15),
                      blurRadius: 36,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(slide.icon, size: hasHints ? 38 : 48, color: slide.color),
              ),
            ),
          ),
          SizedBox(height: hasHints ? 22 : 36),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.darkText,
              fontSize: hasHints ? 21 : 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            slide.desc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.subtitleColor,
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (hasHints) ...[
            const SizedBox(height: 22),
            _buildHints(slide.hints!, slide.color),
          ],
        ],
      ),
    );
  }

  Widget _buildHints(List<_Hint> hints, Color fallback) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: hints.map((h) {
        final col = h.color ?? fallback;
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: col.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: col.withOpacity(0.22), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(h.icon, size: 14, color: col),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(h.label,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: col)),
                    if (h.sublabel != null)
                      Text(h.sublabel!,
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.subtitleColor,
                              height: 1.3)),
                  ],
                ),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _Slide {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  final List<_Hint>? hints;
  const _Slide({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
    this.hints,
  });
}

class _Hint {
  final IconData icon;
  final String label;
  final String? sublabel;
  final Color? color;
  const _Hint({
    required this.icon,
    required this.label,
    this.sublabel,
    this.color,
  });
}