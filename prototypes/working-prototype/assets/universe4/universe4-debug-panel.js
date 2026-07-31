const output = (host, selector) => host?.querySelector(selector);

const format = (value, digits = 2, suffix = '') => Number.isFinite(value)
  ? `${value.toFixed(digits)}${suffix}`
  : `—${suffix}`;

export function mountUniverse4DebugPanel({ host, viewport, onProof }) {
  if (!host) return { update() {}, dispose() {} };
  const fields = {
    state: output(host, '[data-universe4-debug-state]'),
    status: output(host, '[data-universe4-state]'),
    planet: output(host, '[data-universe4-debug-planet]'),
    owner: output(host, '[data-universe4-pointer-owner]'),
    center: output(host, '[data-universe4-debug-center-delta]'),
    radius: output(host, '[data-universe4-debug-radius-delta]'),
    landmarkRms: output(host, '[data-universe4-debug-landmark-rms]'),
    landmarks: output(host, '[data-universe4-debug-landmark-delta]'),
    globeOffset: output(host, '[data-universe4-debug-globe-offset]'),
    stages: output(host, '[data-universe4-debug-stages]'),
    details: output(host, '[data-universe4-debug-details]'),
    signalLog: output(host, '[data-universe4-signal-log]'),
  };
  const signals = [];
  const renderSignals = () => {
    if (!fields.signalLog) return;
    fields.signalLog.textContent = signals.length
      ? signals.map((entry) => JSON.stringify(entry)).join('\n')
      : 'V7 Globe eseményekre vár…';
    fields.signalLog.scrollTop = fields.signalLog.scrollHeight;
  };
  const onClick = (event) => {
    if (event.target.closest('[data-universe4-copy-signal]')) {
      const payload = signals.map((entry) => JSON.stringify(entry)).join('\n');
      if (payload) navigator.clipboard?.writeText?.(payload).catch?.(() => {});
      return;
    }
    const proof = event.target.closest('[data-universe4-proof]')?.dataset.universe4Proof;
    if (proof) onProof?.(proof);
  };
  host.addEventListener('click', onClick);

  return {
    update(metrics = {}) {
      const match = metrics.pixelMatch || {};
      if (fields.state) fields.state.textContent = metrics.state || 'GALAXY_IDLE';
      if (fields.status) fields.status.textContent = metrics.state || 'GALAXY_IDLE';
      if (fields.planet) fields.planet.textContent = metrics.planetId || '—';
      if (fields.owner) fields.owner.textContent = metrics.pointerOwner || 'FORCE';
      if (fields.center) fields.center.textContent = `${format(match.centerDeltaPx)} px`;
      if (fields.radius) fields.radius.textContent = `${format(match.radiusDeltaPercent)} %`;
      if (fields.landmarkRms) fields.landmarkRms.textContent = `${format(match.landmarkRmsDeltaPx)} px`;
      if (fields.landmarks) fields.landmarks.textContent = `${format(match.maxLandmarkDeltaPx)} px`;
      if (fields.globeOffset) {
        const [x = 0, y = 0] = Array.isArray(metrics.globeOffset) ? metrics.globeOffset : [];
        fields.globeOffset.textContent = Number.isFinite(x) && Number.isFinite(y)
          ? `${x.toFixed(1)}, ${y.toFixed(1)}`
          : '—';
      }
      if (fields.stages) fields.stages.textContent = `Force ${format(metrics.forceOpacity)} · Globe ${format(metrics.globeOpacity)}`;
      if (fields.details) {
        fields.details.replaceChildren(...[
          `Generation: ${metrics.generation ?? 0} · Globe ready: ${Boolean(metrics.globeReady)} · frames: ${metrics.globeFrames ?? 0}`,
          `Universe depth: ${metrics.depthState || 'GALAXY'} · Map: ${metrics.mapSnapshot || 'inactive'} · G6 ${format(metrics.mapOpacity)} · Patch ${format(metrics.morphPatchOpacity)}`,
          `G6 center: ${metrics.g6MapState?.focusCityId || '—'} · zoom ${format(metrics.g6MapState?.zoom)} · LOD ${metrics.g6MapState?.lodKey || '—'} · cards ${metrics.g6MapState?.visibleNodeCount ?? 0}`,
          `Force camera: ${metrics.forceCamera || 'awaiting capture'}`,
          `Globe POV: ${metrics.globePov || 'awaiting prewarm'}`,
          `Pixel match: ${match.valid ? 'READY' : (match.failures?.join(', ') || 'awaiting snapshot')} · RMS ${format(match.landmarkRmsDeltaPx)} px`,
          `Fade: ${format(metrics.crossfadeProgress)} · Force paused: ${Boolean(metrics.forcePaused)}`,
        ].map((text) => {
          const line = document.createElement('output');
          line.textContent = text;
          return line;
        }));
      }
    },
    setProof(proof) {
      if (viewport) viewport.dataset.universe4ProofView = proof === 'automatic-handoff' ? '' : proof;
    },
    appendSignal(event, payload = {}) {
      signals.push({ at: Date.now(), event, ...payload });
      while (signals.length > 80) signals.shift();
      renderSignals();
    },
    dispose() { host.removeEventListener('click', onClick); },
  };
}
