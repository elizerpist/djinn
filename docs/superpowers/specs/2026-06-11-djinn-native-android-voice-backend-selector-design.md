# Djinn Native Android Voice Backend Selector Design

Date: 2026-06-11

## Goal

Replace the current one-size-fits-all voice stack with a split voice model:

- single tap uses a Whisper-based conversation backend;
- long press uses a native Android `SpeechRecognizer` push-to-talk backend.

The current Flutter `speech_to_text` implementation must not be deleted. It
stays in the codebase as an inactive future fallback, but it is removed from
the active user-facing backend choices for this iteration.

The native Android path exists to solve the specific push-to-talk bugs
observed in the current plugin-backed implementation:

- release does not reliably stop capture at the right moment;
- late callbacks can leak text after release;
- conversational mode stays open longer than intended;
- partial transcript handling is not precise enough for the desired UX.

## Success Criteria

1. Single tap starts Whisper conversation mode.
2. Long press starts native Android push-to-talk mode.
3. Live partial text appears in the composer while the user is speaking.
4. The transcript committed to chat is the current session transcript, not a
   late callback from a previous session.
5. Switching voice modes does not delete settings, API keys, or conversation
   history.
6. The old Flutter plugin implementation remains in the codebase but is not
   exposed as an active option in this iteration.

## Scope

In scope:

- Add a voice mode preference to app settings.
- Add a Settings UI control for choosing Whisper conversation vs native
  Android push-to-talk.
- Preserve the current `speech_to_text` implementation in code but keep it
  inactive.
- Add a native Android push-to-talk backend and a Whisper conversation
  backend, each wired through Flutter channels or FFI as appropriate.
- Keep the current chat/TTS flow and reuse the existing voice controller
  concepts where possible.
- Add tests for backend selection, transcript commit behavior, and session
  isolation.

Out of scope:

- iOS native speech backend.
- Rewriting TTS.
- Changing the knowledge-base or AI model settings layout.
- Removing the plugin code.

## Architecture

### Current State

The current voice path is:

- Flutter `VoiceController`
- Flutter `speech_to_text` adapter
- Flutter TTS adapter

This works well enough for basic recognition, but the release semantics are not
controlled tightly enough for the desired Android UX.

### Target State

Introduce a backend abstraction with three implementations:

1. `WhisperConversationBackend`
   - handles single-tap conversation mode
   - uses Whisper-based offline transcription with VAD and turn detection

2. `NativeAndroidSpeechBackend`
   - uses a Flutter `MethodChannel`/`EventChannel` bridge
   - talks directly to Android `SpeechRecognizer`
   - exposes `start`, `stop`, `cancel`, `status`, `partial`, `final`, and
     `error`

3. `PluginSpeechBackend`
   - wraps the current `speech_to_text` adapter
   - remains in the codebase as an inactive fallback, not an active setting
   - can be re-enabled later without reconstructing the old implementation

The Flutter side keeps a single higher-level controller that:

- tracks the active session id;
- updates the composer draft text from partial results;
- commits only the current session transcript;
- ignores late events from stale sessions.

## Settings Design

Add one new setting field:

- `voiceMode`: `whisper_conversation` | `native_android_ptt`

Placement:

- not in the AI block;
- in the voice/speech area of Settings, alongside voice behavior controls.

Default behavior:

- fresh Android installs default to `whisper_conversation`;
- existing saved preferences keep their current value on upgrade;
- the user can switch to `native_android_ptt` for long-press dictation;
- the plugin implementation stays in code but is not shown as a live option.

The UI control is a simple segmented selector or two-option pill group.

## Native Android Bridge Design

The native backend runs in the Android app module and owns the recognizer
session lifecycle for push-to-talk.

Minimum responsibilities:

- request microphone permission state through the existing Android permissions
  flow;
- create and reuse a `SpeechRecognizer` instance safely;
- start a session with a requested locale;
- stream `partialResults` back to Flutter;
- emit a final transcript when available;
- stop recognition immediately on release;
- expose explicit error codes for:
  - permission denied;
  - language unavailable;
  - service disconnected;
  - audio error;
  - recognizer unavailable;
- tag every emitted event with a session id.

Partial results are treated as live draft text, not final chat input.
Late callbacks from an older session are discarded on the Flutter side.

## Voice Session Rules

### Whisper Conversation

- single tap starts a Whisper session;
- VAD and turn detection determine when the user has finished speaking;
- partial text updates the composer draft live;
- when the turn ends, the best transcript is committed once;
- late callbacks after commit are ignored.

### Native Android Push-To-Talk

- long press on the mic starts a new session;
- partial text updates the composer draft live;
- release stops the current session;
- on stop, the current best transcript is committed once;
- late callbacks after stop are ignored.

The conversation backend must still obey the same session id filtering so late
partials do not overwrite a newer transcript. If the selected backend ends a
session because of silence or backend closure, the controller may auto-restart
once for conversation mode only.

## Error Handling

Both backends must expose clear states rather than generic failure text. The
Flutter controller maps them into user-visible states:

- no speech detected;
- unsupported language;
- recognizer disconnected;
- permission denied;
- unexpected backend failure.

The error handling rule is strict:

- only the active session may update the UI;
- stop should never create duplicate commit events;
- cancel should be reserved for forced teardown, not normal release handling.

## Migration Plan

The change must be additive:

- keep the current plugin code and tests;
- add the Whisper conversation backend and the native Android push-to-talk
  backend;
- route selection through the saved voice mode preference;
- preserve the existing voice UI and bubble-level TTS controls;
- only switch runtime behavior when the user selects the requested voice mode.

This avoids a risky big-bang rewrite while still allowing Android-native
behavior to be tested in production-like builds.

## Testing

Add tests for:

- settings persistence of the voice mode selector;
- voice mode selection resolving to the correct backend;
- push-to-talk commit happening on release;
- live partial text updating before commit;
- stale session callbacks being ignored;
- conversation mode not launching overlapping sessions;
- inactive plugin code remaining build-safe.

The native bridge itself should also get platform-level checks for:

- start/stop/cancel wiring;
- partial result emission;
- error mapping.

## Logging

The native backend should continue the existing debug console style and add a
backend tag where useful, for example:

- `Voice/STT backend=native_android`
- `Voice/STT backend=plugin`

This keeps the logs comparable across both implementations without inventing a
new console taxonomy.
