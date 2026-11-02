import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

abstract final class NocturneMotion {
  static const Motion enter = Motion.smoothSpring(
    duration: Duration(milliseconds: 620),
  );

  static const Motion enterFast = Motion.snappySpring(
    duration: Duration(milliseconds: 380),
  );

  static const Motion press = Motion.snappySpring(
    duration: Duration(milliseconds: 200),
    extraBounce: 0,
  );

  static const Motion release = Motion.bouncySpring(
    duration: Duration(milliseconds: 520),
    extraBounce: 0.06,
  );

  static const Motion fade = Motion.curved(
    Duration(milliseconds: 320),
    Curves.easeOutCubic,
  );

  static bool reduced(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static Motion resolve(BuildContext context, Motion motion) {
    return reduced(context) ? const Motion.none() : motion;
  }
}
