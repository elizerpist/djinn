import 'dart:convert';

import '../models/note_document.dart';

String buildTextChunkWebEditorHtml(NoteBlock block) {
  final state = <String, Object?>{
    'text': block.text,
    'rangeTags': [
      for (final rangeTag in block.rangeTags)
        {
          'id': rangeTag.id,
          'start': rangeTag.start,
          'end': rangeTag.end,
          'tags': [
            for (final tag in rangeTag.resolvedTags)
              {
                'type': NoteKnowledgeTagTypes.normalize(tag.type),
                'label': tag.label,
                'colorValue': tag.resolvedColorValue,
                'colorHex':
                    '0x${tag.resolvedColorValue.toRadixString(16).padLeft(8, '0').toUpperCase()}',
              },
          ],
        },
    ],
  };
  final encodedState = const JsonEncoder().convert(state);
  final maxSecondaryLines = block.rangeTags.fold<int>(0, (max, rangeTag) {
    final secondaryCount = rangeTag.resolvedTags.length - 1;
    return secondaryCount > max ? secondaryCount : max;
  });

  return '''
<!doctype html>
<html lang="hu">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <style>
    :root {
      --primary: #155EEF;
      --ink: #111827;
      --muted: #6B7280;
      --separator: #E5E7EB;
      font-family: Roboto, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    html, body { width: 100%; min-height: 100%; margin: 0; background: #FFFFFF; color: var(--ink); }
    body { overflow: auto; }
    .text-field-wrap { min-height: 100vh; padding: 12px 16px 24px; overflow: auto; }
    .text-field { min-height: 100%; outline: 0; color: var(--ink); font-size: 16px; line-height: normal; caret-color: var(--primary); white-space: normal; }
    .line { margin: 0; min-height: 20px; white-space: pre-wrap; cursor: text; }
    .tag-unit {
      --primary-bg: rgba(37, 99, 235, 0.22);
      --u1: transparent;
      --u2: transparent;
      --u3: transparent;
      --u4: transparent;
      --u5: transparent;
      --secondary-lines: 0;
      position: relative;
      border-radius: 2px;
      background-color: var(--primary-bg);
      background-image:
        linear-gradient(var(--u1), var(--u1)),
        linear-gradient(var(--u2), var(--u2)),
        linear-gradient(var(--u3), var(--u3)),
        linear-gradient(var(--u4), var(--u4)),
        linear-gradient(var(--u5), var(--u5));
      background-repeat: no-repeat;
      background-size: 100% 2px, 100% 2px, 100% 2px, 100% 2px, 100% 2px;
      background-position: 0 calc(100% - 1px), 0 calc(100% + 3px), 0 calc(100% + 7px), 0 calc(100% + 11px), 0 calc(100% + 15px);
      box-decoration-break: clone;
      -webkit-box-decoration-break: clone;
      font-weight: 600;
      padding-bottom: calc(var(--secondary-lines) * 4px);
      cursor: pointer;
    }
    .tag-unit.focused { outline: 0; }
    .rail {
      width: 100%;
      margin: 8px 0 14px;
      background: #FFFFFF;
      border-top: 1px solid var(--separator);
      border-bottom: 1px solid var(--separator);
    }
    .rail-row {
      min-height: 44px;
      display: flex;
      align-items: center;
      overflow-x: auto;
      overflow-y: hidden;
      -webkit-overflow-scrolling: touch;
      scrollbar-width: none;
    }
    .rail-row::-webkit-scrollbar { display: none; }
    .rail-actions-row { justify-content: flex-start; gap: 4px; padding: 2px 0; }
    .rail-pills-row { gap: 8px; padding: 2px 0 8px; }
    .rail-pills-row.collapsed { display: none; }
    .icon-button {
      width: 44px;
      height: 44px;
      border: 0;
      padding: 10px;
      display: grid;
      place-items: center;
      border-radius: 999px;
      background: transparent;
      color: #49454F;
    }
    .icon-button:active { background: rgba(29, 27, 32, 0.10); }
    .pill {
      min-height: 27px;
      display: inline-flex;
      align-items: center;
      gap: 7px;
      padding: 5px 9px;
      border-radius: 999px;
      color: white;
      font-size: 12px;
      font-weight: 800;
      line-height: 1.4;
      white-space: nowrap;
    }
    .pill-x {
      width: 17px;
      height: 17px;
      border: 0;
      padding: 0;
      display: grid;
      place-items: center;
      border-radius: 999px;
      background: rgba(255,255,255,.24);
      color: white;
      font-size: 13px;
      line-height: 1;
    }
    .no-tag { flex: 0 0 auto; color: var(--muted); font-size: 12px; font-weight: 700; white-space: nowrap; }
  </style>
</head>
<body>
  <div class="text-field-wrap" id="scrollArea">
    <div class="text-field" id="editor" contenteditable="true" spellcheck="false"></div>
  </div>
  <template id="railTemplate">
    <section class="rail" id="activeRail">
      <div class="rail-row rail-actions-row">
        <button class="icon-button" id="togglePills" type="button" aria-label="Tagek bezárása">⌃</button>
        <button class="icon-button" id="tagSelection" type="button" aria-label="Tag">🏷</button>
        <button class="icon-button" id="clearTags" type="button" aria-label="Tagek törlése">⌫</button>
        <button class="icon-button" id="previousTag" type="button" aria-label="Előző">‹</button>
        <button class="icon-button" id="nextTag" type="button" aria-label="Következő">›</button>
      </div>
      <div class="rail-row rail-pills-row" id="pillRow"></div>
    </section>
  </template>
  <script>
    const state = $encodedState;
    const initialSecondaryLineHint = ["--secondary-lines", "$maxSecondaryLines"];
    let activeRange = null;
    let bottomRowExpanded = true;
    const editor = document.getElementById("editor");
    const railTemplate = document.getElementById("railTemplate");

    function post(type, payload = {}) {
      const message = JSON.stringify({ type, ...payload });
      if (window.NoteBridge && window.NoteBridge.postMessage) {
        window.NoteBridge.postMessage(message);
      }
    }

    function colorToCss(tag, alpha = 1) {
      const raw = typeof tag.colorValue === "number" ? tag.colorValue : parseInt(String(tag.colorHex || "0").replace("0x", ""), 16);
      const value = raw >>> 0;
      const r = (value >> 16) & 255;
      const g = (value >> 8) & 255;
      const b = value & 255;
      return `rgba(\${r}, \${g}, \${b}, \${alpha})`;
    }

    function metadataText(tag) {
      return `\${tag.type}:\${tag.label}`;
    }

    function uniqueTags(tags) {
      const seen = new Set();
      const out = [];
      for (const tag of tags || []) {
        const key = metadataText(tag);
        if (!seen.has(key)) {
          seen.add(key);
          out.push(tag);
        }
      }
      return out;
    }

    function overlapTags(start, end) {
      const tags = [];
      for (const range of state.rangeTags) {
        if (range.start < end && range.end > start) {
          tags.push(...(range.tags || []));
        }
      }
      return uniqueTags(tags);
    }

    function render() {
      editor.innerHTML = "";
      const lines = String(state.text || "").split("\\n");
      let offset = 0;
      lines.forEach((lineText, lineIndex) => {
        const line = document.createElement("p");
        line.className = "line";
        line.dataset.line = "true";
        line.dataset.start = String(offset);
        renderLine(line, lineText, offset);
        editor.appendChild(line);
        offset += lineText.length;
        if (lineIndex < lines.length - 1) {
          offset += 1;
        }
      });
      if (lines.length === 0) {
        const line = document.createElement("p");
        line.className = "line";
        line.dataset.line = "true";
        line.dataset.start = "0";
        line.appendChild(document.createElement("br"));
        editor.appendChild(line);
      }
    }

    function renderLine(line, lineText, lineStart) {
      if (lineText.length === 0) {
        line.appendChild(document.createElement("br"));
        return;
      }
      const breaks = new Set([0, lineText.length]);
      for (const range of state.rangeTags) {
        const start = Math.max(0, range.start - lineStart);
        const end = Math.min(lineText.length, range.end - lineStart);
        if (start < end) {
          breaks.add(start);
          breaks.add(end);
        }
      }
      const sorted = [...breaks].sort((a, b) => a - b);
      for (let i = 0; i < sorted.length - 1; i += 1) {
        const start = sorted[i];
        const end = sorted[i + 1];
        if (start >= end) continue;
        const text = lineText.slice(start, end);
        const tags = overlapTags(lineStart + start, lineStart + end);
        if (tags.length === 0) {
          line.appendChild(document.createTextNode(text));
          continue;
        }
        const unit = document.createElement("span");
        unit.className = "tag-unit";
        unit.textContent = text;
        unit.dataset.start = String(lineStart + start);
        unit.dataset.end = String(lineStart + end);
        unit.dataset.tags = JSON.stringify(tags);
        applyVisualState(unit, tags);
        line.appendChild(unit);
      }
    }

    function applyVisualState(unit, tags) {
      const primary = tags[0];
      const secondary = tags.slice(1);
      unit.style.setProperty("--primary-bg", colorToCss(primary, 0.22));
      unit.style.setProperty("--secondary-lines", String(secondary.length));
      for (let i = 0; i < 5; i += 1) {
        unit.style.setProperty(`--u\${i + 1}`, secondary[i] ? colorToCss(secondary[i], 1) : "transparent");
      }
    }

    function removeRail() {
      document.getElementById("activeRail")?.remove();
      activeRange = null;
    }

    function renderRail(line, tags, skipScroll = false) {
      removeRail();
      const rail = railTemplate.content.firstElementChild.cloneNode(true);
      const pillRow = rail.querySelector("#pillRow");
      rail.querySelector("#togglePills").textContent = bottomRowExpanded ? "⌃" : "⌄";
      pillRow.classList.toggle("collapsed", !bottomRowExpanded);
      if (tags.length === 0) {
        const empty = document.createElement("span");
        empty.className = "no-tag";
        empty.textContent = "Nincs tag";
        pillRow.appendChild(empty);
      } else {
        for (const tag of tags) {
          const pill = document.createElement("span");
          pill.className = "pill";
          pill.style.background = colorToCss(tag, 1);
          pill.textContent = metadataText(tag);
          const x = document.createElement("button");
          x.className = "pill-x";
          x.textContent = "×";
          x.addEventListener("click", () => deleteSingleTag(tag));
          pill.appendChild(x);
          pillRow.appendChild(pill);
        }
      }
      rail.querySelector("#togglePills").addEventListener("click", () => {
        bottomRowExpanded = !bottomRowExpanded;
        renderRail(line, tags, true);
      });
      rail.querySelector("#tagSelection").addEventListener("click", () => {
        if (activeRange) post("tagRequest", { range: activeRange, tags });
      });
      rail.querySelector("#clearTags").addEventListener("click", deleteActiveTags);
      rail.querySelector("#previousTag").addEventListener("click", () => focusAdjacentTag(-1));
      rail.querySelector("#nextTag").addEventListener("click", () => focusAdjacentTag(1));
      line.after(rail);
      if (!skipScroll) rail.scrollIntoView({ block: "nearest" });
    }

    function lineOffset(line) {
      return Number(line.dataset.start || "0");
    }

    function normalizeEditableLines() {
      const children = [...editor.children];
      if (children.length === 0) {
        const line = document.createElement("p");
        line.className = "line";
        line.dataset.line = "true";
        line.dataset.start = "0";
        line.appendChild(document.createElement("br"));
        editor.appendChild(line);
        return;
      }
      for (const child of children) {
        child.classList.add("line");
        child.dataset.line = "true";
      }
      refreshLineStarts();
    }

    function refreshLineStarts() {
      let offset = 0;
      for (const line of editor.querySelectorAll("[data-line]")) {
        line.dataset.start = String(offset);
        offset += line.textContent.length + 1;
      }
    }

    function closestLine(node) {
      return node && node.nodeType === 1
        ? node.closest("[data-line]")
        : node?.parentElement?.closest("[data-line]");
    }

    function localTextOffset(root, node, offset) {
      let total = 0;
      const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
      while (walker.nextNode()) {
        const current = walker.currentNode;
        if (current === node) {
          return total + offset;
        }
        total += current.textContent.length;
      }
      return total;
    }

    function selectionOffsets() {
      const selection = window.getSelection();
      if (!selection || selection.rangeCount === 0) return null;
      const range = selection.getRangeAt(0);
      const startLine = closestLine(range.startContainer);
      const endLine = closestLine(range.endContainer);
      if (!startLine || !endLine || !editor.contains(startLine) || !editor.contains(endLine)) return null;
      const start = lineOffset(startLine) + localTextOffset(startLine, range.startContainer, range.startOffset);
      const end = lineOffset(endLine) + localTextOffset(endLine, range.endContainer, range.endOffset);
      return { start: Math.min(start, end), end: Math.max(start, end), line: endLine };
    }

    function showRailForCurrentSelection() {
      const offsets = selectionOffsets();
      if (!offsets) return;
      if (offsets.start === offsets.end) {
        const tagRange = state.rangeTags.find((range) => offsets.start >= range.start && offsets.start < range.end);
        if (!tagRange) return;
        activeRange = { start: tagRange.start, end: tagRange.end };
        renderRail(offsets.line, uniqueTags(tagRange.tags || []));
        return;
      }
      activeRange = { start: offsets.start, end: offsets.end };
      renderRail(offsets.line, overlapTags(offsets.start, offsets.end));
    }

    function applyTagsToActive(tags) {
      if (!activeRange || !tags || tags.length === 0) return;
      const next = state.rangeTags.filter((range) => range.end <= activeRange.start || range.start >= activeRange.end);
      next.push({
        id: `range-\${Date.now()}`,
        start: activeRange.start,
        end: activeRange.end,
        tags,
      });
      next.sort((a, b) => a.start - b.start);
      state.rangeTags = next;
      render();
      post("rangeTagsChanged", { rangeTags: state.rangeTags });
      const line = [...editor.querySelectorAll("[data-line]")].find((item) => Number(item.dataset.start || "0") <= activeRange.start && Number(item.dataset.start || "0") + item.textContent.length >= activeRange.start) || editor.querySelector("[data-line]");
      renderRail(line, tags, true);
    }

    function deleteActiveTags() {
      if (!activeRange) return;
      state.rangeTags = state.rangeTags.filter((range) => range.end <= activeRange.start || range.start >= activeRange.end);
      render();
      post("rangeTagsChanged", { rangeTags: state.rangeTags });
      removeRail();
    }

    function deleteSingleTag(tag) {
      if (!activeRange) return;
      const key = metadataText(tag);
      const next = [];
      for (const range of state.rangeTags) {
        if (range.end <= activeRange.start || range.start >= activeRange.end) {
          next.push(range);
          continue;
        }
        const tags = uniqueTags((range.tags || []).filter((current) => metadataText(current) !== key));
        if (tags.length > 0) next.push({ ...range, tags });
      }
      state.rangeTags = next;
      render();
      post("rangeTagsChanged", { rangeTags: state.rangeTags });
      removeRail();
    }

    function focusAdjacentTag(direction) {
      if (state.rangeTags.length === 0) return;
      const current = activeRange ? activeRange.start : -1;
      const sorted = [...state.rangeTags].sort((a, b) => a.start - b.start);
      let target = direction > 0
        ? sorted.find((range) => range.start > current) || sorted[0]
        : [...sorted].reverse().find((range) => range.start < current) || sorted[sorted.length - 1];
      activeRange = { start: target.start, end: target.end };
      const line = [...editor.querySelectorAll("[data-line]")].find((item) => {
        const start = Number(item.dataset.start || "0");
        return start <= target.start && start + item.textContent.length >= target.start;
      }) || editor.querySelector("[data-line]");
      renderRail(line, uniqueTags(target.tags || []));
    }

    editor.addEventListener("input", () => {
      normalizeEditableLines();
      state.text = [...editor.querySelectorAll("[data-line]")].map((line) => line.textContent).join("\\n");
      post("textChanged", { text: state.text });
    });

    editor.addEventListener("click", (event) => {
      const unit = event.target.closest?.(".tag-unit");
      if (!unit) {
        if (!window.getSelection() || window.getSelection().isCollapsed) removeRail();
        return;
      }
      activeRange = { start: Number(unit.dataset.start), end: Number(unit.dataset.end) };
      renderRail(closestLine(unit), uniqueTags(JSON.parse(unit.dataset.tags || "[]")));
    });

    document.addEventListener("selectionchange", () => {
      const selection = window.getSelection();
      if (!selection || !editor.contains(selection.anchorNode)) return;
      if (!selection.isCollapsed) showRailForCurrentSelection();
    });

    window.DjinnEditor = {
      applyTags: (encodedTags) => applyTagsToActive(typeof encodedTags === "string" ? JSON.parse(encodedTags) : encodedTags),
      clearActiveTags: deleteActiveTags,
      getState: () => JSON.stringify(state),
    };

    render();
  </script>
</body>
</html>
''';
}
