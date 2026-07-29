// A world-anchored virtual-sun flare for the separate Globe.gl planet views.
// It deliberately owns no renderer/camera/render loop: the enclosing V6/V7
// lighting rig calls updateFrame immediately before Globe.gl renders.

export const FLARE_MODES = Object.freeze([
  'flare-off',
  'constant-flare',
  'world-sun-flare',
  'occlusion-proof',
  'limb-burst-proof',
  'optical-axis-proof',
  'flare-isolation-proof',
  'production-cinematic',
]);

export const FLARE_STATES = Object.freeze([
  'DISABLED',
  'INITIALIZING',
  'HIDDEN_BEHIND_PLANET',
  'EDGE_APPROACH',
  'EDGE_BURST',
  'VISIBLE',
  'VIEWPORT_FADE',
  'DISPOSING',
]);

const DEFAULT_MODE = 'production-cinematic';
const TEXTURE_CANVASES = new WeakMap();

function clamp(value, min = 0, max = 1) {
  return Math.max(min, Math.min(max, value));
}

function smoothstep(min, max, value) {
  const t = clamp((value - min) / Math.max(.000001, max - min));
  return t * t * (3 - (2 * t));
}

function damp(current, target, deltaMs, halfLifeMs) {
  const alpha = 1 - Math.pow(.5, Math.max(0, deltaMs) / Math.max(1, halfLifeMs));
  return current + ((target - current) * alpha);
}

function canvasTextureSource(kind) {
  if (typeof document === 'undefined') return null;
  const canvas = document.createElement('canvas');
  canvas.width = kind === 'anamorphic-streak' ? 256 : 128;
  canvas.height = kind === 'anamorphic-streak' ? 64 : 128;
  const context = canvas.getContext('2d');
  const width = canvas.width;
  const height = canvas.height;
  const centerX = width / 2;
  const centerY = height / 2;
  const radius = Math.min(width, height) / 2;
  if (kind === 'sun-core') {
    const gradient = context.createRadialGradient(centerX, centerY, 0, centerX, centerY, radius);
    gradient.addColorStop(0, 'rgba(255,255,255,1)');
    gradient.addColorStop(.11, 'rgba(244,255,255,.98)');
    gradient.addColorStop(.34, 'rgba(168,236,255,.48)');
    gradient.addColorStop(1, 'rgba(122,202,255,0)');
    context.fillStyle = gradient;
    context.fillRect(0, 0, width, height);
  } else if (kind === 'anamorphic-streak') {
    const horizontal = context.createLinearGradient(0, 0, width, 0);
    horizontal.addColorStop(0, 'rgba(214,248,255,0)');
    horizontal.addColorStop(.38, 'rgba(226,252,255,.03)');
    horizontal.addColorStop(.5, 'rgba(255,255,255,.42)');
    horizontal.addColorStop(.62, 'rgba(226,252,255,.03)');
    horizontal.addColorStop(1, 'rgba(214,248,255,0)');
    const vertical = context.createLinearGradient(0, centerY - 5, 0, centerY + 5);
    vertical.addColorStop(0, 'rgba(255,255,255,0)');
    vertical.addColorStop(.48, 'rgba(255,255,255,.84)');
    vertical.addColorStop(.52, 'rgba(255,255,255,.84)');
    vertical.addColorStop(1, 'rgba(255,255,255,0)');
    context.fillStyle = horizontal;
    context.fillRect(0, centerY - 6, width, 12);
    context.globalCompositeOperation = 'destination-in';
    context.fillStyle = vertical;
    context.fillRect(0, centerY - 6, width, 12);
  } else if (kind === 'inner-ghost' || kind === 'far-ghost') {
    const innerRadius = kind === 'inner-ghost' ? radius * .24 : radius * .3;
    const outerRadius = kind === 'inner-ghost' ? radius * .67 : radius * .58;
    context.strokeStyle = kind === 'inner-ghost' ? 'rgba(176,157,255,.38)' : 'rgba(230,243,255,.28)';
    context.lineWidth = kind === 'inner-ghost' ? 4 : 3;
    context.shadowColor = kind === 'inner-ghost' ? 'rgba(125,210,255,.24)' : 'rgba(164,126,255,.16)';
    context.shadowBlur = 7;
    context.beginPath();
    context.arc(centerX, centerY, outerRadius, 0, Math.PI * 2);
    context.stroke();
    context.globalCompositeOperation = 'destination-out';
    context.beginPath();
    context.arc(centerX, centerY, innerRadius, 0, Math.PI * 2);
    context.fill();
  } else {
    // A faint aperture ring with a cool/violet chromatic split. It stays
    // visually hollow, so it cannot be mistaken for a blue glow disk.
    context.lineWidth = 3;
    context.strokeStyle = 'rgba(132,225,255,.23)';
    context.beginPath();
    context.arc(centerX - 1.5, centerY, radius * .48, Math.PI * .12, Math.PI * 1.12);
    context.stroke();
    context.strokeStyle = 'rgba(202,154,255,.22)';
    context.beginPath();
    context.arc(centerX + 1.5, centerY, radius * .48, Math.PI * 1.12, Math.PI * 2.12);
    context.stroke();
    context.strokeStyle = 'rgba(235,248,255,.1)';
    context.lineWidth = 1;
    context.beginPath();
    context.arc(centerX, centerY, radius * .31, 0, Math.PI * 2);
    context.stroke();
  }
  return canvas;
}

function cachedCanvasSources(THREE) {
  let sources = TEXTURE_CANVASES.get(THREE);
  if (!sources) {
    sources = {
      sunCore: canvasTextureSource('sun-core'),
      anamorphicStreak: canvasTextureSource('anamorphic-streak'),
      innerGhost: canvasTextureSource('inner-ghost'),
      apertureRing: canvasTextureSource('aperture-ring'),
      farGhost: canvasTextureSource('far-ghost'),
    };
    TEXTURE_CANVASES.set(THREE, sources);
  }
  return sources;
}

function createTexture(THREE, source) {
  const texture = source ? new THREE.CanvasTexture(source) : new THREE.Texture();
  texture.generateMipmaps = false;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.colorSpace = THREE.SRGBColorSpace || texture.colorSpace;
  texture.needsUpdate = true;
  return texture;
}

function rendererKind(renderer) {
  if (renderer?.isWebGPURenderer || renderer?.constructor?.name === 'WebGPURenderer') return 'webgpu';
  return 'webgl';
}

/**
 * A no-RAF lifecycle controller for a Lensflare that is anchored to the same
 * world-fixed sun direction as the Galaxy Key Light. Geometry visibility is
 * independently checked because a translucent globe can weaken native depth
 * occlusion in some WebGL compositions.
 */
export class VirtualSunLensFlareController {
  constructor({
    THREE,
    scene,
    getRenderer,
    getCamera,
    getPlanetCenter,
    getPlanetRadius,
    getWorldSunDirection,
    getUiAttenuation = () => 1,
  }) {
    this.THREE = THREE;
    this.scene = scene;
    this.getRenderer = getRenderer;
    this.getCamera = getCamera;
    this.getPlanetCenter = getPlanetCenter;
    this.getPlanetRadius = getPlanetRadius;
    this.getWorldSunDirection = getWorldSunDirection;
    this.getUiAttenuation = getUiAttenuation;
    this.mode = DEFAULT_MODE;
    this.state = 'INITIALIZING';
    this.enabled = true;
    this.active = false;
    this.initialized = false;
    this.disposed = false;
    this.flare = null;
    this.elements = [];
    this.elementSpecs = [];
    this.debugOverlay = null;
    this.debugLine = null;
    this.debugMarkers = null;
    this._debugLinePositions = null;
    this._debugMarkerPositions = null;
    this._loadPromise = null;
    this._adapterKind = null;
    this._lastFrameAt = null;
    this._virtualSunDistance = null;
    this.currentVisibility = 0;
    this.targetVisibility = 0;
    this._center = new THREE.Vector3();
    this._sunDirection = new THREE.Vector3();
    this._proxyPosition = new THREE.Vector3();
    this._cameraPosition = new THREE.Vector3();
    this._cameraForward = new THREE.Vector3();
    this._segment = new THREE.Vector3();
    this._originToCenter = new THREE.Vector3();
    this._closestPoint = new THREE.Vector3();
    this._sunNdc = new THREE.Vector3();
    this._centerNdc = new THREE.Vector3();
    this._edgeNdc = new THREE.Vector3();
    this._cameraRight = new THREE.Vector3();
    this._snapshot = {
      rendererKind: 'unknown',
      adapter: 'pending',
      state: this.state,
      worldSunDirection: [0, 0, 0],
      proxyWorldPosition: [0, 0, 0],
      projectedNdc: [0, 0, 0],
      inFrontOfCamera: false,
      insideViewport: false,
      raySphereOccluded: false,
      limbProximity: 0,
      zoomFactor: 0,
      viewportFade: 0,
      uiAttenuation: 1,
      targetVisibility: 0,
      currentVisibility: 0,
      activeElements: 0,
      elementDistances: [],
      elementKinds: [],
      opticalAxisProof: false,
    };
  }

  initialize() {
    if (this.initialized || this.disposed) return this;
    this.initialized = true;
    this.virtualSunFlareProxy = new this.THREE.Object3D();
    this.virtualSunFlareProxy.name = 'virtual-sun-flare-proxy';
    this.virtualSunFlareProxy.userData.djinnNonInteractive = true;
    this.scene.add(this.virtualSunFlareProxy);
    this._adapterKind = rendererKind(this.getRenderer?.());
    this._snapshot.rendererKind = this._adapterKind;
    this._loadAddon();
    return this;
  }

  async _loadAddon() {
    if (this._loadPromise || this.disposed) return this._loadPromise;
    this._loadPromise = (async () => {
      try {
        const addon = this._adapterKind === 'webgpu'
          ? await import('./vendor/addons/objects/LensflareMesh.js?rev=1')
          : await import('./vendor/addons/objects/Lensflare.js?rev=1');
        if (this.disposed) return;
        const Lensflare = this._adapterKind === 'webgpu' ? addon.LensflareMesh : addon.Lensflare;
        const LensflareElement = addon.LensflareElement;
        if (!Lensflare || !LensflareElement) throw new Error(`Missing ${this._adapterKind} lens flare addon`);
        this._attachLensflare(Lensflare, LensflareElement);
      } catch (error) {
        // Never substitute the WebGL Lensflare on a WebGPU renderer. The
        // controlled fallback keeps the planet view usable and exposes the
        // exact condition in the compact debug output.
        this._snapshot.adapter = `${this._adapterKind}-addon-unavailable`;
        this._snapshot.error = String(error?.message || error);
      }
    })();
    return this._loadPromise;
  }

  _attachLensflare(Lensflare, LensflareElement) {
    if (this.flare || this.disposed) return;
    const sources = cachedCanvasSources(this.THREE);
    this.elementSpecs = [
      { kind: 'sun-core', texture: createTexture(this.THREE, sources.sunCore), size: 52, distance: 0, color: '#f9ffff', intensity: .8, nearFade: 1, limbBoost: .18 },
      { kind: 'anamorphic-streak', texture: createTexture(this.THREE, sources.anamorphicStreak), size: 112, distance: 0, color: '#dffaff', intensity: .26, nearFade: 0, limbBoost: .1 },
      { kind: 'inner-ghost', texture: createTexture(this.THREE, sources.innerGhost), size: 32, distance: .3, color: '#a69aff', intensity: .34, nearFade: .22, limbBoost: .05 },
      { kind: 'aperture-ring', texture: createTexture(this.THREE, sources.apertureRing), size: 44, distance: .52, color: '#c5aaff', intensity: .28, nearFade: 0, limbBoost: .04 },
      { kind: 'far-ghost', texture: createTexture(this.THREE, sources.farGhost), size: 24, distance: .76, color: '#e8f3ff', intensity: .18, nearFade: 0, limbBoost: 0 },
    ];
    this.flare = new Lensflare();
    this.flare.name = 'virtual-sun-lens-flare';
    this.flare.userData.djinnNonInteractive = true;
    this.flare.frustumCulled = false;
    this.elements = this.elementSpecs.map((spec) => new LensflareElement(
      spec.texture,
      spec.size,
      spec.distance,
      new this.THREE.Color(spec.color),
    ));
    this.elements.forEach((element) => this.flare.addElement(element));
    this.virtualSunFlareProxy.add(this.flare);
    this._snapshot.adapter = this._adapterKind === 'webgpu' ? 'LensflareMesh' : 'Lensflare';
  }

  setMode(mode) {
    if (!FLARE_MODES.includes(mode)) return false;
    this.mode = mode;
    this._syncDebugOverlay();
    return true;
  }

  whenReady() {
    return this._loadPromise ? this._loadPromise.then(() => this) : Promise.resolve(this);
  }

  setEnabled(enabled) {
    this.enabled = Boolean(enabled);
    if (!this.enabled) this.targetVisibility = 0;
  }

  resume() {
    this.initialize();
    this.active = true;
    this._lastFrameAt = null;
  }

  captureEntryFrame() {
    // The proxy has a world position, not a camera-relative one. Capture the
    // safe distance once per separate-planet entry so pinch/orbit cannot make
    // the sun drift with the user.
    this._virtualSunDistance = null;
    this._lastFrameAt = null;
  }

  suspend() {
    this.active = false;
    this.targetVisibility = 0;
    if (this.flare) this.flare.visible = false;
  }

  updateFrame(timestamp = performance.now()) {
    if (!this.initialized || this.disposed) return;
    if (!this.active) {
      this.currentVisibility = 0;
      this.targetVisibility = 0;
      if (this.flare) this.flare.visible = false;
      this.state = 'DISABLED';
      return;
    }
    const camera = this.getCamera?.();
    if (!camera) return;
    const deltaMs = this._lastFrameAt == null ? 16 : Math.max(1, timestamp - this._lastFrameAt);
    this._lastFrameAt = timestamp;
    this._copyPlanetCenter(this._center);
    this._copyWorldSunDirection(this._sunDirection);
    const radius = Math.max(.0001, Number(this.getPlanetRadius?.()) || 1);
    camera.updateMatrixWorld?.(true);
    camera.getWorldPosition?.(this._cameraPosition) || this._cameraPosition.copy(camera.position);
    const sunDistance = this._virtualSunDistance ?? this._sunDistance(camera, radius);
    this._virtualSunDistance ??= sunDistance;
    this._proxyPosition.copy(this._center).addScaledVector(this._sunDirection, sunDistance);
    this.virtualSunFlareProxy.position.copy(this._proxyPosition);
    this.virtualSunFlareProxy.updateMatrixWorld(true);

    const metrics = this._visibilityMetrics(camera, radius);
    this.targetVisibility = this._targetFromMetrics(metrics);
    const halfLife = this.targetVisibility < this.currentVisibility ? 62 : 118;
    this.currentVisibility = damp(this.currentVisibility, this.targetVisibility, deltaMs, halfLife);
    if (!this.active || !this.enabled || this.mode === 'flare-off') this.currentVisibility = 0;
    this._applyVisibility(metrics);
    this._updateDebugOverlay(camera);
    this._setState(metrics);
    this._snapshot = {
      rendererKind: this._adapterKind || 'unknown',
      adapter: this._snapshot.adapter || 'pending',
      state: this.state,
      worldSunDirection: this._sunDirection.toArray(),
      proxyWorldPosition: this._proxyPosition.toArray(),
      projectedNdc: this._sunNdc.toArray(),
      inFrontOfCamera: metrics.inFront,
      insideViewport: metrics.insideViewport,
      raySphereOccluded: metrics.occluded,
      occlusionFade: metrics.occlusionFade,
      limbProximity: metrics.limbProximity,
      zoomFactor: metrics.zoomFactor,
      viewportFade: metrics.viewportFade,
      uiAttenuation: metrics.uiAttenuation,
      targetVisibility: this.targetVisibility,
      currentVisibility: this.currentVisibility,
      activeElements: this.flare ? this.elements.length : 0,
      elementDistances: this.elementSpecs.map((spec) => spec.distance),
      elementKinds: this.elementSpecs.map((spec) => spec.kind),
      opticalAxisProof: this.debugOverlay?.visible || false,
      error: this._snapshot.error,
    };
  }

  _sunDistance(camera, radius) {
    const centerDistance = this._cameraPosition.distanceTo(this._center);
    const farBudget = Math.max(radius * 2, ((Number(camera.far) || radius * 50) - centerDistance) * .72);
    // Prefer a 15–30R virtual sun, but preserve a safe in-frustum fallback
    // when a host scene deliberately uses a short far clipping plane.
    return Math.max(radius * 2, Math.min(radius * 30, farBudget));
  }

  _visibilityMetrics(camera, radius) {
    this._segment.copy(this._proxyPosition).sub(this._cameraPosition);
    const segmentLengthSq = Math.max(.000001, this._segment.lengthSq());
    this._originToCenter.copy(this._cameraPosition).sub(this._center);
    const projection = clamp(-this._originToCenter.dot(this._segment) / segmentLengthSq, 0, 1);
    const closestDistance = this._closestPoint.copy(this._originToCenter)
      .addScaledVector(this._segment, projection).length();
    const occlusionClearance = closestDistance - radius;
    const intersectsBeforeSun = occlusionClearance < 0 && projection < .999;
    camera.getWorldDirection(this._cameraForward);
    const inFront = this._segment.dot(this._cameraForward) > 0;
    this._sunNdc.copy(this._proxyPosition).project(camera);
    this._centerNdc.copy(this._center).project(camera);
    this._cameraRight.set(1, 0, 0).applyQuaternion(camera.quaternion).normalize();
    this._edgeNdc.copy(this._center).addScaledVector(this._cameraRight, radius).project(camera);
    const screenRadius = Math.max(.00001, this._edgeNdc.distanceTo(this._centerNdc));
    const screenDistance = this._sunNdc.distanceTo(this._centerNdc);
    const limbSignedDistance = screenDistance - screenRadius;
    const limbProximity = 1 - clamp(Math.abs(limbSignedDistance) / Math.max(.0001, screenRadius * .32));
    const edgeDistance = 1 - Math.max(Math.abs(this._sunNdc.x), Math.abs(this._sunNdc.y));
    const viewportFade = smoothstep(-.12, .12, edgeDistance);
    const insideViewport = viewportFade > .001 && this._sunNdc.z >= -1 && this._sunNdc.z <= 1;
    const occlusionFade = smoothstep(-radius * .11, radius * .09, occlusionClearance);
    const distanceToPlanet = this._cameraPosition.distanceTo(this._center) / radius;
    const zoomFactor = .22 + (.78 * smoothstep(.84, 2.15, distanceToPlanet));
    return {
      inFront,
      insideViewport,
      occluded: intersectsBeforeSun,
      occlusionFade: intersectsBeforeSun ? occlusionFade : 1,
      limbProximity,
      viewportFade,
      zoomFactor,
      uiAttenuation: clamp(Number(this.getUiAttenuation?.()) || 0, 0, 1),
    };
  }

  _targetFromMetrics(metrics) {
    if (!this.active || !this.enabled || this.mode === 'flare-off' || !metrics.inFront || !metrics.insideViewport) return 0;
    const base = metrics.viewportFade * metrics.zoomFactor * metrics.uiAttenuation;
    if (this.mode === 'constant-flare') return .62 * base;
    if (this.mode === 'world-sun-flare') return .54 * base;
    const occluded = metrics.occlusionFade;
    const limbBurst = 1 + (metrics.limbProximity * (this.mode === 'limb-burst-proof' ? .95 : .28));
    const modeIntensity = this.mode === 'occlusion-proof' || this.mode === 'optical-axis-proof' || this.mode === 'flare-isolation-proof' ? .9 : .38;
    return clamp(modeIntensity * base * occluded * limbBurst);
  }

  _applyVisibility(metrics) {
    if (!this.flare) return;
    this.flare.visible = this.currentVisibility > .002;
    const brightness = this.currentVisibility;
    const closeDetail = smoothstep(.34, .72, metrics?.zoomFactor ?? 1);
    this.elements.forEach((element, index) => {
      const spec = this.elementSpecs[index];
      if (!spec) return;
      const detailFade = spec.nearFade + ((1 - spec.nearFade) * closeDetail);
      const limbBoost = 1 + ((metrics?.limbProximity || 0) * spec.limbBoost);
      element.color.set(spec.color).multiplyScalar(brightness * spec.intensity * detailFade * limbBoost);
      element.size = spec.size * (.72 + (brightness * .28));
    });
  }

  _syncDebugOverlay() {
    const enabled = this.mode === 'optical-axis-proof' || this.mode === 'flare-isolation-proof';
    if (!enabled) {
      if (this.debugOverlay) this.debugOverlay.visible = false;
      return;
    }
    const camera = this.getCamera?.();
    if (!camera) return;
    if (!this.debugOverlay) this._createDebugOverlay(camera);
    if (this.debugOverlay) this.debugOverlay.visible = true;
  }

  _createDebugOverlay(camera) {
    const THREE = this.THREE;
    this.debugOverlay = new THREE.Group();
    this.debugOverlay.name = 'virtual-sun-optical-axis-proof';
    this.debugOverlay.renderOrder = 1000;
    this.debugOverlay.userData.djinnNonInteractive = true;
    this.debugOverlay.raycast = () => {};

    const lineGeometry = new THREE.BufferGeometry();
    this._debugLinePositions = new Float32Array(6);
    lineGeometry.setAttribute('position', new THREE.BufferAttribute(this._debugLinePositions, 3));
    this.debugLine = new THREE.Line(
      lineGeometry,
      new THREE.LineBasicMaterial({ color: '#ffe889', transparent: true, opacity: .72, depthTest: false, depthWrite: false }),
    );
    this.debugLine.renderOrder = 1001;
    this.debugLine.raycast = () => {};
    this.debugOverlay.add(this.debugLine);

    const markerGeometry = new THREE.BufferGeometry();
    this._debugMarkerPositions = new Float32Array(this.elementSpecs.length * 3);
    const markerColors = new Float32Array(this.elementSpecs.length * 3);
    ['#ffffff', '#75eaff', '#ba9dff', '#e4c4ff', '#dcefff'].forEach((value, index) => {
      const color = new THREE.Color(value);
      markerColors[index * 3] = color.r;
      markerColors[(index * 3) + 1] = color.g;
      markerColors[(index * 3) + 2] = color.b;
    });
    markerGeometry.setAttribute('position', new THREE.BufferAttribute(this._debugMarkerPositions, 3));
    markerGeometry.setAttribute('color', new THREE.BufferAttribute(markerColors, 3));
    this.debugMarkers = new THREE.Points(
      markerGeometry,
      new THREE.PointsMaterial({ size: 7, sizeAttenuation: false, vertexColors: true, transparent: true, opacity: .9, depthTest: false, depthWrite: false }),
    );
    this.debugMarkers.renderOrder = 1002;
    this.debugMarkers.raycast = () => {};
    this.debugOverlay.add(this.debugMarkers);
    camera.add(this.debugOverlay);
  }

  _updateDebugOverlay(camera) {
    this._syncDebugOverlay();
    if (!this.debugOverlay?.visible || !this._debugLinePositions || !this._debugMarkerPositions) return;
    const planeDistance = Math.max(2, Number(camera.near) * 8);
    const fov = (Number(camera.fov) || 45) * Math.PI / 180;
    const halfHeight = Math.tan(fov * .5) * planeDistance;
    const halfWidth = halfHeight * (Number(camera.aspect) || 1);
    const sourceX = this._sunNdc.x * halfWidth;
    const sourceY = this._sunNdc.y * halfHeight;
    this._debugLinePositions.set([sourceX, sourceY, -planeDistance, 0, 0, -planeDistance]);
    this.debugLine.geometry.getAttribute('position').needsUpdate = true;
    this.elementSpecs.forEach((spec, index) => {
      const axisFactor = 1 - spec.distance;
      this._debugMarkerPositions[index * 3] = sourceX * axisFactor;
      this._debugMarkerPositions[(index * 3) + 1] = sourceY * axisFactor;
      this._debugMarkerPositions[(index * 3) + 2] = -planeDistance;
    });
    this.debugMarkers.geometry.getAttribute('position').needsUpdate = true;
  }

  _setState(metrics) {
    if (this.disposed) this.state = 'DISPOSING';
    else if (!this.enabled || this.mode === 'flare-off' || !this.active) this.state = 'DISABLED';
    else if (metrics.occluded && metrics.occlusionFade < .08) this.state = 'HIDDEN_BEHIND_PLANET';
    else if (metrics.limbProximity > .82) this.state = 'EDGE_BURST';
    else if (metrics.limbProximity > .34) this.state = 'EDGE_APPROACH';
    else if (!metrics.insideViewport) this.state = 'VIEWPORT_FADE';
    else this.state = 'VISIBLE';
  }

  _copyPlanetCenter(target) {
    const result = this.getPlanetCenter?.(target);
    if (result && result !== target) target.copy(result);
    return target;
  }

  _copyWorldSunDirection(target) {
    const result = this.getWorldSunDirection?.(target);
    if (result && result !== target) target.copy(result);
    if (target.lengthSq() < .000001) target.set(-.62, .54, .57);
    return target.normalize();
  }

  getDebugSnapshot() {
    return {
      ...this._snapshot,
      worldSunDirection: [...this._snapshot.worldSunDirection],
      proxyWorldPosition: [...this._snapshot.proxyWorldPosition],
      projectedNdc: [...this._snapshot.projectedNdc],
      elementDistances: [...this._snapshot.elementDistances],
      elementKinds: [...this._snapshot.elementKinds],
    };
  }

  isSmoothing() {
    return Math.abs(this.targetVisibility - this.currentVisibility) > .002;
  }

  resize() {
    // LensflareElement sizes are pixel based and Globe.gl owns the renderer
    // viewport. The next shared render frame projects the proxy again; no
    // texture, geometry or flare element is recreated here.
  }

  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    this.state = 'DISPOSING';
    this.suspend();
    this.flare?.removeFromParent();
    this.flare?.dispose?.();
    this.flare = null;
    this.elements = [];
    this.elementSpecs = [];
    this.debugOverlay?.removeFromParent();
    this.debugLine?.geometry?.dispose?.();
    this.debugLine?.material?.dispose?.();
    this.debugMarkers?.geometry?.dispose?.();
    this.debugMarkers?.material?.dispose?.();
    this.debugOverlay = null;
    this.debugLine = null;
    this.debugMarkers = null;
    this.virtualSunFlareProxy?.removeFromParent();
    this.virtualSunFlareProxy = null;
  }
}
