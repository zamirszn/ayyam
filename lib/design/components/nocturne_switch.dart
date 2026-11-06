import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/motion/nocturne_motion.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
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
    final trackOff = theme.isDark
        ? const Color(0x1FFFFFFF)
        : const Color(0x22000000);
    final thumbColor = value
        ? theme.canvas
        : (theme.isDark ? theme.ink : theme.raised);

    return Pressable(
      onTap: onChanged == null ? null : () => onChanged?.call(!value),
      semanticLabel: semanticLabel,
      button: false,
      toggled: value,
      scale: 0.98,
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
                    color: Color.lerp(trackOff, theme.accent, progress),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: theme.line, width: 1),
                  ),
                  child: Align(
                    alignment: Alignment(-1 + (2 * progress), 0),
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: thumbColor,
                        shape: BoxShape.circle,
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
