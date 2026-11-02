import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_panel.dart';
import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:flutter/widgets.dart';

typedef NocturneTime = ({int hour, int minute});

String nocturneClockLabel(int hour, int minute) {
  final safeHour = hour % 24;
  final suffix = safeHour >= 12 ? 'PM' : 'AM';
  final displayHour = safeHour % 12 == 0 ? 12 : safeHour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}

String nocturneDateLabel(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')} / '
      '${date.month.toString().padLeft(2, '0')} / '
      '${date.year.toString().padLeft(4, '0')}';
}

Future<NocturneTime?> showNocturneTimePicker(
  BuildContext context, {
  required int hour,
  required int minute,
}) {
  return showNocturnePanel<NocturneTime>(
    context,
    (_) => _TimePickerPanel(hour: hour, minute: minute),
  );
}

Future<DateTime?> showNocturneDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  DateTime? maximumDate,
  DateTime? minimumDate,
}) {
  final today = _dateOnly(maximumDate ?? DateTime.now());
  final earliest = _dateOnly(minimumDate ?? DateTime(today.year - 100, 1, 1));
  final fallback = DateTime(today.year - 25, today.month, today.day);
  final selected = _dateOnly(initialDate ?? fallback);
  final safeInitial = selected.isBefore(earliest)
      ? earliest
      : (selected.isAfter(today) ? today : selected);

  return showNocturnePanel<DateTime>(
    context,
    (_) => _DatePickerPanel(
      initialDate: safeInitial,
      minimumDate: earliest,
      maximumDate: today,
    ),
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

class NocturnePickerField extends StatelessWidget {
  const NocturnePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.glyph,
    required this.onTap,
    this.helper,
    this.placeholder = false,
  });

  final String label;
  final String value;
  final NocturneGlyph glyph;
  final VoidCallback onTap;
  final String? helper;
  final bool placeholder;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: NocturneType.label(theme.muted)),
        const SizedBox(height: NocturneSpace.x2),
        GlassCard(
          radius: NocturneRadius.medium,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          onTap: onTap,
          semanticLabel: '$label, $value',
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.pending.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(NocturneRadius.small),
                  border: Border.all(
                    color: theme.pending.withValues(alpha: 0.26),
                  ),
                ),
                child: NocturneIcon(glyph, size: 18, color: theme.pending),
              ),
              const SizedBox(width: NocturneSpace.x3),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NocturneType.bodyStrong(
                    placeholder ? theme.faint : theme.ink,
                  ),
                ),
              ),
              const SizedBox(width: NocturneSpace.x2),
              NocturneIcon(
                NocturneGlyph.arrowRight,
                size: 17,
                color: theme.muted,
              ),
            ],
          ),
        ),
        if (helper != null) ...<Widget>[
          const SizedBox(height: NocturneSpace.x2),
          Text(helper!, style: NocturneType.caption(theme.faint)),
        ],
      ],
    );
  }
}

class _TimePickerPanel extends StatefulWidget {
  const _TimePickerPanel({required this.hour, required this.minute});

  final int hour;
  final int minute;

  @override
  State<_TimePickerPanel> createState() => _TimePickerPanelState();
}

class _TimePickerPanelState extends State<_TimePickerPanel> {
  static const double _itemExtent = 44;

  late int _hour12;
  late int _minute;
  late bool _pm;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  int get _hour24 {
    if (_hour12 == 12) return _pm ? 12 : 0;
    return _pm ? _hour12 + 12 : _hour12;
  }

  @override
  void initState() {
    super.initState();
    final safeHour = widget.hour % 24;
    _hour12 = safeHour % 12 == 0 ? 12 : safeHour % 12;
    _pm = safeHour >= 12;
    _minute = widget.minute.clamp(0, 59);
    _hourController = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return NocturnePanel(
      title: 'Reminder time',
      subtitle: 'Choose when the daily dua should arrive.',
      child: Column(
        children: <Widget>[
          Text(
            nocturneClockLabel(_hour24, _minute),
            style: NocturneType.hero(theme.ink, size: 46),
          ),
          const SizedBox(height: NocturneSpace.x2),
          Text(
            'LOCAL TIME · ON THIS DEVICE',
            style: NocturneType.label(theme.faint),
          ),
          const SizedBox(height: NocturneSpace.x5),
          Row(
            children: <Widget>[
              const Expanded(flex: 5, child: _WheelLabel('HOUR')),
              const SizedBox(width: NocturneSpace.x2),
              const Expanded(flex: 5, child: _WheelLabel('MINUTE')),
              const SizedBox(width: NocturneSpace.x5),
              const SizedBox(width: 72),
            ],
          ),
          const SizedBox(height: NocturneSpace.x2),
          SizedBox(
            height: _itemExtent * 3,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                IgnorePointer(
                  child: Container(
                    height: _itemExtent,
                    decoration: BoxDecoration(
                      color: theme.glassStrong,
                      borderRadius: BorderRadius.circular(NocturneRadius.small),
                      border: Border.symmetric(
                        horizontal: BorderSide(color: theme.line),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 5,
                      child: _PickerWheel(
                        controller: _hourController,
                        count: 12,
                        selected: _hour12 - 1,
                        label: (index) => '${index + 1}',
                        onChanged: (index) =>
                            setState(() => _hour12 = index + 1),
                      ),
                    ),
                    const SizedBox(width: NocturneSpace.x2),
                    Expanded(
                      flex: 5,
                      child: _PickerWheel(
                        controller: _minuteController,
                        count: 60,
                        selected: _minute,
                        label: (index) => index.toString().padLeft(2, '0'),
                        onChanged: (index) => setState(() => _minute = index),
                      ),
                    ),
                    const SizedBox(width: NocturneSpace.x5),
                    SizedBox(
                      width: 72,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _MeridiemPill(
                            label: 'AM',
                            selected: !_pm,
                            onTap: () => setState(() => _pm = false),
                          ),
                          const SizedBox(height: 6),
                          _MeridiemPill(
                            label: 'PM',
                            selected: _pm,
                            onTap: () => setState(() => _pm = true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: NocturneSpace.x5),
          NocturneButton(
            label: 'Set time',
            trailing: NocturneGlyph.check,
            onTap: () =>
                Navigator.of(context)
                    .pop<NocturneTime>((hour: _hour24, minute: _minute)),
          ),
        ],
      ),
    );
  }
}

class _DatePickerPanel extends StatefulWidget {
  const _DatePickerPanel({
    required this.initialDate,
    required this.minimumDate,
    required this.maximumDate,
  });

  final DateTime initialDate;
  final DateTime minimumDate;
  final DateTime maximumDate;

  @override
  State<_DatePickerPanel> createState() => _DatePickerPanelState();
}

class _DatePickerPanelState extends State<_DatePickerPanel> {
  static const double _itemExtent = 44;

  late int _day;
  late int _month;
  late int _year;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;

  int get _yearCount => widget.maximumDate.year - widget.minimumDate.year + 1;
  int get _daysInMonth => DateTime(_year, _month + 1, 0).day;
  DateTime get _selectedDate => DateTime(_year, _month, _day);
  bool get _valid =>
      !_selectedDate.isBefore(widget.minimumDate) &&
      !_selectedDate.isAfter(widget.maximumDate);

  @override
  void initState() {
    super.initState();
    _day = widget.initialDate.day;
    _month = widget.initialDate.month;
    _year = widget.initialDate.year;
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _yearController = FixedExtentScrollController(
      initialItem: _year - widget.minimumDate.year,
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  void _setMonth(int index) {
    setState(() {
      _month = index + 1;
      _clampDay();
    });
  }

  void _setYear(int index) {
    setState(() {
      _year = widget.minimumDate.year + index;
      _clampDay();
    });
  }

  void _clampDay() {
    final lastDay = _daysInMonth;
    if (_day <= lastDay) return;
    _day = lastDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_dayController.hasClients) _dayController.jumpToItem(_day - 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return NocturnePanel(
      title: 'Date of birth',
      subtitle: 'Used only on this device to anchor Life in Dots.',
      child: Column(
        children: <Widget>[
          Text(
            nocturneDateLabel(_selectedDate),
            style: NocturneType.display(theme.ink, size: 38),
          ),
          const SizedBox(height: NocturneSpace.x2),
          Text('DD / MM / YYYY', style: NocturneType.label(theme.faint)),
          const SizedBox(height: NocturneSpace.x5),
          const Row(
            children: <Widget>[
              Expanded(flex: 3, child: _WheelLabel('DAY')),
              SizedBox(width: NocturneSpace.x2),
              Expanded(flex: 3, child: _WheelLabel('MONTH')),
              SizedBox(width: NocturneSpace.x2),
              Expanded(flex: 5, child: _WheelLabel('YEAR')),
            ],
          ),
          const SizedBox(height: NocturneSpace.x2),
          SizedBox(
            height: _itemExtent * 3,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                IgnorePointer(
                  child: Container(
                    height: _itemExtent,
                    decoration: BoxDecoration(
                      color: theme.glassStrong,
                      borderRadius: BorderRadius.circular(NocturneRadius.small),
                      border: Border.symmetric(
                        horizontal: BorderSide(color: theme.line),
                      ),
                    ),
                  ),
                ),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: _PickerWheel(
                        controller: _dayController,
                        count: _daysInMonth,
                        selected: _day - 1,
                        label: (index) => '${index + 1}'.padLeft(2, '0'),
                        onChanged: (index) => setState(() => _day = index + 1),
                      ),
                    ),
                    const SizedBox(width: NocturneSpace.x2),
                    Expanded(
                      flex: 3,
                      child: _PickerWheel(
                        controller: _monthController,
                        count: 12,
                        selected: _month - 1,
                        label: (index) => '${index + 1}'.padLeft(2, '0'),
                        onChanged: _setMonth,
                      ),
                    ),
                    const SizedBox(width: NocturneSpace.x2),
                    Expanded(
                      flex: 5,
                      child: _PickerWheel(
                        controller: _yearController,
                        count: _yearCount,
                        selected: _year - widget.minimumDate.year,
                        label: (index) => '${widget.minimumDate.year + index}',
                        onChanged: _setYear,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!_valid) ...<Widget>[
            const SizedBox(height: NocturneSpace.x3),
            Text(
              'Choose today or an earlier date.',
              style: NocturneType.caption(theme.missed),
            ),
          ],
          const SizedBox(height: NocturneSpace.x5),
          NocturneButton(
            label: 'Set date',
            trailing: _valid ? NocturneGlyph.check : null,
            onTap: _valid
                ? () => Navigator.of(context).pop<DateTime>(_selectedDate)
                : null,
          ),
        ],
      ),
    );
  }
}

class _PickerWheel extends StatelessWidget {
  const _PickerWheel({
    required this.controller,
    required this.count,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final int selected;
  final String Function(int index) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _TimePickerPanelState._itemExtent,
      diameterRatio: 1.7,
      perspective: 0.002,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) {
          final active = index == selected;
          return Center(
            child: AnimatedDefaultTextStyle(
              duration: reduce ? Duration.zero : NocturneDuration.fast,
              curve: Curves.easeOutCubic,
              style: NocturneType.title(active ? theme.ink : theme.faint)
                  .copyWith(fontSize: 25, height: 1),
              child: Text(label(index)),
            ),
          );
        },
      ),
    );
  }
}

class _WheelLabel extends StatelessWidget {
  const _WheelLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Center(child: Text(label, style: NocturneType.label(theme.muted)));
  }
}

class _MeridiemPill extends StatelessWidget {
  const _MeridiemPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: NocturneDuration.fast,
        curve: Curves.easeOutCubic,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? theme.ink : theme.glass,
          borderRadius: BorderRadius.circular(NocturneRadius.pill),
          border: Border.all(color: selected ? theme.ink : theme.line),
        ),
        child: Text(
          label,
          style: NocturneType.label(selected ? theme.canvas : theme.muted),
        ),
      ),
    );
  }
}
