/**
 * Small, renderer-agnostic gesture gate for planet node selection.
 * OrbitControls still sees drag/pinch events; only a short, single-pointer
 * gesture reaches the city picker. This intentionally owns no Globe state.
 */
function describeTarget(target) {
  if (!target) return null;
  return {
    tag: target.tagName || null,
    id: target.id || null,
    className: typeof target.className === 'string' ? target.className : null,
    role: target.getAttribute?.('role') || null,
    nodeId: target.dataset?.nodeId || null,
  };
}

function eventDiagnostics(event, canvas) {
  let style = null;
  try {
    style = canvas && typeof window !== 'undefined' ? window.getComputedStyle?.(canvas) : null;
  } catch {
    style = null;
  }
  return {
    target: describeTarget(event?.target),
    currentTarget: describeTarget(event?.currentTarget),
    pointerType: event?.pointerType ?? null,
    buttons: event?.buttons ?? null,
    button: event?.button ?? null,
    defaultPrevented: event?.defaultPrevented === true,
    cancelable: event?.cancelable === true,
    eventPhase: event?.eventPhase ?? null,
    canvasPointerEvents: style?.pointerEvents ?? null,
    canvasTouchAction: style?.touchAction ?? null,
  };
}

export function createPlanetInputRouter({
  canvas,
  runtimeFor,
  isEnabled,
  now = () => performance.now(),
  pick,
  activate,
  onEmptyTap = () => {},
  trace = () => {},
  tapDistanceSquared = 81,
  tapDurationMs = 360,
} = {}) {
  if (!canvas || !runtimeFor || !isEnabled || !pick || !activate) {
    throw new Error('PlanetInputRouter requires canvas, runtimeFor, isEnabled, pick and activate');
  }

  function onPointerDown(event) {
    if (!isEnabled() || (event.button != null && event.button !== 0)) return;
    const runtime = runtimeFor();
    if (!runtime) return;
    const gesture = {
      startX: event.clientX,
      startY: event.clientY,
      startedAt: now(),
      moved: false,
      multiPointer: runtime.gestures.size > 0,
    };
    runtime.gestures.forEach((activeGesture) => { activeGesture.multiPointer = true; });
    runtime.gestures.set(event.pointerId, gesture);
    canvas.setPointerCapture?.(event.pointerId);
    trace('pointer.down', {
      ...eventDiagnostics(event, canvas),
      pointerId: event.pointerId,
      x: event.clientX,
      y: event.clientY,
    });
  }

  function onPointerMove(event) {
    const runtime = runtimeFor();
    const gesture = runtime?.gestures.get(event.pointerId);
    if (!gesture) return;
    const dx = event.clientX - gesture.startX;
    const dy = event.clientY - gesture.startY;
    const distanceSquared = (dx * dx) + (dy * dy);
    if (distanceSquared > tapDistanceSquared && !gesture.moved) {
      gesture.moved = true;
      trace('pointer.drag', { ...eventDiagnostics(event, canvas), pointerId: event.pointerId, distanceSquared });
    }
  }

  function onPointerCancel(event) {
    const runtime = runtimeFor();
    runtime?.gestures.delete(event.pointerId);
    if (canvas.hasPointerCapture?.(event.pointerId)) canvas.releasePointerCapture?.(event.pointerId);
    trace('pointer.cancel', { ...eventDiagnostics(event, canvas), pointerId: event.pointerId });
  }

  function onPointerUp(event) {
    const runtime = runtimeFor();
    const gesture = runtime?.gestures.get(event.pointerId);
    if (!gesture) return;
    const hadMultiplePointers = gesture.multiPointer || runtime.gestures.size > 1;
    runtime.gestures.delete(event.pointerId);
    if (canvas.hasPointerCapture?.(event.pointerId)) canvas.releasePointerCapture?.(event.pointerId);
    const duration = now() - gesture.startedAt;
    if (gesture.moved || hadMultiplePointers || duration > tapDurationMs) {
      trace('pointer.tap.reject', {
        ...eventDiagnostics(event, canvas),
        pointerId: event.pointerId,
        moved: gesture.moved,
        hadMultiplePointers,
        duration: Math.round(duration),
      });
      return;
    }
    // `undefined` is a third, deliberate result: the renderer is rebuilding
    // its hit-target registry. It is neither a city hit nor a blank-globe
    // tap, so it must not accidentally clear an already focused city.
    const cityId = pick(event);
    if (cityId === undefined) {
      trace('pointer.tap.defer', { ...eventDiagnostics(event, canvas), pointerId: event.pointerId, duration: Math.round(duration) });
      return;
    }
    if (cityId) {
      trace('pointer.tap', { ...eventDiagnostics(event, canvas), pointerId: event.pointerId, cityId, duration: Math.round(duration) });
      activate(cityId);
    } else {
      trace('pointer.tap.no-city', { ...eventDiagnostics(event, canvas), pointerId: event.pointerId, duration: Math.round(duration) });
      onEmptyTap(event);
    }
  }

  return Object.freeze({
    onPointerDown,
    onPointerMove,
    onPointerCancel,
    onPointerUp,
    clear(variant) {
      runtimeFor(variant)?.gestures.clear();
    },
  });
}
