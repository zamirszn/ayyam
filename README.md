# Ayyam

**Ayyam** (أيام, “days”) is a calm, private companion for building a daily dua habit and reflecting on a lifetime of prayer. It is being built with Flutter for Android and the web.

> Ayyam is a learning and personal-tracking tool, not a source of religious rulings. AI-generated content must always be checked against the cited Quran or hadith source.

## What Ayyam does

### Dua Bucket List

- Delivers one new Quranic or authentically sourced dua each day.
- Shows the Arabic text, transliteration, translation, context, benefits, and source grading.
- Stores a five-day offline buffer so Android reminders can remain useful without a connection.
- Enforces non-repetition locally, rather than trusting the AI prompt alone.
- Tracks recited duas, streaks, history, and a searchable lifetime collection.

### Life in Dots

- Visualizes a 100-year life as one dot per day.
- Records days when all five prayers were completed, missed, or later addressed through the user's chosen personal practice.
- Supports historical estimates, make-up progress, completion trends, and debt projections.
- Keeps disputed religious framing explicit and configurable instead of presenting it as settled guidance.

Both features are optional and can be enabled or disabled independently without deleting their data.

## Product principles

- **Private by default:** user data stays on the device; there is no account or Ayyam backend.
- **Trust over novelty:** every dua needs a visible, verifiable source and grading.
- **Offline first:** stored content and local scheduling keep the core Android experience working offline.
- **Quiet and respectful:** calm visuals, generous spacing, accessible typography, and minimal motion.
- **Honest platform support:** Android is the reliable reminder platform; web reminders are best-effort because browsers cannot guarantee background execution without a push service.

## Planned stack

- Flutter and Dart for Android and PWA builds
- Riverpod for application state
- Drift for local structured data
- `flutter_secure_storage` for Android key storage
- Google Gemini structured output for sourced dua discovery
- Local notifications, Android exact alarms, and WorkManager for reminders and prefetching
- Nocturne UI as the visual-system reference

The user supplies their own Gemini API key. On Android it will be stored in Keystore-backed storage. The web app will clearly explain that browsers cannot provide equivalent secret storage and will avoid silently persisting the key.

## Roadmap

- [x] Project foundation, Nocturne theme, onboarding, secure key storage, and feature toggles
- [x] Settings screen, preferences management, and Nocturne date/time pickers
- [x] Local database, Gemini generation, validation, deduplication, and dua card
- [x] Android notifications, exact alarms, reboot recovery, and five-day prefetch
- [x] History, collection, source details, and streaks
- [ ] Life in Dots visualization, prayer check-in, and personal make-up tracking
- [ ] Analytics, data export/import, web build, accessibility, and release QA

## Current status

Ayyam is in early development. The app now includes calendar and swipe-based dua history, a searchable and filterable recited collection, full source-detail views, and honest current/longest streaks that are not repaired by late recitation. Work is moving next to Life in Dots, prayer check-ins, and personal make-up tracking.

The complete product requirements are in the [PRD](./PRD%20Dua%20Bucket%20List%20and%20Life%20in%20Dots.md).

## Development

Prerequisites:

- Flutter 3.47 or newer
- Dart 3.13 or newer
- Android Studio or an Android SDK for Android development
- A Chromium-based browser for the web target

Once the application scaffold is present:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

Before running the web target, install Drift's checked runtime assets:

```sh
bash tool/setup_drift_web.sh
flutter run -d chrome
```

Generated Drift bindings and web runtime assets are created in CI and are not committed.

Run the quality checks with:

```sh
flutter analyze
flutter test
```

## Contributing

The product is still defining its religious-content review process. Changes involving dua text, hadith attribution, prayer repayment language, or seed content should include reliable sources and should not imply a fatwa.

## License

No license has been selected yet. All rights are reserved until one is added.
