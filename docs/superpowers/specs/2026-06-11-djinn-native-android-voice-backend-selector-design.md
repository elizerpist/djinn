# Djinn Native Android Voice Backend Selector Design

Date: 2026-06-11

## Goal

Replace the current one-size-fits-all voice stack with a selectable backend so
Djinn can use either:

- the existing Flutter `speech_to_text` path, or
- a new native Android `SpeechRecognizer` bridge.

The key requirement is that the current implementation is not removed. The user
must be able to switch back and forth from Settings while keeping the existing
chat, TTS, and knowledge-base flow intact.

The native Android path exists to solve the specific push-to-talk and
conversation bugs observed in the current plugin-backed implementation:

- release does not reliably stop capture at the right moment;
- late callbacks can leak text after release;
- conversational mode stays open longer than intended;
- partial transcript handling is not precise enough for the desired UX.

## Success Criteria

1. Settings contains a voice backend selector with two choices:
   - `Plugin`
   - `Natív Android`
2. The existing plugin path continues to work.
3. The native Android path uses `SpeechRecognizer` and partial results.
4. Long press starts recording and release stops recording.
5. Live partial text appears in the composer while the user is speaking.
6. The transcript committed to chat is the current session transcript, not a
   late callback from a previous session.
7. Conversation mode and push-to-talk mode both run through the same selected
   backend, but with different session rules.
8. Switching the backend does not delete settings, API keys, or conversation
   history.

## Scope

In scope:

- Add a voice backend preference to app settings.
- Add a Settings UI control for choosing plugin vs native Android.
- Preserve the current `speech_to_text` implementation as one backend.
- Add a native Android voice backend and wire it through Flutter channels.
- Keep the current chat/TTS flow and reuse the existing voice controller
  concepts where possible.
- Add tests for backend selection, transcript commit behavior, and session
  isolation.

Out of scope:

- iOS native speech backend.
- Rewriting TTS.
- Changing the knowledge-base or AI model settings layout.
- Removing the plugin path.

## Architecture

### Current State

The current voice path is:

- Flutter `VoiceController`
- Flutter `speech_to_text` adapter
- Flutter TTS adapter

This works well enough for basic recognition, but the release semantics are not
controlled tightly enough for the desired Android UX.

### Target State

Introduce a backend abstraction with two implementations:

1. `PluginSpeechBackend`
   - wraps the current `speech_to_text` adapter
   - remains available for fallback and comparison

2. `NativeAndroidSpeechBackend`
   - uses a Flutter `MethodChannel`/`EventChannel` bridge
   - talks directly to Android `SpeechRecognizer`
   - exposes `start`, `stop`, `cancel`, `status`, `partial`, `final`, and
     `error`

The Flutter side keeps a single higher-level controller that:

- tracks the active session id;
- updates the composer draft text from partial results;
- commits only the current session transcript;
- ignores late events from stale sessions.

## Settings Design

Add one new setting field:

- `voiceBackend`: `plugin` | `native_android`

Placement:

- not in the AI block;
- in the voice/speech area of Settings, alongside voice behavior controls.

Default behavior:

- fresh Android installs default to `native_android`;
- existing saved preferences keep their current value on upgrade;
- the user can switch back to `plugin` at any time.

The UI control is a simple segmented selector or two-option pill group.
The app does not remove the plugin option.

## Native Android Bridge Design

The native backend runs in the Android app module and owns the recognizer
session lifecycle.

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

### Push-To-Talk

- long press on the mic starts a new session;
- partial text updates the composer draft live;
- release stops the current session;
- on stop, the current best transcript is committed once;
- late callbacks after stop are ignored.

### Conversation Mode

- single tap starts a session in conversation mode;
- the session can stay open longer than push-to-talk;
- if the backend ends the session, the controller decides whether to restart;
- only one active session may exist at a time.

Conversation mode must still obey the same session id filtering so late partials
do not overwrite a newer transcript. If the selected backend ends a session
because of silence or backend closure, the controller may auto-restart once for
conversation mode only.

## Error Handling

The native backend must expose clear states rather than generic failure text.
The Flutter controller maps them into user-visible states:

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
- add the native backend next to it;
- route selection through the saved backend preference;
- preserve the existing voice UI and bubble-level TTS controls;
- only switch runtime behavior when the user selects the native backend.

This avoids a risky big-bang rewrite while still allowing Android-native
behavior to be tested in production-like builds.

## Testing

Add tests for:

- settings persistence of the backend selector;
- backend selection resolving to the correct adapter;
- push-to-talk commit happening on release;
- live partial text updating before commit;
- stale session callbacks being ignored;
- conversation mode not launching overlapping sessions;
- plugin fallback still working when selected.

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
