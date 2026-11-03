import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_field.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_picker.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/routes/nocturne_page_route.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/dua/application/dua_library_service.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/features/dua/presentation/dua_detail_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum _LibraryTab { history, collection }

class DuaLibraryScreen extends ConsumerStatefulWidget {
  const DuaLibraryScreen({super.key});

  @override
  ConsumerState<DuaLibraryScreen> createState() => _DuaLibraryScreenState();
}

class _DuaLibraryScreenState extends ConsumerState<DuaLibraryScreen> {
  _LibraryTab _tab = _LibraryTab.history;
  late DateTime _selectedDay;
  late final TextEditingController _searchController;
  DuaSourceFilter _sourceFilter = DuaSourceFilter.all;
  String? _occasion;

  @override
  void initState() {
    super.initState();
    _selectedDay = _dateOnly(ref.read(duaLibraryTodayProvider));
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final library = ref.watch(duaLibraryProvider);
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
                  onTap: () => Navigator.of(context).maybePop(),
                  semanticLabel: 'Back',
                  size: 38,
                ),
                const Spacer(),
                Text('LIBRARY / 002', style: NocturneType.label(theme.muted)),
              ],
            ),
            const SizedBox(height: NocturneSpace.x5),
            Expanded(
              child: library.when(
                data: (value) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Keep the\nrecord.',
                        style: NocturneType.hero(theme.ink, size: 50),
                      ),
                      const SizedBox(height: NocturneSpace.x3),
                      Text(
                        'Move through earlier days, revisit every recited dua, and keep the streak honest.',
                        style: NocturneType.body(theme.muted),
                      ),
                      const SizedBox(height: NocturneSpace.x6),
                      _StatsRow(stats: value.stats),
                      const SizedBox(height: NocturneSpace.x6),
                      _TabSelector(
                        tab: _tab,
                        onChanged: (tab) => setState(() => _tab = tab),
                      ),
                      const SizedBox(height: NocturneSpace.x6),
                      if (_tab == _LibraryTab.history)
                        _buildHistory(value)
                      else
                        _buildCollection(value),
                      const SizedBox(height: NocturneSpace.x5),
                    ],
                  ),
                ),
                error: (error, stackTrace) => _LibraryError(
                  onRetry: () => ref.invalidate(duaLibraryProvider),
                ),
                loading: () => const _LibraryLoading(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory(DuaLibrary library) {
    final today = library.today;
    final selected = _selectedDay.isAfter(today) ? today : _selectedDay;
    final dua = library.assignedTo(selected);
    final earliest = library.history.isEmpty
        ? DateTime(today.year - 1, today.month, today.day)
        : _dateOnly(library.history.last.assignedDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity < -50) {
              _selectOlder(earliest);
            } else if (velocity > 50) {
              _selectNewer(today);
            }
          },
          child: GlassCard(
            radius: NocturneRadius.medium,
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(
              children: <Widget>[
                CircleAction(
                  glyph: NocturneGlyph.chevronLeft,
                  onTap: selected.isAfter(earliest)
                      ? () => _selectOlder(earliest)
                      : null,
                  semanticLabel: 'Previous day',
                  size: 38,
                ),
                Expanded(
                  child: Pressable(
                    onTap: () =>
                        _pickDay(selected, minimum: earliest, maximum: today),
                    semanticLabel: 'Choose history date',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: <Widget>[
                          Text(
                            _dateLabel(selected),
                            style: NocturneType.bodyStrong(
                              NocturneScope.of(context).ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SWIPE OR OPEN CALENDAR',
                            style: NocturneType.label(
                              NocturneScope.of(context).faint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                CircleAction(
                  glyph: NocturneGlyph.arrowRight,
                  onTap: selected.isBefore(today)
                      ? () => _selectNewer(today)
                      : null,
                  semanticLabel: 'Next day',
                  size: 38,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: NocturneSpace.x3),
        if (dua == null)
          const _EmptyHistoryDay()
        else
          _HistoryCard(
            dua: dua,
            status: library.statusOf(dua),
            onTap: () => _openDua(dua),
          ),
        const SizedBox(height: NocturneSpace.x8),
        Text(
          'RECENT DAYS',
          style: NocturneType.label(NocturneScope.of(context).muted),
        ),
        const SizedBox(height: NocturneSpace.x3),
        if (library.history.isEmpty)
          Text(
            'No daily duas have been assigned yet.',
            style: NocturneType.body(NocturneScope.of(context).muted),
          )
        else
          for (final item in library.history.take(30)) ...<Widget>[
            _HistoryListRow(
              dua: item,
              status: library.statusOf(item),
              onTap: () {
                setState(() => _selectedDay = _dateOnly(item.assignedDate));
                _openDua(item);
              },
            ),
            const SizedBox(height: NocturneSpace.x2),
          ],
      ],
    );
  }

  Widget _buildCollection(DuaLibrary library) {
    final results = library.searchCollection(
      query: _searchController.text,
      source: _sourceFilter,
      occasion: _occasion,
    );
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        NocturneField(
          controller: _searchController,
          label: 'Search collection',
          hint: 'Arabic, translation or source',
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: NocturneSpace.x5),
        Text('SOURCE TYPE', style: NocturneType.label(theme.muted)),
        const SizedBox(height: NocturneSpace.x2),
        Wrap(
          spacing: NocturneSpace.x2,
          runSpacing: NocturneSpace.x2,
          children: <Widget>[
            for (final filter in DuaSourceFilter.values)
              _FilterPill(
                label: switch (filter) {
                  DuaSourceFilter.all => 'All sources',
                  DuaSourceFilter.quran => 'Quran',
                  DuaSourceFilter.hadith => 'Hadith',
                },
                selected: _sourceFilter == filter,
                onTap: () => setState(() => _sourceFilter = filter),
              ),
          ],
        ),
        if (library.occasions.isNotEmpty) ...<Widget>[
          const SizedBox(height: NocturneSpace.x5),
          Text('OCCASION', style: NocturneType.label(theme.muted)),
          const SizedBox(height: NocturneSpace.x2),
          Wrap(
            spacing: NocturneSpace.x2,
            runSpacing: NocturneSpace.x2,
            children: <Widget>[
              _FilterPill(
                label: 'All occasions',
                selected: _occasion == null,
                onTap: () => setState(() => _occasion = null),
              ),
              for (final occasion in library.occasions)
                _FilterPill(
                  label: occasion,
                  selected: _occasion == occasion,
                  onTap: () => setState(() => _occasion = occasion),
                ),
            ],
          ),
        ],
        const SizedBox(height: NocturneSpace.x6),
        Row(
          children: <Widget>[
            Text('RECITED DUAS', style: NocturneType.label(theme.muted)),
            const Spacer(),
            Text(
              results.length.toString().padLeft(3, '0'),
              style: NocturneType.mono(theme.faint),
            ),
          ],
        ),
        const SizedBox(height: NocturneSpace.x3),
        if (results.isEmpty)
          GlassCard(
            child: Text(
              library.collection.isEmpty
                  ? 'Recited duas will collect here over time.'
                  : 'No recited dua matches these filters.',
              style: NocturneType.body(theme.muted),
            ),
          )
        else
          for (final dua in results) ...<Widget>[
            _CollectionCard(dua: dua, onTap: () => _openDua(dua)),
            const SizedBox(height: NocturneSpace.x3),
          ],
      ],
    );
  }

  void _selectOlder(DateTime earliest) {
    final next = _previousDay(_selectedDay);
    if (next.isBefore(earliest)) return;
    setState(() => _selectedDay = next);
  }

  void _selectNewer(DateTime today) {
    final next = _nextDay(_selectedDay);
    if (next.isAfter(today)) return;
    setState(() => _selectedDay = next);
  }

  Future<void> _pickDay(
    DateTime initial, {
    required DateTime minimum,
    required DateTime maximum,
  }) async {
    final picked = await showNocturneDatePicker(
      context,
      initialDate: initial,
      minimumDate: minimum,
      maximumDate: maximum,
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedDay = _dateOnly(picked));
  }

  void _openDua(Dua dua) {
    Navigator.of(context).push<void>(
      nocturnePageRoute<void>(
        const RouteSettings(name: '/dua/detail'),
        (_) => DuaDetailScreen(dua: dua),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final DuaStreakStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatCard(label: 'CURRENT', value: '${stats.current}'),
        ),
        const SizedBox(width: NocturneSpace.x2),
        Expanded(
          child: _StatCard(label: 'LONGEST', value: '${stats.longest}'),
        ),
        const SizedBox(width: NocturneSpace.x2),
        Expanded(
          child: _StatCard(
            label: 'COLLECTED',
            value: '${stats.totalCollected}',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: <Widget>[
          Text(value, style: NocturneType.title(theme.ink)),
          const SizedBox(height: NocturneSpace.x1),
          Text(label, style: NocturneType.label(theme.faint)),
        ],
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.tab, required this.onChanged});

  final _LibraryTab tab;
  final ValueChanged<_LibraryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _TabButton(
            label: 'History',
            glyph: NocturneGlyph.calendar,
            selected: tab == _LibraryTab.history,
            onTap: () => onChanged(_LibraryTab.history),
          ),
        ),
        const SizedBox(width: NocturneSpace.x2),
        Expanded(
          child: _TabButton(
            label: 'Collection',
            glyph: NocturneGlyph.book,
            selected: tab == _LibraryTab.collection,
            onTap: () => onChanged(_LibraryTab.collection),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.glyph,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final NocturneGlyph glyph;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      tint: selected ? theme.accent : null,
      glow: selected,
      onTap: onTap,
      semanticLabel: label,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          NocturneIcon(
            glyph,
            size: 18,
            color: selected ? theme.accent : theme.muted,
          ),
          const SizedBox(width: NocturneSpace.x2),
          Text(
            label.toUpperCase(),
            style: NocturneType.label(selected ? theme.accent : theme.muted),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.dua,
    required this.status,
    required this.onTap,
  });

  final Dua dua;
  final DuaHistoryStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final color = _statusColor(theme, status);
    return GlassCard(
      tint: color,
      glow: status == DuaHistoryStatus.recited,
      onTap: onTap,
      semanticLabel: 'Open dua for ${_dateLabel(dua.assignedDate)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                (dua.occasion ?? 'Daily dua').toUpperCase(),
                style: NocturneType.label(color),
              ),
              const Spacer(),
              Text(_statusLabel(status), style: NocturneType.label(color)),
            ],
          ),
          const SizedBox(height: NocturneSpace.x4),
          Text(dua.translation, style: NocturneType.cardTitle(theme.ink)),
          const SizedBox(height: NocturneSpace.x3),
          Text(
            dua.sources.map((source) => source.displayLabel).join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: NocturneType.caption(theme.muted),
          ),
        ],
      ),
    );
  }
}

class _HistoryListRow extends StatelessWidget {
  const _HistoryListRow({
    required this.dua,
    required this.status,
    required this.onTap,
  });

  final Dua dua;
  final DuaHistoryStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final color = _statusColor(theme, status);
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      onTap: onTap,
      semanticLabel: 'Open ${_dateLabel(dua.assignedDate)} history',
      child: Row(
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: NocturneSpace.x3),
          SizedBox(
            width: 74,
            child: Text(
              _shortDateLabel(dua.assignedDate),
              style: NocturneType.label(theme.faint),
            ),
          ),
          Expanded(
            child: Text(
              dua.translation,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NocturneType.bodyStrong(theme.ink),
            ),
          ),
          const SizedBox(width: NocturneSpace.x2),
          NocturneIcon(NocturneGlyph.arrowRight, size: 16, color: theme.faint),
        ],
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.dua, required this.onTap});

  final Dua dua;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      tint: theme.kept,
      onTap: onTap,
      semanticLabel: 'Open collected dua ${dua.translation}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                (dua.occasion ?? 'Daily dua').toUpperCase(),
                style: NocturneType.label(theme.kept),
              ),
              const Spacer(),
              Text(
                _shortDateLabel(dua.assignedDate),
                style: NocturneType.label(theme.faint),
              ),
            ],
          ),
          const SizedBox(height: NocturneSpace.x4),
          Text(dua.translation, style: NocturneType.cardTitle(theme.ink)),
          const SizedBox(height: NocturneSpace.x3),
          Text(
            dua.sources.map((source) => source.displayLabel).join(' · '),
            style: NocturneType.caption(theme.muted),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
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
      semanticLabel: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? theme.ink : theme.glass,
          borderRadius: BorderRadius.circular(NocturneRadius.pill),
          border: Border.all(color: selected ? theme.ink : theme.lineStrong),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            label,
            style: NocturneType.caption(selected ? theme.canvas : theme.ink),
          ),
        ),
      ),
    );
  }
}

class _EmptyHistoryDay extends StatelessWidget {
  const _EmptyHistoryDay();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      child: Row(
        children: <Widget>[
          NocturneIcon(NocturneGlyph.calendar, color: theme.faint),
          const SizedBox(width: NocturneSpace.x3),
          Expanded(
            child: Text(
              'No dua was assigned to this day.',
              style: NocturneType.body(theme.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryLoading extends StatelessWidget {
  const _LibraryLoading();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Center(
      child: Text(
        'READING LOCAL HISTORY…',
        style: NocturneType.label(theme.muted),
      ),
    );
  }
}

class _LibraryError extends StatelessWidget {
  const _LibraryError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Center(
      child: GlassCard(
        onTap: onRetry,
        semanticLabel: 'Retry loading dua library',
        child: Text(
          'Local history could not be read. Tap to retry.',
          style: NocturneType.body(theme.muted),
        ),
      ),
    );
  }
}

Color _statusColor(NocturneThemeData theme, DuaHistoryStatus status) {
  return switch (status) {
    DuaHistoryStatus.recited => theme.kept,
    DuaHistoryStatus.recitedLate => theme.blue,
    DuaHistoryStatus.missed || DuaHistoryStatus.flagged => theme.missed,
    DuaHistoryStatus.pending => theme.pending,
  };
}

String _statusLabel(DuaHistoryStatus status) {
  return switch (status) {
    DuaHistoryStatus.recited => 'RECITED',
    DuaHistoryStatus.recitedLate => 'RECITED LATE',
    DuaHistoryStatus.missed => 'MISSED',
    DuaHistoryStatus.pending => 'READY',
    DuaHistoryStatus.flagged => 'HIDDEN',
  };
}

String _dateLabel(DateTime value) {
  const months = <String>[
    'JANUARY',
    'FEBRUARY',
    'MARCH',
    'APRIL',
    'MAY',
    'JUNE',
    'JULY',
    'AUGUST',
    'SEPTEMBER',
    'OCTOBER',
    'NOVEMBER',
    'DECEMBER',
  ];
  return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]} ${value.year}';
}

String _shortDateLabel(DateTime value) {
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
  return '${value.day.toString().padLeft(2, '0')} ${months[value.month - 1]}';
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _nextDay(DateTime value) =>
    DateTime(value.year, value.month, value.day + 1);

DateTime _previousDay(DateTime value) =>
    DateTime(value.year, value.month, value.day - 1);
