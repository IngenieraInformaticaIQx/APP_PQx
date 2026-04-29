import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:uuid/uuid.dart';
import 'package:untitled/services/audio_notas_service.dart';
import 'package:untitled/services/app_theme.dart';

class AudioNotasPanel extends StatefulWidget {
  final String casoId;
  const AudioNotasPanel({super.key, required this.casoId});

  @override
  State<AudioNotasPanel> createState() => _AudioNotasPanelState();
}

class _AudioNotasPanelState extends State<AudioNotasPanel> {
  final _recorder  = AudioRecorder();
  final _player    = AudioPlayer();

  List<AudioNota> _notas = [];
  bool   _grabando        = false;
  String? _reproduciendo;   // id de la nota en reproducción
  int    _segGrabando     = 0;
  Timer? _timerGrabacion;
  String? _idActual;        // UUID para el archivo y la nota (mismo)

  @override
  void initState() {
    super.initState();
    _cargar();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _reproduciendo = null);
    });
  }

  @override
  void dispose() {
    _timerGrabacion?.cancel();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final notas = await AudioNotasService.cargar(widget.casoId);
    if (mounted) setState(() => _notas = notas);
  }

  Future<void> _iniciarGrabacion() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Se necesita permiso de micrófono para grabar notas de voz.')));
      }
      return;
    }
    final id   = const Uuid().v4();
    _idActual  = id;
    final ruta = await AudioNotasService.nuevaRuta(widget.casoId, id);
    await _recorder.start(RecordConfig(encoder: AudioEncoder.aacLc), path: ruta);
    setState(() { _grabando = true; _segGrabando = 0; });
    _timerGrabacion = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _segGrabando++);
    });
  }

  Future<void> _pararGrabacion() async {
    _timerGrabacion?.cancel();
    final ruta = await _recorder.stop();
    final duracion = _segGrabando;
    setState(() { _grabando = false; _segGrabando = 0; });

    if (ruta == null || ruta.isEmpty || _idActual == null) return;

    final nota = AudioNota(
      id:                _idActual!,
      casoId:            widget.casoId,
      path:              ruta,
      fecha:             DateTime.now(),
      duracionSegundos:  duracion,
    );
    _idActual = null;
    await AudioNotasService.guardar(nota);
    await _cargar();
  }

  Future<void> _togglePlay(AudioNota nota) async {
    if (_reproduciendo == nota.id) {
      await _player.stop();
      setState(() => _reproduciendo = null);
    } else {
      await _player.stop();
      try {
        await _player.play(DeviceFileSource(nota.path));
        setState(() => _reproduciendo = nota.id);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo reproducir la nota de voz.')));
        }
      }
    }
  }

  Future<void> _eliminar(AudioNota nota) async {
    if (_reproduciendo == nota.id) {
      await _player.stop();
      setState(() => _reproduciendo = null);
    }
    await AudioNotasService.eliminar(nota);
    await _cargar();
  }

  String _fmtSeg(int s) {
    final m = s ~/ 60, seg = s % 60;
    return '${m.toString().padLeft(2,'0')}:${seg.toString().padLeft(2,'0')}';
  }

  String _fmtFecha(DateTime d) {
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}  ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: 300,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          decoration: BoxDecoration(
            color: AppTheme.sheetBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.cardBorder, width: 1.5),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(children: [
                Icon(Icons.mic_rounded, size: 16, color: const Color(0xFF2A7FF5)),
                const SizedBox(width: 8),
                Text('Notas de voz', style: TextStyle(color: AppTheme.darkText, fontSize: 14, fontWeight: FontWeight.w800)),
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    if (_grabando) await _pararGrabacion();
                    if (mounted) Navigator.pop(context);
                  },
                  child: Icon(Icons.close, size: 18, color: AppTheme.subtitleColor),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            Divider(height: 1, color: AppTheme.cardBorder),

            // Lista de notas
            if (_notas.isEmpty && !_grabando)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('Sin notas grabadas', style: TextStyle(color: AppTheme.subtitleColor, fontSize: 12)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _notas.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.cardBorder),
                  itemBuilder: (_, i) {
                    final nota = _notas[i];
                    final playing = _reproduciendo == nota.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => _togglePlay(nota),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: playing
                                  ? const Color(0xFF2A7FF5).withOpacity(0.15)
                                  : AppTheme.darkText.withOpacity(0.06),
                            ),
                            child: Icon(
                              playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                              size: 18,
                              color: playing ? const Color(0xFF2A7FF5) : AppTheme.darkText.withOpacity(0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_fmtFecha(nota.fecha),
                              style: TextStyle(color: AppTheme.darkText, fontSize: 11, fontWeight: FontWeight.w600)),
                          Text(_fmtSeg(nota.duracionSegundos),
                              style: TextStyle(color: AppTheme.subtitleColor, fontSize: 10)),
                        ])),
                        GestureDetector(
                          onTap: () => _eliminar(nota),
                          child: Icon(Icons.delete_outline, size: 16, color: AppTheme.subtitleColor),
                        ),
                      ]),
                    );
                  },
                ),
              ),

            Divider(height: 1, color: AppTheme.cardBorder),

            // Botón grabar
            Padding(
              padding: const EdgeInsets.all(14),
              child: GestureDetector(
                onTap: _grabando ? _pararGrabacion : _iniciarGrabacion,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 44,
                  decoration: BoxDecoration(
                    color: _grabando
                        ? Colors.redAccent.withOpacity(0.15)
                        : const Color(0xFF2A7FF5).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _grabando ? Colors.redAccent.withOpacity(0.5) : const Color(0xFF2A7FF5).withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(
                      _grabando ? Icons.stop_circle_outlined : Icons.mic_rounded,
                      size: 16,
                      color: _grabando ? Colors.redAccent : const Color(0xFF2A7FF5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _grabando ? 'Detener  ${_fmtSeg(_segGrabando)}' : 'Grabar nota',
                      style: TextStyle(
                        color: _grabando ? Colors.redAccent : const Color(0xFF2A7FF5),
                        fontSize: 13, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
