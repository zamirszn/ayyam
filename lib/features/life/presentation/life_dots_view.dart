import 'package:ayyam/design/theme/nocturne_theme.dart';
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
  static const double _horizontalGap = 2.3;
  static const double _verticalGap = 5;
  static const double _padding = 10;
  static const double _canvasWidth = 366 * _horizontalGap + (_padding * 2);
  static const double _canvasHeight = 100 * _verticalGap + (_padding * 2);

  late final TransformationController _transformController;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController(
      Matrix4.diagonal3Values(0.42, 0.42, 1),
    );
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDot = _selectionForSemantics();
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
      hint: 'Pinch to zoom, tap a dot, or use left and right arrow keys to choose a day.',
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
        },
        actions: <Type, Action<Intent>>{
          _MoveDayIntent: CallbackAction<_MoveDayIntent>(
            onInvoke: (intent) {
              _moveSelection(intent.delta);
              return null;
            },
          ),
        },
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: _focused
                ? Border.all(color: NocturneScope.of(context).accent, width: 2)
                : null,
          ),
          child: SizedBox(
            height: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: InteractiveViewer(
                transformationController: _transformController,
                constrained: false,
                minScale: 0.32,
                maxScale: 5,
                boundaryMargin: const EdgeInsets.all(120),
                alignment: Alignment.topLeft,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) => _selectAt(details.localPosition),
                  child: SizedBox(
                    width: _canvasWidth,
                    height: _canvasHeight,
                    child: CustomPaint(
                      painter: _LifeDotsPainter(
                        years: widget.years,
                        selectedDate: widget.selectedDate,
                        theme: NocturneScope.of(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectAt(Offset position) {
    final row = ((position.dy - _padding) / _verticalGap).round();
    final column = ((position.dx - _padding) / _horizontalGap).round();
    if (row < 0 || row >= widget.years.length) return;
    final days = widget.years[row].days;
    if (column < 0 || column >= days.length) return;
    widget.onSelected(days[column]);
  }

  LifeDot? _selectionForSemantics() {
    final selectedDate = widget.selectedDate;
    LifeDot? first;
    LifeDot? today;
    for (final year in widget.years) {
      for (final dot in year.days) {
        first ??= dot;
        if (selectedDate != null && _sameDay(dot.date, selectedDate)) {
          return dot;
        }
        if (dot.isToday) today = dot;
      }
    }
    return today ?? first;
  }

  void _moveSelection(int delta) {
    final adjacent = _adjacentSelection(delta);
    if (adjacent != null) widget.onSelected(adjacent);
  }

  LifeDot? _adjacentSelection(int delta) {
    final current = _selectionForSemantics();
    if (current == null) return null;

    LifeDot? previous;
    var selectNext = false;
    for (final year in widget.years) {
      for (final dot in year.days) {
        if (selectNext) return dot;
        if (_sameDay(dot.date, current.date)) {
          if (delta < 0) return previous;
          if (delta > 0) selectNext = true;
        }
        previous = dot;
      }
    }
    return null;
  }
}

class _MoveDayIntent extends Intent {
  const _MoveDayIntent(this.delta);

  final int delta;
}

class _LifeDotsPainter extends CustomPainter {
  const _LifeDotsPainter({
    required this.years,
    required this.selectedDate,
    required this.theme,
  });

  static const double _horizontalGap = 2.3;
  static const double _verticalGap = 5;
  static const double _padding = 10;

  final List<LifeYear> years;
  final DateTime? selectedDate;
  final NocturneThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75;

    for (var row = 0; row < years.length; row++) {
      final days = years[row].days;
      final y = _padding + row * _verticalGap;
      for (var column = 0; column < days.length; column++) {
        final dot = days[column];
        final center = Offset(_padding + column * _horizontalGap, y);
        fill.color = _colorFor(dot);
        canvas.drawCircle(center, dot.estimated ? 0.7 : 0.82, fill);

        if (dot.isToday) {
          ring.color = theme.accent;
          ring.strokeWidth = 0.9;
          canvas.drawCircle(center, 1.65, ring);
        }
        if (selectedDate != null && _sameDay(dot.date, selectedDate!)) {
          ring.color = theme.ink;
          ring.strokeWidth = 0.75;
          canvas.drawCircle(center, 2.25, ring);
        }
      }
    }
  }

  Color _colorFor(LifeDot dot) {
    final base = switch (dot.state) {
      LifeDotState.unrecorded => theme.faint.withValues(alpha: 0.55),
      LifeDotState.completed => theme.kept,
      LifeDotState.missed => theme.missed,
      LifeDotState.repaid => theme.blue,
      LifeDotState.remaining => theme.faint.withValues(alpha: 0.18),
    };
    return dot.estimated ? base.withValues(alpha: 0.65) : base;
  }

  @override
  bool shouldRepaint(_LifeDotsPainter oldDelegate) {
    return oldDelegate.years != years ||
        oldDelegate.selectedDate != selectedDate ||
        oldDelegate.theme != theme;
  }
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
