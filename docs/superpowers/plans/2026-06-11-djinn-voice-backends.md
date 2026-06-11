# Djinn Voice Backends Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current single voice path with Whisper conversation on single tap and native Android push-to-talk on long press, while keeping the existing Flutter plugin code in the repo as an inactive fallback.

**Architecture:** The app keeps one Flutter voice controller and one shared transcript/session state machine. The actual speech engines become pluggable backends: Whisper handles conversation mode through a Flutter-side chunked recorder/transcriber, native Android `SpeechRecognizer` handles push-to-talk, and the old Flutter `speech_to_text` path remains compiled but inactive. The settings screen stores the selected voice mode, and the UI routes mic gestures to the matching backend without changing the chat, TTS, or knowledge flows.

**Tech Stack:** Flutter/Dart, `whisper_ggml`, `record`, Kotlin, Android `SpeechRecognizer`, Android `MethodChannel`/`EventChannel`, Material 3, `flutter_test`.

---

## File Structure Map

Create:

- `lib/src/voice/voice_mode.dart` - enum and wire names for `whisper_conversation` and `native_android_ptt`.
- `lib/src/voice/voice_backend.dart` - backend interface, event types, and shared session objects.
- `lib/src/voice/whisper_conversation_adapter.dart` - Dart-facing Whisper conversation backend.
- `lib/src/voice/native_android_speech_adapter.dart` - Dart-facing native Android push-to-talk backend.
- `lib/src/voice/voice_backend_factory.dart` - resolves the selected backend from settings.
- `lib/src/voice/voice_channels.dart` - channel names used by the native Android bridge.
- `android/app/src/main/kotlin/com/elizerpist/djinn/voice/NativeSpeechBridge.kt` - native Android recognizer/session bridge.
- `android/app/src/main/kotlin/com/elizerpist/djinn/voice/VoiceChannels.kt` - channel names and message mapping.

Modify:

- `lib/src/settings/models/app_settings.dart` - add the selected voice mode field and persistence helpers.
- `lib/src/settings/data/app_settings_repository.dart` - persist the new voice mode value.
- `lib/src/settings/ui/settings_screen.dart` - add the voice mode selector UI and remove the old settings that no longer apply.
- `lib/src/voice/speech_adapter.dart` - keep the plugin implementation in place, but mark it as inactive/internal-only for this iteration.
- `lib/src/voice/voice_controller.dart` - route mic gestures and transcript commit logic through the selected backend.
- `lib/src/voice/voice_controls.dart` - wire tap versus long press to the correct backend mode.
- `lib/src/chat/ui/message_composer.dart` - keep the composer as the live transcript target.
- `lib/src/chat/ui/chat_screen.dart` - pass the selected voice mode and backend into the composer/controller.
- `lib/main.dart` - instantiate the new backend factory and pass it through app dependencies.
- `android/app/src/main/kotlin/com/elizerpist/djinn/MainActivity.kt` - attach the voice channels to the activity.
- `android/app/src/main/AndroidManifest.xml` - only if the native bridge needs extra permissions or queries beyond what already exists.

Tests:

- `test/settings_repository_test.dart`
- `test/settings_screen_test.dart`
- `test/voice_controller_test.dart`
- `test/message_composer_test.dart`
- `test/chat_screen_voice_test.dart`
- `test/speech_adapter_test.dart`
- `test/widget_test.dart`

---

### Task 1: Add Voice Mode Domain And Settings Persistence

**Files:**
- Create: `lib/src/voice/voice_mode.dart`
- Modify: `lib/src/settings/models/app_settings.dart`
- Modify: `lib/src/settings/data/app_settings_repository.dart`
- Modify: `test/settings_repository_test.dart`

- [ ] **Step 1: Write the failing tests**

Add tests that assert:

- `AppSettings.defaults()` resolves to `whisper_conversation` on fresh installs.
- the selected voice mode survives save/load round-trips.
- the settings repository keeps the selected mode when other unrelated AI settings change.

Run:

```bash
flutter test test/settings_repository_test.dart
```

Expected: FAIL because `voiceMode` does not yet exist as a first-class setting.

- [ ] **Step 2: Implement the minimal settings model**

Add `VoiceMode` in `lib/src/voice/voice_mode.dart`:

```dart
enum VoiceMode {
  whisperConversation('whisper_conversation'),
  nativeAndroidPtt('native_android_ptt');

  const VoiceMode(this.wireName);
  final String wireName;

  static VoiceMode fromWireName(String? value) {
    return VoiceMode.values.firstWhere(
      (mode) => mode.wireName == value,
      orElse: () => VoiceMode.whisperConversation,
    );
  }
}
```

Update `AppSettings` so it stores `voiceMode` as a `VoiceMode` value instead of a raw string. Keep all existing fields intact.

- [ ] **Step 3: Persist it in the repository**

Extend the settings repository serialization so the new voice mode writes and reads alongside the existing settings fields. Existing rows must default to `whisperConversation` if the field is absent.

- [ ] **Step 4: Re-run the tests**

Run:

```bash
flutter test test/settings_repository_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/voice/voice_mode.dart lib/src/settings/models/app_settings.dart lib/src/settings/data/app_settings_repository.dart test/settings_repository_test.dart
git commit -m "feat: persist voice mode setting"
```

---

### Task 2: Add Voice Backend Abstraction And Route Mic Gestures

**Files:**
- Create: `lib/src/voice/voice_backend.dart`
- Create: `lib/src/voice/voice_backend_factory.dart`
- Modify: `lib/src/voice/voice_controller.dart`
- Modify: `lib/src/voice/voice_controls.dart`
- Modify: `lib/src/chat/ui/message_composer.dart`
- Modify: `lib/src/chat/ui/chat_screen.dart`
- Test: `test/voice_controller_test.dart`
- Test: `test/message_composer_test.dart`
- Test: `test/chat_screen_voice_test.dart`

- [ ] **Step 1: Write the failing tests**

Add tests that assert:

- single tap starts the Whisper backend;
- long press starts the native Android PTT backend;
- only the current session may commit a transcript;
- late callbacks from the previous session are ignored;
- the plugin backend still compiles but is not selected by default.

Run:

```bash
flutter test test/voice_controller_test.dart test/message_composer_test.dart test/chat_screen_voice_test.dart
```

Expected: FAIL because the backend abstraction does not exist yet.

- [ ] **Step 2: Add the shared backend contract**

Create a small backend interface in `lib/src/voice/voice_backend.dart` with:

- `listen({required VoiceMode mode, required String locale})`
- `stop()`
- a stream of transcript/status/error events
- a session id on every emitted event

Keep `speech_to_text` behind the inactive plugin backend implementation, not in the UI routing path.

- [ ] **Step 3: Rewire the controller**

Update `VoiceController` so it owns:

- the active session id;
- the current partial transcript buffer;
- the commit gate that only accepts the current session.

The controller must treat:

- `whisperConversation` as the single-tap path;
- `nativeAndroidPtt` as the long-press path.

Update `voice_controls.dart` so:

- tap starts conversation mode;
- long press starts push-to-talk;
- release stops PTT immediately.

- [ ] **Step 4: Re-run the tests**

Run:

```bash
flutter test test/voice_controller_test.dart test/message_composer_test.dart test/chat_screen_voice_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/voice/voice_backend.dart lib/src/voice/voice_backend_factory.dart lib/src/voice/voice_controller.dart lib/src/voice/voice_controls.dart lib/src/chat/ui/message_composer.dart lib/src/chat/ui/chat_screen.dart test/voice_controller_test.dart test/message_composer_test.dart test/chat_screen_voice_test.dart
git commit -m "feat: route voice gestures through backend abstraction"
```

---

### Task 3: Add Native Android Push-To-Talk Backend

**Files:**
- Create: `android/app/src/main/kotlin/com/elizerpist/djinn/voice/NativeSpeechBridge.kt`
- Create: `android/app/src/main/kotlin/com/elizerpist/djinn/voice/VoiceChannels.kt`
- Modify: `android/app/src/main/kotlin/com/elizerpist/djinn/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml` only if needed
- Modify: `lib/src/voice/native_android_speech_adapter.dart`
- Test: `test/speech_adapter_test.dart`

- [ ] **Step 1: Write the failing adapter test**

Add a Dart-side test that proves the backend factory can construct a native Android adapter and that the adapter exposes the expected event shape for:

- `partial`
- `final`
- `status`
- `error`

Run:

```bash
flutter test test/speech_adapter_test.dart
```

Expected: FAIL because no native backend is wired yet.

- [ ] **Step 2: Implement the Android bridge**

Create a `SpeechRecognizer` bridge in Kotlin that:

- requests microphone access through the existing Android permission flow;
- starts a session with the requested locale;
- emits partial results through an `EventChannel`;
- emits final results or clear errors through the same channel;
- stops immediately on release;
- tags each event with a session id.

Use `SpeechRecognizer` and `RecognitionListener` directly. Keep `cancel()` reserved for forced teardown only.

- [ ] **Step 3: Attach the bridge to the Flutter activity**

Update `MainActivity.kt` so the channels are registered when the Flutter engine attaches. Keep the channel names in one shared Kotlin file so the Dart side and Android side cannot drift.

- [ ] **Step 4: Connect the Dart backend**

Implement `lib/src/voice/native_android_speech_adapter.dart` as the Dart-facing adapter that turns the channel stream into backend events and exposes `listen` and `stop`.

- [ ] **Step 5: Re-run the tests**

Run:

```bash
flutter test test/speech_adapter_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add android/app/src/main/kotlin/com/elizerpist/djinn/voice/NativeSpeechBridge.kt android/app/src/main/kotlin/com/elizerpist/djinn/voice/VoiceChannels.kt android/app/src/main/kotlin/com/elizerpist/djinn/MainActivity.kt lib/src/voice/native_android_speech_adapter.dart test/speech_adapter_test.dart
git commit -m "feat: add native android push to talk backend"
```

---

### Task 4: Add Whisper Conversation Backend

**Files:**
- Create: `lib/src/voice/whisper_conversation_adapter.dart`
- Create: `lib/src/voice/voice_backend_factory.dart`
- Test: `test/voice_controller_test.dart`

- [ ] **Step 1: Write the failing conversation tests**

Add tests that assert:

- a single tap starts the Whisper conversation backend;
- partial transcript updates arrive while speech is ongoing;
- turn end commits the current best transcript once;
- silence or backend closure may auto-restart once for conversation mode only;
- the active session gate ignores stale callbacks.

Run:

```bash
flutter test test/voice_controller_test.dart
```

Expected: FAIL because the Whisper backend and turn detector are missing.

- [ ] **Step 2: Build the conversation pipeline**

Implement a turn-based pipeline:

- audio capture;
- VAD or speech-end detection;
- ring buffer for the current turn;
- partial hypothesis updates;
- final commit on end-of-turn.

The pipeline should be offline-first and deterministic. Use `whisper_ggml` as the transcription engine and `record` for the mic capture path.

- [ ] **Step 3: Keep partials and finals separate**

The Whisper backend must expose:

- `partial`
- `final`
- `error`

The controller only sends the final transcript to chat after the turn closes.

- [ ] **Step 4: Re-run the tests**

Run:

```bash
flutter test test/voice_controller_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/src/voice/whisper_conversation_adapter.dart lib/src/voice/voice_backend_factory.dart
git commit -m "feat: add whisper conversation backend"
```

---

### Task 5: Wire Settings, Hide The Old Plugin Path, And Verify Builds

**Files:**
- Modify: `lib/src/settings/ui/settings_screen.dart`
- Modify: `lib/src/voice/speech_adapter.dart`
- Modify: `lib/main.dart`
- Modify: `test/settings_screen_test.dart`
- Modify: `test/widget_test.dart`
- Modify: `test/message_composer_test.dart`
- Modify: `test/chat_screen_voice_test.dart`

- [ ] **Step 1: Write the UI tests**

Add tests that assert:

- the settings screen shows the Whisper conversation / native Android PTT selector;
- the old plugin path is not visible as an active option;
- the selected mode survives app reload;
- the chat composer keeps the mic-only layout;
- the play/pause/stop controls remain on the assistant bubble.

Run:

```bash
flutter test test/settings_screen_test.dart test/widget_test.dart test/message_composer_test.dart test/chat_screen_voice_test.dart
```

Expected: FAIL until the settings UI and wiring are updated.

- [ ] **Step 2: Wire dependency injection**

Update `main.dart` so the app builds both backends, resolves the selected mode from settings, and passes the correct backend into the chat screen.

- [ ] **Step 3: Keep plugin code inactive**

Leave `lib/src/voice/speech_adapter.dart` and its tests in the repository, but remove it from active selection. The code must still compile so it can be reactivated later without reconstruction.

- [ ] **Step 4: Re-run the full Dart suite**

Run:

```bash
flutter analyze
flutter test
```

Expected: `No issues found!` from analyzer and all tests passing.

- [ ] **Step 5: Run the Android release pipeline**

Do not run a local APK build in Termux. Trigger the GitHub Actions debug APK workflow and verify:

- the workflow completes successfully;
- the release asset updates;
- the direct APK link resolves to the fresh build.

- [ ] **Step 6: Commit**

```bash
git add lib/src/settings/ui/settings_screen.dart lib/src/voice/speech_adapter.dart lib/main.dart test/settings_screen_test.dart test/widget_test.dart test/message_composer_test.dart test/chat_screen_voice_test.dart
git commit -m "feat: wire voice mode selection through settings"
```

---

## Verification Checklist

Before calling the work complete:

- `flutter analyze` passes cleanly.
- `flutter test` passes cleanly.
- The GitHub Actions debug APK workflow completes successfully.
- The release asset is refreshed with the expected APK.
- The old plugin code still exists in the repo but is not user-selectable.
- Single tap uses Whisper conversation.
- Long press uses native Android push-to-talk.
- Late callbacks cannot overwrite a newer session transcript.
