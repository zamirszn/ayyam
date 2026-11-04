import 'package:ayyam/core/backup/app_backup_service.dart';
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
import 'package:ayyam/features/dua/application/dua_library_service.dart';
import 'package:ayyam/features/dua/application/dua_reminder_coordinator.dart';
import 'package:ayyam/features/dua/application/dua_reminder_platform.dart';
import 'package:ayyam/features/dua/application/today_dua_controller.dart';
import 'package:ayyam/features/life/application/life_dashboard_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    required this.initialPreferences,
    this.embedded = false,
  });

  final AppPreferences initialPreferences;
  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late AppPreferences _savedPreferences;
  late bool _duaEnabled;
  late bool _lifeEnabled;
  late int _reminderHour;
  late int _reminderMinute;
  late bool _lifeReminderEnabled;
  late int _lifeReminderHour;
  late int _lifeReminderMinute;
  late String _language;
  late DateTime? _birthDate;
  late AppThemeMode _themeMode;
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
  bool _loadingDelivery = false;
  bool _backingUp = false;
  bool _deletingAll = false;
  bool _deleteArmed = false;
  bool _restoreArmed = false;
  ReminderDeliveryStatus? _deliveryStatus;
  String? _backupMessage;
  String? _backupError;

  @override
  void initState() {
    super.initState();
    _savedPreferences = widget.initialPreferences;
    _duaEnabled = _savedPreferences.duaEnabled;
    _lifeEnabled = _savedPreferences.lifeInDotsEnabled;
    _reminderHour = _savedPreferences.reminderHour;
    _reminderMinute = _savedPreferences.reminderMinute;
    _lifeReminderEnabled = _savedPreferences.lifeReminderEnabled;
    _lifeReminderHour = _savedPreferences.lifeReminderHour;
    _lifeReminderMinute = _savedPreferences.lifeReminderMinute;
    _language = _savedPreferences.translationLanguage;
    _birthDate = _savedPreferences.dateOfBirth;
    _themeMode = _savedPreferences.themeMode;
    _apiKeyController = TextEditingController();
    _missedYearsController = TextEditingController(
      text: _savedPreferences.missedPrayerYears == 0
          ? ''
          : '${_savedPreferences.missedPrayerYears}',
    );
    _restoreApiKey();
    _refreshDeliveryStatus();
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

  Future<void> _refreshDeliveryStatus() async {
    if (!isAndroidRuntime) return;
    setState(() => _loadingDelivery = true);
    try {
      final status = await ref
          .read(duaReminderPlatformProvider)
          .deliveryStatus();
      if (!mounted) return;
      setState(() {
        _deliveryStatus = status;
        _loadingDelivery = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDelivery = false);
    }
  }

  Future<void> _requestReminderPermissions() async {
    setState(() => _loadingDelivery = true);
    try {
      final status = await ref
          .read(duaReminderPlatformProvider)
          .requestPermissions();
      if (!mounted) return;
      setState(() {
        _deliveryStatus = status;
        _loadingDelivery = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDelivery = false);
    }
  }

  Future<void> _openBatteryOptimizationSettings() async {
    try {
      await ref
          .read(duaReminderPlatformProvider)
          .openBatteryOptimizationSettings();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saveError = 'Could not open Android battery settings.');
    }
  }

  String _deliveryLabel(bool? allowed) {
    if (_loadingDelivery) return 'CHECKING';
    return switch (allowed) {
      true => 'ENABLED',
      false => 'OFF',
      null => 'NOT CHECKED',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final lifeSection = _duaEnabled ? '04' : '02';
    final dataSection = (2 + (_duaEnabled ? 2 : 0) + (_lifeEnabled ? 1 : 0))
        .toString()
        .padLeft(2, '0');

    return NocturneScaffold(
      tone: NocturneTone.rest,
      includeBottomSafeArea: !widget.embedded,
      child: AnimatedPadding(
        duration: NocturneDuration.fast,
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboard),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            NocturneSpace.gutter,
            NocturneSpace.x2,
            NocturneSpace.gutter,
            widget.embedded
                ? NocturneSpace.navHeight + NocturneSpace.x3
                : NocturneSpace.x5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (!widget.embedded)
                    CircleAction(
                      glyph: NocturneGlyph.chevronLeft,
                      onTap: _saving || _backingUp || _deletingAll
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      semanticLabel: 'Back',
                      size: 38,
                    )
                  else
                    Text('YOU', style: NocturneType.label(theme.ink)),
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
                      const _SectionLabel(index: '01', label: 'Appearance'),
                      const SizedBox(height: NocturneSpace.x3),
                      Wrap(
                        spacing: NocturneSpace.x2,
                        runSpacing: NocturneSpace.x2,
                        children: <Widget>[
                          for (final mode in AppThemeMode.values)
                            _ChoicePill(
                              label: switch (mode) {
                                AppThemeMode.system => 'Device',
                                AppThemeMode.light => 'Light',
                                AppThemeMode.dark => 'Dark',
                              },
                              selected: _themeMode == mode,
                              onTap: () => setState(() {
                                _themeMode = mode;
                                _clearFeedback();
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: NocturneSpace.x2),
                      Text(
                        'Device follows the appearance selected by your operating system.',
                        style: NocturneType.caption(theme.faint),
                      ),
                      const SizedBox(height: NocturneSpace.x8),
                      const _SectionLabel(index: '02', label: 'Features'),
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
                          status: isAndroid
                              ? _deliveryLabel(
                                  _deliveryStatus?.notificationsAllowed,
                                )
                              : 'BEST EFFORT',
                          onTap: isAndroidRuntime
                              ? _requestReminderPermissions
                              : null,
                        ),
                        const SizedBox(height: NocturneSpace.x2),
                        _StatusRow(
                          glyph: NocturneGlyph.clock,
                          title: 'Exact alarms',
                          subtitle: isAndroid
                              ? 'Used for punctual reminders after permission is granted.'
                              : 'Browsers cannot guarantee an exact background alarm.',
                          status: isAndroid
                              ? _deliveryLabel(
                                  _deliveryStatus?.exactAlarmsAllowed,
                                )
                              : 'UNAVAILABLE',
                          onTap: isAndroidRuntime
                              ? _requestReminderPermissions
                              : null,
                        ),
                        const SizedBox(height: NocturneSpace.x2),
                        _StatusRow(
                          glyph: NocturneGlyph.lock,
                          title: 'Battery access',
                          subtitle: isAndroid
                              ? 'Optional exemption for more reliable delivery.'
                              : 'No extra background access is requested on the web.',
                          status: isAndroid ? 'OPEN SETTINGS' : 'NOT NEEDED',
                          onTap: isAndroidRuntime
                              ? _openBatteryOptimizationSettings
                              : null,
                        ),
                      ],
                      if (_lifeEnabled) ...<Widget>[
                        const SizedBox(height: NocturneSpace.x8),
                        _SectionLabel(index: lifeSection, label: 'Life anchor'),
                        const SizedBox(height: NocturneSpace.x3),
                        _FeatureRow(
                          glyph: NocturneGlyph.bell,
                          title: 'Daily prayer check-in',
                          subtitle:
                              'An optional private reminder to record today.',
                          value: _lifeReminderEnabled,
                          onChanged: (value) => setState(() {
                            _lifeReminderEnabled = value;
                            _clearFeedback();
                          }),
                        ),
                        if (_lifeReminderEnabled) ...<Widget>[
                          const SizedBox(height: NocturneSpace.x3),
                          NocturnePickerField(
                            label: 'Check-in time',
                            value: nocturneClockLabel(
                              _lifeReminderHour,
                              _lifeReminderMinute,
                            ),
                            glyph: NocturneGlyph.clock,
                            onTap: _pickLifeReminderTime,
                            helper: 'Opens Life in Dots from the reminder. Off by default.',
                          ),
                          if (!_duaEnabled) ...<Widget>[
                            const SizedBox(height: NocturneSpace.x3),
                            _StatusRow(
                              glyph: NocturneGlyph.bell,
                              title: 'Reminder permission',
                              subtitle: isAndroid
                                  ? 'Required for the daily check-in notification.'
                                  : 'Browser delivery is best-effort; the check-in remains available in-app.',
                              status: isAndroid
                                  ? _deliveryLabel(
                                      _deliveryStatus?.notificationsAllowed,
                                    )
                                  : 'BEST EFFORT',
                              onTap: isAndroidRuntime
                                  ? _requestReminderPermissions
                                  : null,
                            ),
                          ],
                        ],
                        const SizedBox(height: NocturneSpace.x5),
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
                          helper: 'Each year adds 365 undated personal make-up items; no historical dates are assumed.',
                          onChanged: (_) => setState(() {
                            _lifeError = null;
                            _clearFeedback();
                          }),
                        ),
                      ],
                      const SizedBox(height: NocturneSpace.x8),
                      _SectionLabel(index: dataSection, label: 'Your data'),
                      const SizedBox(height: NocturneSpace.x3),
                      GlassCard(
                        tint: theme.blue,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Private JSON backup',
                              style: NocturneType.bodyStrong(theme.ink),
                            ),
                            const SizedBox(height: NocturneSpace.x2),
                            Text(
                              'Copies saved settings, duas, prayer days, and make-up progress. Your Gemini key is never included.',
                              style: NocturneType.caption(theme.muted),
                            ),
                            const SizedBox(height: NocturneSpace.x4),
                            NocturneButton(
                              label: _backingUp
                                  ? 'Preparing backup…'
                                  : 'Copy backup JSON',
                              style: NocturneButtonStyle.glass,
                              compact: true,
                              onTap: _backingUp || _deletingAll
                                  ? null
                                  : _copyBackup,
                            ),
                            const SizedBox(height: NocturneSpace.x2),
                            NocturneButton(
                              label: _restoreArmed
                                  ? 'Tap again to replace local data'
                                  : 'Restore JSON from clipboard',
                              style: NocturneButtonStyle.danger,
                              compact: true,
                              onTap: _backingUp || _deletingAll
                                  ? null
                                  : _restoreBackup,
                            ),
                            if (_restoreArmed) ...<Widget>[
                              const SizedBox(height: NocturneSpace.x2),
                              Text(
                                'This replaces current saved data. Invalid backups make no changes.',
                                style: NocturneType.caption(theme.missed),
                              ),
                            ],
                            const SizedBox(height: NocturneSpace.x2),
                            NocturneButton(
                              label: _deletingAll
                                  ? 'Deleting local data…'
                                  : _deleteArmed
                                  ? 'Tap again to delete everything'
                                  : 'Delete all data',
                              style: NocturneButtonStyle.danger,
                              compact: true,
                              onTap: _backingUp || _deletingAll
                                  ? null
                                  : _deleteAllData,
                            ),
                            if (_deleteArmed) ...<Widget>[
                              const SizedBox(height: NocturneSpace.x2),
                              Text(
                                'This permanently removes all saved duas, prayer records, settings, and the Gemini key, then returns to onboarding.',
                                style: NocturneType.caption(theme.missed),
                              ),
                            ],
                            if (_backupError != null ||
                                _backupMessage != null) ...<Widget>[
                              const SizedBox(height: NocturneSpace.x3),
                              Text(
                                _backupError ?? _backupMessage!,
                                style: NocturneType.caption(
                                  _backupError == null
                                      ? theme.kept
                                      : theme.missed,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
                label: _saving
                    ? 'Saving…'
                    : _backingUp || _deletingAll
                    ? 'Working…'
                    : 'Save changes',
                trailing: _saving || _backingUp || _deletingAll
                    ? null
                    : NocturneGlyph.check,
                onTap: _saving || _backingUp || _deletingAll ? null : _save,
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

  Future<void> _pickLifeReminderTime() async {
    final picked = await showNocturneTimePicker(
      context,
      hour: _lifeReminderHour,
      minute: _lifeReminderMinute,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _lifeReminderHour = picked.hour;
      _lifeReminderMinute = picked.minute;
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

  Future<void> _copyBackup() async {
    setState(() {
      _backingUp = true;
      _deleteArmed = false;
      _restoreArmed = false;
      _backupError = null;
      _backupMessage = null;
    });
    try {
      final json = await ref.read(appBackupServiceProvider).exportJson();
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      setState(() {
        _backingUp = false;
        _backupMessage = 'Backup copied. The Gemini key was excluded.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _backingUp = false;
        _backupError = 'Could not copy a backup. Check clipboard access.';
      });
    }
  }

  Future<void> _restoreBackup() async {
    if (!_restoreArmed) {
      setState(() {
        _deleteArmed = false;
        _restoreArmed = true;
        _backupError = null;
        _backupMessage = null;
      });
      return;
    }
    setState(() {
      _backingUp = true;
      _restoreArmed = false;
      _backupError = null;
      _backupMessage = null;
    });
    try {
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      final source = clipboard?.text?.trim();
      if (source == null || source.isEmpty) {
        throw const FormatException('Clipboard is empty.');
      }
      final result = await ref
          .read(appBackupServiceProvider)
          .importJson(source);
      ref
        ..invalidate(appPreferencesProvider)
        ..invalidate(todayDuaProvider)
        ..invalidate(duaLibraryProvider)
        ..invalidate(lifeDashboardProvider);
      if (!mounted) return;
      final preferences = result.preferences;
      setState(() {
        _savedPreferences = preferences;
        _duaEnabled = preferences.duaEnabled;
        _lifeEnabled = preferences.lifeInDotsEnabled;
        _reminderHour = preferences.reminderHour;
        _reminderMinute = preferences.reminderMinute;
        _lifeReminderEnabled = preferences.lifeReminderEnabled;
        _lifeReminderHour = preferences.lifeReminderHour;
        _lifeReminderMinute = preferences.lifeReminderMinute;
        _language = preferences.translationLanguage;
        _birthDate = preferences.dateOfBirth;
        _themeMode = preferences.themeMode;
        _missedYearsController.text = preferences.missedPrayerYears == 0
            ? ''
            : '${preferences.missedPrayerYears}';
        _backingUp = false;
        _backupMessage =
            'Restored ${result.duas} duas, ${result.prayerDays} prayer days, and ${result.makeupDebts} make-up items.';
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _backingUp = false;
        _backupError = 'Backup not restored: ${error.message}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _backingUp = false;
        _backupError =
            'Could not restore this backup. Local data is unchanged.';
      });
    }
  }

  Future<void> _deleteAllData() async {
    if (!_deleteArmed) {
      setState(() {
        _deleteArmed = true;
        _restoreArmed = false;
        _backupError = null;
        _backupMessage = null;
      });
      return;
    }
    setState(() {
      _deletingAll = true;
      _deleteArmed = false;
      _restoreArmed = false;
      _backupError = null;
      _backupMessage = null;
    });
    try {
      await ref
          .read(duaReminderCoordinatorProvider)
          .sync(AppPreferences.defaults);
      await ref.read(apiKeyVaultProvider).delete();
      await ref.read(appBackupServiceProvider).deleteAllData();
      ref.read(selectedDuaDayProvider.notifier).clear();
      ref.read(selectedLifeReminderProvider.notifier).clear();
      ref
        ..invalidate(appPreferencesProvider)
        ..invalidate(todayDuaProvider)
        ..invalidate(duaLibraryProvider)
        ..invalidate(lifeDashboardProvider);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deletingAll = false;
        _backupError =
            'Reset could not finish. Retry to clear any remaining local data.';
      });
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
      lifeReminderEnabled: _lifeReminderEnabled,
      lifeReminderHour: _lifeReminderHour,
      lifeReminderMinute: _lifeReminderMinute,
      themeMode: _themeMode,
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
    this.onTap,
  });

  final NocturneGlyph glyph;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      onTap: onTap,
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
