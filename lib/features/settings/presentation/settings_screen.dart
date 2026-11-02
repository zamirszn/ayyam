import 'package:ayyam/core/gemini/gemini_key_validator.dart';
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
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.initialPreferences});

  final AppPreferences initialPreferences;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late AppPreferences _savedPreferences;
  late bool _duaEnabled;
  late bool _lifeEnabled;
  late int _reminderHour;
  late int _reminderMinute;
  late String _language;
  late DateTime? _birthDate;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _missedYearsController;

  String? _storedKey;
  String? _featureError;
  String? _keyError;
  String? _lifeError;
  String? _saveError;
  String? _saveMessage;
  GeminiKeyStatus? _keyStatus;
  bool _loadingKey = true;
  bool _keyReadFailed = false;
  bool _keyEdited = false;
  bool _testingKey = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _savedPreferences = widget.initialPreferences;
    _duaEnabled = _savedPreferences.duaEnabled;
    _lifeEnabled = _savedPreferences.lifeInDotsEnabled;
    _reminderHour = _savedPreferences.reminderHour;
    _reminderMinute = _savedPreferences.reminderMinute;
    _language = _savedPreferences.translationLanguage;
    _birthDate = _savedPreferences.dateOfBirth;
    _apiKeyController = TextEditingController();
    _missedYearsController = TextEditingController(
      text: _savedPreferences.missedPrayerYears == 0
          ? ''
          : '${_savedPreferences.missedPrayerYears}',
    );
    _restoreApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _missedYearsController.dispose();
    super.dispose();
  }

  Future<void> _restoreApiKey() async {
    try {
      final key = await ref.read(apiKeyVaultProvider).read();
      if (!mounted) return;
      setState(() {
        _storedKey = key;
        if (!_keyEdited) _apiKeyController.text = key ?? '';
        _loadingKey = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingKey = false;
        _keyReadFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final lifeSection = _duaEnabled ? '04' : '02';

    return NocturneScaffold(
      tone: NocturneTone.rest,
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
                  Text(
                    'SETTINGS / (001)',
                    style: NocturneType.label(theme.muted),
                  ),
                ],
              ),
              const SizedBox(height: NocturneSpace.x5),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Keep it\nyours.',
                        style: NocturneType.hero(theme.ink, size: 50),
                      ),
                      const SizedBox(height: NocturneSpace.x3),
                      Text(
                        'Your rhythm, features and private credentials stay under your control.',
                        style: NocturneType.body(theme.muted),
                      ),
                      const SizedBox(height: NocturneSpace.x6),
                      const _PrivacyCard(),
                      const SizedBox(height: NocturneSpace.x8),
                      const _SectionLabel(index: '01', label: 'Features'),
                      const SizedBox(height: NocturneSpace.x3),
                      _FeatureRow(
                        glyph: NocturneGlyph.book,
                        title: 'Dua Bucket List',
                        subtitle: 'Daily sourced supplications and reminders.',
                        value: _duaEnabled,
                        onChanged: (value) => _setFeature(dua: value),
                      ),
                      const SizedBox(height: NocturneSpace.x2),
                      _FeatureRow(
                        glyph: NocturneGlyph.dots,
                        title: 'Life in Dots',
                        subtitle: 'Lifetime view and personal prayer record.',
                        value: _lifeEnabled,
                        onChanged: (value) => _setFeature(life: value),
                      ),
                      if (_featureError != null) ...<Widget>[
                        const SizedBox(height: NocturneSpace.x2),
                        Text(
                          _featureError!,
                          style: NocturneType.caption(theme.missed),
                        ),
                      ],
                      if (_duaEnabled) ...<Widget>[
                        const SizedBox(height: NocturneSpace.x8),
                        const _SectionLabel(index: '02', label: 'Daily dua'),
                        const SizedBox(height: NocturneSpace.x3),
                        NocturnePickerField(
                          label: 'Reminder time',
                          value: nocturneClockLabel(
                            _reminderHour,
                            _reminderMinute,
                          ),
                          glyph: NocturneGlyph.clock,
                          onTap: _pickReminderTime,
                          helper:
                              'The notification engine will use local time.',
                        ),
                        const SizedBox(height: NocturneSpace.x6),
                        Text(
                          'TRANSLATION',
                          style: NocturneType.label(theme.muted),
                        ),
                        const SizedBox(height: NocturneSpace.x2),
                        Wrap(
                          spacing: NocturneSpace.x2,
                          runSpacing: NocturneSpace.x2,
                          children: <Widget>[
                            for (final language in const <String>[
                              'English',
                              'French',
                              'Arabic',
                            ])
                              _ChoicePill(
                                label: language,
                                selected: _language == language,
                                onTap: () => setState(() {
                                  _language = language;
                                  _clearFeedback();
                                }),
                              ),
                          ],
                        ),
                        const SizedBox(height: NocturneSpace.x6),
                        NocturneField(
                          controller: _apiKeyController,
                          label: 'Gemini API key',
                          hint: _loadingKey
                              ? 'Reading secure storage…'
                              : 'Paste a key',
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          error: _keyError,
                          helper: _keyHelper,
                          onChanged: (_) => setState(() {
                            _keyEdited = true;
                            _keyStatus = null;
                            _keyError = null;
                            _clearFeedback();
                          }),
                        ),
                        const SizedBox(height: NocturneSpace.x3),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: NocturneButton(
                                label: _testingKey ? 'Testing…' : 'Test key',
                                style: NocturneButtonStyle.glass,
                                compact: true,
                                onTap: _testingKey ? null : _testKey,
                              ),
                            ),
                            const SizedBox(width: NocturneSpace.x2),
                            Expanded(
                              child: NocturneButton(
                                label: 'Remove key',
                                style: NocturneButtonStyle.danger,
                                compact: true,
                                onTap: _apiKeyController.text.trim().isEmpty
                                    ? null
                                    : _removeKey,
                              ),
                            ),
                          ],
                        ),
                        if (_keyStatus case final status?) ...<Widget>[
                          const SizedBox(height: NocturneSpace.x3),
                          _KeyStatusLine(status: status),
                        ],
                        const SizedBox(height: NocturneSpace.x2),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Pressable(
                            semanticLabel:
                                'Open Google AI Studio to get an API key',
                            onTap: _openKeyHelp,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Text(
                                'GET OR RESTRICT A KEY ↗',
                                style: NocturneType.label(theme.accent),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: NocturneSpace.x6),
                        const _SectionLabel(
                          index: '03',
                          label: 'Delivery status',
                        ),
                        const SizedBox(height: NocturneSpace.x3),
                        _StatusRow(
                          glyph: NocturneGlyph.bell,
                          title: 'Notifications',
                          subtitle: isAndroid
                              ? 'Permission will be requested with the reminder engine.'
                              : 'Browser delivery is best-effort; in-app content remains available.',
                          status: isAndroid ? 'NOT REQUESTED' : 'BEST EFFORT',
                        ),
                        const SizedBox(height: NocturneSpace.x2),
                        _StatusRow(
                          glyph: NocturneGlyph.clock,
                          title: 'Exact alarms',
                          subtitle: isAndroid
                              ? 'Used for punctual reminders after permission is granted.'
                              : 'Browsers cannot guarantee an exact background alarm.',
                          status: isAndroid ? 'NOT REQUESTED' : 'UNAVAILABLE',
                        ),
                        const SizedBox(height: NocturneSpace.x2),
                        _StatusRow(
                          glyph: NocturneGlyph.lock,
                          title: 'Battery access',
                          subtitle: isAndroid
                              ? 'Optional exemption for more reliable delivery.'
                              : 'No extra background access is requested on the web.',
                          status: isAndroid ? 'OPTIONAL' : 'NOT NEEDED',
                        ),
                      ],
                      if (_lifeEnabled) ...<Widget>[
                        const SizedBox(height: NocturneSpace.x8),
                        _SectionLabel(index: lifeSection, label: 'Life anchor'),
                        const SizedBox(height: NocturneSpace.x3),
                        NocturnePickerField(
                          label: 'Date of birth',
                          value: _birthDate == null
                              ? 'DD / MM / YYYY'
                              : nocturneDateLabel(_birthDate!),
                          glyph: NocturneGlyph.calendar,
                          placeholder: _birthDate == null,
                          onTap: _pickBirthDate,
                          helper:
                              'Used locally to place lived and future days.',
                        ),
                        if (_lifeError?.contains('birth') == true) ...<Widget>[
                          const SizedBox(height: NocturneSpace.x2),
                          Text(
                            _lifeError!,
                            style: NocturneType.caption(theme.missed),
                          ),
                        ],
                        const SizedBox(height: NocturneSpace.x5),
                        NocturneField(
                          controller: _missedYearsController,
                          label: 'Estimated missed years — optional',
                          hint: '0',
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          error: _lifeError?.contains('years') == true
                              ? _lifeError
                              : null,
                          helper: 'An estimate only; no religious ruling is implied.',
                          onChanged: (_) => setState(() {
                            _lifeError = null;
                            _clearFeedback();
                          }),
                        ),
                      ],
                      const SizedBox(height: NocturneSpace.x8),
                      ColoredBox(
                        color: theme.line,
                        child: const SizedBox(height: 1),
                      ),
                      const SizedBox(height: NocturneSpace.x4),
                      Text('Ayyam', style: NocturneType.body(theme.muted)),
                      const SizedBox(height: NocturneSpace.x1),
                      Text(
                        'VERSION 0.1.0 · LOCAL FIRST',
                        style: NocturneType.label(theme.faint),
                      ),
                      const SizedBox(height: NocturneSpace.x5),
                    ],
                  ),
                ),
              ),
              if (_saveError != null || _saveMessage != null) ...<Widget>[
                const SizedBox(height: NocturneSpace.x2),
                Text(
                  _saveError ?? _saveMessage!,
                  style: NocturneType.caption(
                    _saveError == null ? theme.kept : theme.missed,
                  ),
                ),
                const SizedBox(height: NocturneSpace.x3),
              ],
              NocturneButton(
                label: _saving ? 'Saving…' : 'Save changes',
                trailing: _saving ? null : NocturneGlyph.check,
                onTap: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _keyHelper {
    if (_loadingKey) return 'Checking secure storage on this device.';
    if (_keyReadFailed && !_keyEdited) {
      return 'The saved key could not be read. Entering one here will replace it.';
    }
    if (kIsWeb) {
      return 'Kept only for this browser session; browsers cannot fully protect a key.';
    }
    if (_apiKeyController.text.trim().isEmpty) {
      return 'Without a key, new dua generation stays paused.';
    }
    return 'Masked here and stored using device-backed secure storage.';
  }

  void _clearFeedback() {
    _saveError = null;
    _saveMessage = null;
  }

  void _setFeature({bool? dua, bool? life}) {
    final nextDua = dua ?? _duaEnabled;
    final nextLife = life ?? _lifeEnabled;
    if (!nextDua && !nextLife) {
      setState(() => _featureError = 'Keep at least one feature on.');
      return;
    }
    setState(() {
      _duaEnabled = nextDua;
      _lifeEnabled = nextLife;
      _featureError = null;
      _clearFeedback();
    });
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
      _clearFeedback();
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
      _clearFeedback();
    });
  }

  Future<void> _testKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _keyError = 'Add a Gemini API key first.';
        _keyStatus = GeminiKeyStatus.invalid;
      });
      return;
    }
    setState(() {
      _testingKey = true;
      _keyError = null;
      _keyStatus = null;
      _clearFeedback();
    });
    final result = await ref.read(geminiKeyValidatorProvider).validate(key);
    if (!mounted) return;
    setState(() {
      _testingKey = false;
      _keyStatus = result;
      if (result == GeminiKeyStatus.invalid) {
        _keyError = 'That key was not accepted. Check it and try again.';
      }
    });
  }

  void _removeKey() {
    setState(() {
      _apiKeyController.clear();
      _keyEdited = true;
      _keyStatus = null;
      _keyError = null;
      _clearFeedback();
    });
  }

  Future<void> _openKeyHelp() async {
    final opened = await launchUrl(
      Uri.parse('https://aistudio.google.com/app/apikey'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      setState(() => _keyError = 'Could not open Google AI Studio.');
    }
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_duaEnabled && !_lifeEnabled) {
      setState(() => _featureError = 'Keep at least one feature on.');
      return;
    }
    final key = _apiKeyController.text.trim();
    if (key.isNotEmpty && _keyStatus == GeminiKeyStatus.invalid) {
      setState(() => _keyError = 'Use a valid key or remove it before saving.');
      return;
    }

    var birthDate = _savedPreferences.dateOfBirth;
    var missedYears = _savedPreferences.missedPrayerYears;
    if (_lifeEnabled) {
      birthDate = _birthDate;
      if (birthDate == null || birthDate.isAfter(DateTime.now())) {
        setState(() => _lifeError = 'Choose a valid past date of birth.');
        return;
      }
      final missedText = _missedYearsController.text.trim();
      missedYears = missedText.isEmpty ? 0 : int.tryParse(missedText) ?? -1;
      if (missedYears < 0) {
        setState(() => _lifeError = 'Missed years must be zero or more.');
        return;
      }
      if (missedYears > _ageOn(birthDate, DateTime.now())) {
        setState(
          () => _lifeError = 'Missed years cannot be greater than your age.',
        );
        return;
      }
    }

    final preferences = _savedPreferences.copyWith(
      duaEnabled: _duaEnabled,
      lifeInDotsEnabled: _lifeEnabled,
      reminderHour: _reminderHour,
      reminderMinute: _reminderMinute,
      translationLanguage: _language,
      dateOfBirth: birthDate,
      missedPrayerYears: missedYears,
    );

    setState(() {
      _saving = true;
      _saveError = null;
      _saveMessage = null;
    });
    try {
      if (_keyEdited) {
        if (key.isEmpty) {
          await ref.read(apiKeyVaultProvider).delete();
        } else {
          await ref.read(apiKeyVaultProvider).write(key);
        }
      }
      await ref
          .read(appPreferencesProvider.notifier)
          .updatePreferences(preferences);
      if (!mounted) return;
      setState(() {
        _savedPreferences = preferences;
        if (_keyEdited) _storedKey = key.isEmpty ? null : key;
        _keyEdited = false;
        _saving = false;
        final keyKnownMissing =
            !_keyReadFailed && (_storedKey == null || _storedKey!.isEmpty);
        _saveMessage = _duaEnabled && keyKnownMissing
            ? 'Saved. New dua generation is paused until a key is added.'
            : 'Saved on this device.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Could not save changes. Check device storage and retry.';
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

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      tint: theme.kept,
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.kept.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(NocturneRadius.small),
              border: Border.all(color: theme.kept.withValues(alpha: 0.26)),
            ),
            child: NocturneIcon(
              NocturneGlyph.lock,
              size: 19,
              color: theme.kept,
            ),
          ),
          const SizedBox(width: NocturneSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Private on this device',
                  style: NocturneType.bodyStrong(theme.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Turning a feature off hides it without deleting its data.',
                  style: NocturneType.caption(theme.muted),
                ),
              ],
            ),
          ),
          Text('LOCAL', style: NocturneType.label(theme.kept)),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final NocturneGlyph glyph;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final color = value ? theme.pending : theme.faint;
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      onTap: () => onChanged(!value),
      semanticLabel: '$title, ${value ? 'on' : 'off'}',
      tint: color,
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(NocturneRadius.small),
              border: Border.all(color: color.withValues(alpha: 0.26)),
            ),
            child: NocturneIcon(glyph, size: 18, color: color),
          ),
          const SizedBox(width: NocturneSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: NocturneType.bodyStrong(theme.ink)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: NocturneType.caption(theme.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: NocturneSpace.x2),
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

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.glyph,
    required this.title,
    required this.subtitle,
    required this.status,
  });

  final NocturneGlyph glyph;
  final String title;
  final String subtitle;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.glassStrong,
              borderRadius: BorderRadius.circular(NocturneRadius.small),
              border: Border.all(color: theme.line),
            ),
            child: NocturneIcon(glyph, size: 18, color: theme.muted),
          ),
          const SizedBox(width: NocturneSpace.x3),
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
                const SizedBox(height: 2),
                Text(subtitle, style: NocturneType.caption(theme.muted)),
              ],
            ),
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

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
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
    final foreground = selected ? theme.canvas : theme.ink;
    return Semantics(
      selected: selected,
      child: Pressable(
        onTap: onTap,
        semanticLabel: label,
        child: AnimatedContainer(
          duration: NocturneDuration.fast,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? theme.ink : const Color(0x00000000),
            borderRadius: BorderRadius.circular(NocturneRadius.pill),
            border: Border.all(color: selected ? theme.ink : theme.lineStrong),
          ),
          child: Text(label, style: NocturneType.bodyStrong(foreground)),
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
        'COULD NOT TEST — KEEP WORKING OFFLINE',
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
