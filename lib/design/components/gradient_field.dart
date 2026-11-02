import 'dart:math' as math;

import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:flutter/widgets.dart';

class GradientField extends StatelessWidget {
  const GradientField({super.key, required this.tone, required this.child});

  final NocturneTone tone;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final glow = NocturneGradients.glowFor(tone, theme);

    return ColoredBox(
      color: theme.canvas,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: NocturneGradients.forTone(tone),
            stops: const <double>[0, 0.48, 1],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(painter: _AtmospherePainter(glow)),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  const _AtmospherePainter(this.glow);

  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final auraCenter = Offset(size.width * 0.78, size.height * 0.22);
    final auraRadius = math.max(size.width, size.height) * 0.42;
    final auraRect = Rect.fromCircle(center: auraCenter, radius: auraRadius);
    final auraPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          glow.withValues(alpha: 0.16),
          glow.withValues(alpha: 0),
        ],
      ).createShader(auraRect);
    canvas.drawCircle(auraCenter, auraRadius, auraPaint);

    final horizonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = glow.withValues(alpha: 0.08);
    final horizonRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 1.03),
      width: size.width * 1.45,
      height: size.height * 0.34,
    );
    canvas.drawArc(horizonRect, math.pi, math.pi, false, horizonPaint);

    final grainPaint = Paint()..color = const Color(0x09FFFFFF);
    for (var y = 10; y < size.height; y += 18) {
      for (var x = 8; x < size.width; x += 18) {
        if (((x * 31) + (y * 17)) % 7 == 0) {
          canvas.drawCircle(
            Offset(x.toDouble(), y.toDouble()),
            0.65,
            grainPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      oldDelegate.glow != glow;
}
