import 'package:ayyam/design/motion/nocturne_motion.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:flutter/widgets.dart';

PageRoute<T> nocturnePageRoute<T>(
  RouteSettings settings,
  WidgetBuilder builder,
) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: NocturneDuration.base,
    reverseTransitionDuration: NocturneDuration.fast,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (NocturneMotion.reduced(context)) return child;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.025),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
