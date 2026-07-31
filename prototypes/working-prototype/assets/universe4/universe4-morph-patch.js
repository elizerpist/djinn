const ease = (value) => value < .5 ? 4 * value ** 3 : 1 - ((-2 * value + 2) ** 3) / 2;

/**
 * A short-lived canvas-only visual bridge. It never changes Globe geometry:
 * selected city/edges interpolate from their current projected surface points
 * into the prepared G6 Entry Layout while the far hemisphere fades away.
 */
export function createUniverse4MorphPatch({ mount } = {}) {
  if (!mount) throw new Error('Universe 4 morph patch mount is required');
  const canvas = document.createElement('canvas');
  canvas.className = 'universe4-morph-patch-canvas';
  canvas.setAttribute('aria-hidden', 'true');
  mount.replaceChildren(canvas);
  const context = canvas.getContext('2d');
  let disposed = false;
  let resizeFrame = 0;

  const size = () => {
    const rect = mount.getBoundingClientRect();
    const scale = Math.min(window.devicePixelRatio || 1, 2);
    const width = Math.max(1, Math.round(rect.width * scale));
    const height = Math.max(1, Math.round(rect.height * scale));
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
      canvas.style.width = `${rect.width}px`;
      canvas.style.height = `${rect.height}px`;
    }
    return { width: rect.width, height: rect.height, scale };
  };

  const draw = ({ nodes = [], edges = [], globePositions = new Map(), entryPositions = new Map(), progress = 0 } = {}) => {
    if (disposed || !context) return;
    const { width, height, scale } = size();
    const t = ease(Math.max(0, Math.min(1, progress)));
    context.setTransform(scale, 0, 0, scale, 0, 0);
    context.clearRect(0, 0, width, height);
    const positionFor = (id) => {
      const source = globePositions.get(id) || entryPositions.get(id) || { x: width / 2, y: height / 2 };
      const target = entryPositions.get(id) || source;
      return { x: source.x + (target.x - source.x) * t, y: source.y + (target.y - source.y) * t };
    };
    context.lineCap = 'round';
    edges.forEach((edge) => {
      const source = positionFor(edge.source);
      const target = positionFor(edge.target);
      context.globalAlpha = .25 + t * .65;
      context.strokeStyle = '#FFD45A';
      context.lineWidth = 1.3 + t * 1.5;
      context.beginPath();
      context.moveTo(source.x, source.y);
      context.quadraticCurveTo((source.x + target.x) / 2, (source.y + target.y) / 2 - (1 - t) * 22, target.x, target.y);
      context.stroke();
    });
    nodes.forEach((node) => {
      const point = positionFor(node.id);
      const focus = node.id === nodes[0]?.id;
      context.globalAlpha = .3 + t * .7;
      context.fillStyle = focus ? '#FFF4CD' : '#FFD45A';
      context.beginPath();
      context.arc(point.x, point.y, focus ? 7 + t * 8 : 4 + t * 5, 0, Math.PI * 2);
      context.fill();
    });
    context.globalAlpha = 1;
  };

  const resize = () => {
    if (resizeFrame) return;
    resizeFrame = requestAnimationFrame(() => { resizeFrame = 0; size(); });
  };
  const observer = new ResizeObserver(resize);
  observer.observe(mount);

  return Object.freeze({
    setOpacity(opacity) { canvas.style.opacity = String(Math.max(0, Math.min(1, Number(opacity) || 0))); },
    draw,
    clear() { context?.clearRect(0, 0, canvas.width, canvas.height); },
    dispose() {
      disposed = true;
      observer.disconnect();
      if (resizeFrame) cancelAnimationFrame(resizeFrame);
      canvas.remove();
    },
  });
}
