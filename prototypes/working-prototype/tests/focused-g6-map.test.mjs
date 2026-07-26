import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import {
  knowledgeNodes,
  knowledgeEdges,
  buildFocusedG6Subgraph,
  focusedG6Positions,
} from '../assets/knowledge-map.js';

const subgraph = buildFocusedG6Subgraph('resp_failure', knowledgeNodes, knowledgeEdges);

assert.equal(subgraph.focusId, 'resp_failure', 'a központi atom maradjon a fókusz');
assert.ok(subgraph.nodes.length > 1, 'a fókuszhoz tartozzon lokális környezet');
assert.ok(subgraph.nodes.length <= 24, 'a G6 ne kapja meg a teljes gráfot');
assert.ok(subgraph.nodes.some((node) => node.id === 'do2'), 'a legerősebb szomszédok kerüljenek be');
assert.ok(subgraph.edges.every((edge) => subgraph.nodeIds.has(edge.source) && subgraph.nodeIds.has(edge.target)), 'csak a lokális kártyák közötti kapcsolatok rajzolódjanak ki');

const positions = focusedG6Positions(subgraph.nodes, 'resp_failure', 360, 560);
const focus = positions.get('resp_failure');
assert.deepEqual(focus, { x: 180, y: 280, level: 0 }, 'a fókuszkártya a vászon közepére kerüljön');
assert.ok([...positions.values()].some((position) => position.level === 1), 'az első gyűrű külön pozíciós szintet kapjon');

const cardSizes = { 0: [124, 62], 1: [96, 48], 2: [78, 38] };
for (const focusId of ['resp_failure', 'niv', 'do2', 'ards']) {
  const focusedGraph = buildFocusedG6Subgraph(focusId, knowledgeNodes, knowledgeEdges);
  const focusedPositions = focusedG6Positions(focusedGraph.nodes, focusedGraph.focusId, 360, 560);
  const collisions = [];
  assert.equal(focusedPositions.size, focusedGraph.nodes.length, `${focusId}: minden renderelt kártyához legyen pozíció`);
  for (let index = 0; index < focusedGraph.nodes.length; index += 1) {
    for (let otherIndex = index + 1; otherIndex < focusedGraph.nodes.length; otherIndex += 1) {
      const first = focusedGraph.nodes[index];
      const second = focusedGraph.nodes[otherIndex];
      const firstPosition = focusedPositions.get(first.id);
      const secondPosition = focusedPositions.get(second.id);
      const [firstWidth, firstHeight] = cardSizes[first.focusDepth];
      const [secondWidth, secondHeight] = cardSizes[second.focusDepth];
      const overlapsHorizontally = Math.abs(firstPosition.x - secondPosition.x) < (firstWidth + secondWidth) / 2 + 10;
      const overlapsVertically = Math.abs(firstPosition.y - secondPosition.y) < (firstHeight + secondHeight) / 2 + 10;
      if (overlapsHorizontally && overlapsVertically) collisions.push(`${first.id}:${second.id}`);
    }
  }
  assert.deepEqual(collisions, [], `${focusId}: a lokális G6-kártyák között legalább 10 px biztonsági távolság maradjon`);
}

const mapSource = await readFile(new URL('../assets/knowledge-map.js', import.meta.url), 'utf8');
assert.match(mapSource, /labelPlacement:\s*'center'/, 'a G6 címke a kártya belsejében, középen jelenjen meg');

console.log(`focused G6 map OK (${subgraph.nodes.length} nodes, ${subgraph.edges.length} edges)`);
