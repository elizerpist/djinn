# Typography and icon token system design

## Goal

Make the prototype's typography and reusable icon dimensions centrally configurable without flattening the visual hierarchy. Card titles, supporting copy, menu headers, child-menu text, labels, and diagnostic text keep distinct semantic sizes while reading from one token source.

## Source of truth

`assets/styles.css` remains the single visual token owner. New typography and icon tokens live in its existing `:root` block and are inherited by `assets/explore-discovery.css` and `assets/universe4/universe4.css`. No second token palette is introduced in feature stylesheets.

## Semantic roles

The migration will define tokens for these roles:

- card title/primary text;
- card body/supporting text;
- card metadata and caption text;
- menu header and menu subheader;
- child-menu label and child-menu metadata;
- eyebrow/section label text;
- display/title text used by answer and detail screens;
- card icon container and glyph;
- action, navigation, inline, and graph-label icon sizes.

Existing relative sizing is preserved: primary text remains larger and heavier than secondary text, menu headers remain larger than child-menu labels, and captions remain the smallest readable UI text.

## Migration rules

1. Replace repeated semantic `font-size`, `font-weight`, and line-height declarations with the closest role token.
2. Replace reusable icon width/height and glyph-size pairs with icon tokens.
3. Keep geometry-specific canvas, globe, graph-node, avatar, and illustration dimensions local when they describe the visual model rather than a reusable UI icon.
4. Preserve existing colors and layout behavior; this change only centralizes typography and icon sizing.
5. Keep “Mai felfedezés” as a legend and preserve its independent visual treatment.

## Verification

- Extend `tests/card-style-contract.test.mjs` with token presence and representative consumer assertions.
- Add a focused typography/icon contract test if the card contract becomes too broad.
- Run the complete Node test suite and `git diff --check`.
- Inspect the final diff to confirm that no duplicate token palette or accidental card/legend coupling was introduced.

## Acceptance

- All shared card primary/secondary/meta text roles resolve through `:root` tokens.
- Menu header, subheader, and child-menu text roles resolve through `:root` tokens.
- Reusable icon containers and glyph sizes resolve through `:root` tokens.
- Distinct hierarchy is retained; centralization does not make all text the same size.
- The Explore legend and graph geometry remain behaviorally unchanged.
