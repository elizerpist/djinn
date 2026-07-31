// Canvas-local controls for the reusable G6 V2 map. They live inside the
// stage, so Universe 4 can make them interactive only after the Globe → Map
// ownership handoff has completed.
export function createFocusedG6V2StageControls({ host, onZoomIn, onZoomOut, onCenter } = {}) {
  if (!host) throw new Error('Focused G6 V2 controls require a host');
  const controls = document.createElement('div');
  controls.className = 'focused-g6-v2-stage-controls';
  controls.setAttribute('aria-label', 'Fókuszált térkép vezérlők');
  controls.innerHTML = `
    <button type="button" data-focused-g6-control="zoom-in" aria-label="Nagyítás">+</button>
    <button type="button" data-focused-g6-control="zoom-out" aria-label="Kicsinyítés">−</button>
    <button type="button" data-focused-g6-control="center" aria-label="Középső kártya fókusza">◎</button>
  `;
  const handlers = new Map([
    ['zoom-in', onZoomIn],
    ['zoom-out', onZoomOut],
    ['center', onCenter],
  ]);
  const onClick = (event) => {
    const button = event.target.closest('[data-focused-g6-control]');
    const handler = button && handlers.get(button.dataset.focusedG6Control);
    if (!handler) return;
    event.preventDefault();
    event.stopPropagation();
    handler();
  };
  controls.addEventListener('click', onClick);
  host.append(controls);
  return Object.freeze({
    dispose() {
      controls.removeEventListener('click', onClick);
      controls.remove();
    },
  });
}
