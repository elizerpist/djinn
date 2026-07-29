function resolveClipboard(clipboard) {
  return clipboard ?? globalThis.navigator?.clipboard;
}

function copyErrorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}

export function mountPlanetSignalDebugPanel({ host, trace, clipboard } = {}) {
  const document = host?.ownerDocument ?? globalThis.document;
  if (!host || !trace || !document) {
    throw new TypeError('host and trace are required to mount the planet signal debug panel');
  }

  const panel = document.createElement('aside');
  panel.className = 'planet-signal-debug-panel';
  panel.setAttribute('aria-label', 'Planet signal debug log');

  const log = document.createElement('pre');
  log.className = 'planet-signal-debug-panel-log';
  log.setAttribute('data-planet-signal-log', '');
  log.setAttribute('aria-live', 'polite');

  const copyButton = document.createElement('button');
  copyButton.type = 'button';
  copyButton.className = 'planet-signal-debug-panel-copy';
  copyButton.setAttribute('data-planet-signal-copy', '');
  copyButton.textContent = 'Mind másolása';

  panel.append(log, copyButton);
  host.append(panel);

  let disposed = false;

  function render() {
    if (!disposed) log.textContent = trace.serialize();
  }

  async function copyTrace() {
    try {
      const targetClipboard = resolveClipboard(clipboard);
      if (typeof targetClipboard?.writeText !== 'function') {
        throw new Error('Clipboard is unavailable');
      }
      await targetClipboard.writeText(trace.serialize());
    } catch (error) {
      trace.record('signal.copy.error', { message: copyErrorMessage(error) });
      render();
    }
  }

  function onCopy() {
    void copyTrace();
  }

  copyButton.addEventListener('click', onCopy);
  render();

  return {
    render,
    dispose() {
      if (disposed) return;
      disposed = true;
      copyButton.removeEventListener('click', onCopy);
      panel.remove();
    },
  };
}
