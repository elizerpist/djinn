// World-space star environment for the separate V6/V7 Globe.gl views.
// It owns neither a camera nor a renderer: the host advances it from its
// existing Globe.gl/ForceGraph frame. The intentional production output is
// exactly three reliable batched star point clouds — no sun object or flare.

export const COSMIC_MODES = Object.freeze([
  'static-background-proof',
  'single-star-shell',
  'three-depth-shells',
  'near-stars-exaggerated',
  'stars-only',
  'cosmic-production',
]);

const DEFAULT_MODE = 'cosmic-production';
const STAR_LAYER_DEFINITIONS = Object.freeze([
  { key: 'far', count: 720, minRadius: 48, maxRadius: 72, opacity: .42, pointSize: 2.2 },
  { key: 'mid', count: 110, minRadius: 20, maxRadius: 32, opacity: .3, pointSize: 2.6 },
  { key: 'near', count: 14, minRadius: 9, maxRadius: 14, opacity: .24, pointSize: 3.1 },
]);

const STAR_TEXTURES = new WeakMap();

function clamp(value, min = 0, max = 1) {
  return Math.max(min, Math.min(max, value));
}

function damp(current, target, deltaMs, halfLifeMs) {
  const alpha = 1 - Math.pow(.5, Math.max(0, deltaMs) / Math.max(1, halfLifeMs));
  return current + ((target - current) * alpha);
}

function hashSeed(value) {
  let hash = 2166136261;
  for (const char of String(value || 'djinn-cosmic-environment')) {
    hash ^= char.charCodeAt(0);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0 || 1;
}

function seededRandom(seed) {
  let state = seed >>> 0 || 1;
  return () => {
    state ^= state << 13;
    state ^= state >>> 17;
    state ^= state << 5;
    return ((state >>> 0) / 4294967296);
  };
}

function createSoftStarTexture(THREE) {
  const cached = STAR_TEXTURES.get(THREE);
  if (cached) return cached;
  if (typeof document === 'undefined') {
    const texture = new THREE.Texture();
    texture.needsUpdate = true;
    STAR_TEXTURES.set(THREE, texture);
    return texture;
  }
  const canvas = document.createElement('canvas');
  canvas.width = 64;
  canvas.height = 64;
  const context = canvas.getContext('2d');
  const radius = canvas.width / 2;
  const gradient = context.createRadialGradient(radius, radius, 0, radius, radius, radius);
  gradient.addColorStop(0, 'rgba(255,255,255,1)');
  gradient.addColorStop(.22, 'rgba(225,246,255,.94)');
  gradient.addColorStop(.58, 'rgba(164,212,255,.32)');
  gradient.addColorStop(1, 'rgba(112,159,255,0)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, canvas.width, canvas.height);
  const texture = new THREE.CanvasTexture(canvas);
  texture.generateMipmaps = false;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  texture.colorSpace = THREE.SRGBColorSpace || texture.colorSpace;
  texture.needsUpdate = true;
  STAR_TEXTURES.set(THREE, texture);
  return texture;
}

function layerModeVisibility(mode) {
  if (mode === 'single-star-shell') return [1, 0, 0];
  if (mode === 'three-depth-shells' || mode === 'near-stars-exaggerated' || mode === 'stars-only' || mode === 'cosmic-production') return [1, 1, 1];
  return [0, 0, 0];
}

function makeNonInteractive(object) {
  object.userData.djinnNonInteractive = true;
  object.raycast = () => {};
  return object;
}

function starColor(random, THREE) {
  const roll = random();
  if (roll < .72) return new THREE.Color('#eaf5ff');
  if (roll < .92) return new THREE.Color('#a6dbff');
  return random() < .5 ? new THREE.Color('#c2b5ff') : new THREE.Color('#f4edff');
}

function createStarLayer(THREE, definition, planetRadius, seed) {
  const random = seededRandom(seed);
  const geometry = new THREE.BufferGeometry();
  const positions = new Float32Array(definition.count * 3);
  const colors = new Float32Array(definition.count * 3);
  for (let index = 0; index < definition.count; index += 1) {
    const z = (random() * 2) - 1;
    const azimuth = random() * Math.PI * 2;
    const planar = Math.sqrt(Math.max(0, 1 - (z * z)));
    const shellRadius = planetRadius * (definition.minRadius + ((definition.maxRadius - definition.minRadius) * random()));
    const offset = index * 3;
    positions[offset] = Math.cos(azimuth) * planar * shellRadius;
    positions[offset + 1] = z * shellRadius;
    positions[offset + 2] = Math.sin(azimuth) * planar * shellRadius;
    const color = starColor(random, THREE);
    const brightness = .68 + (random() * .32);
    colors[offset] = color.r * brightness;
    colors[offset + 1] = color.g * brightness;
    colors[offset + 2] = color.b * brightness;
  }
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  const material = new THREE.PointsMaterial({
    map: createSoftStarTexture(THREE),
    size: definition.pointSize,
    sizeAttenuation: false,
    vertexColors: true,
    transparent: true,
    opacity: definition.opacity,
    alphaTest: .015,
    depthTest: true,
    depthWrite: false,
    blending: THREE.AdditiveBlending,
  });
  material.name = `cosmic-${definition.key}-stars-material`;
  const points = new THREE.Points(geometry, material);
  points.name = `cosmic-${definition.key}-stars`;
  points.frustumCulled = false;
  makeNonInteractive(points);
  points.userData.cosmicLayer = definition.key;
  return { points, geometry, material, definition, opacity: definition.opacity, targetOpacity: definition.opacity };
}

export class CosmicEnvironment {
  constructor({
    THREE,
    scene,
    getCamera,
    getPlanetCenter = null,
    getPlanetRadius,
    getWorldSunDirection = null,
    getLensFlareController = null,
    getUiAttenuation = () => 1,
    planetId = 'djinn-planet',
  }) {
    this.THREE = THREE;
    this.scene = scene;
    this.getCamera = getCamera;
    this.getPlanetCenter = getPlanetCenter;
    this.getPlanetRadius = getPlanetRadius;
    // Retained as inert API parameters so host lighting can still use a
    // virtual direction without constructing a visual sun object.
    this.getWorldSunDirection = getWorldSunDirection;
    this.getLensFlareController = getLensFlareController;
    this.getUiAttenuation = getUiAttenuation;
    this.planetId = planetId;
    this.mode = DEFAULT_MODE;
    this.reducedEffects = false;
    this.initialized = false;
    this.active = false;
    this.disposed = false;
    this.root = null;
    this.starLayers = {};
    this.sunRoot = null;
    this.sunBody = null;
    this.sunCore = null;
    this.coronas = [];
    this._cameraPosition = new THREE.Vector3();
    this._planetCenter = new THREE.Vector3();
    this._lastFrameAt = null;
    this._snapshot = this._emptySnapshot();
  }

  _emptySnapshot() {
    return {
      mode: this.mode,
      reducedEffects: this.reducedEffects,
      starCounts: STAR_LAYER_DEFINITIONS.map((layer) => layer.count),
      starRadii: STAR_LAYER_DEFINITIONS.map((layer) => [layer.minRadius, layer.maxRadius]),
      starOpacities: [0, 0, 0],
      starMinimumPixels: STAR_LAYER_DEFINITIONS.map((layer) => layer.pointSize),
      pointsObjectCount: 0,
      sunWorldPosition: [0, 0, 0],
      sunNdc: [0, 0, 0],
      sunInFront: false,
      sunOccluded: false,
      sunWorldRadius: 0,
      coronaOpacity: 0,
      sunBodyPixels: 0,
      sunCorePixels: 0,
      coronaPixels: 0,
      flareVisibility: 0,
      farPlane: 0,
    };
  }

  initialize() {
    if (this.initialized || this.disposed) return this;
    this.initialized = true;
    this.root = new this.THREE.Group();
    this.root.name = 'CosmicEnvironmentRoot';
    makeNonInteractive(this.root);
    this._copyPlanetCenter(this.root.position);
    this.scene.add(this.root);
    this.root.updateMatrixWorld(true);
    this.createStarLayers();
    this._ensureClipping();
    return this;
  }

  createStarLayers() {
    if (!this.root || Object.keys(this.starLayers).length) return this.starLayers;
    const radius = Math.max(1, Number(this.getPlanetRadius?.()) || 1);
    STAR_LAYER_DEFINITIONS.forEach((definition, index) => {
      const layer = createStarLayer(this.THREE, definition, radius, hashSeed(`${this.planetId}:${definition.key}:${index}`));
      this.starLayers[definition.key] = layer;
      this.root.add(layer.points);
    });
    return this.starLayers;
  }

  _copyPlanetCenter(target) {
    const result = this.getPlanetCenter?.(target);
    if (result?.isVector3 && result !== target) target.copy(result);
    return target;
  }

  captureEntryFrame() { return this; }

  setMode(mode) {
    if (!COSMIC_MODES.includes(mode)) return false;
    this.mode = mode;
    return true;
  }

  setReducedEffects(enabled) {
    this.reducedEffects = Boolean(enabled);
    return this;
  }

  setLOD() { return this; }

  resume() {
    this.initialize();
    this.active = true;
    if (this.root) this.root.visible = true;
    this._lastFrameAt = null;
    return this;
  }

  suspend() {
    this.active = false;
    if (this.root) this.root.visible = false;
    return this;
  }

  updateFrame(timestamp = performance.now()) {
    if (!this.initialized || this.disposed || !this.active) return;
    const camera = this.getCamera?.();
    if (!camera) return;
    const deltaMs = this._lastFrameAt == null ? 16 : Math.max(1, timestamp - this._lastFrameAt);
    this._lastFrameAt = timestamp;
    camera.updateMatrixWorld?.(true);
    this._ensureClipping();
    this._updateStarLod(camera, deltaMs);
    this._updateSnapshot(camera);
  }

  _updateStarLod(camera, deltaMs) {
    const radius = Math.max(1, Number(this.getPlanetRadius?.()) || 1);
    const center = this.root?.getWorldPosition(this._planetCenter) || this._planetCenter.set(0, 0, 0);
    const distance = camera.getWorldPosition(this._cameraPosition).distanceTo(center) / radius;
    const modeVisibility = layerModeVisibility(this.mode);
    const closeMid = clamp((distance - .85) / 1.05);
    const closeNear = clamp((distance - 1.2) / 1.45);
    const layers = [this.starLayers.far, this.starLayers.mid, this.starLayers.near];
    layers.forEach((layer, index) => {
      if (!layer) return;
      let lod = index === 0 ? 1 : (index === 1 ? closeMid : closeNear);
      if (this.reducedEffects && index > 0) lod = 0;
      layer.targetOpacity = layer.definition.opacity * modeVisibility[index] * lod;
      layer.opacity = damp(layer.opacity, layer.targetOpacity, deltaMs, 84);
      layer.material.opacity = layer.opacity;
      layer.points.visible = layer.opacity > .002;
      layer.points.scale.setScalar(this.mode === 'near-stars-exaggerated' && index === 2 ? 1.55 : 1);
    });
  }

  _ensureClipping() {
    const camera = this.getCamera?.();
    const radius = Math.max(1, Number(this.getPlanetRadius?.()) || 1);
    const requiredFar = radius * 84;
    if (camera && Number(camera.far) < requiredFar) {
      camera.far = requiredFar;
      camera.updateProjectionMatrix?.();
    }
  }

  _updateSnapshot(camera) {
    this._snapshot = {
      mode: this.mode,
      reducedEffects: this.reducedEffects,
      starCounts: STAR_LAYER_DEFINITIONS.map((layer) => layer.count),
      starRadii: STAR_LAYER_DEFINITIONS.map((layer) => [layer.minRadius, layer.maxRadius]),
      starOpacities: [this.starLayers.far, this.starLayers.mid, this.starLayers.near].map((layer) => layer?.opacity || 0),
      starMinimumPixels: STAR_LAYER_DEFINITIONS.map((layer) => layer.pointSize),
      pointsObjectCount: Object.values(this.starLayers).filter((layer) => layer?.points?.isPoints).length,
      sunWorldPosition: [0, 0, 0],
      sunNdc: [0, 0, 0],
      sunInFront: false,
      sunOccluded: false,
      sunWorldRadius: 0,
      coronaOpacity: 0,
      sunBodyPixels: 0,
      sunCorePixels: 0,
      coronaPixels: 0,
      flareVisibility: 0,
      farPlane: Number(camera.far) || 0,
    };
  }

  getDebugSnapshot() {
    return {
      ...this._snapshot,
      starCounts: [...this._snapshot.starCounts],
      starRadii: this._snapshot.starRadii.map((range) => [...range]),
      starOpacities: [...this._snapshot.starOpacities],
      starMinimumPixels: [...this._snapshot.starMinimumPixels],
      sunWorldPosition: [...this._snapshot.sunWorldPosition],
      sunNdc: [...this._snapshot.sunNdc],
    };
  }

  isSmoothing() {
    return Object.values(this.starLayers).some((layer) => Math.abs((layer?.targetOpacity || 0) - (layer?.opacity || 0)) > .003);
  }

  resize() { this._ensureClipping(); }

  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    this.suspend();
    Object.values(this.starLayers).forEach((layer) => {
      layer.geometry?.dispose?.();
      layer.material?.dispose?.();
    });
    this.starLayers = {};
    this.root?.removeFromParent();
    this.root = null;
  }
}
