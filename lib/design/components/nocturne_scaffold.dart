import 'package:ayyam/design/components/gradient_field.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:flutter/widgets.dart';

class NocturneScaffold extends StatelessWidget {
  const NocturneScaffold({
    super.key,
    required this.tone,
    required this.child,
    this.includeBottomSafeArea = true,
  });

  final NocturneTone tone;
  final Widget child;
  final bool includeBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return NocturneScope(
      theme: theme,
      tone: tone,
      child: GradientField(
        tone: tone,
        child: SafeArea(bottom: includeBottomSafeArea, child: child),
      ),
    );
  }
}
