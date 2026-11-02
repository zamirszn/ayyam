import 'package:flutter/widgets.dart';

enum NocturneTone { pending, kept, missed, rest }

@immutable
class NocturneThemeData {
  const NocturneThemeData({
    required this.brightness,
    required this.canvas,
    required this.canvasRaised,
    required this.surface,
    required this.raised,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.line,
    required this.lineStrong,
    required this.glass,
    required this.glassStrong,
    required this.accent,
    required this.kept,
    required this.missed,
    required this.pending,
    required this.blue,
  });

  final Brightness brightness;
  final Color canvas;
  final Color canvasRaised;
  final Color surface;
  final Color raised;
  final Color ink;
  final Color muted;
  final Color faint;
  final Color line;
  final Color lineStrong;
  final Color glass;
  final Color glassStrong;
  final Color accent;
  final Color kept;
  final Color missed;
  final Color pending;
  final Color blue;

  bool get isDark => brightness == Brightness.dark;

  static const NocturneThemeData dark = NocturneThemeData(
    brightness: Brightness.dark,
    canvas: Color(0xFF08090B),
    canvasRaised: Color(0xFF111218),
    surface: Color(0xFF101116),
    raised: Color(0xFF17181F),
    ink: Color(0xFFF6F6F2),
    muted: Color(0xFFA2A5AE),
    faint: Color(0xFF63666F),
    line: Color(0x1FFFFFFF),
    lineStrong: Color(0x3DFFFFFF),
    glass: Color(0x12FFFFFF),
    glassStrong: Color(0x1FFFFFFF),
    accent: Color(0xFFE8FF3A),
    kept: Color(0xFF67F5B5),
    missed: Color(0xFFFF5C5C),
    pending: Color(0xFF8C7BFF),
    blue: Color(0xFF4CA6FF),
  );
}

class NocturneScope extends InheritedWidget {
  const NocturneScope({
    super.key,
    required this.theme,
    required this.tone,
    required super.child,
  });

  final NocturneThemeData theme;
  final NocturneTone tone;

  static NocturneThemeData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NocturneScope>()?.theme ??
        NocturneThemeData.dark;
  }

  static NocturneTone toneOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<NocturneScope>()?.tone ??
        NocturneTone.rest;
  }

  @override
  bool updateShouldNotify(NocturneScope oldWidget) {
    return oldWidget.theme != theme || oldWidget.tone != tone;
  }
}

abstract final class NocturneGradients {
  static const List<Color> pending = <Color>[
    Color(0xFF221551),
    Color(0xFF0C0A18),
    Color(0xFF07070B),
  ];

  static const List<Color> kept = <Color>[
    Color(0xFF0B4B36),
    Color(0xFF081713),
    Color(0xFF07090A),
  ];

  static const List<Color> missed = <Color>[
    Color(0xFF5A0D22),
    Color(0xFF1A070D),
    Color(0xFF0A0608),
  ];

  static const List<Color> rest = <Color>[
    Color(0xFF252830),
    Color(0xFF101116),
    Color(0xFF08090B),
  ];

  static List<Color> forTone(NocturneTone tone) => switch (tone) {
    NocturneTone.pending => pending,
    NocturneTone.kept => kept,
    NocturneTone.missed => missed,
    NocturneTone.rest => rest,
  };

  static Color glowFor(NocturneTone tone, NocturneThemeData theme) {
    return switch (tone) {
      NocturneTone.pending => theme.pending,
      NocturneTone.kept => theme.kept,
      NocturneTone.missed => theme.missed,
      NocturneTone.rest => theme.muted,
    };
  }
}
