// U4 owns the ForceGraph source controller. Keeping it as a mounted adapter
// prevents the Galaxy entry/morph from drifting into a second implementation.
import { initUniverse4ForceController } from './universe4-force-controller.js?rev=2';

function u3Markup() {
  return `
    <section class="universe4-u3-screen">
      <main class="universe4-u3-root" data-universe4-u3-root>
        <div class="universe4-u3-stage" data-universe-stage>
          <div class="universe4-u3-galaxy" data-universe-galaxy aria-label="Universe V4 Force Graph"></div>
          <div class="universe4-u3-map" data-universe-map hidden></div>
          <div class="universe4-u3-proxy" data-universe-proxy hidden></div>
          <button type="button" class="universe-fullscreen-toggle" data-universe-fullscreen aria-pressed="false" aria-label="Universe teljes képernyőre kapcsolása">⛶</button>
          <aside class="universe4-u3-city-context" data-universe-city-context hidden aria-live="polite"></aside>
          <section class="universe4-u3-corridor" data-universe-corridor hidden></section>
          <aside class="universe4-u3-debug" data-universe-debug aria-label="Universe V4 Force debug"></aside>
        </div>
      </main>
    </section>`;
}

export function createUniverse4U3Stage({ mount, helpers = {}, onPlanetReady } = {}) {
  if (!mount) throw new Error('Universe 4 U3 source stage mount kötelező.');
  const host = document.createElement('div');
  host.className = 'universe4-u3-source-root';
  host.innerHTML = u3Markup();
  mount.replaceChildren(host);

  let disposed = false;
  let animationPaused = false;
  const destroy = initUniverse4ForceController(host, {
    ...helpers,
    // U4's inline ForceGraph planet is transition-only. The canonical V7
    // Globe stage owns the first visible city-label layout after handoff.
    suppressInlineCityLabels: true,
    onPlanetReady: async (payload) => {
      if (disposed) return { claimed: false };
      return onPlanetReady?.(payload) || { claimed: false };
    },
  });

  function pauseAnimation() {
    if (disposed || animationPaused) return;
    destroy.pauseAnimation?.();
    animationPaused = true;
  }

  function resumeAnimation() {
    if (disposed || !animationPaused) return;
    destroy.resumeAnimation?.();
    animationPaused = false;
  }

  async function resetToGalaxyOverview() {
    if (disposed) return false;
    resumeAnimation();
    return (await destroy.resetToGalaxyOverview?.()) === true;
  }

  function setBackgroundColor(color) {
    if (disposed) return false;
    return destroy.setUniverseBackgroundColor?.(color) === true;
  }

  function resumeInlineInteraction() {
    if (disposed) return false;
    resumeAnimation();
    const resumed = Boolean(destroy.resumeAfterExternalHandoff?.());
    if (resumed) setInputEnabled(true);
    return resumed;
  }

  function captureHandoffFrame(options) {
    if (disposed) return null;
    return destroy.captureFocusedPlanetHandoffFrame?.(options) || null;
  }

  function captureRenderProfile() {
    if (disposed) return null;
    return destroy.captureFocusedPlanetRenderProfile?.() || null;
  }

  function applyHandoffCamera(snapshot) {
    if (disposed) return false;
    return Boolean(destroy.applyFocusedPlanetHandoffCamera?.(snapshot));
  }

  return {
    get isAnimationPaused() { return animationPaused; },
    setOpacity(opacity) {
      mount.style.opacity = String(Math.max(0, Math.min(1, Number(opacity) || 0)));
      mount.style.pointerEvents = opacity > .99 ? 'auto' : 'none';
    },
    setInputEnabled(enabled) {
      host.classList.toggle('is-u4-input-disabled', !enabled);
      mount.style.pointerEvents = enabled ? 'auto' : 'none';
    },
    resize() {
      window.dispatchEvent(new Event('resize'));
    },
    pauseAnimation,
    resumeAnimation,
    resetToGalaxyOverview,
    setBackgroundColor,
    resumeInlineInteraction,
    captureHandoffFrame,
    captureRenderProfile,
    applyHandoffCamera,
    dispose() {
      if (disposed) return;
      disposed = true;
      destroy?.();
      host.remove();
    },
  };
}
