import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:flutter/widgets.dart';

enum NocturneGlyph {
  arrowRight,
  chevronLeft,
  check,
  plus,
  minus,
  book,
  dots,
  bell,
  lock,
  settings,
  close,
  calendar,
  clock,
}

class NocturneIcon extends StatelessWidget {
  const NocturneIcon(
    this.glyph, {
    super.key,
    this.size = 22,
    this.color,
    this.strokeWidth = 1.7,
    this.semanticLabel,
  });

  final NocturneGlyph glyph;
  final double size;
  final Color? color;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final icon = SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _NocturneIconPainter(
          glyph: glyph,
          color: color ?? NocturneScope.of(context).ink,
          strokeWidth: strokeWidth,
        ),
      ),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: icon)
        : Semantics(label: semanticLabel, child: icon);
  }
}

class _NocturneIconPainter extends CustomPainter {
  const _NocturneIconPainter({
    required this.glyph,
    required this.color,
    required this.strokeWidth,
  });

  final NocturneGlyph glyph;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale, scale);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();

    switch (glyph) {
      case NocturneGlyph.arrowRight:
        path
          ..moveTo(5, 12)
          ..lineTo(19, 12)
          ..moveTo(13, 6)
          ..lineTo(19, 12)
          ..lineTo(13, 18);
      case NocturneGlyph.chevronLeft:
        path
          ..moveTo(15, 5)
          ..lineTo(8, 12)
          ..lineTo(15, 19);
      case NocturneGlyph.check:
        path
          ..moveTo(5, 12.5)
          ..lineTo(9.5, 17)
          ..lineTo(19, 7);
      case NocturneGlyph.plus:
        path
          ..moveTo(5, 12)
          ..lineTo(19, 12)
          ..moveTo(12, 5)
          ..lineTo(12, 19);
      case NocturneGlyph.minus:
        path
          ..moveTo(5, 12)
          ..lineTo(19, 12);
      case NocturneGlyph.book:
        path
          ..moveTo(4, 5)
          ..quadraticBezierTo(8, 4, 12, 7)
          ..quadraticBezierTo(16, 4, 20, 5)
          ..lineTo(20, 18.5)
          ..quadraticBezierTo(16, 17.5, 12, 20)
          ..quadraticBezierTo(8, 17.5, 4, 18.5)
          ..close()
          ..moveTo(12, 7)
          ..lineTo(12, 20);
      case NocturneGlyph.dots:
        canvas
          ..drawCircle(
            const Offset(7, 12),
            1.5,
            paint..style = PaintingStyle.fill,
          )
          ..drawCircle(const Offset(12, 12), 1.5, paint)
          ..drawCircle(const Offset(17, 12), 1.5, paint);
        return;
      case NocturneGlyph.bell:
        path
          ..moveTo(6, 16)
          ..quadraticBezierTo(8, 14, 8, 10)
          ..quadraticBezierTo(8, 5, 12, 5)
          ..quadraticBezierTo(16, 5, 16, 10)
          ..quadraticBezierTo(16, 14, 18, 16)
          ..close()
          ..moveTo(10, 19)
          ..quadraticBezierTo(12, 21, 14, 19);
      case NocturneGlyph.lock:
        path
          ..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(5, 10, 14, 10),
              const Radius.circular(2),
            ),
          )
          ..moveTo(8, 10)
          ..lineTo(8, 7.5)
          ..quadraticBezierTo(8, 3, 12, 3)
          ..quadraticBezierTo(16, 3, 16, 7.5)
          ..lineTo(16, 10);
      case NocturneGlyph.settings:
        path
          ..moveTo(4, 7)
          ..lineTo(9, 7)
          ..moveTo(15, 7)
          ..lineTo(20, 7)
          ..moveTo(4, 17)
          ..lineTo(12, 17)
          ..moveTo(18, 17)
          ..lineTo(20, 17);
        canvas
          ..drawCircle(const Offset(12, 7), 3, paint)
          ..drawCircle(const Offset(15, 17), 3, paint);
        return;
      case NocturneGlyph.close:
        path
          ..moveTo(6, 6)
          ..lineTo(18, 18)
          ..moveTo(18, 6)
          ..lineTo(6, 18);
      case NocturneGlyph.calendar:
        path
          ..addRRect(
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(4, 5, 16, 15),
              const Radius.circular(2),
            ),
          )
          ..moveTo(8, 3)
          ..lineTo(8, 7)
          ..moveTo(16, 3)
          ..lineTo(16, 7)
          ..moveTo(4, 10)
          ..lineTo(20, 10);
      case NocturneGlyph.clock:
        canvas.drawCircle(const Offset(12, 12), 8, paint);
        path
          ..moveTo(12, 7)
          ..lineTo(12, 12)
          ..lineTo(15.5, 14);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_NocturneIconPainter oldDelegate) {
    return oldDelegate.glyph != glyph ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
