import 'package:ayyam/design/routes/nocturne_page_route.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/onboarding/presentation/welcome_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

class AyyamApp extends StatelessWidget {
  const AyyamApp({super.key});

  @override
  Widget build(BuildContext context) {
    const theme = NocturneThemeData.dark;

    return WidgetsApp(
      title: 'Ayyam',
      color: theme.canvas,
      debugShowCheckedModeBanner: false,
      textStyle: NocturneType.body(theme.ink),
      pageRouteBuilder: nocturnePageRoute,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        DefaultWidgetsLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => ScrollConfiguration(
        behavior: const NocturneScrollBehavior(),
        child: NocturneScope(
          theme: theme,
          tone: NocturneTone.pending,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: const WelcomeScreen(),
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
