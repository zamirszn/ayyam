import 'dart:ui' show Tristate;

import 'package:ayyam/design/components/nocturne_switch.dart';
import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('activates a pressable with the keyboard', (tester) async {
    var activations = 0;

    await tester.pumpWidget(
      _Harness(
        child: Pressable(
          semanticLabel: 'Continue',
          autofocus: true,
          onTap: () => activations++,
          child: const SizedBox(width: 120, height: 48),
        ),
      ),
    );

    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);

    expect(activations, 1);
    final semantics = tester
        .getSemantics(find.bySemanticsLabel('Continue'))
        .getSemanticsData();
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
    expect(semantics.flagsCollection.isButton, isTrue);
    expect(semantics.flagsCollection.isFocused, isNot(Tristate.none));
  });

  testWidgets('toggles a switch with the keyboard', (tester) async {
    var value = false;

    await tester.pumpWidget(
      _Harness(
        child: StatefulBuilder(
          builder: (context, setState) => NocturneSwitch(
            value: value,
            semanticLabel: 'Daily reminders',
            onChanged: (next) => setState(() => value = next),
          ),
        ),
      ),
    );

    FocusScope.of(tester.element(find.byType(NocturneSwitch))).nextFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(value, isTrue);
    final semantics = tester
        .getSemantics(find.bySemanticsLabel('Daily reminders'))
        .getSemanticsData();
    expect(semantics.hasAction(SemanticsAction.tap), isTrue);
    expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
    expect(semantics.flagsCollection.isFocused, isNot(Tristate.none));
  });
}

class _Harness extends StatelessWidget {
  const _Harness({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: NocturneThemeData.dark.canvas,
      builder: (context, _) => NocturneScope(
        theme: NocturneThemeData.dark,
        tone: NocturneTone.pending,
        child: Center(child: child),
      ),
    );
  }
}
