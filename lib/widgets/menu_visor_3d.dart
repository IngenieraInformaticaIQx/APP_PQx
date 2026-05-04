import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:untitled/services/app_theme.dart';

class MenuVisor3D extends StatefulWidget {
  const MenuVisor3D({super.key});

  @override
  State<MenuVisor3D> createState() => _MenuVisor3DState();
}

class _MenuVisor3DState extends State<MenuVisor3D>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.8,
      maxScale: 2.8,
      boundaryMargin: const EdgeInsets.all(260),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _MenuVisor3DPainter(
              phase: _controller.value,
              dark: AppTheme.isDark.value,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _MenuVisor3DPainter extends CustomPainter {
  final double phase;
  final bool dark;

  const _MenuVisor3DPainter({required this.phase, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: dark
            ? const [Color(0xFF0B1426), Color(0xFF17223B)]
            : const [Color(0xFFF4F7FB), Color(0xFFE2EAF5)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final grid = Paint()
      ..color = dark
          ? Colors.white.withOpacity(0.055)
          : const Color(0xFF2A6FB6).withOpacity(0.10)
      ..strokeWidth = 1;
    const step = 34.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), grid);
    }
    for (double y = 0; y < size.height + size.width; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - size.width), grid);
    }

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + 14);
    final scale =
        math.min(size.width / 620, size.height / 520).clamp(0.55, 1.35).toDouble();
    canvas.scale(scale);
    canvas.rotate(math.sin(phase * math.pi * 2) * 0.035);

    _drawShadow(canvas);
    _drawBone(
      canvas,
      rect: const Rect.fromLTWH(-76, -250, 64, 250),
      color: const Color(0xFFE9EDF3),
      side: const Color(0xFFB8C1CF),
    );
    _drawBone(
      canvas,
      rect: const Rect.fromLTWH(36, -238, 42, 228),
      color: const Color(0xFFDDE5F0),
      side: const Color(0xFFAAB5C5),
    );
    _drawJoint(canvas, const Offset(-28, 6), 74, 44, const Color(0xFFE4E9F1));
    _drawJoint(canvas, const Offset(-38, 70), 150, 62, const Color(0xFFD9E0EA));
    _drawJoint(canvas, const Offset(44, 88), 170, 46, const Color(0xFFE8ECF3));
    _drawFootFront(canvas);

    canvas.restore();
  }

  void _drawShadow(Canvas canvas) {
    final p = Paint()
      ..color = Colors.black.withOpacity(dark ? 0.28 : 0.14)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    canvas.drawOval(const Rect.fromLTWH(-190, 98, 390, 74), p);
  }

  void _drawBone(Canvas canvas,
      {required Rect rect, required Color color, required Color side}) {
    final path = RRect.fromRectAndRadius(rect, const Radius.circular(28));
    canvas.drawRRect(
      path.shift(const Offset(12, 12)),
      Paint()..color = side.withOpacity(0.78),
    );
    canvas.drawRRect(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color, side],
        ).createShader(rect),
    );
    canvas.drawRRect(
      path.deflate(9),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withOpacity(0.45),
    );
  }

  void _drawJoint(Canvas canvas, Offset center, double width, double height,
      Color color) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    canvas.drawOval(
      rect.shift(const Offset(12, 12)),
      Paint()..color = const Color(0xFF9CA9BA).withOpacity(0.55),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color, const Color(0xFFAEB9C8)],
        ).createShader(rect),
    );
    canvas.drawOval(
      rect.deflate(8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withOpacity(0.42),
    );
  }

  void _drawFootFront(Canvas canvas) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F7FA), Color(0xFFC9D2DE), Color(0xFF9CA9BA)],
      ).createShader(const Rect.fromLTWH(-22, 100, 230, 96));

    final foot = Path()
      ..moveTo(-22, 118)
      ..cubicTo(20, 84, 104, 92, 178, 126)
      ..cubicTo(205, 139, 214, 164, 194, 178)
      ..cubicTo(144, 199, 34, 189, -24, 154)
      ..cubicTo(-42, 143, -40, 130, -22, 118)
      ..close();
    canvas.drawPath(
      foot.shift(const Offset(12, 12)),
      Paint()..color = const Color(0xFF9CA9BA).withOpacity(0.54),
    );
    canvas.drawPath(foot, paint);

    final toePaint = Paint()..color = Colors.white.withOpacity(0.35);
    for (var i = 0; i < 5; i++) {
      final x = 95 + i * 20.0;
      canvas.drawOval(Rect.fromLTWH(x, 134 + i * 2.5, 28, 18), toePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MenuVisor3DPainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.dark != dark;
  }
}
