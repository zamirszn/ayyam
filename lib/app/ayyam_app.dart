import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/design/routes/nocturne_page_route.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/app/root_gate.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AyyamApp extends ConsumerWidget {
  const AyyamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(appPreferencesProvider).value?.themeMode ??
        AppThemeMode.system;
    final shellTheme = themeMode == AppThemeMode.light
        ? NocturneThemeData.light
        : NocturneThemeData.dark;

    return WidgetsApp(
      title: 'Ayyam',
      color: shellTheme.canvas,
      debugShowCheckedModeBanner: false,
      textStyle: NocturneType.body(shellTheme.ink),
      pageRouteBuilder: nocturnePageRoute,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        DefaultWidgetsLocalizations.delegate,
      ],
      builder: (context, child) {
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final brightness = switch (themeMode) {
          AppThemeMode.system => platformBrightness,
          AppThemeMode.light => Brightness.light,
          AppThemeMode.dark => Brightness.dark,
        };
        final theme = brightness == Brightness.dark
            ? NocturneThemeData.dark
            : NocturneThemeData.light;
        return ScrollConfiguration(
          behavior: const NocturneScrollBehavior(),
          child: NocturneScope(
            theme: theme,
            tone: NocturneTone.pending,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const RootGate(),
    );
  }
}

class NocturneScrollBehavior extends ScrollBehavior {
  const NocturneScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Set<PointerDeviceKind> get dragDevices => const <PointerDeviceKind>{
    PointerDeviceKind.touch,
    PointerDeviceKind.stylus,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
