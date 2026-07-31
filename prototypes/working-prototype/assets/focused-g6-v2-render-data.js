// Renderer-neutral Focused Map v2 data.  The Explore map and the embedded
// Universe 4 G6 stage call this same builder so card/edge geometry and the
// deep-space palette cannot drift apart.
const paletteFor = (dark) => (dark ? {
  0: { fill: '#6B3EF6', stroke: '#B9B0E6', label: '#ECE7FF', shadow: '#2B1366' },
  1: { fill: '#B9B0E6', stroke: '#C9C4FF', label: '#21153F', shadow: '#6B3EF6' },
  2: { fill: '#8276BA', stroke: '#C9C4FF', label: '#ECE7FF', shadow: '#2B1366' },
} : {
  0: { fill: '#7954ed', stroke: '#6341d2', label: '#ffffff', shadow: '#6848d8' },
  1: { fill: '#ffffff', stroke: '#d7c9eb', label: '#494154', shadow: '#aa9ac8' },
  2: { fill: '#faf9fd', stroke: '#ebe6f2', label: '#655e70', shadow: '#d7cfdf' },
});

export function buildFocusedG6V2RenderData({
  focusId,
  nodes,
  edges,
  includeNode = () => true,
  zoom = 1,
  width,
  height,
  dark = false,
  pathMode = false,
  isPathEdge = () => false,
  buildSubgraph,
  getLod,
  getPositions,
  getCardSize,
  positionById = null,
} = {}) {
  if (typeof buildSubgraph !== 'function' || typeof getLod !== 'function' || typeof getPositions !== 'function' || typeof getCardSize !== 'function') {
    throw new TypeError('Focused G6 V2 requires subgraph, LOD, position and card-size helpers');
  }
  const lod = getLod(zoom);
  const subgraph = buildSubgraph(focusId, nodes, edges, { includeNode, ...lod });
  const positions = positionById instanceof Map
    ? positionById
    : getPositions(subgraph.nodes, subgraph.focusId, width, height);
  const palette = paletteFor(dark);
  const renderNodes = subgraph.nodes.map((node, index) => {
    const depth = node.focusDepth;
    const colors = palette[depth] || palette[2];
    const cardSize = getCardSize(depth);
    const position = positions.get(node.id);
    if (!position) return null;
    return {
      id: node.id,
      type: 'rect',
      data: { ...node, focusDepth: depth },
      zIndex: 40 - Math.min(depth, 8) + index / 100,
      style: {
        x: position.x,
        y: position.y,
        size: cardSize,
        radius: depth === 0 ? 18 : 13,
        fill: colors.fill,
        stroke: colors.stroke,
        lineWidth: depth < 2 ? 1.4 : 1,
        shadowColor: colors.shadow,
        shadowBlur: depth === 0 ? 18 : depth === 1 ? 10 : 6,
        shadowOffsetY: depth === 0 ? 7 : 3,
        labelText: node.title,
        labelPlacement: 'center',
        labelFill: colors.label,
        labelFontSize: depth === 0 ? 11 : depth === 1 ? 9.5 : 8,
        labelFontWeight: depth < 2 ? 700 : 600,
        labelWordWrap: true,
        labelMaxWidth: cardSize[0] - 15,
      },
    };
  }).filter(Boolean);
  const nodeById = new Map(subgraph.nodes.map((node) => [node.id, node]));
  const renderEdges = subgraph.edges.map((edge, index) => {
    const sourceDepth = nodeById.get(edge.source)?.focusDepth ?? 2;
    const targetDepth = nodeById.get(edge.target)?.focusDepth ?? 2;
    const localEdge = Math.max(sourceDepth, targetDepth) <= 1;
    const onPath = pathMode && isPathEdge(edge.source, edge.target);
    return {
      id: `${edge.source}-${edge.target}-${index}`,
      type: 'quadratic',
      source: edge.source,
      target: edge.target,
      data: { ...edge },
      zIndex: 1,
      style: {
        stroke: dark ? (onPath ? '#ECE7FF' : '#C9C4FF') : (onPath ? '#7250e6' : localEdge ? '#b7a7dd' : '#ddd6e9'),
        lineWidth: onPath ? 3 : localEdge ? 1.7 : 1,
        opacity: onPath ? 1 : localEdge ? .62 : .36,
        endArrow: false,
      },
    };
  });
  return { focusId: subgraph.focusId, lodKey: lod.key, nodes: renderNodes, edges: renderEdges, positions };
}
