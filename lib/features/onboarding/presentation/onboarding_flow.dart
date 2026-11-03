import 'package:ayyam/core/gemini/gemini_key_validator.dart';
import 'package:ayyam/core/platform/runtime_platform.dart';
import 'package:ayyam/core/security/api_key_vault.dart';
import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_field.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_picker.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/components/nocturne_switch.dart';
import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/dua/application/dua_reminder_platform.dart';
import 'package:ayyam/features/onboarding/presentation/welcome_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

enum _OnboardingStep { welcome, features, dua, life, permissions }

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, required this.initialPreferences});

  final AppPreferences initialPreferences;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  _OnboardingStep _step = _OnboardingStep.welcome;
  late bool _duaEnabled;
  late bool _lifeEnabled;
  late int _reminderHour;
  late int _reminderMinute;
  late String _language;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _missedYearsController;
  DateTime? _birthDate;
  String? _featureError;
  String? _duaError;
  String? _lifeError;
  String? _finishError;
  GeminiKeyStatus? _keyStatus;
  bool _testingKey = false;
  bool _finishing = false;

  List<_OnboardingStep> get _steps => <_OnboardingStep>[
    _OnboardingStep.welcome,
    _OnboardingStep.features,
    if (_duaEnabled) _OnboardingStep.dua,
    if (_lifeEnabled) _OnboardingStep.life,
    _OnboardingStep.permissions,
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPreferences;
    _duaEnabled = initial.duaEnabled;
    _lifeEnabled = initial.lifeInDotsEnabled;
    _reminderHour = initial.reminderHour;
    _reminderMinute = initial.reminderMinute;
    _language = initial.translationLanguage;
    _apiKeyController = TextEditingController();
    _birthDate = initial.dateOfBirth;
    _missedYearsController = TextEditingController(
      text: initial.missedPrayerYears == 0
          ? ''
          : '${initial.missedPrayerYears}',
    );
    _restoreApiKey();
  }

  Future<void> _restoreApiKey() async {
    final key = await ref.read(apiKeyVaultProvider).read();
    if (!mounted || key == null) return;
    _apiKeyController.text = key;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _missedYearsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_step) {
      _OnboardingStep.welcome => WelcomeScreen(
        key: const ValueKey<_OnboardingStep>(_OnboardingStep.welcome),
        onBegin: () => _goTo(_OnboardingStep.features),
      ),
      _OnboardingStep.features => _buildFeatures(),
      _OnboardingStep.dua => _buildDuaSetup(),
      _OnboardingStep.life => _buildLifeSetup(),
      _OnboardingStep.permissions => _buildPermissions(),
    };

    return AnimatedSwitcher(
      duration: NocturneDuration.base,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.025, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: page,
    );
  }

  Widget _buildFeatures() {
    return _OnboardingFrame(
      key: const ValueKey<_OnboardingStep>(_OnboardingStep.features),
      progress: _progress,
      headline: 'Choose what\nyou need.',
      supporting:
          'Keep one or both. You can change this later without losing data.',
      onBack: _goBack,
      actionLabel: 'Continue',
      onAction: _continueFromFeatures,
      error: _featureError,
      child: Column(
        children: <Widget>[
          _FeatureCard(
            glyph: NocturneGlyph.book,
            title: 'Dua Bucket List',
            body: 'Meet one sourced supplication each day.',
            value: _duaEnabled,
            onChanged: (value) => _setFeature(dua: value),
          ),
          const SizedBox(height: NocturneSpace.x4),
          _FeatureCard(
            glyph: NocturneGlyph.dots,
            title: 'Life in Dots',
            body: 'See a lifetime in days and reflect on prayer.',
            value: _lifeEnabled,
            onChanged: (value) => _setFeature(life: value),
          ),
        ],
      ),
    );
  }

  Widget _buildDuaSetup() {
    final theme = NocturneScope.of(context);
    return _OnboardingFrame(
      key: const ValueKey<_OnboardingStep>(_OnboardingStep.dua),
      progress: _progress,
      headline: 'Set the\nmorning rhythm.',
      supporting:
          'Ayyam prepares new duas ahead of time and keeps them on device.',
      onBack: _goBack,
      actionLabel: 'Continue',
      onAction: _continueFromDua,
      error: _duaError,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NocturneField(
            controller: _apiKeyController,
            label: 'Gemini API key',
            hint: 'Paste your key',
            obscureText: true,
            textInputAction: TextInputAction.done,
            error: _duaError?.contains('key') == true ? _duaError : null,
            helper: kIsWeb
                ? 'Kept only for this browser session. Web storage cannot fully protect a key.'
                : 'Stored using device-backed secure storage. It is never logged.',
            onChanged: (_) => setState(() {
              _keyStatus = null;
              _duaError = null;
            }),
          ),
          const SizedBox(height: NocturneSpace.x3),
          Row(
            children: <Widget>[
              Expanded(
                child: NocturneButton(
                  label: _testingKey ? 'Testing…' : 'Test key',
                  style: NocturneButtonStyle.glass,
                  onTap: _testingKey ? null : _testKey,
                ),
              ),
              const SizedBox(width: NocturneSpace.x3),
              Pressable(
                semanticLabel: 'Open Google AI Studio to get an API key',
                onTap: _openKeyHelp,
                child: SizedBox(
                  height: 48,
                  child: Center(
                    child: Text(
                      'GET A KEY ↗',
                      style: NocturneType.label(theme.accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_keyStatus case final status?) ...<Widget>[
            const SizedBox(height: NocturneSpace.x3),
            _KeyStatusLine(status: status),
          ],
          const SizedBox(height: NocturneSpace.x8),
          _SectionLabel(index: '01', label: 'Reminder time'),
          const SizedBox(height: NocturneSpace.x3),
          NocturnePickerField(
            label: 'Daily reminder',
            value: nocturneClockLabel(_reminderHour, _reminderMinute),
            glyph: NocturneGlyph.clock,
            onTap: _pickReminderTime,
            helper: 'Stored as local time on this device.',
          ),
          const SizedBox(height: NocturneSpace.x8),
          _SectionLabel(index: '02', label: 'Translation'),
          const SizedBox(height: NocturneSpace.x3),
          Wrap(
            spacing: NocturneSpace.x2,
            runSpacing: NocturneSpace.x2,
            children: <Widget>[
              for (final language in const <String>[
                'English',
                'French',
                'Arabic',
              ])
                _ChoiceChip(
                  label: language,
                  selected: _language == language,
                  onTap: () => setState(() => _language = language),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLifeSetup() {
    return _OnboardingFrame(
      key: const ValueKey<_OnboardingStep>(_OnboardingStep.life),
      progress: _progress,
      headline: 'Place the\nfirst dot.',
      supporting: 'Your date of birth anchors the 36,500-day view.',
      onBack: _goBack,
      actionLabel: 'Continue',
      onAction: _continueFromLife,
      error: _lifeError,
      child: Column(
        children: <Widget>[
          NocturnePickerField(
            label: 'Date of birth',
            value: _birthDate == null
                ? 'DD / MM / YYYY'
                : nocturneDateLabel(_birthDate!),
            glyph: NocturneGlyph.calendar,
            placeholder: _birthDate == null,
            onTap: _pickBirthDate,
            helper: 'Used only on this device to place lived and future days.',
          ),
          if (_lifeError?.contains('birth') == true) ...<Widget>[
            const SizedBox(height: NocturneSpace.x2),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _lifeError!,
                style: NocturneType.caption(NocturneScope.of(context).missed),
              ),
            ),
          ],
          const SizedBox(height: NocturneSpace.x5),
          NocturneField(
            controller: _missedYearsController,
            label: 'Estimated missed years — optional',
            hint: '0',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            error: _lifeError?.contains('years') == true ? _lifeError : null,
            helper: 'Each year adds 365 undated items to the personal make-up tracker; historical dots stay neutral until backfilled.',
            onChanged: (_) => setState(() => _lifeError = null),
          ),
          const SizedBox(height: NocturneSpace.x6),
          const _NoticeCard(
            glyph: NocturneGlyph.book,
            title: 'Personal reflection, not a ruling',
            body: 'Prayer make-up practices differ. Ayyam will keep the language configurable and encourage qualified guidance.',
          ),
        ],
      ),
    );
  }

  Widget _buildPermissions() {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    return _OnboardingFrame(
      key: const ValueKey<_OnboardingStep>(_OnboardingStep.permissions),
      progress: _progress,
      headline: 'Keep the\nday on time.',
      supporting: isAndroid
          ? 'Android will ask for these when the reminder engine is activated.'
          : 'Web reminders are best-effort. Your daily dua will always be available when the app opens.',
      onBack: _goBack,
      actionLabel: _finishing ? 'Saving…' : 'Finish setup',
      onAction: _finishing ? null : _finish,
      error: _finishError,
      child: Column(
        children: <Widget>[
          _PermissionCard(
            glyph: NocturneGlyph.bell,
            title: 'Notifications',
            body: isAndroid
                ? 'Show the translation preview at your chosen time.'
                : 'Used only where the browser supports local notifications.',
            status: isAndroid ? 'ASK ON FINISH' : 'BEST EFFORT',
          ),
          const SizedBox(height: NocturneSpace.x3),
          _PermissionCard(
            glyph: NocturneGlyph.check,
            title: 'Exact alarms',
            body: isAndroid
                ? 'Keep the reminder punctual, including after a reboot.'
                : 'Browsers cannot guarantee an exact background alarm.',
            status: isAndroid ? 'ASK ON FINISH' : 'NOT AVAILABLE',
          ),
          const SizedBox(height: NocturneSpace.x3),
          _PermissionCard(
            glyph: NocturneGlyph.lock,
            title: 'Battery access',
            body: isAndroid
                ? 'Prevent battery optimization from delaying reminders.'
                : 'No extra background access is requested on the web.',
            status: isAndroid ? 'OPTIONAL' : 'NOT NEEDED',
          ),
          const SizedBox(height: NocturneSpace.x6),
          _NoticeCard(
            glyph: NocturneGlyph.check,
            title: 'Your choices',
            body: [
              if (_duaEnabled)
                'Dua at ${nocturneClockLabel(_reminderHour, _reminderMinute)} in $_language',
              if (_lifeEnabled) 'Life in Dots stored locally',
            ].join(' · '),
          ),
        ],
      ),
    );
  }

  String get _progress {
    final steps = _steps;
    final current = steps.indexOf(_step) + 1;
    return '${current.toString().padLeft(2, '0')} / ${steps.length.toString().padLeft(2, '0')}';
  }

  void _goTo(_OnboardingStep step) => setState(() => _step = step);

  void _goBack() {
    final steps = _steps;
    final index = steps.indexOf(_step);
    if (index > 0) {
      _goTo(steps[index - 1]);
    }
  }

  void _setFeature({bool? dua, bool? life}) {
    final nextDua = dua ?? _duaEnabled;
    final nextLife = life ?? _lifeEnabled;
    if (!nextDua && !nextLife) {
      setState(() {
        _featureError = 'Keep at least one feature on.';
      });
      return;
    }
    setState(() {
      _duaEnabled = nextDua;
      _lifeEnabled = nextLife;
      _featureError = null;
    });
  }

  void _continueFromFeatures() {
    if (!_duaEnabled && !_lifeEnabled) {
      setState(() => _featureError = 'Keep at least one feature on.');
      return;
    }
    _goTo(_duaEnabled ? _OnboardingStep.dua : _OnboardingStep.life);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showNocturneTimePicker(
      context,
      hour: _reminderHour,
      minute: _reminderMinute,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _reminderHour = picked.hour;
      _reminderMinute = picked.minute;
    });
  }

  Future<void> _pickBirthDate() async {
    final picked = await showNocturneDatePicker(
      context,
      initialDate: _birthDate,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _birthDate = picked;
      _lifeError = null;
    });
  }

  Future<void> _testKey() async {
    if (_apiKeyController.text.trim().isEmpty) {
      setState(() {
        _duaError = 'Add a Gemini API key first.';
        _keyStatus = GeminiKeyStatus.invalid;
      });
      return;
    }
    setState(() {
      _testingKey = true;
      _duaError = null;
      _keyStatus = null;
    });
    final result = await ref
        .read(geminiKeyValidatorProvider)
        .validate(_apiKeyController.text);
    if (!mounted) return;
    setState(() {
      _testingKey = false;
      _keyStatus = result;
      if (result == GeminiKeyStatus.invalid) {
        _duaError = 'That key was not accepted. Check it and try again.';
      }
    });
  }

  Future<void> _openKeyHelp() async {
    final opened = await launchUrl(
      Uri.parse('https://aistudio.google.com/app/apikey'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      setState(() => _duaError = 'Could not open Google AI Studio.');
    }
  }

  void _continueFromDua() {
    if (_apiKeyController.text.trim().isEmpty) {
      setState(() => _duaError = 'Add a Gemini API key to continue.');
      return;
    }
    if (_keyStatus == GeminiKeyStatus.invalid) {
      setState(() => _duaError = 'Use a valid Gemini API key to continue.');
      return;
    }
    _goTo(_lifeEnabled ? _OnboardingStep.life : _OnboardingStep.permissions);
  }

  void _continueFromLife() {
    final birthDate = _birthDate;
    if (birthDate == null || birthDate.isAfter(DateTime.now())) {
      setState(() => _lifeError = 'Enter a valid past date of birth.');
      return;
    }
    final missedText = _missedYearsController.text.trim();
    final missedYears = missedText.isEmpty ? 0 : int.tryParse(missedText);
    if (missedYears == null || missedYears < 0) {
      setState(() => _lifeError = 'Missed years must be zero or more.');
      return;
    }
    final age = _ageOn(birthDate, DateTime.now());
    if (missedYears > age) {
      setState(
        () => _lifeError = 'Missed years cannot be greater than your age.',
      );
      return;
    }
    setState(() => _lifeError = null);
    _goTo(_OnboardingStep.permissions);
  }

  Future<void> _finish() async {
    setState(() {
      _finishing = true;
      _finishError = null;
    });
    try {
      if (_duaEnabled) {
        await ref.read(apiKeyVaultProvider).write(_apiKeyController.text);
        if (isAndroidRuntime) {
          try {
            await ref.read(duaReminderPlatformProvider).requestPermissions();
          } catch (_) {
            // Setup remains usable when Android declines a permission prompt.
          }
        }
      }
      final birthDate = _lifeEnabled ? _birthDate : null;
      final missedYears = _lifeEnabled
          ? int.tryParse(_missedYearsController.text.trim()) ?? 0
          : 0;
      await ref
          .read(appPreferencesProvider.notifier)
          .completeOnboarding(
            OnboardingSetup(
              duaEnabled: _duaEnabled,
              lifeInDotsEnabled: _lifeEnabled,
              reminderHour: _reminderHour,
              reminderMinute: _reminderMinute,
              translationLanguage: _language,
              dateOfBirth: birthDate,
              missedPrayerYears: missedYears,
            ),
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _finishError =
            'Could not save setup. Check device storage and try again.';
      });
    }
  }

  static int _ageOn(DateTime birthDate, DateTime date) {
    var age = date.year - birthDate.year;
    if (date.month < birthDate.month ||
        (date.month == birthDate.month && date.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}

class _OnboardingFrame extends StatelessWidget {
  const _OnboardingFrame({
    super.key,
    required this.progress,
    required this.headline,
    required this.supporting,
    required this.onBack,
    required this.actionLabel,
    required this.onAction,
    required this.child,
    this.error,
  });

  final String progress;
  final String headline;
  final String supporting;
  final VoidCallback onBack;
  final String actionLabel;
  final VoidCallback? onAction;
  final Widget child;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return NocturneScaffold(
      tone: NocturneTone.pending,
      child: AnimatedPadding(
        duration: NocturneDuration.fast,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboard),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  CircleAction(
                    glyph: NocturneGlyph.chevronLeft,
                    onTap: onBack,
                    semanticLabel: 'Back',
                    size: 38,
                  ),
                  Text(progress, style: NocturneType.label(theme.muted)),
                ],
              ),
              const SizedBox(height: NocturneSpace.x5),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        headline,
                        style: NocturneType.hero(theme.ink, size: 48),
                      ),
                      const SizedBox(height: NocturneSpace.x4),
                      Text(supporting, style: NocturneType.body(theme.muted)),
                      const SizedBox(height: NocturneSpace.x8),
                      child,
                      const SizedBox(height: NocturneSpace.x5),
                    ],
                  ),
                ),
              ),
              if (error != null) ...<Widget>[
                Text(error!, style: NocturneType.caption(theme.missed)),
                const SizedBox(height: NocturneSpace.x3),
              ],
              NocturneButton(
                label: actionLabel,
                trailing: onAction == null ? null : NocturneGlyph.arrowRight,
                onTap: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.glyph,
    required this.title,
    required this.body,
    required this.value,
    required this.onChanged,
  });

  final NocturneGlyph glyph;
  final String title;
  final String body;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      onTap: () => onChanged(!value),
      semanticLabel: '$title, ${value ? 'on' : 'off'}',
      tint: value ? theme.pending : theme.faint,
      glow: value,
      child: Row(
        children: <Widget>[
          SizedBox.square(
            dimension: 48,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: value
                    ? theme.pending.withValues(alpha: 0.16)
                    : theme.glass,
                borderRadius: BorderRadius.circular(NocturneRadius.small),
                border: Border.all(color: theme.line),
              ),
              child: Center(child: NocturneIcon(glyph)),
            ),
          ),
          const SizedBox(width: NocturneSpace.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: NocturneType.cardTitle(theme.ink)),
                const SizedBox(height: NocturneSpace.x1),
                Text(body, style: NocturneType.caption(theme.muted)),
              ],
            ),
          ),
          const SizedBox(width: NocturneSpace.x3),
          NocturneSwitch(
            value: value,
            onChanged: onChanged,
            semanticLabel: title,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.index, required this.label});

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

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
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
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? theme.accent : theme.glass,
            borderRadius: BorderRadius.circular(NocturneRadius.pill),
            border: Border.all(
              color: selected ? theme.accent : theme.lineStrong,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              label,
              style: NocturneType.caption(selected ? theme.canvas : theme.ink),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeyStatusLine extends StatelessWidget {
  const _KeyStatusLine({required this.status});

  final GeminiKeyStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final (label, color) = switch (status) {
      GeminiKeyStatus.valid => ('KEY ACCEPTED', theme.kept),
      GeminiKeyStatus.invalid => ('KEY NOT ACCEPTED', theme.missed),
      GeminiKeyStatus.unavailable => (
        'COULD NOT TEST — CONTINUE OFFLINE',
        theme.muted,
      ),
    };
    return Row(
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: NocturneSpace.x2),
        Expanded(child: Text(label, style: NocturneType.label(color))),
      ],
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.glyph,
    required this.title,
    required this.body,
    required this.status,
  });

  final NocturneGlyph glyph;
  final String title;
  final String body;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NocturneIcon(glyph, color: theme.ink),
          const SizedBox(width: NocturneSpace.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: NocturneType.bodyStrong(theme.ink),
                      ),
                    ),
                    Text(status, style: NocturneType.label(theme.faint)),
                  ],
                ),
                const SizedBox(height: NocturneSpace.x1),
                Text(body, style: NocturneType.caption(theme.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.glyph,
    required this.title,
    required this.body,
  });

  final NocturneGlyph glyph;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      tint: theme.kept,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          NocturneIcon(glyph, color: theme.kept),
          const SizedBox(width: NocturneSpace.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: NocturneType.bodyStrong(theme.ink)),
                const SizedBox(height: NocturneSpace.x1),
                Text(body, style: NocturneType.caption(theme.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
