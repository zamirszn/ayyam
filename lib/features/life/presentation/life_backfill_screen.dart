import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_picker.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/life/application/life_dashboard_controller.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LifeBackfillScreen extends ConsumerStatefulWidget {
  const LifeBackfillScreen({
    super.key,
    required this.dateOfBirth,
    required this.today,
  });

  final DateTime dateOfBirth;
  final DateTime today;

  @override
  ConsumerState<LifeBackfillScreen> createState() => _LifeBackfillScreenState();
}

class _LifeBackfillScreenState extends ConsumerState<LifeBackfillScreen> {
  late DateTime _start;
  late DateTime _end;
  PrayerDayStatus _status = PrayerDayStatus.completed;
  bool _saving = false;
  String? _error;

  DateTime get _yesterday =>
      DateTime(widget.today.year, widget.today.month, widget.today.day - 1);

  @override
  void initState() {
    super.initState();
    _end = _yesterday;
    final proposed = DateTime(_end.year, _end.month, _end.day - 6);
    _start = proposed.isBefore(widget.dateOfBirth)
        ? widget.dateOfBirth
        : proposed;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final count = _utc(_end).difference(_utc(_start)).inDays + 1;
    return NocturneScaffold(
      tone: NocturneTone.rest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NocturneSpace.gutter,
          NocturneSpace.x2,
          NocturneSpace.gutter,
          NocturneSpace.x5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAction(
                  glyph: NocturneGlyph.chevronLeft,
                  onTap: _saving
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  semanticLabel: 'Back',
                  size: 38,
                ),
                const Spacer(),
                Text('BACKFILL / 007', style: NocturneType.label(theme.muted)),
              ],
            ),
            const SizedBox(height: NocturneSpace.x6),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Mark a past\nrange.',
                      style: NocturneType.hero(theme.ink, size: 50),
                    ),
                    const SizedBox(height: NocturneSpace.x4),
                    Text(
                      'Use this only for dates you intentionally want to estimate. You can overwrite the range later.',
                      style: NocturneType.body(theme.muted),
                    ),
                    const SizedBox(height: NocturneSpace.x8),
                    NocturnePickerField(
                      label: 'From',
                      value: nocturneDateLabel(_start),
                      glyph: NocturneGlyph.calendar,
                      onTap: _pickStart,
                    ),
                    const SizedBox(height: NocturneSpace.x4),
                    NocturnePickerField(
                      label: 'To',
                      value: nocturneDateLabel(_end),
                      glyph: NocturneGlyph.calendar,
                      onTap: _pickEnd,
                    ),
                    const SizedBox(height: NocturneSpace.x6),
                    Text(
                      'RANGE STATUS',
                      style: NocturneType.label(theme.muted),
                    ),
                    const SizedBox(height: NocturneSpace.x3),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _StatusChoice(
                            label: 'All 5 prayed',
                            selected: _status == PrayerDayStatus.completed,
                            color: theme.kept,
                            onTap: () => setState(
                              () => _status = PrayerDayStatus.completed,
                            ),
                          ),
                        ),
                        const SizedBox(width: NocturneSpace.x2),
                        Expanded(
                          child: _StatusChoice(
                            label: 'Missed',
                            selected: _status == PrayerDayStatus.missed,
                            color: theme.missed,
                            onTap: () => setState(
                              () => _status = PrayerDayStatus.missed,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: NocturneSpace.x5),
                    GlassCard(
                      tint: _status == PrayerDayStatus.completed
                          ? theme.kept
                          : theme.missed,
                      child: Text(
                        '$count day${count == 1 ? '' : 's'} will be stored as an estimate.',
                        style: NocturneType.body(theme.muted),
                      ),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: NocturneSpace.x3),
                      Text(_error!, style: NocturneType.caption(theme.missed)),
                    ],
                    const SizedBox(height: NocturneSpace.x6),
                    NocturneButton(
                      label: _saving ? 'Saving…' : 'Apply range',
                      trailing: NocturneGlyph.check,
                      onTap: _saving ? null : _apply,
                    ),
                    const SizedBox(height: NocturneSpace.x5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart() async {
    final picked = await showNocturneDatePicker(
      context,
      initialDate: _start,
      minimumDate: widget.dateOfBirth,
      maximumDate: _end,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _start = picked;
      _error = null;
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showNocturneDatePicker(
      context,
      initialDate: _end,
      minimumDate: _start,
      maximumDate: _yesterday,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _end = picked;
      _error = null;
    });
  }

  Future<void> _apply() async {
    if (_end.isBefore(_start)) {
      setState(() => _error = 'The end date must follow the start date.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(lifeDashboardProvider.notifier)
          .backfill(start: _start, end: _end, status: _status);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this range. Try again.';
      });
    }
  }
}

class _StatusChoice extends StatelessWidget {
  const _StatusChoice({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : theme.glass,
          borderRadius: BorderRadius.circular(NocturneRadius.medium),
          border: Border.all(color: selected ? color : theme.lineStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: NocturneType.bodyStrong(selected ? color : theme.ink),
          ),
        ),
      ),
    );
  }
}

DateTime _utc(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
