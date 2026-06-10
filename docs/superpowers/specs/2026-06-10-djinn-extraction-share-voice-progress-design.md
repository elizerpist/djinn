# Djinn Extraction, Share, Voice, And Progress Follow-Up Design

Date: 2026-06-10

## Goal

Fix the gaps found after the latest debug APK test without changing the
working chunking path unnecessarily. The app already chunks Gemini documents,
exports/imports `.djinnpack` packages, and answers from ObjectBox evidence, but
the tested PDF exposed missing image/table extraction, no flowchart candidates,
language drift in answers, broken voice input, incomplete native share behavior,
and weak visual feedback during processing.

This follow-up is intentionally scoped around observable user failures:

- image-based RAVE score table is not extracted;
- flowchart in the PDF is not listed for validation;
- Hungarian questions can get English answers;
- share action does not behave like native Android share of the PDF+chunk pack;
- already chunked PDFs need an explicit re-sync/re-chunk workflow;
- settings place language in the wrong logical block;
- voice input still fails in both push-to-talk and conversation mode;
- TTS controls must live on each AI answer bubble, not beside the text input;
- chunking needs visible per-document progress in the knowledge list.

## Non-Goals

- Do not rewrite the working basic chunking path without a test proving the
  change is needed.
- Do not add placeholder or disabled menu items. Visible controls must either
  work or be hidden until they can work.
- Do not run local Android APK builds in Termux. APK builds remain GitHub
  Actions only.
- Do not make offline non-LLM answer generation part of this follow-up unless
  the implementation plan explicitly creates a small, tested slice.

## User-Visible Success Criteria

1. A PDF page whose important content is an image-based table can be processed
   through OCR/vision and stored as usable evidence chunks.
2. RAVE score criteria inside an image/table are extractable and retrievable in
   chat answers.
3. Flowchart-like structures in processed PDFs create validation candidates and
   appear in the validation screen.
4. Hungarian questions receive Hungarian answers. Ambiguous input defaults to
   Hungarian. Clearly English questions receive English answers.
5. Native share opens the Android share sheet with the same PDF+chunk package
   that "save package" would create.
6. Unprocessed PDFs show `Szinkronizalas`; processed PDFs show
   `Ujraszinkronizalas`.
7. Re-sync clears the old generated knowledge for that document and rebuilds it
   from the current settings.
8. Language/TTS settings are moved out of the AI section.
9. Chat input shows only the mic button. AI answer bubbles contain their own
   play/pause/stop controls.
10. During chunking, the PDF row shows clear progress/state without becoming a
    large card again.

## Extraction Design

### Current Failure

The current Gemini flow can successfully produce text chunks:

```text
[AI Training] extraction chunks=15 model=gemini-2.5-flash-lite provider=gemini
[Flowchart] extraction candidates=0 reason=text_chunk_schema_only
```

That means the extraction schema currently stores text chunks only. It does not
ask for, validate, or persist table/score structures or flowchart candidates.
For image-based PDF content, text extraction can report `text_available` while
still missing the visually important table.

### Required Extraction Stages

1. Text extraction remains the first pass.
2. Page diagnostics decide whether a page needs visual extraction:
   - low text length;
   - table-like region detected by OCR/vision;
   - score keywords such as `RAVE`, `score`, `pont`, `skala`, `kriterium`;
   - flowchart keywords or visual diagram hints.
3. Vision/OCR extraction runs only for pages that need it, not blindly for every
   page.
4. Structured extraction returns separate collections:
   - `chunks`;
   - `tables`;
   - `scores`;
   - `flowcharts`.
5. Stored evidence records keep source kind:
   - `text_chunk`;
   - `table_chunk`;
   - `score_chunk`;
   - `flowchart_candidate`.

### RAVE Score Handling

RAVE score extraction must not depend on the table being copied as plain text.
The vision/OCR pass should produce structured rows:

- score name;
- row label/criterion;
- point value or category;
- explanation text;
- source page;
- confidence;
- raw OCR text if useful for debugging.

The RAG store can still index these as text evidence, but the text must be
generated from the structured table rows so chat can answer score-element
questions.

### Flowchart Handling

Flowchart extraction is a sibling output to text chunks, not a side effect of
text chunking.

Minimum flowchart candidate fields:

- document id;
- page number;
- title or inferred label;
- nodes;
- edges;
- raw OCR/vision summary;
- confidence;
- validation status.

The validation screen must query persisted flowchart candidates. A zero list
must log and display a precise reason:

- no processed documents;
- no candidate records persisted;
- only text chunk schema ran;
- candidates already validated;
- extraction failed.

## Answer Language Design

The answer generator receives a strict language rule:

- if the user's latest question is Hungarian, answer Hungarian;
- if the language is ambiguous, answer Hungarian;
- if the user's latest question is clearly English, answer English;
- do not infer answer language from retrieved PDF language alone.

This rule must be added to both Gemini and OpenAI answer prompts. Debug logs
should include the selected answer language without logging the full prompt:

```text
[Chat/RAG] answer language=hu reason=user_or_default
[Chat/RAG] answer language=en reason=user_question_english
```

## Native Share Design

The share action uses the same package creation path as package export:

1. Build a `.djinnpack` file containing the PDF bytes, chunks, embeddings,
   metadata, and manifest.
2. Write it to app cache or a temporary share location.
3. Invoke the native Android share sheet with a file URI handled through the
   Flutter share plugin/platform channel.
4. Use a native share icon in the UI.

Share and save differ only in destination:

- save package: user selects storage location;
- share package: Android share sheet receives the generated package.

The share action must work for one selected PDF first. Multi-select sharing can
either create one multi-document package or stay hidden until supported.

## Sync And Re-Sync Design

The document action label depends on processing state:

- no chunks/failed/imported: `Szinkronizalas`;
- processed/embedded: `Ujraszinkronizalas`;
- currently processing: disabled state with spinner/progress.

Re-sync behavior:

1. User confirms or taps explicit re-sync.
2. Existing generated chunks, embeddings, flowchart candidates, and extraction
   errors for that document are deleted.
3. The original imported PDF bytes are used as source.
4. Processing runs with the current provider/model/chunking mode settings.
5. If the new run fails, the document keeps a failed state and can be retried.

The app must not require the original external file path to still exist,
because PDFs are copied into app-private storage at import time.

## Settings Layout

The AI section contains only AI configuration:

- provider pills;
- provider API key;
- API key test;
- model dropdowns;
- chunking detail mode.

Language/TTS settings move into a separate non-AI block, for example
`Nyelv es felolvasas`:

- answer language default behavior, if exposed;
- TTS voice/locale dropdown;
- speech rate/pitch if retained.

Voice mode is not a settings dropdown. Chat controls define behavior:

- single mic tap: conversation mode;
- long mic press: push-to-talk.

## Voice Input Design

The observed voice failures:

```text
[Voice/STT] listen start locale=hu-HU
[Voice/STT] permission status=granted
[Voice/STT] status=listening
[Voice/STT] status=notListening
[Voice/STT] status=done
[Voice/STT] error code=error_language_not_supported
[Voice/STT] error code=error_server_disconnected
```

The current logs are not sufficient because they show the requested locale, not
necessarily the resolved locale used by Android SpeechRecognizer.

Required diagnostics:

- requested locale;
- normalized locale;
- system locale;
- available locale count;
- chosen fallback locale;
- retry attempt;
- final error classification.

Rules:

- `error_language_not_supported` triggers at most one fallback attempt with an
  available locale or system locale.
- `error_server_disconnected` is treated as a recognizer/service failure, not
  an endless retry loop.
- empty transcripts never start chat.
- final, non-empty transcript starts chat.
- conversation mode must not start a new listener while one is already active.

The UI should surface a short actionable state, for example:

- `A magyar beszedfelismeres nem elerheto ezen a keszuleken.`
- `A beszedfelismero szolgaltatas megszakadt. Probald ujra.`

## Per-Bubble TTS Design

The chat input row contains only text input and mic.

Each assistant bubble has its own TTS controls:

- idle: play;
- speaking on this bubble: pause and stop;
- paused on this bubble: resume and stop;
- another bubble speaking: this bubble shows play, and tapping it stops the
  previous speech before starting this one.

TTS state is keyed by message id, not by global text content only. Duplicate
suppression still prevents repeated taps from stacking speech sessions.

## Chunking Progress Design

The recommended UX is a compact row-level progress strip.

### Why Not A Large Per-Row Sync Button

Always-visible buttons made the PDF boxes too large and noisy. The action
should stay in the header/selection menu, while row state shows what is
happening.

### Proposed Row States

- Idle imported:
  - badge: `Nincs szinkronizalva`;
  - selected-menu action: `Szinkronizalas`.
- Extracting:
  - thin indeterminate progress strip at row bottom;
  - text: `Kinyeres...`;
  - destructive actions disabled for that row.
- Embedding:
  - determinate progress strip when chunk count is known;
  - text: `Embedding 4/15`.
- Complete:
  - badge: `Kesz`;
  - selected-menu action: `Ujraszinkronizalas`.
- Failed:
  - badge: `Hiba`;
  - selected-menu action: `Ujraprobalas` or `Ujraszinkronizalas`.

### Progress Data Contract

The processing service should emit document-level progress events:

- document id;
- phase: queued, extracting, embedding, complete, failed;
- current step;
- total steps when known;
- short display label;
- retryable error code when failed.

The extraction phase is indeterminate because chunk count is not yet known.
The embedding phase can be determinate because the app knows the chunk count.

## Detailed Implementation Checklist

### Extraction

- [ ] Add tests showing image-only/table-heavy pages currently lose RAVE score
      evidence.
- [ ] Add page diagnostics for text length and visual extraction need.
- [ ] Add vision/OCR extraction path for selected pages.
- [ ] Extend extraction result schema with tables, scores, and flowcharts.
- [ ] Store RAVE score rows as searchable evidence.
- [ ] Store flowchart candidates separately from text chunks.
- [ ] Add debug logs for text pages, vision pages, score rows, table rows, and
      flowchart candidates.

### Flowchart Validation

- [ ] Persist flowchart candidates from extraction.
- [ ] Query validation screen from persisted candidate records.
- [ ] Log zero-state reason precisely.
- [ ] Add a fixture/mock test where one candidate appears in validation.

### Language

- [ ] Add language detection/default rule to OpenAI answer prompts.
- [ ] Add language detection/default rule to Gemini answer prompts.
- [ ] Add tests for Hungarian question -> Hungarian answer instruction.
- [ ] Add tests for ambiguous question -> Hungarian default.
- [ ] Add tests for English question -> English answer instruction.

### Share

- [ ] Add package-share service using existing pack export builder.
- [ ] Add native share icon.
- [ ] Add Android share sheet invocation.
- [ ] Hide or disable share only when no selected shareable document exists.
- [ ] Test that share receives a real `.djinnpack` file path.

### Sync/Re-Sync

- [ ] Compute action label from document processing state.
- [ ] Add explicit re-sync path for processed documents.
- [ ] Delete old generated records before reprocessing.
- [ ] Keep original imported PDF bytes as the processing source.
- [ ] Test re-sync replaces old chunks.

### Settings

- [ ] Move language/TTS controls out of AI block.
- [ ] Keep AI block focused on provider/key/models/chunking.
- [ ] Keep voice mode out of settings.
- [ ] Verify settings persist provider and do not reset to OpenAI.

### Voice

- [ ] Log requested, normalized, system, available, and selected locale.
- [ ] Retry `error_language_not_supported` once with fallback locale.
- [ ] Treat `error_server_disconnected` as service failure with no retry loop.
- [ ] Prevent concurrent listeners.
- [ ] Ensure push-to-talk and conversation mode both send final non-empty text.

### Chat TTS

- [ ] Remove global play/pause/stop controls from input area.
- [ ] Keep only mic in input area.
- [ ] Add per-message TTS state keyed by assistant message id.
- [ ] Show play/pause/resume/stop on the active assistant bubble.
- [ ] Test duplicate speak suppression per message.

### Knowledge Progress UI

- [ ] Add processing progress state to document view model.
- [ ] Add row-bottom indeterminate strip during extraction.
- [ ] Add row-bottom determinate strip during embedding.
- [ ] Show `Embedding current/total` once total is known.
- [ ] Disable conflicting actions during processing.
- [ ] Test idle, extracting, embedding, complete, failed row states.

## Test Plan

Automated tests should be added before implementation changes where practical:

- service tests for language instruction selection;
- pack share service test using a fake share adapter;
- document re-sync service test;
- extraction parser/schema tests for tables, scores, and flowcharts;
- voice controller tests for locale fallback and server-disconnected handling;
- chat widget tests for per-bubble TTS controls;
- knowledge row widget tests for progress states.

Manual verification after implementation:

1. Import a PDF with image-based RAVE score table.
2. Sync it through Gemini.
3. Verify RAVE rows are retrieved by chat.
4. Verify flowchart appears under validation.
5. Ask in Hungarian and confirm Hungarian answer.
6. Ask in English and confirm English answer.
7. Share the PDF+chunk package to Android share sheet / Drive.
8. Re-sync an already processed PDF.
9. Test single-tap mic conversation mode.
10. Test long-press mic push-to-talk mode.
11. Verify only the active assistant bubble shows pause/stop.
12. Verify progress strip appears during extraction and embedding.

## Approval Gate

This document is a planning/spec checkpoint. Implementation should start only
after the user confirms that this follow-up scope is correct.
