import 'package:ayyam/core/security/api_key_vault.dart';
import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/features/dua/application/dua_generation_service.dart';
import 'package:ayyam/features/dua/application/dua_reminder_platform.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/data/gemini_dua_client.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentDateProvider = Provider<DateTime>(
  (ref) => ref.watch(selectedDuaDayProvider) ?? DateTime.now(),
);

final todayDuaProvider =
    AsyncNotifierProvider<TodayDuaController, TodayDuaState>(
      TodayDuaController.new,
    );

sealed class TodayDuaState {
  const TodayDuaState();
}

class TodayDuaDisabled extends TodayDuaState {
  const TodayDuaDisabled();
}

class TodayDuaNeedsKey extends TodayDuaState {
  const TodayDuaNeedsKey({this.rejected = false});

  final bool rejected;
}

class TodayDuaReady extends TodayDuaState {
  const TodayDuaReady(this.dua, {this.canMarkRecited = true});

  final Dua dua;
  final bool canMarkRecited;
}

class TodayDuaFlagged extends TodayDuaState {
  const TodayDuaFlagged();
}

class TodayDuaUnavailable extends TodayDuaState {
  const TodayDuaUnavailable(this.message, {this.canRetry = true});

  final String message;
  final bool canRetry;
}

class TodayDuaController extends AsyncNotifier<TodayDuaState> {
  @override
  Future<TodayDuaState> build() async {
    final preferences = await ref.watch(appPreferencesProvider.future);
    final date = ref.watch(currentDateProvider);
    return _load(preferences, date);
  }

  Future<void> retry() async {
    state = const AsyncLoading<TodayDuaState>();
    state = await AsyncValue.guard(() async {
      final preferences = await ref.read(appPreferencesProvider.future);
      return _load(preferences, ref.read(currentDateProvider));
    });
  }

  Future<void> markRecited() async {
    final current = state.value;
    if (current is! TodayDuaReady ||
        current.dua.isRecited ||
        !current.canMarkRecited) {
      return;
    }
    try {
      final updated = await ref
          .read(duaRepositoryProvider)
          .markRecited(current.dua.id, DateTime.now());
      state = AsyncData<TodayDuaState>(
        TodayDuaReady(updated, canMarkRecited: current.canMarkRecited),
      );
    } catch (error, stackTrace) {
      state = AsyncError<TodayDuaState>(error, stackTrace);
    }
  }

  Future<void> reportIssue() async {
    final current = state.value;
    if (current is! TodayDuaReady) return;
    try {
      await ref.read(duaRepositoryProvider).flag(current.dua.id);
      state = const AsyncData<TodayDuaState>(TodayDuaFlagged());
    } catch (error, stackTrace) {
      state = AsyncError<TodayDuaState>(error, stackTrace);
    }
  }

  Future<TodayDuaState> _load(AppPreferences preferences, DateTime date) async {
    if (!preferences.duaEnabled) return const TodayDuaDisabled();

    final repository = ref.read(duaRepositoryProvider);
    final existing = await repository.findAssignedTo(date);
    if (existing != null) {
      if (existing.flagged) return const TodayDuaFlagged();
      final visible = existing.status == DuaStatus.scheduled
          ? await repository.markShown(existing.id)
          : existing;
      return TodayDuaReady(
        visible,
        canMarkRecited: ref.read(selectedDuaDayProvider) == null,
      );
    }

    final apiKey = await ref.read(apiKeyVaultProvider).read();
    if (apiKey == null || apiKey.trim().isEmpty) {
      return const TodayDuaNeedsKey();
    }

    try {
      final dua = await ref
          .read(duaGenerationServiceProvider)
          .prepareForDate(
            date: date,
            apiKey: apiKey,
            language: preferences.translationLanguage,
          );
      return TodayDuaReady(
        dua,
        canMarkRecited: ref.read(selectedDuaDayProvider) == null,
      );
    } on DuaGenerationException catch (error) {
      return switch (error.error) {
        DuaGenerationError.invalidKey => const TodayDuaNeedsKey(rejected: true),
        DuaGenerationError.rateLimited => const TodayDuaUnavailable(
          'Gemini is rate-limiting requests. Your existing collection remains available.',
        ),
        DuaGenerationError.unavailable => const TodayDuaUnavailable(
          'The daily dua could not be prepared right now. Check the connection and retry.',
        ),
        DuaGenerationError.refused ||
        DuaGenerationError.malformed => const TodayDuaUnavailable(
          'Gemini did not return content that passed Ayyam’s source checks.',
        ),
      };
    } on DuaPreparationException catch (error) {
      return TodayDuaUnavailable(error.message);
    }
  }
}
