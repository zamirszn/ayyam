import 'dart:math' as math;

import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

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
  static const int _columns = 7;
  static const double _rowExtent = 27;
  static const double _viewportHeight = 350;
  static const double _dotSize = 14;

  late List<LifeDot> _days;
  late ScrollController _scrollController;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _days = _flatten(widget.years);
    _scrollController = ScrollController(
      initialScrollOffset: _initialOffset(_days),
    );
  }

  @override
  void didUpdateWidget(LifeDotsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.years, widget.years)) {
      _days = _flatten(widget.years);
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
      hint: 'Scroll vertically, tap a dot, or use arrow keys to choose a day. Press Home to return to today.',
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
          SingleActivator(LogicalKeyboardKey.arrowDown): _MoveDayIntent(7),
          SingleActivator(LogicalKeyboardKey.arrowUp): _MoveDayIntent(-7),
          SingleActivator(LogicalKeyboardKey.home): _TodayIntent(),
        },
        actions: <Type, Action<Intent>>{
          _MoveDayIntent: CallbackAction<_MoveDayIntent>(
            onInvoke: (intent) {
              _moveSelection(intent.delta);
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
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: GridView.builder(
                      key: const ValueKey('life-dots-grid'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 18),
                      physics: const ClampingScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: _columns,
                            mainAxisExtent: _rowExtent,
                            crossAxisSpacing: 3,
                          ),
                      itemCount: _days.length,
                      itemBuilder: (context, index) {
                        final dot = _days[index];
                        return _LifeDotCell(
                          key: dot.isToday
                              ? const ValueKey('life-dot-today')
                              : null,
                          dot: dot,
                          selected:
                              widget.selectedDate != null &&
                              _sameDay(dot.date, widget.selectedDate!),
                          onTap: () => widget.onSelected(dot),
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
              ),
            ),
          ),
        ),
      ),
    );
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

  void _scrollToIndex(int index) {
    if (!_scrollController.hasClients) return;
    final row = index ~/ _columns;
    final target = row * _rowExtent - (_viewportHeight * 0.68);
    _scrollController.animateTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
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

  static double _initialOffset(List<LifeDot> days) {
    final todayIndex = days.indexWhere((dot) => dot.isToday);
    if (todayIndex < 0) return 0;
    final todayRow = todayIndex ~/ _columns;
    return math.max(0, todayRow * _rowExtent - (_viewportHeight * 0.68));
  }
}

class _LifeDotCell extends StatelessWidget {
  const _LifeDotCell({
    super.key,
    required this.dot,
    required this.selected,
    required this.onTap,
  });

  final LifeDot dot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final color = switch (dot.state) {
      LifeDotState.unrecorded => theme.faint.withValues(alpha: 0.55),
      LifeDotState.completed => theme.kept,
      LifeDotState.missed => theme.missed,
      LifeDotState.repaid => theme.blue,
      LifeDotState.remaining => theme.faint.withValues(alpha: 0.18),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: _describeDot(dot),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: dot.isToday || selected ? 20 : _LifeDotsViewState._dotSize,
            height: dot.isToday || selected ? 20 : _LifeDotsViewState._dotSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: dot.isToday || selected
                  ? Border.all(
                      color: selected ? theme.ink : theme.accent,
                      width: selected ? 2 : 1.5,
                    )
                  : null,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dot.estimated ? color.withValues(alpha: 0.65) : color,
              ),
              child: const SizedBox.square(
                dimension: _LifeDotsViewState._dotSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoveDayIntent extends Intent {
  const _MoveDayIntent(this.delta);

  final int delta;
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
