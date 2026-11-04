import 'dart:ui' show SemanticsAction;

import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:ayyam/features/life/presentation/life_dots_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens with today visible in the virtualized scrollable grid', (
    tester,
  ) async {
    final start = DateTime(2025, 1, 1);
    final days = <LifeDot>[
      for (var index = 0; index < 800; index++)
        LifeDot(
          date: DateTime(start.year, start.month, start.day + index),
          state: index > 600 ? LifeDotState.remaining : LifeDotState.unrecorded,
          isToday: index == 600,
          estimated: false,
        ),
    ];

    await tester.pumpWidget(
      _Harness(
        child: LifeDotsView(
          years: <LifeYear>[LifeYear(age: 0, days: days)],
          selectedDate: days[600].date,
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('life-dot-today')), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byKey(const ValueKey('life-dots-800')), findsOneWidget);
    expect(find.byType(CustomPaint).evaluate().length, lessThan(20));
  });

  testWidgets('selects adjacent days with keyboard and semantics actions', (
    tester,
  ) async {
    final days = <LifeDot>[
      LifeDot(
        date: DateTime(2026, 11, 2),
        state: LifeDotState.completed,
        isToday: false,
        estimated: false,
      ),
      LifeDot(
        date: DateTime(2026, 11, 3),
        state: LifeDotState.missed,
        isToday: true,
        estimated: false,
      ),
      LifeDot(
        date: DateTime(2026, 11, 4),
        state: LifeDotState.remaining,
        isToday: false,
        estimated: false,
      ),
    ];
    LifeDot? selected;

    await tester.pumpWidget(
      _Harness(
        child: LifeDotsView(
          years: <LifeYear>[LifeYear(age: 0, days: days)],
          selectedDate: days[1].date,
          onSelected: (dot) => selected = dot,
        ),
      ),
    );

    FocusScope.of(tester.element(find.byType(LifeDotsView))).nextFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);

    expect(selected?.date, DateTime(2026, 11, 4));
    final semantics = tester
        .getSemantics(
          find.bySemanticsLabel(
            'Life in Dots, one dot for every day across 100 years',
          ),
        )
        .getSemanticsData();
    expect(semantics.value, contains('2026-11-03, prayers missed'));
    expect(semantics.hasAction(SemanticsAction.increase), isTrue);
    expect(semantics.hasAction(SemanticsAction.decrease), isTrue);
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
