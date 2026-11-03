import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_nav_shell.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/routes/nocturne_page_route.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/dua/application/dua_reminder_platform.dart';
import 'package:ayyam/features/dua/application/dua_library_service.dart';
import 'package:ayyam/features/dua/application/today_dua_controller.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/features/dua/presentation/dua_library_screen.dart';
import 'package:ayyam/features/dua/presentation/source_detail_screen.dart';
import 'package:ayyam/features/life/application/life_dashboard_controller.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:ayyam/features/life/presentation/life_screen.dart';
import 'package:ayyam/features/settings/presentation/settings_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, required this.preferences});

  final AppPreferences preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(currentDateProvider);
    final selectedDay = ref.watch(selectedDuaDayProvider);
    final lifeReminderSelected = ref.watch(selectedLifeReminderProvider);
    if (lifeReminderSelected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ref.read(selectedLifeReminderProvider)) return;
        ref.read(selectedLifeReminderProvider.notifier).clear();
        if (context.mounted && preferences.lifeInDotsEnabled) {
          _openLife(context);
        }
      });
    }
    final library = preferences.duaEnabled
        ? ref.watch(duaLibraryProvider)
        : null;
    final duaState = preferences.duaEnabled
        ? ref.watch(todayDuaProvider)
        : null;
    final lifeDashboard = preferences.lifeInDotsEnabled
        ? ref.watch(lifeDashboardProvider)
        : null;
    final readyState = duaState?.value;
    final tone = switch (readyState) {
      TodayDuaReady(:final dua) =>
        dua.isRecited ? NocturneTone.kept : NocturneTone.pending,
      TodayDuaFlagged() => NocturneTone.missed,
      _ => NocturneTone.rest,
    };
    final theme = NocturneScope.of(context);

    return NocturneScaffold(
      tone: tone,
      includeBottomSafeArea: false,
      child: SizedBox.expand(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  NocturneSpace.gutter,
                  NocturneSpace.x2,
                  NocturneSpace.gutter,
                  NocturneSpace.navHeight + NocturneSpace.x10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    LayoutBuilder(
                      builder: (context, constraints) => Row(
                        children: <Widget>[
                          Text('AYYAM', style: NocturneType.label(theme.ink)),
                          const Spacer(),
                          if (constraints.maxWidth >= 360) ...<Widget>[
                            Text(
                              '${_shortDateLabel(today)} / (001)',
                              style: NocturneType.label(theme.muted),
                            ),
                            const SizedBox(width: NocturneSpace.x3),
                          ],
                          CircleAction(
                            glyph: NocturneGlyph.settings,
                            onTap: () => _openSettings(context),
                            semanticLabel: 'Open settings',
                            size: 38,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (selectedDay != null) ...<Widget>[
                      Pressable(
                        onTap: () =>
                            ref.read(selectedDuaDayProvider.notifier).clear(),
                        semanticLabel: 'Return to today',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'OPENED FROM REMINDER · RETURN TO TODAY',
                            style: NocturneType.label(theme.accent),
                          ),
                        ),
                      ),
                      const SizedBox(height: NocturneSpace.x3),
                    ],
                    _DailyOverview(
                      preferences: preferences,
                      duaState: duaState,
                      library: library,
                      lifeDashboard: lifeDashboard,
                      onOpenLibrary: () => _openLibrary(context),
                      onOpenLife: () => _openLife(context),
                      onMarkRecited:
                          readyState is TodayDuaReady &&
                              !readyState.dua.isRecited &&
                              readyState.canMarkRecited
                          ? () => ref
                                .read(todayDuaProvider.notifier)
                                .markRecited()
                          : null,
                    ),
                    const SizedBox(height: NocturneSpace.x10),
                    if (duaState != null)
                      duaState.when(
                        data: (state) => _DuaStateView(
                          state: state,
                          onRetry: () =>
                              ref.read(todayDuaProvider.notifier).retry(),
                          onOpenSettings: () => _openSettings(context),
                          onReportIssue: () =>
                              ref.read(todayDuaProvider.notifier).reportIssue(),
                        ),
                        error: (error, stackTrace) => _UnavailableDua(
                          message: 'Local storage could not be opened. Your settings and key were not changed.',
                          onRetry: () =>
                              ref.read(todayDuaProvider.notifier).retry(),
                        ),
                        loading: _LoadingDua.new,
                      )
                    else
                      const _LifeOnlyHeader(),
                    if (preferences.lifeInDotsEnabled) ...<Widget>[
                      const SizedBox(height: NocturneSpace.x8),
                      _LifePreview(
                        dashboard: lifeDashboard!,
                        onTap: () => _openLife(context),
                      ),
                    ],
                    const SizedBox(height: NocturneSpace.x8),
                    ColoredBox(
                      color: theme.line,
                      child: const SizedBox(width: double.infinity, height: 1),
                    ),
                    const SizedBox(height: NocturneSpace.x4),
                    Text(
                      'LOCAL FIRST / PRIVATE BY DEFAULT',
                      style: NocturneType.label(theme.faint),
                    ),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: NocturneNavShell(
                selectedIndex: 0,
                items: <NocturneNavItem>[
                  NocturneNavItem(
                    label: 'Today',
                    glyph: NocturneGlyph.calendar,
                    onTap: () {},
                  ),
                  NocturneNavItem(
                    label: preferences.lifeInDotsEnabled ? 'Life' : 'Library',
                    glyph: preferences.lifeInDotsEnabled
                        ? NocturneGlyph.dots
                        : NocturneGlyph.book,
                    semanticLabel: preferences.lifeInDotsEnabled
                        ? 'Open Life in Dots'
                        : 'Open dua library',
                    onTap: preferences.lifeInDotsEnabled
                        ? () => _openLife(context)
                        : () => _openLibrary(context),
                  ),
                  NocturneNavItem(
                    label: 'You',
                    glyph: NocturneGlyph.settings,
                    onTap: () => _openSettings(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push<void>(
      nocturnePageRoute<void>(
        const RouteSettings(name: '/settings'),
        (_) => SettingsScreen(initialPreferences: preferences),
      ),
    );
  }

  void _openLibrary(BuildContext context) {
    Navigator.of(context).push<void>(
      nocturnePageRoute<void>(
        const RouteSettings(name: '/dua/library'),
        (_) => const DuaLibraryScreen(),
      ),
    );
  }

  void _openLife(BuildContext context) {
    Navigator.of(context).push<void>(
      nocturnePageRoute<void>(
        const RouteSettings(name: '/life'),
        (_) => const LifeScreen(),
      ),
    );
  }

  static String _dateLabel(DateTime date) {
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
    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  static String _shortDateLabel(DateTime date) =>
      _dateLabel(date).substring(0, 6);
}

class _DailyOverview extends StatelessWidget {
  const _DailyOverview({
    required this.preferences,
    required this.duaState,
    required this.library,
    required this.lifeDashboard,
    required this.onOpenLibrary,
    required this.onOpenLife,
    required this.onMarkRecited,
  });

  final AppPreferences preferences;
  final AsyncValue<TodayDuaState>? duaState;
  final AsyncValue<DuaLibrary>? library;
  final AsyncValue<LifeDashboard>? lifeDashboard;
  final VoidCallback onOpenLibrary;
  final VoidCallback onOpenLife;
  final VoidCallback? onMarkRecited;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final currentDua = duaState?.asData?.value;
    final libraryValue = library?.asData?.value;
    final lifeValue = lifeDashboard?.asData?.value;
    final stats = libraryValue?.stats;
    final streak = stats?.current ?? 0;
    final assigned = stats?.totalAssigned ?? 0;
    final collected = stats?.totalCollected ?? 0;
    final rate = assigned == 0 ? 0.0 : collected / assigned;
    final percentage = (rate * 100).round();
    final recited = currentDua is TodayDuaReady && currentDua.dua.isRecited;
    final status = _duaStatus(currentDua, duaState?.isLoading ?? false);
    final statusColor = recited ? theme.kept : theme.pending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          preferences.duaEnabled ? _headline(currentDua) : 'A life in\ndays.',
          style: NocturneType.hero(theme.ink),
        ),
        const SizedBox(height: NocturneSpace.x3),
        Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 3,
              decoration: BoxDecoration(
                color: theme.accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: NocturneSpace.x3),
            Text(
              preferences.duaEnabled ? 'daily remembrance' : 'a life in days',
              style: NocturneType.body(theme.muted),
            ),
            const SizedBox(width: NocturneSpace.x3),
            Expanded(
              child: Text(
                preferences.duaEnabled
                    ? 'DAILY / ${_clock(preferences.reminderHour, preferences.reminderMinute)}'
                    : 'PRIVATE / LOCAL',
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NocturneType.label(theme.faint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 26),
        GlassCard(
          glow: true,
          tint: statusColor,
          padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          preferences.duaEnabled ? 'DAY STREAK' : 'DAYS LIVED',
                          style: NocturneType.label(theme.muted),
                        ),
                        const SizedBox(height: NocturneSpace.x3),
                        _DotMatrixNumber(
                          preferences.duaEnabled
                              ? streak
                              : lifeValue?.summary.daysLived ?? 0,
                          height: 54,
                          color: theme.ink,
                          dim: statusColor,
                        ),
                        const SizedBox(height: 14),
                        _StatusChip(label: status, color: statusColor),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      _VerticalRuler(
                        value: preferences.duaEnabled
                            ? rate
                            : lifeValue?.summary.percentLived ?? 0,
                        height: 86,
                        color: statusColor,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${preferences.duaEnabled ? percentage : ((lifeValue?.summary.percentLived ?? 0) * 100).round()}%',
                        style: NocturneType.title(theme.ink)
                            .copyWith(fontSize: 22),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preferences.duaEnabled ? 'RECITED' : 'LIVED',
                        style: NocturneType.label(theme.faint),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: NocturneSpace.x5),
              _DuaSparkline(library: libraryValue),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _DashboardStatTile(
                value: '$collected',
                label: 'duas collected',
                detail: 'of $assigned',
                color: theme.kept,
                onTap: preferences.duaEnabled ? onOpenLibrary : null,
                semanticLabel: 'View dua collection',
              ),
            ),
            const SizedBox(width: NocturneSpace.x3),
            Expanded(
              child: _PrayerDayTile(
                dashboard: lifeValue,
                loading: lifeDashboard?.isLoading ?? false,
                onTap: preferences.lifeInDotsEnabled ? onOpenLife : null,
              ),
            ),
          ],
        ),
        if (preferences.lifeInDotsEnabled) ...<Widget>[
          const SizedBox(height: NocturneSpace.x3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _DashboardStatTile(
                  value: lifeValue == null
                      ? '—'
                      : '${(lifeValue.summary.percentLived * 100).toStringAsFixed(1)}%',
                  label: 'life elapsed',
                  detail: lifeValue == null
                      ? 'loading'
                      : '${lifeValue.summary.daysRemaining} days remain',
                  color: theme.blue,
                  onTap: onOpenLife,
                  semanticLabel: 'View life progress',
                ),
              ),
              const SizedBox(width: NocturneSpace.x3),
              Expanded(child: _LifeWeekCard(dashboard: lifeValue)),
            ],
          ),
        ],
        const SizedBox(height: NocturneSpace.x5),
        Row(
          children: <Widget>[
            if (preferences.duaEnabled) ...<Widget>[
              CircleAction(
                glyph: NocturneGlyph.calendar,
                onTap: onOpenLibrary,
                semanticLabel: 'Open dua history',
                size: 48,
              ),
              const SizedBox(width: NocturneSpace.x3),
            ],
            Expanded(
              child: preferences.duaEnabled
                  ? NocturneButton(
                      label: recited ? 'Recited today' : 'Mark as recited',
                      trailing: NocturneGlyph.check,
                      style: recited
                          ? NocturneButtonStyle.glass
                          : NocturneButtonStyle.signal,
                      onTap: onMarkRecited,
                    )
                  : NocturneButton(
                      label: 'View your life',
                      semanticLabel: 'Open Life dashboard',
                      trailing: NocturneGlyph.arrowRight,
                      onTap: onOpenLife,
                    ),
            ),
            if (preferences.lifeInDotsEnabled &&
                preferences.duaEnabled) ...<Widget>[
              const SizedBox(width: NocturneSpace.x3),
              CircleAction(
                glyph: NocturneGlyph.dots,
                onTap: onOpenLife,
                semanticLabel: 'Open Life dashboard',
                foreground: theme.accent,
                size: 48,
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String _headline(TodayDuaState? state) => switch (state) {
    TodayDuaNeedsKey() => 'The key is\nmissing.',
    TodayDuaFlagged() => 'Hidden for\nreview.',
    TodayDuaUnavailable() => 'The day is\nwaiting.',
    TodayDuaDisabled() => 'A life in\ndays.',
    _ => 'A prayer for\ntoday.',
  };

  static String _duaStatus(TodayDuaState? state, bool loading) {
    if (loading) return 'Preparing today';
    return switch (state) {
      TodayDuaReady(:final dua) =>
        dua.isRecited ? 'Kept today' : 'Today is open',
      TodayDuaNeedsKey() => 'API key needed',
      TodayDuaFlagged() => 'Hidden locally',
      TodayDuaUnavailable() => 'Try again',
      TodayDuaDisabled() => 'Life tracking',
      null => 'Loading locally',
    };
  }

  static String _clock(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(NocturneRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: const SizedBox.square(dimension: 5),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NocturneType.label(color).copyWith(letterSpacing: 1.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardStatTile extends StatelessWidget {
  const _DashboardStatTile({
    required this.value,
    required this.label,
    required this.detail,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
  });

  final String value;
  final String label;
  final String detail;
  final Color color;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: SizedBox(
        height: 82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: const SizedBox.square(dimension: 6),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NocturneType.label(theme.muted),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NocturneType.title(theme.ink).copyWith(fontSize: 30),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: NocturneType.mono(theme.faint, size: 9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrayerDayTile extends StatelessWidget {
  const _PrayerDayTile({
    required this.dashboard,
    required this.loading,
    required this.onTap,
  });

  final LifeDashboard? dashboard;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final entry = dashboard?.todayEntry;
    final color = switch (entry?.status) {
      PrayerDayStatus.completed => theme.kept,
      PrayerDayStatus.missed => theme.missed,
      null => theme.pending,
    };
    final status = loading
        ? 'Loading'
        : switch (entry?.status) {
            PrayerDayStatus.completed => 'Complete',
            PrayerDayStatus.missed => 'Missed',
            null => 'Open',
          };
    final detail = dashboard == null
        ? 'Life disabled'
        : '${dashboard!.summary.outstandingDebts} make-up';
    return _DashboardStatTile(
      value: status,
      label: 'prayer day',
      detail: detail,
      color: color,
      onTap: onTap,
      semanticLabel: 'Open prayer reflection',
    );
  }
}

class _LifeWeekCard extends StatelessWidget {
  const _LifeWeekCard({required this.dashboard});

  final LifeDashboard? dashboard;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final today = dashboard?.today ?? DateTime.now();
    final byDay = <String, PrayerDay>{
      for (final entry in dashboard?.prayerDays ?? const <PrayerDay>[])
        _dayKey(entry.day): entry,
    };
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: SizedBox(
        height: 90,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Text('THIS WEEK', style: NocturneType.label(theme.muted)),
            ),
            const Spacer(),
            Row(
              children: <Widget>[
                for (var offset = 6; offset >= 0; offset--)
                  Expanded(
                    child: _WeekDay(
                      date: DateTime(
                        today.year,
                        today.month,
                        today.day - offset,
                      ),
                      entry:
                          byDay[_dayKey(
                            DateTime(
                              today.year,
                              today.month,
                              today.day - offset,
                            ),
                          )],
                      isToday: offset == 0,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDay extends StatelessWidget {
  const _WeekDay({
    required this.date,
    required this.entry,
    required this.isToday,
  });

  final DateTime date;
  final PrayerDay? entry;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    const initials = <String>['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final color = switch (entry?.status) {
      PrayerDayStatus.completed => theme.kept,
      PrayerDayStatus.missed => theme.missed,
      null => theme.faint,
    };
    return Column(
      children: <Widget>[
        Text(
          initials[date.weekday - 1],
          style: NocturneType.label(theme.faint),
        ),
        const SizedBox(height: 7),
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: entry == null ? color.withValues(alpha: 0.12) : color,
            border: Border.all(
              color: isToday ? theme.ink : color.withValues(alpha: 0.5),
              width: isToday ? 1.5 : 1,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${date.day}',
          style: NocturneType.mono(isToday ? theme.ink : theme.faint, size: 9),
        ),
      ],
    );
  }
}

class _DuaSparkline extends StatelessWidget {
  const _DuaSparkline({required this.library});

  final DuaLibrary? library;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final today = library?.today ?? DateTime.now();
    return SizedBox(
      height: 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (var offset = 6; offset >= 0; offset--)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.5),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Builder(
                    builder: (context) {
                      final date = DateTime(
                        today.year,
                        today.month,
                        today.day - offset,
                      );
                      final dua = library?.assignedTo(date);
                      final recited = dua?.isRecited ?? false;
                      final missed = dua != null && !recited && offset > 0;
                      final color = recited
                          ? theme.kept
                          : missed
                          ? theme.missed
                          : theme.pending;
                      return AnimatedContainer(
                        duration: NocturneDuration.base,
                        height: recited
                            ? 34
                            : missed
                            ? 18
                            : offset == 0
                            ? 11
                            : 5,
                        decoration: BoxDecoration(
                          color: color.withValues(
                            alpha: recited || missed ? 0.85 : 0.16,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VerticalRuler extends StatelessWidget {
  const _VerticalRuler({
    required this.value,
    required this.height,
    required this.color,
  });

  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 26,
    height: height,
    child: CustomPaint(
      painter: _VerticalRulerPainter(value: value.clamp(0, 1), color: color),
    ),
  );
}

class _VerticalRulerPainter extends CustomPainter {
  const _VerticalRulerPainter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const ticks = 28;
    final x = size.width - 1;
    for (var index = 0; index <= ticks; index++) {
      final fraction = index / ticks;
      final y = size.height * (1 - fraction);
      final major = index % 4 == 0;
      canvas.drawLine(
        Offset(x - (major ? size.width * 0.72 : size.width * 0.4), y),
        Offset(x, y),
        Paint()
          ..color = fraction <= value ? color : color.withValues(alpha: 0.16)
          ..strokeWidth = major ? 1.4 : 1
          ..strokeCap = StrokeCap.round,
      );
    }
    final markerY = size.height * (1 - value);
    canvas.drawLine(
      Offset(0, markerY),
      Offset(size.width, markerY),
      Paint()
        ..color = color
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(_VerticalRulerPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.color != color;
}

class _DotMatrixNumber extends StatelessWidget {
  const _DotMatrixNumber(
    this.value, {
    required this.height,
    required this.color,
    required this.dim,
  });

  final int value;
  final double height;
  final Color color;
  final Color dim;

  @override
  Widget build(BuildContext context) {
    final digits = value.abs().toString();
    final cell = height / 7;
    return Semantics(
      label: '$value',
      child: SizedBox(
        width: digits.length * 5 * cell + (digits.length - 1) * cell * 1.25,
        height: height,
        child: CustomPaint(
          painter: _DotMatrixPainter(value: value, color: color, dim: dim),
        ),
      ),
    );
  }
}

class _DotMatrixPainter extends CustomPainter {
  const _DotMatrixPainter({
    required this.value,
    required this.color,
    required this.dim,
  });

  final int value;
  final Color color;
  final Color dim;

  static const Map<String, List<int>> _glyphs = <String, List<int>>{
    '0': <int>[0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E],
    '1': <int>[0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E],
    '2': <int>[0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F],
    '3': <int>[0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E],
    '4': <int>[0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02],
    '5': <int>[0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E],
    '6': <int>[0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E],
    '7': <int>[0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],
    '8': <int>[0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E],
    '9': <int>[0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.height / 7;
    var x = 0.0;
    for (final digit in value.abs().toString().split('')) {
      final glyph = _glyphs[digit]!;
      for (var row = 0; row < 7; row++) {
        for (var column = 0; column < 5; column++) {
          final on = (glyph[row] & (1 << (4 - column))) != 0;
          canvas.drawCircle(
            Offset(x + column * cell + cell / 2, row * cell + cell / 2),
            cell * (on ? 0.32 : 0.2),
            Paint()..color = on ? color : dim.withValues(alpha: 0.075),
          );
        }
      }
      x += cell * 6.25;
    }
  }

  @override
  bool shouldRepaint(_DotMatrixPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.dim != dim;
}

String _dayKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

class _DuaStateView extends StatelessWidget {
  const _DuaStateView({
    required this.state,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onReportIssue,
  });

  final TodayDuaState state;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  final VoidCallback onReportIssue;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      TodayDuaDisabled() => const SizedBox.shrink(),
      TodayDuaNeedsKey(:final rejected) => _NeedsKeyDua(
        rejected: rejected,
        onOpenSettings: onOpenSettings,
      ),
      TodayDuaReady(:final dua) => _ReadyDua(
        dua: dua,
        onReportIssue: onReportIssue,
      ),
      TodayDuaFlagged() => const _FlaggedDua(),
      TodayDuaUnavailable(:final message, :final canRetry) => _UnavailableDua(
        message: message,
        onRetry: canRetry ? onRetry : null,
      ),
    };
  }
}

class _LoadingDua extends StatelessWidget {
  const _LoadingDua();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionRule(index: '01', label: 'Today’s dua · preparing'),
        const SizedBox(height: NocturneSpace.x3),
        Text(
          'Checking local history, source requirements and today’s language.',
          style: NocturneType.body(theme.muted),
        ),
        const SizedBox(height: NocturneSpace.x6),
        GlassCard(
          glow: true,
          tint: theme.pending,
          child: Row(
            children: <Widget>[
              NocturneIcon(NocturneGlyph.book, color: theme.pending),
              const SizedBox(width: NocturneSpace.x4),
              Expanded(
                child: Text(
                  'PREPARING A SOURCED DUA',
                  style: NocturneType.label(theme.muted),
                ),
              ),
              Text('•••', style: NocturneType.mono(theme.faint)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NeedsKeyDua extends StatelessWidget {
  const _NeedsKeyDua({required this.rejected, required this.onOpenSettings});

  final bool rejected;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionRule(index: '01', label: 'Gemini connection'),
        const SizedBox(height: NocturneSpace.x3),
        Text(
          rejected
              ? 'Gemini no longer accepts the saved key. Replace or remove it in Settings.'
              : 'Add a Gemini API key to prepare a new sourced dua. Nothing is sent through an Ayyam server.',
          style: NocturneType.body(theme.muted),
        ),
        const SizedBox(height: NocturneSpace.x6),
        NocturneButton(
          label: 'Open settings',
          trailing: NocturneGlyph.arrowRight,
          onTap: onOpenSettings,
        ),
      ],
    );
  }
}

class _UnavailableDua extends StatelessWidget {
  const _UnavailableDua({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionRule(index: '01', label: 'Today’s dua · waiting'),
        const SizedBox(height: NocturneSpace.x3),
        Text(message, style: NocturneType.body(theme.muted)),
        if (onRetry != null) ...<Widget>[
          const SizedBox(height: NocturneSpace.x6),
          NocturneButton(
            label: 'Try again',
            style: NocturneButtonStyle.glass,
            trailing: NocturneGlyph.arrowRight,
            onTap: onRetry,
          ),
        ],
      ],
    );
  }
}

class _ReadyDua extends StatelessWidget {
  const _ReadyDua({required this.dua, required this.onReportIssue});

  final Dua dua;
  final VoidCallback onReportIssue;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionRule(
          index: '01',
          label: dua.isRecited
              ? 'Today’s dua · recited'
              : 'Today’s dua · ready',
        ),
        const SizedBox(height: NocturneSpace.x3),
        GlassCard(
          glow: true,
          tint: dua.isRecited ? theme.kept : theme.pending,
          padding: const EdgeInsets.all(NocturneSpace.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (dua.occasion case final occasion?) ...<Widget>[
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
                    dua.arabic,
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
                dua.transliteration,
                style: NocturneType.body(theme.muted)
                    .copyWith(fontStyle: FontStyle.italic, height: 1.55),
              ),
              const SizedBox(height: NocturneSpace.x5),
              ColoredBox(
                color: theme.line,
                child: const SizedBox(width: double.infinity, height: 1),
              ),
              const SizedBox(height: NocturneSpace.x5),
              Text(
                dua.translation,
                style: NocturneType.title(theme.ink).copyWith(height: 1.25),
              ),
            ],
          ),
        ),
        const SizedBox(height: NocturneSpace.x5),
        const _SectionRule(index: '02', label: 'Context'),
        const SizedBox(height: NocturneSpace.x3),
        Text(dua.benefits, style: NocturneType.body(theme.muted)),
        const SizedBox(height: NocturneSpace.x6),
        const _SectionRule(index: '03', label: 'Sources'),
        const SizedBox(height: NocturneSpace.x3),
        for (var index = 0; index < dua.sources.length; index++) ...<Widget>[
          _SourceRow(
            source: dua.sources[index],
            onTap: () => _openSource(context, dua.sources[index]),
          ),
          if (index != dua.sources.length - 1)
            const SizedBox(height: NocturneSpace.x2),
        ],
        const SizedBox(height: NocturneSpace.x5),
        GlassCard(
          radius: NocturneRadius.medium,
          tint: theme.muted,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              NocturneIcon(NocturneGlyph.lock, color: theme.muted),
              const SizedBox(width: NocturneSpace.x3),
              Expanded(
                child: Text(
                  'Generated with AI from the cited source. Verify the wording and attribution with a trusted source or qualified scholar.',
                  style: NocturneType.caption(theme.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: NocturneSpace.x2),
        Align(
          alignment: Alignment.center,
          child: Pressable(
            onTap: onReportIssue,
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
    );
  }

  void _openSource(BuildContext context, DuaSource source) {
    Navigator.of(context).push<void>(
      nocturnePageRoute<void>(
        const RouteSettings(name: '/dua/source'),
        (_) => SourceDetailScreen(source: source, dua: dua),
      ),
    );
  }
}

class _FlaggedDua extends StatelessWidget {
  const _FlaggedDua();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionRule(index: '01', label: 'Today’s dua · hidden'),
        const SizedBox(height: NocturneSpace.x3),
        Text(
          'This dua was flagged locally and will remain excluded from future daily generation.',
          style: NocturneType.body(theme.muted),
        ),
        const SizedBox(height: NocturneSpace.x6),
        GlassCard(
          tint: theme.missed,
          child: Row(
            children: <Widget>[
              NocturneIcon(NocturneGlyph.lock, color: theme.missed),
              const SizedBox(width: NocturneSpace.x3),
              Expanded(
                child: Text(
                  'The report stays on this device. No content was sent to Ayyam.',
                  style: NocturneType.caption(theme.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.onTap});

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
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.kept.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(NocturneRadius.small),
              border: Border.all(color: theme.kept.withValues(alpha: 0.26)),
            ),
            child: NocturneIcon(
              NocturneGlyph.check,
              size: 18,
              color: theme.kept,
            ),
          ),
          const SizedBox(width: NocturneSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  source.collection,
                  style: NocturneType.bodyStrong(theme.ink),
                ),
                const SizedBox(height: 2),
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

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      children: <Widget>[
        Text(value, style: NocturneType.title(theme.ink)),
        const SizedBox(height: NocturneSpace.x1),
        Text(label, style: NocturneType.label(theme.faint)),
      ],
    );
  }
}

class _LifeOnlyHeader extends StatelessWidget {
  const _LifeOnlyHeader();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionRule(index: '01', label: 'Daily reflection'),
        const SizedBox(height: NocturneSpace.x3),
        Text(
          'Your private prayer reflection is ready for its first daily check-in.',
          style: NocturneType.body(theme.muted),
        ),
      ],
    );
  }
}

class _LifePreview extends StatelessWidget {
  const _LifePreview({required this.dashboard, required this.onTap});

  final AsyncValue<LifeDashboard> dashboard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionRule(index: 'L1', label: 'Life in Dots'),
        const SizedBox(height: NocturneSpace.x3),
        GlassCard(
          onTap: onTap,
          semanticLabel: 'View the 100-year Life in Dots',
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: dashboard.when(
            data: (value) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      'THE 100-YEAR VIEW',
                      style: NocturneType.label(theme.muted),
                    ),
                    const Spacer(),
                    NocturneIcon(
                      NocturneGlyph.arrowRight,
                      size: 18,
                      color: theme.faint,
                    ),
                  ],
                ),
                const SizedBox(height: NocturneSpace.x3),
                Text(
                  value.todayEntry == null
                      ? 'Today is waiting for your reflection.'
                      : value.todayEntry!.status == PrayerDayStatus.completed
                      ? 'Today’s five prayers are recorded complete.'
                      : 'Today is recorded with missed prayers.',
                  style: NocturneType.cardTitle(theme.ink)
                      .copyWith(height: 1.25),
                ),
                const SizedBox(height: NocturneSpace.x4),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _PreviewStat(
                        value: '${value.summary.daysLived}',
                        label: 'DAYS LIVED',
                      ),
                    ),
                    Expanded(
                      child: _PreviewStat(
                        value: '${value.summary.completedDays}',
                        label: 'COMPLETE',
                      ),
                    ),
                    Expanded(
                      child: _PreviewStat(
                        value: '${value.summary.outstandingDebts}',
                        label: 'MAKE-UP',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            loading: () => Text(
              'READING YOUR PRIVATE LIFE VIEW…',
              style: NocturneType.label(theme.muted),
            ),
            error: (error, stackTrace) => Text(
              'Open Life in Dots to retry local records.',
              style: NocturneType.body(theme.muted),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionRule extends StatelessWidget {
  const _SectionRule({required this.index, required this.label});

  final String index;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Row(
      children: <Widget>[
        Text(index, style: NocturneType.label(theme.accent)),
        const SizedBox(width: NocturneSpace.x3),
        Expanded(
          child: ColoredBox(
            color: theme.line,
            child: const SizedBox(height: 1),
          ),
        ),
        const SizedBox(width: NocturneSpace.x3),
        Text(label.toUpperCase(), style: NocturneType.label(theme.muted)),
      ],
    );
  }
}
