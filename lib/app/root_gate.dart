import 'dart:async';

import 'package:ayyam/core/platform/runtime_platform.dart';
import 'package:ayyam/app/main_shell.dart';
import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/onboarding/presentation/onboarding_flow.dart';
import 'package:ayyam/features/dua/application/dua_reminder_coordinator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider);
    if (isAndroidRuntime) {
      ref.listen<AsyncValue<AppPreferences>>(appPreferencesProvider, (
        previous,
        next,
      ) {
        next.whenData((value) {
          unawaited(
            ref
                .read(duaReminderCoordinatorProvider)
                .sync(value)
                .catchError((_) => const DuaReminderSyncResult()),
          );
        });
      });
    }
    return preferences.when(
      data: (value) => value.onboardingComplete
          ? MainShell(preferences: value)
          : OnboardingFlow(initialPreferences: value),
      error: (error, stackTrace) =>
          const OnboardingFlow(initialPreferences: AppPreferences.defaults),
      loading: _LoadingScreen.new,
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return NocturneScaffold(
      tone: NocturneTone.rest,
      child: Padding(
        padding: const EdgeInsets.all(NocturneSpace.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Spacer(),
            Text('AYYAM', style: NocturneType.label(theme.muted)),
            const SizedBox(height: NocturneSpace.x4),
            Text('Holding the day.', style: NocturneType.hero(theme.ink)),
            const SizedBox(height: NocturneSpace.x5),
            Text('PREPARING / 001', style: NocturneType.label(theme.faint)),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
