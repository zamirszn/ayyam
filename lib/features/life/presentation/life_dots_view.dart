import 'dart:math' as math;

import 'package:ayyam/design/motion/nocturne_motion.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

class LifeDotsView extends StatefulWidget {
  const LifeDotsView({
    super.key,
    required this.years,
    required this.selectedDate,
    required this.onSelected,
  });

  final List<LifeYear> years;
  final DateTime? selectedDate;
  final ValueChanged<LifeDot> onSelected;

  @override
  State<LifeDotsView> createState() => _LifeDotsViewState();
}

class _LifeDotsViewState extends State<LifeDotsView> {
  static const double _viewportHeight = 350;
  static const double _yearHeaderHeight = 28;

  late List<LifeDot> _days;
  late ScrollController _scrollController;
  bool _focused = false;
  bool _didInitialScroll = false;
  double _itemExtent = 150;
  int _columns = 28;

  @override
  void initState() {
    super.initState();
    _days = _flatten(widget.years);
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(LifeDotsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.years, widget.years)) {
      _days = _flatten(widget.years);
      _didInitialScroll = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDot = _selectionForSemantics();
    final theme = NocturneScope.of(context);
    return Semantics(
      container: true,
      focusable: true,
      focused: _focused,
      label: 'Life in Dots, one dot for every day across 100 years',
      value: selectedDot == null ? null : _describeDot(selectedDot),
      increasedValue: selectedDot == null
          ? null
          : _describeDot(_adjacentSelection(1) ?? selectedDot),
      decreasedValue: selectedDot == null
          ? null
          : _describeDot(_adjacentSelection(-1) ?? selectedDot),
      hint:
          '${_days.length} calendar days. Scroll by age, tap a dot, or use arrow keys. Press Home for today.',
      onIncrease: () => _moveSelection(1),
      onDecrease: () => _moveSelection(-1),
      child: FocusableActionDetector(
        onShowFocusHighlight: (focused) {
          if (_focused == focused) return;
          setState(() => _focused = focused);
        },
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.arrowRight): _MoveDayIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowLeft): _MoveDayIntent(-1),
          SingleActivator(LogicalKeyboardKey.arrowDown): _MoveRowIntent(1),
          SingleActivator(LogicalKeyboardKey.arrowUp): _MoveRowIntent(-1),
          SingleActivator(LogicalKeyboardKey.home): _TodayIntent(),
        },
        actions: <Type, Action<Intent>>{
          _MoveDayIntent: CallbackAction<_MoveDayIntent>(
            onInvoke: (intent) {
              _moveSelection(intent.delta);
              return null;
            },
          ),
          _MoveRowIntent: CallbackAction<_MoveRowIntent>(
            onInvoke: (intent) {
              _moveSelection(intent.direction * _columns);
              return null;
            },
          ),
          _TodayIntent: CallbackAction<_TodayIntent>(
            onInvoke: (_) {
              _selectToday();
              return null;
            },
          ),
        },
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: _focused ? Border.all(color: theme.accent, width: 2) : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: _viewportHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  _columns = (width / 11).floor().clamp(21, 32);
                  final cellExtent = width / _columns;
                  final longestYear = widget.years.fold<int>(
                    1,
                    (longest, year) => math.max(longest, year.days.length),
                  );
                  final rows = (longestYear / _columns).ceil();
                  _itemExtent = _yearHeaderHeight + (rows * cellExtent) + 12;
                  _scheduleInitialScroll();

                  return Stack(
                    children: <Widget>[
                      Positioned.fill(
                        child: ListView.builder(
                          key: ValueKey<String>('life-dots-${_days.length}'),
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 72),
                          physics: const ClampingScrollPhysics(),
                          itemExtent: _itemExtent,
                          itemCount: widget.years.length,
                          itemBuilder: (context, index) {
                            final year = widget.years[index];
                            final hasToday = year.days.any(
                              (dot) => dot.isToday,
                            );
                            final selectedInYear =
                                widget.selectedDate != null &&
                                year.days.any(
                                  (dot) =>
                                      _sameDay(dot.date, widget.selectedDate!),
                                );
                            final focused = selectedInYear || hasToday;

                            Widget buildCanvas(double reveal, double focus) {
                              return _LifeYearCanvas(
                                year: year,
                                columns: _columns,
                                cellExtent: cellExtent,
                                headerHeight: _yearHeaderHeight,
                                selectedDate: widget.selectedDate,
                                revealProgress: reveal,
                                focusProgress: focus,
                                onSelected: widget.onSelected,
                              );
                            }

                            final dots = NocturneMotion.reduced(context)
                                ? buildCanvas(1, focused ? 1 : 0)
                                : SingleMotionBuilder(
                                    key: ValueKey<String>(
                                      'life-dot-reveal-${year.age}',
                                    ),
                                    motion: NocturneMotion.enter,
                                    from: 0,
                                    value: 1,
                                    builder: (context, reveal, child) {
                                      return SingleMotionBuilder(
                                        key: ValueKey<String>(
                                          'life-dot-focus-${year.age}-${selectedInYear ? widget.selectedDate?.millisecondsSinceEpoch : hasToday}',
                                        ),
                                        motion: NocturneMotion.enterFast,
                                        from: 0,
                                        value: focused ? 1 : 0,
                                        builder: (context, focus, child) =>
                                            buildCanvas(reveal, focus),
                                      );
                                    },
                                  );
                            return RepaintBoundary(
                              key: hasToday
                                  ? const ValueKey('life-dot-today')
                                  : null,
                              child: dots,
                            );
                          },
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Semantics(
                          button: true,
                          label: 'Jump to today',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _selectToday,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: theme.canvas.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: theme.lineStrong),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'TODAY',
                                  style: NocturneType.label(theme.accent),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _scheduleInitialScroll() {
    if (_didInitialScroll) return;
    _didInitialScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final todayIndex = _days.indexWhere((dot) => dot.isToday);
      if (todayIndex >= 0) _jumpToIndex(todayIndex);
    });
  }

  void _selectToday() {
    final index = _days.indexWhere((dot) => dot.isToday);
    if (index < 0) return;
    widget.onSelected(_days[index]);
    _scrollToIndex(index);
  }

  void _moveSelection(int delta) {
    final current = _selectionForSemantics();
    if (current == null) return;
    final currentIndex = _days.indexWhere(
      (dot) => _sameDay(dot.date, current.date),
    );
    if (currentIndex < 0) return;
    final nextIndex = (currentIndex + delta).clamp(0, _days.length - 1);
    widget.onSelected(_days[nextIndex]);
    _scrollToIndex(nextIndex);
  }

  void _jumpToIndex(int index) {
    final target = _targetForIndex(index);
    _scrollController.jumpTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
    );
  }

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _targetForIndex(index)
          .clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  double _targetForIndex(int index) {
    var consumed = 0;
    for (var yearIndex = 0; yearIndex < widget.years.length; yearIndex++) {
      final next = consumed + widget.years[yearIndex].days.length;
      if (index < next) {
        return math.max(
          0,
          (yearIndex * _itemExtent) - (_viewportHeight - _itemExtent) / 2,
        );
      }
      consumed = next;
    }
    return 0;
  }

  LifeDot? _selectionForSemantics() {
    final selectedDate = widget.selectedDate;
    if (selectedDate != null) {
      for (final dot in _days) {
        if (_sameDay(dot.date, selectedDate)) return dot;
      }
    }
    for (final dot in _days) {
      if (dot.isToday) return dot;
    }
    return _days.isEmpty ? null : _days.first;
  }

  LifeDot? _adjacentSelection(int delta) {
    final current = _selectionForSemantics();
    if (current == null) return null;
    final index = _days.indexWhere((dot) => _sameDay(dot.date, current.date));
    if (index < 0) return null;
    final next = index + delta;
    return next < 0 || next >= _days.length ? null : _days[next];
  }

  static List<LifeDot> _flatten(List<LifeYear> years) =>
      List<LifeDot>.unmodifiable(years.expand((year) => year.days));
}

class _LifeYearCanvas extends StatelessWidget {
  const _LifeYearCanvas({
    required this.year,
    required this.columns,
    required this.cellExtent,
    required this.headerHeight,
    required this.selectedDate,
    required this.revealProgress,
    required this.focusProgress,
    required this.onSelected,
  });

  final LifeYear year;
  final int columns;
  final double cellExtent;
  final double headerHeight;
  final DateTime? selectedDate;
  final double revealProgress;
  final double focusProgress;
  final ValueChanged<LifeDot> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) {
        final y = details.localPosition.dy - headerHeight;
        if (y < 0) return;
        final column = (details.localPosition.dx / cellExtent).floor();
        final row = (y / cellExtent).floor();
        final index = (row * columns) + column;
        if (column < 0 || column >= columns || index >= year.days.length) {
          return;
        }
        onSelected(year.days[index]);
      },
      child: CustomPaint(
        painter: _LifeYearPainter(
          year: year,
          columns: columns,
          cellExtent: cellExtent,
          headerHeight: headerHeight,
          selectedDate: selectedDate,
          revealProgress: revealProgress,
          focusProgress: focusProgress,
          theme: theme,
        ),
      ),
    );
  }
}

class _LifeYearPainter extends CustomPainter {
  const _LifeYearPainter({
    required this.year,
    required this.columns,
    required this.cellExtent,
    required this.headerHeight,
    required this.selectedDate,
    required this.revealProgress,
    required this.focusProgress,
    required this.theme,
  });

  final LifeYear year;
  final int columns;
  final double cellExtent;
  final double headerHeight;
  final DateTime? selectedDate;
  final double revealProgress;
  final double focusProgress;
  final NocturneThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = revealProgress.clamp(0.0, 1.0);
    final focus = focusProgress.clamp(0.0, 1.0);
    final first = year.days.isEmpty ? null : year.days.first.date.year;
    final label = first == null
        ? 'AGE ${year.age}'
        : 'AGE ${year.age.toString().padLeft(2, '0')}  ·  $first';
    final labelPainter = TextPainter(
      text: TextSpan(text: label, style: NocturneType.label(theme.faint)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    labelPainter.paint(canvas, const Offset(2, 3));

    canvas.drawLine(
      Offset(labelPainter.width + 12, 10),
      Offset(size.width, 10),
      Paint()
        ..color = theme.line
        ..strokeWidth = 1,
    );

    for (var index = 0; index < year.days.length; index++) {
      final dot = year.days[index];
      final column = index % columns;
      final row = index ~/ columns;
      final center = Offset(
        (column * cellExtent) + (cellExtent / 2),
        headerHeight + (row * cellExtent) + (cellExtent / 2),
      );
      final color = switch (dot.state) {
        LifeDotState.unrecorded => theme.faint.withValues(alpha: 0.52),
        LifeDotState.completed => theme.kept,
        LifeDotState.missed => theme.missed,
        LifeDotState.repaid => theme.blue,
        LifeDotState.remaining => theme.faint.withValues(alpha: 0.14),
      };
      final selected =
          selectedDate != null && _sameDay(dot.date, selectedDate!);
      final highlighted = dot.isToday || selected;
      final baseRadius = math.min(3.1, cellExtent * 0.25);
      final dotReveal = _staggeredReveal(
        index: index,
        total: year.days.length,
        columns: columns,
        progress: reveal,
      );
      final revealScale = 0.45 + (dotReveal * 0.55);
      final focusedRadius = highlighted
          ? baseRadius * (1 + (focus * 0.22))
          : baseRadius;
      final radius = focusedRadius * revealScale;
      final resolvedColor = dot.estimated
          ? color.withValues(alpha: 0.58)
          : color;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = resolvedColor.withValues(
            alpha: resolvedColor.a * dotReveal,
          ),
      );
      if (highlighted) {
        canvas.drawCircle(
          center,
          radius + ((1.4 + (focus * 1.5)) * revealScale),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = selected ? 1.7 : 1.2
            ..color = (selected ? theme.ink : theme.accent).withValues(
              alpha: (0.55 + (focus * 0.45)) * dotReveal,
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_LifeYearPainter oldDelegate) {
    return oldDelegate.year != year ||
        oldDelegate.columns != columns ||
        oldDelegate.cellExtent != cellExtent ||
        oldDelegate.selectedDate != selectedDate ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.focusProgress != focusProgress ||
        oldDelegate.theme != theme;
  }
}

double _staggeredReveal({
  required int index,
  required int total,
  required int columns,
  required double progress,
}) {
  if (progress <= 0) return 0;
  if (progress >= 1 || total <= 1) return 1;

  final safeColumns = math.max(1, columns);
  final rows = (total / safeColumns).ceil();
  final column = index % safeColumns;
  final row = index ~/ safeColumns;
  final maxDiagonal = math.max(1, (safeColumns - 1) + (rows - 1));
  const staggerSpan = 0.45;
  final start = ((column + row) / maxDiagonal) * staggerSpan;
  final local = ((progress - start) / (1 - staggerSpan)).clamp(0.0, 1.0);
  return Curves.easeOutCubic.transform(local);
}

class _MoveDayIntent extends Intent {
  const _MoveDayIntent(this.delta);

  final int delta;
}

class _MoveRowIntent extends Intent {
  const _MoveRowIntent(this.direction);

  final int direction;
}

class _TodayIntent extends Intent {
  const _TodayIntent();
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _describeDot(LifeDot dot) {
  final state = switch (dot.state) {
    LifeDotState.unrecorded => 'unrecorded',
    LifeDotState.completed => 'all five prayers completed',
    LifeDotState.missed => 'prayers missed',
    LifeDotState.repaid => 'personal make-up completed',
    LifeDotState.remaining => 'future day',
  };
  final date =
      '${dot.date.year.toString().padLeft(4, '0')}-'
      '${dot.date.month.toString().padLeft(2, '0')}-'
      '${dot.date.day.toString().padLeft(2, '0')}';
  return '$date, $state${dot.estimated ? ', estimated' : ''}';
}
