import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/design/components/nocturne_nav_shell.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/features/life/presentation/life_screen.dart';
import 'package:ayyam/features/life/presentation/makeup_screen.dart';
import 'package:ayyam/features/settings/presentation/settings_screen.dart';
import 'package:ayyam/features/today/presentation/today_screen.dart';
import 'package:flutter/widgets.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key, required this.preferences});

  final AppPreferences preferences;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  void _select(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TodayScreen(
        key: const PageStorageKey<String>('today-tab'),
        preferences: widget.preferences,
        showNavigation: false,
        onSelectTab: _select,
      ),
      LifeScreen(
        key: const PageStorageKey<String>('life-tab'),
        embedded: true,
        onOpenMakeup: () => _select(2),
      ),
      const MakeupScreen(
        key: PageStorageKey<String>('makeup-tab'),
        embedded: true,
      ),
      SettingsScreen(
        key: const PageStorageKey<String>('you-tab'),
        initialPreferences: widget.preferences,
        embedded: true,
      ),
    ];

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: IndexedStack(index: _selectedIndex, children: pages),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: NocturneNavShell(
            selectedIndex: _selectedIndex,
            items: <NocturneNavItem>[
              NocturneNavItem(
                label: 'Today',
                glyph: NocturneGlyph.calendar,
                onTap: () => _select(0),
              ),
              NocturneNavItem(
                label: 'Life',
                glyph: NocturneGlyph.dots,
                semanticLabel: 'Open Life in Dots',
                onTap: () => _select(1),
              ),
              NocturneNavItem(
                label: 'Makeup',
                glyph: NocturneGlyph.check,
                semanticLabel: 'Open Makeup tab',
                onTap: () => _select(2),
              ),
              NocturneNavItem(
                label: 'You',
                glyph: NocturneGlyph.settings,
                semanticLabel: 'Open You',
                onTap: () => _select(3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
