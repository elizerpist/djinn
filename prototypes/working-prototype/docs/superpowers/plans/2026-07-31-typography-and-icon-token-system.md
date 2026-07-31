# Typography and Icon Token System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move shared card/menu typography and reusable icon dimensions to semantic `:root` tokens while preserving the existing visual hierarchy.

**Architecture:** `assets/styles.css` owns all semantic typography and icon tokens in its existing `:root` block. `styles.css`, `explore-discovery.css`, and `universe4/universe4.css` consume those tokens; graph/canvas geometry stays local. Contract tests verify token declarations and representative consumers.

**Tech Stack:** Plain CSS custom properties, static HTML fragments, Node.js ESM contract tests.

## Global Constraints

- Preserve distinct primary, secondary, metadata, menu, label, and diagnostic text hierarchy.
- Keep Explore “Mai felfedezés” as a legend with its independent visual treatment.
- Keep graph/canvas geometry-specific dimensions local.
- Do not introduce a second token palette outside `assets/styles.css`.

### Task 1: Add the failing typography/icon contract

**Files:**
- Modify: `tests/card-style-contract.test.mjs`

- [x] **Step 1: Add token and consumer assertions**

Assert the semantic token declarations and representative selectors for card title/body/meta, menu header/subheader/child, and card/action/navigation icon roles.

- [x] **Step 2: Run the focused contract**

Run: `node tests/card-style-contract.test.mjs`
Expected: FAIL because the new `:root` tokens and token consumers do not exist yet.

### Task 2: Add the semantic token source and migrate app CSS

**Files:**
- Modify: `assets/styles.css`
- Modify: `assets/explore-discovery.css`
- Modify: `assets/universe4/universe4.css`

- [x] **Step 1: Define semantic tokens in `:root`**

Use the existing values as the baseline, including `--type-card-title-size: 11px`, `--type-card-body-size: 10px`, `--type-card-meta-size: 9px`, `--type-card-caption-size: 8px`, `--type-menu-header-size: 19px`, `--type-menu-subheader-size: 15px`, `--type-menu-child-size: 10px`, `--type-menu-child-meta-size: 8px`, `--type-label-size: 8px`, and icon container/glyph tokens for card, action, navigation, inline, and graph-label roles.

- [x] **Step 2: Replace repeated semantic declarations**

Route card primary/secondary/meta selectors, top-bar/menu selectors, child-menu selectors, labels, and the Explore equivalents through the new type tokens. Route reusable icon width/height and glyph sizes through icon tokens while leaving globe/graph model geometry unchanged.

- [x] **Step 3: Run the focused contract**

Run: `node tests/card-style-contract.test.mjs`
Expected: PASS with `shared card style contract OK`.

### Task 3: Verify the full prototype

**Files:**
- Modify: `docs/architecture/prototype-html-fragment-refactor.md`

- [x] **Step 1: Mark HTML-09 complete**

Set the typography/icon centralization checklist row to `DONE` after the contract passes.

- [x] **Step 2: Run all tests and whitespace validation**

Run the Node test loop over `tests/*.test.mjs` and `git diff --check`.
Expected: 45 tests, 0 failures, clean diff.

- [x] **Step 3: Commit the implementation**

```bash
git add assets/styles.css assets/explore-discovery.css assets/universe4/universe4.css tests/card-style-contract.test.mjs docs/architecture/prototype-html-fragment-refactor.md docs/superpowers/plans/2026-07-31-typography-and-icon-token-system.md
git commit -m "refactor: centralize typography and icon sizing"
```
