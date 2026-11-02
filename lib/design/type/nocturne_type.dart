import 'package:flutter/widgets.dart';

abstract final class NocturneType {
  static TextStyle hero(Color color, {double size = 54}) => TextStyle(
    color: color,
    fontFamily: 'InstrumentSans',
    fontSize: size,
    height: 0.94,
    letterSpacing: -2.2,
    fontVariations: const <FontVariation>[FontVariation('wght', 680)],
  );

  static TextStyle display(Color color, {double size = 42}) => TextStyle(
    color: color,
    fontFamily: 'InstrumentSans',
    fontSize: size,
    height: 0.98,
    letterSpacing: -1.6,
    fontVariations: const <FontVariation>[FontVariation('wght', 680)],
  );

  static TextStyle title(Color color) => TextStyle(
    color: color,
    fontFamily: 'InstrumentSans',
    fontSize: 27,
    height: 1.05,
    letterSpacing: -0.8,
    fontVariations: const <FontVariation>[FontVariation('wght', 680)],
  );

  static TextStyle cardTitle(Color color) => TextStyle(
    color: color,
    fontFamily: 'InstrumentSans',
    fontSize: 19,
    height: 1.15,
    letterSpacing: -0.3,
    fontVariations: const <FontVariation>[FontVariation('wght', 560)],
  );

  static TextStyle body(Color color) => TextStyle(
    color: color,
    fontFamily: 'InstrumentSans',
    fontSize: 15,
    height: 1.4,
    letterSpacing: -0.1,
    fontVariations: const <FontVariation>[FontVariation('wght', 440)],
  );

  static TextStyle bodyStrong(Color color) => TextStyle(
    color: color,
    fontFamily: 'InstrumentSans',
    fontSize: 15,
    height: 1.35,
    letterSpacing: -0.1,
    fontVariations: const <FontVariation>[FontVariation('wght', 560)],
  );

  static TextStyle caption(Color color) => TextStyle(
    color: color,
    fontFamily: 'InstrumentSans',
    fontSize: 13,
    height: 1.35,
    fontVariations: const <FontVariation>[FontVariation('wght', 440)],
  );

  static TextStyle label(Color color) => TextStyle(
    color: color,
    fontFamily: 'SpaceMono',
    fontSize: 10,
    height: 1.2,
    letterSpacing: 1.5,
  );

  static TextStyle mono(Color color, {double size = 13}) => TextStyle(
    color: color,
    fontFamily: 'SpaceMono',
    fontSize: size,
    height: 1.3,
  );
}
