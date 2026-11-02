import 'package:ayyam/design/motion/nocturne_motion.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

class NocturneSwitch extends StatelessWidget {
  const NocturneSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: onChanged != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onChanged?.call(!value);
              },
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: SingleMotionBuilder(
              value: value ? 1 : 0,
              motion: NocturneMotion.resolve(
                context,
                value ? NocturneMotion.release : NocturneMotion.press,
              ),
              builder: (context, animatedValue, child) {
                final progress = animatedValue.clamp(0.0, 1.0);
                return SizedBox(
                  width: 44,
                  height: 26,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.lerp(
                        theme.glassStrong,
                        theme.pending,
                        progress,
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.lineStrong),
                    ),
                    child: Align(
                      alignment: Alignment(-1 + (2 * progress), 0),
                      child: Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: theme.ink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
