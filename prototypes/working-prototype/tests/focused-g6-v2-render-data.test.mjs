import assert from 'node:assert/strict';
import {
  buildFocusedG6V2Subgraph,
  focusedG6CardSize,
  focusedG6V2Lod,
  focusedG6V2Positions,
  knowledgeEdges,
  knowledgeNodes,
} from '../assets/universe4/universe4-graph-data.js';
import { buildFocusedG6V2RenderData } from '../assets/focused-g6-v2-render-data.js';

const renderData = buildFocusedG6V2RenderData({
  focusId: 'resp_failure',
  nodes: knowledgeNodes,
  edges: knowledgeEdges,
  includeNode: () => true,
  zoom: 1,
  width: 360,
  height: 560,
  dark: true,
  buildSubgraph: buildFocusedG6V2Subgraph,
  getLod: focusedG6V2Lod,
  getPositions: focusedG6V2Positions,
  getCardSize: focusedG6CardSize,
});

assert.equal(renderData.focusId, 'resp_failure');
assert.equal(renderData.lodKey, 'near');
assert.ok(renderData.nodes.length > 1 && renderData.nodes.length <= 8);
assert.equal(renderData.nodes[0].style.fill, '#6B3EF6', 'the exact existing deep-space V2 focus palette must be shared by the adapter');
assert.ok(renderData.edges.every((edge) => edge.type === 'quadratic'));

console.log('focused G6 V2 render data OK');
