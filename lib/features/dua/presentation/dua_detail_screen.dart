import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/routes/nocturne_page_route.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/dua/application/dua_library_service.dart';
import 'package:ayyam/features/dua/application/dua_share_service.dart';
import 'package:ayyam/features/dua/application/today_dua_controller.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/features/dua/presentation/source_detail_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DuaDetailScreen extends ConsumerStatefulWidget {
  const DuaDetailScreen({super.key, required this.dua});

  final Dua dua;

  @override
  ConsumerState<DuaDetailScreen> createState() => _DuaDetailScreenState();
}

class _DuaDetailScreenState extends ConsumerState<DuaDetailScreen> {
  late Dua _dua;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dua = widget.dua;
  }

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final today = ref.watch(duaLibraryTodayProvider);
    final assigned = _dateOnly(_dua.assignedDate);
    final currentDay = _dateOnly(today);
    final canRecite =
        !_dua.isRecited && !_dua.flagged && !assigned.isAfter(currentDay);
    final isPast = assigned.isBefore(currentDay);

    return NocturneScaffold(
      tone: _dua.isRecited ? NocturneTone.kept : NocturneTone.rest,
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
                Text('DUA / 003', style: NocturneType.label(theme.muted)),
              ],
            ),
            const SizedBox(height: NocturneSpace.x6),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          _dateLabel(_dua.assignedDate),
                          style: NocturneType.label(theme.faint),
                        ),
                        const Spacer(),
                        Text(
                          _statusLabel(_dua, currentDay),
                          style: NocturneType.label(
                            _dua.flagged
                                ? theme.missed
                                : _dua.isRecited
                                ? theme.kept
                                : theme.pending,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: NocturneSpace.x3),
                    Text(
                      _dua.isRecited
                          ? 'Held in your\ncollection.'
                          : 'Return to the\nwording.',
                      style: NocturneType.hero(theme.ink, size: 48),
                    ),
                    const SizedBox(height: NocturneSpace.x6),
                    GlassCard(
                      glow: true,
                      tint: _dua.isRecited ? theme.kept : theme.pending,
                      padding: const EdgeInsets.all(NocturneSpace.x6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          if (_dua.occasion case final occasion?) ...<Widget>[
                            Text(
                              occasion.toUpperCase(),
                              style: NocturneType.label(theme.pending),
                            ),
                            const SizedBox(height: NocturneSpace.x4),
                          ],
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                _dua.arabic,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: theme.ink,
                                  fontSize: 31,
                                  height: 1.75,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: NocturneSpace.x5),
                          Text(
                            _dua.transliteration,
                            style: NocturneType.body(theme.muted).copyWith(
                              fontStyle: FontStyle.italic,
                              height: 1.55,
                            ),
                          ),
                          const SizedBox(height: NocturneSpace.x5),
                          ColoredBox(
                            color: theme.line,
                            child: const SizedBox(
                              width: double.infinity,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: NocturneSpace.x5),
                          Text(
                            _dua.translation,
                            style: NocturneType.title(theme.ink)
                                .copyWith(height: 1.25),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NocturneSpace.x6),
                    Text('CONTEXT', style: NocturneType.label(theme.muted)),
                    const SizedBox(height: NocturneSpace.x3),
                    Text(_dua.benefits, style: NocturneType.body(theme.muted)),
                    const SizedBox(height: NocturneSpace.x6),
                    Text('SOURCES', style: NocturneType.label(theme.muted)),
                    const SizedBox(height: NocturneSpace.x3),
                    for (
                      var index = 0;
                      index < _dua.sources.length;
                      index++
                    ) ...<Widget>[
                      _SourceCard(
                        source: _dua.sources[index],
                        onTap: () => _openSource(_dua.sources[index]),
                      ),
                      if (index != _dua.sources.length - 1)
                        const SizedBox(height: NocturneSpace.x2),
                    ],
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: NocturneSpace.x4),
                      Text(_error!, style: NocturneType.caption(theme.missed)),
                    ],
                    if (canRecite) ...<Widget>[
                      const SizedBox(height: NocturneSpace.x6),
                      NocturneButton(
                        label: _saving
                            ? 'Saving…'
                            : isPast
                            ? 'Recite and add to collection'
                            : 'Mark as recited',
                        trailing: NocturneGlyph.check,
                        onTap: _saving ? null : _markRecited,
                      ),
                      if (isPast) ...<Widget>[
                        const SizedBox(height: NocturneSpace.x2),
                        Text(
                          'A late recitation joins your collection but does not restore the streak for that day.',
                          style: NocturneType.caption(theme.faint),
                        ),
                      ],
                    ],
                    if (!_dua.flagged) ...<Widget>[
                      const SizedBox(height: NocturneSpace.x4),
                      NocturneButton(
                        label: 'Share this dua',
                        style: NocturneButtonStyle.glass,
                        trailing: NocturneGlyph.share,
                        onTap: () => shareDua(context, _dua),
                      ),
                      const SizedBox(height: NocturneSpace.x2),
                      Align(
                        alignment: Alignment.center,
                        child: Pressable(
                          onTap: _saving ? null : _reportIssue,
                          semanticLabel: 'Report an issue with this dua',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: NocturneSpace.x4,
                              vertical: NocturneSpace.x3,
                            ),
                            child: Text(
                              'REPORT AN ISSUE',
                              style: NocturneType.label(theme.missed),
                            ),
                          ),
                        ),
                      ),
                    ],
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

  Future<void> _markRecited() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(duaRepositoryProvider)
          .markRecited(_dua.id, DateTime.now());
      ref.invalidate(duaLibraryProvider);
      ref.invalidate(todayDuaProvider);
      if (!mounted) return;
      setState(() {
        _dua = updated;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not update this dua. Try again.';
      });
    }
  }

  Future<void> _reportIssue() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await ref.read(duaRepositoryProvider).flag(_dua.id);
      ref.invalidate(duaLibraryProvider);
      ref.invalidate(todayDuaProvider);
      if (!mounted) return;
      setState(() {
        _dua = updated;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not hide this dua. Try again.';
      });
    }
  }

  void _openSource(DuaSource source) {
    Navigator.of(context).push<void>(
      nocturnePageRoute<void>(
        const RouteSettings(name: '/dua/source'),
        (_) => SourceDetailScreen(source: source, dua: _dua),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.onTap});

  final DuaSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      onTap: onTap,
      semanticLabel: 'Open source ${source.collection} ${source.reference}',
      child: Row(
        children: <Widget>[
          NocturneIcon(NocturneGlyph.check, color: theme.kept),
          const SizedBox(width: NocturneSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  source.collection,
                  style: NocturneType.bodyStrong(theme.ink),
                ),
                Text(
                  source.reference,
                  style: NocturneType.caption(theme.muted),
                ),
              ],
            ),
          ),
          if (source.grading case final grading?)
            Text(grading.toUpperCase(), style: NocturneType.label(theme.kept)),
          const SizedBox(width: NocturneSpace.x2),
          NocturneIcon(NocturneGlyph.arrowRight, size: 17, color: theme.faint),
        ],
      ),
    );
  }
}

String _statusLabel(Dua dua, DateTime today) {
  if (dua.flagged) return 'HIDDEN';
  if (dua.isRecited) {
    final recitedAt = dua.recitedAt;
    final onAssignedDay =
        recitedAt != null &&
        _dateOnly(recitedAt.toLocal()) == _dateOnly(dua.assignedDate);
    return onAssignedDay ? 'RECITED' : 'RECITED LATE';
  }
  return _dateOnly(dua.assignedDate).isBefore(today) ? 'MISSED' : 'READY';
}

String _dateLabel(DateTime value) {
  const months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${value.day.toString().padLeft(2, '0')} '
      '${months[value.month - 1]} ${value.year}';
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
