/**
 * Small, renderer-agnostic gesture gate for planet node selection.
 * OrbitControls still sees drag/pinch events; only a short, single-pointer
 * gesture reaches the city picker. This intentionally owns no Globe state.
 */
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
    trace('pointer.down', { pointerId: event.pointerId, x: event.clientX, y: event.clientY });
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
      trace('pointer.drag', { pointerId: event.pointerId, distanceSquared });
    }
  }

  function onPointerCancel(event) {
    const runtime = runtimeFor();
    runtime?.gestures.delete(event.pointerId);
    if (canvas.hasPointerCapture?.(event.pointerId)) canvas.releasePointerCapture?.(event.pointerId);
    trace('pointer.cancel', { pointerId: event.pointerId });
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
      trace('pointer.tap.defer', { pointerId: event.pointerId, duration: Math.round(duration) });
      return;
    }
    if (cityId) {
      trace('pointer.tap', { pointerId: event.pointerId, cityId, duration: Math.round(duration) });
      activate(cityId);
    } else {
      trace('pointer.tap.no-city', { pointerId: event.pointerId, duration: Math.round(duration) });
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
