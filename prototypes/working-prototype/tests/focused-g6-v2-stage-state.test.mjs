import assert from 'node:assert/strict';
import {
  FOCUSED_G6_V2_STAGE_ZOOM,
  focusedG6V2NextStageZoom,
  focusedG6V2ResolveStageFocus,
  focusedG6V2ShouldRefreshLod,
} from '../assets/focused-g6-v2-stage-state.js';
import {
  buildFocusedG6V2Subgraph,
  focusedG6V2Lod,
  knowledgeEdges,
  knowledgeNodes,
} from '../assets/universe4/universe4-graph-data.js';

assert.deepEqual(FOCUSED_G6_V2_STAGE_ZOOM, { min: .35, max: 2.6, step: .22 });
assert.equal(focusedG6V2NextStageZoom(1, 'in'), 1.22, 'the embedded Universe map exposes the same deliberate zoom-in step as G6 V2');
assert.equal(focusedG6V2NextStageZoom(.4, 'out'), .35, 'zoom out clamps at the G6 lower bound');
assert.equal(focusedG6V2NextStageZoom(2.55, 'in'), 2.6, 'zoom in clamps at the G6 upper bound');

const initialFocus = knowledgeNodes[0].id;
const alternateFocus = knowledgeNodes.find((node) => node.id !== initialFocus).id;
assert.equal(focusedG6V2ResolveStageFocus(alternateFocus, knowledgeNodes, initialFocus), alternateFocus,
  'a real G6 node tap must be allowed to become the new dynamic center card');
assert.equal(focusedG6V2ResolveStageFocus('missing-city', knowledgeNodes, initialFocus), initialFocus,
  'unknown graph targets must leave the active center stable');

assert.equal(focusedG6V2ShouldRefreshLod('near', .7, focusedG6V2Lod), true,
  'zooming out through an LOD boundary must reveal additional G6 V2 context');
assert.equal(focusedG6V2ShouldRefreshLod('near', 1.1, focusedG6V2Lod), false,
  'ordinary smooth zoom frames must not rebuild the graph');

const dynamicSubgraph = buildFocusedG6V2Subgraph(alternateFocus, knowledgeNodes, knowledgeEdges, focusedG6V2Lod(1));
assert.equal(dynamicSubgraph.focusId, alternateFocus);
assert.equal(dynamicSubgraph.nodes.find((node) => node.id === alternateFocus)?.focusDepth, 0,
  'the selected map node becomes the depth-zero central card rather than a static label');

console.log('focused G6 V2 stage state tests OK');
