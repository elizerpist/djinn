// A light-only controller for the separate Globe.gl planet view.  It owns no
// camera, renderer or animation loop: Globe.gl renders the scene and calls
// updateFrame from its existing scene.onBeforeRender hook.

export const V7_LIGHT_MODES = Object.freeze([
  'default-globe',
  'camera-headlight',
  'fixed-galaxy-sun',
  'hybrid-cinematic',
  'universe-v3-reference',
  'no-fill',
  'specular-proof',
  'light-direction-proof',
]);

export const V7_PRODUCTION_CINEMATIC_BLEND = .12;

const DEFAULTS = Object.freeze({
  color: '#241451',
  keyDistance: 300,
  keyColor: 0xc86ed1,
  keyIntensity: 1.48,
  fillColor: 0x654a88,
  fillGroundColor: 0x332047,
  fillIntensity: .82,
  productionAmbientColor: 0x281b42,
  defaultAmbientIntensity: .46,
  productionAmbientIntensity: .28,
  specular: '#382848',
  shininess: 13,
  emissive: '#0e0926',
  emissiveIntensity: .032,
  keyHalfLifeMs: 170,
  intensityHalfLifeMs: 210,
  minBlend: 0,
  maxBlend: 1,
});

// One immutable visual token set is shared by the ForceGraph V3 planet and
// the standalone Globe.gl V7 planet. Each owns distinct Three.js lights and
// materials; only the numeric colour/lighting contract is shared.
export const UNIVERSE_V3_REFERENCE_LIGHTING = Object.freeze({
  color: '#2a1a57',
  keyColor: 0xf5d8ff,
  keyIntensity: 1.40,
  fillColor: 0x40305e,
  // Keep V3's cool, world-fixed key but lift only its darkest hemisphere.
  // The original #050710 ground collapses to black on a Phong globe; this
  // deep violet floor preserves a subdued, visible back quarter instead.
  fillGroundColor: 0x2a1a4d,
  fillIntensity: .78,
  ambientColor: 0x211640,
  ambientIntensity: .46,
  productionAmbientColor: 0x211640,
  productionAmbientIntensity: .46,
  glowColor: 0x8c5baa,
  specular: '#c68bd7',
  shininess: 9,
  emissive: '#241044',
  emissiveIntensity: .14,
});

// Production Hybrid keeps its own magenta/violet light rig, but uses the
// solid V3-reference body so the primary V7 view cannot fall back to a dark,
// glassy-looking globe after a mode switch.
const HYBRID_CINEMATIC_PROFILE = Object.freeze({
  ...DEFAULTS,
  color: UNIVERSE_V3_REFERENCE_LIGHTING.color,
  emissive: UNIVERSE_V3_REFERENCE_LIGHTING.emissive,
  emissiveIntensity: UNIVERSE_V3_REFERENCE_LIGHTING.emissiveIntensity,
});

function stableHash(value) {
  let hash = 2166136261;
  const text = String(value || 'djinn-planet');
  for (let index = 0; index < text.length; index += 1) {
    hash ^= text.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return hash >>> 0;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function smoothingAlpha(deltaMs, halfLifeMs) {
  return 1 - Math.pow(.5, Math.max(0, deltaMs) / Math.max(1, halfLifeMs));
}

/**
 * Deterministic three-light rig for a globe which visually belongs to a
 * virtual galaxy. A caller must invoke updateTargetFromCamera on controls
 * changes, and updateFrame from the existing renderer frame.
 */
export class VirtualGalaxyLightingRig {
  constructor({ THREE, scene, getCamera, getPlanetCenter, getPlanetRadius = null, planetId = 'djinn-planet' }) {
    this.THREE = THREE;
    this.scene = scene;
    this.getCamera = getCamera;
    this.getPlanetCenter = getPlanetCenter;
    this.getPlanetRadius = getPlanetRadius;
    this.planetId = planetId;
    this.mode = 'hybrid-cinematic';
    this.cinematicBlend = V7_PRODUCTION_CINEMATIC_BLEND;
    this.active = false;
    this.suspended = false;
    this.initialized = false;
    this.frameState = null;
    this.lastFrameAt = null;
    this.lastFrameDeltaMs = 16;
    this._lastStableSide = new THREE.Vector3(1, 0, 0);
    this._center = new THREE.Vector3();
    this._cameraDirection = new THREE.Vector3();
    this._cameraForward = new THREE.Vector3();
    this._side = new THREE.Vector3();
    this._cinematic = new THREE.Vector3();
    this._targetKey = new THREE.Vector3();
    this._currentKey = new THREE.Vector3();
    this._tmp = new THREE.Vector3();
    this._tmpUp = new THREE.Vector3(0, 1, 0);
    this._proof = null;
  }

  initialize() {
    if (this.initialized) return;
    const { THREE } = this;
    this.galaxyLightTarget = new THREE.Object3D();
    this.galaxyLightTarget.name = 'v7-galaxy-light-target';
    // A clear magenta-violet key broadens the coloured lit hemisphere while
    // remaining well below V5's warm-white, high-intensity key.
    this.galaxyKeyLight = new THREE.DirectionalLight(DEFAULTS.keyColor, DEFAULTS.keyIntensity);
    this.galaxyKeyLight.name = 'v7-galaxy-key-light';
    // A broader, softer violet gradient expands the coloured field without
    // relying on a separate side/rim source.
    this.galaxyFillLight = new THREE.HemisphereLight(DEFAULTS.fillColor, DEFAULTS.fillGroundColor, DEFAULTS.fillIntensity);
    this.galaxyFillLight.name = 'v7-galaxy-fill-light';
    this.defaultAmbientLight = new THREE.AmbientLight(DEFAULTS.productionAmbientColor, DEFAULTS.defaultAmbientIntensity);
    this.defaultAmbientLight.name = 'v7-default-globe-reference-light';
    this.galaxyKeyLight.target = this.galaxyLightTarget;
    this.scene.add(this.galaxyLightTarget);
    this.initialized = true;
  }

  getLights() {
    this.initialize();
    return [
      this.defaultAmbientLight,
      this.galaxyKeyLight,
      this.galaxyFillLight,
    ];
  }

  captureEntryFrame({ planetId = this.planetId, entryLightDirection = null } = {}) {
    this.initialize();
    this.planetId = planetId;
    const camera = this.getCamera();
    this._copyPlanetCenter(this._center);
    this._cameraDirection.copy(camera.position).sub(this._center).normalize();
    const seed = stableHash(planetId);
    const yaw = (((seed & 0xffff) / 0xffff) - .5) * .34;
    const pitch = ((((seed >>> 16) & 0xffff) / 0xffff) - .5) * .2;
    const sunDirection = entryLightDirection
      ? this._tmp.copy(entryLightDirection).normalize()
      : new this.THREE.Vector3(-.62, .54, .57)
        .applyAxisAngle(this._tmpUp, yaw)
        .applyAxisAngle(this._lastStableSide, pitch)
        .normalize();
    this.frameState = {
      planetCenter: this._center.clone(),
      entryCameraPosition: camera.position.clone(),
      entryCameraQuaternion: camera.quaternion.clone(),
      entryCameraDirection: this._cameraDirection.clone(),
      galaxyUp: this._tmpUp.clone(),
      worldSunDirection: sunDirection.clone(),
      planetSeed: seed,
      entryDistance: Math.max(1, camera.position.distanceTo(this._center)),
      targetFillIntensity: DEFAULTS.fillIntensity,
      currentFillIntensity: DEFAULTS.fillIntensity,
      currentKeyIntensity: DEFAULTS.keyIntensity,
      targetKeyIntensity: DEFAULTS.keyIntensity,
      cameraFacingKey: 0,
    };
    this._currentKey.copy(sunDirection);
    this._targetKey.copy(sunDirection);
    this.galaxyLightTarget.position.copy(this._center);
    this.updateTargetFromCamera();
    // Prevent an entry-time light sweep: the first visual frame starts with
    // the current and target directions already aligned to the entry camera.
    this._currentKey.copy(this._targetKey);
    this.frameState.currentFillIntensity = this.frameState.targetFillIntensity;
    this.frameState.currentKeyIntensity = this.frameState.targetKeyIntensity;
    this._applyLightTransforms();
    this.lastFrameAt = null;
    return this.getDebugSnapshot();
  }

  setMode(mode) {
    if (!V7_LIGHT_MODES.includes(mode)) return false;
    this.mode = mode;
    this._setProofVisible(mode === 'light-direction-proof');
    this.updateTargetFromCamera();
    return true;
  }

  setCinematicBlend(value) {
    this.cinematicBlend = clamp(Number(value) || 0, DEFAULTS.minBlend, DEFAULTS.maxBlend);
    this.updateTargetFromCamera();
  }

  resume() {
    this.active = true;
    this.suspended = false;
    if (!this.frameState) this.captureEntryFrame();
    this.updateTargetFromCamera();
  }

  suspend() {
    this.suspended = true;
    this.active = false;
    this._setProofVisible(false);
  }

  updateTargetFromCamera() {
    if (!this.frameState || this.suspended) return;
    const camera = this.getCamera();
    this._copyPlanetCenter(this._center);
    this._cameraDirection.copy(camera.position).sub(this._center).normalize();
    camera.getWorldDirection(this._cameraForward);
    const mode = this.mode;
    const profile = this._getLightProfile();
    const universeV3Reference = mode === 'universe-v3-reference';
    this._applyLightProfile(profile);
    const fixed = universeV3Reference || mode === 'fixed-galaxy-sun' || mode === 'light-direction-proof';
    const headlight = mode === 'camera-headlight' || mode === 'default-globe';
    const blend = headlight ? 1 : (fixed ? 0 : this.cinematicBlend);
    this._computeCinematicDirection(this._cameraDirection, this._cinematic);
    // The diagnostic headlight has to be genuinely camera-aligned. The
    // production hybrid uses the offset cinematic direction below, so its
    // small correction cannot turn into a screen-fixed studio light.
    if (headlight) this._targetKey.copy(this._cameraDirection);
    else this._targetKey.copy(this.frameState.worldSunDirection).lerp(this._cinematic, blend).normalize();
    const currentDistance = Math.max(1, camera.position.distanceTo(this._center));
    const zoomRatio = clamp(currentDistance / this.frameState.entryDistance, .7, 1.35);
    // At the entry distance the configured production fill must be applied
    // exactly.  Starting at 96% made the V7 magenta field perceptibly smaller
    // than its declared value even before a user zoomed the camera.
    this.frameState.targetFillIntensity = mode === 'no-fill' || mode === 'default-globe'
      ? 0
      : profile.fillIntensity * (universeV3Reference ? 1 : (1 + ((zoomRatio - 1) * .08)));
    // Keep the brighter key through normal orbit angles, but apply a much
    // stronger falloff only near the camera axis. A quadratic response avoids
    // a centre-hotspot while leaving the off-axis magenta hemisphere visible.
    const cameraFacingKey = clamp((this.frameState.worldSunDirection.dot(this._cameraDirection) - .08) / .92, 0, 1);
    this.frameState.cameraFacingKey = cameraFacingKey;
    const cinematicKeyIntensity = universeV3Reference
      ? profile.keyIntensity
      : profile.keyIntensity * (1 - ((cameraFacingKey ** 2) * .27));
    this.frameState.targetKeyIntensity = mode === 'specular-proof'
      ? 2.05
      : (mode === 'default-globe' ? 1.85 : cinematicKeyIntensity);
  }

  updateFrame(timestamp = performance.now()) {
    if (!this.active || this.suspended || !this.frameState) return;
    const deltaMs = this.lastFrameAt == null ? 16 : Math.max(1, timestamp - this.lastFrameAt);
    this.lastFrameAt = timestamp;
    this.lastFrameDeltaMs = deltaMs;
    this._copyPlanetCenter(this._center);
    const keyAlpha = smoothingAlpha(deltaMs, this.mode === 'camera-headlight' ? 1 : DEFAULTS.keyHalfLifeMs);
    const intensityAlpha = smoothingAlpha(deltaMs, DEFAULTS.intensityHalfLifeMs);
    this._currentKey.lerp(this._targetKey, keyAlpha).normalize();
    this.frameState.currentFillIntensity += (this.frameState.targetFillIntensity - this.frameState.currentFillIntensity) * intensityAlpha;
    this.frameState.currentKeyIntensity += (this.frameState.targetKeyIntensity - this.frameState.currentKeyIntensity) * intensityAlpha;
    this._applyLightTransforms();
    this._updateProof();
  }

  getMaterialSettings() {
    const proof = this.mode === 'specular-proof';
    const profile = this._getLightProfile();
    const universeV3Reference = this.mode === 'universe-v3-reference';
    const frontLit = this.frameState?.cameraFacingKey || 0;
    return {
      // The bright hemisphere must retain the V5 violet body colour. The
      // direct key adds a soft cool sheen, never a cyan or white repaint.
      color: profile.color,
      // A wide, subdued magenta-violet lobe enlarges the visible coloured
      // field without repainting the planet into a white or neon surface.
      specular: proof ? '#cfd3e8' : profile.specular,
      // Lower Phong shininess deliberately broadens the lobe. A further
      // small reduction when the sun faces the camera suppresses the round,
      // harsh center hotspot without flattening the planetary form.
      shininess: proof ? 42 : Math.round(profile.shininess - (universeV3Reference ? 0 : (frontLit * 3))),
      emissive: profile.emissive,
      emissiveIntensity: proof ? .018 : profile.emissiveIntensity,
    };
  }

  copyWorldSunDirection(target) {
    if (this.frameState?.worldSunDirection) return target.copy(this.frameState.worldSunDirection);
    return target.set(-.62, .54, .57).normalize();
  }

  getDebugSnapshot() {
    const frame = this.frameState;
    const camera = this.getCamera?.();
    const cameraPosition = camera?.position?.toArray?.() || [0, 0, 0];
    const cameraDirection = frame ? this._cameraDirection.toArray() : [0, 0, 0];
    const radius = Number(this.getPlanetRadius?.()) || 1;
    const distance = frame && camera ? camera.position.distanceTo(frame.planetCenter) : 0;
    const latitude = Math.asin(clamp(this._cameraDirection.y, -1, 1)) * 180 / Math.PI;
    const longitude = Math.atan2(this._cameraDirection.z, this._cameraDirection.x) * 180 / Math.PI;
    return {
      mode: this.mode,
      profile: this.mode === 'universe-v3-reference' ? 'universe-v3-reference' : 'v7-soft-violet',
      planetSeed: frame?.planetSeed ?? null,
      cameraPosition,
      cameraDirection,
      pov: { lat: latitude, lng: longitude, altitude: distance / radius },
      entryCameraDirection: frame?.entryCameraDirection?.toArray?.() || [0, 0, 0],
      worldSunDirection: frame?.worldSunDirection?.toArray?.() || [0, 0, 0],
      cinematicCameraDirection: this._cinematic.toArray(),
      blendedKeyDirection: this._currentKey.toArray(),
      targetKeyDirection: this._targetKey.toArray(),
      keyIntensity: frame?.currentKeyIntensity ?? 0,
      fillIntensity: frame?.currentFillIntensity ?? 0,
      ambientIntensity: this.defaultAmbientLight?.visible ? this.defaultAmbientLight.intensity : 0,
      cameraFacingKey: frame?.cameraFacingKey ?? 0,
      smoothingHalfLives: { key: DEFAULTS.keyHalfLifeMs, intensity: DEFAULTS.intensityHalfLifeMs },
      fps: this.lastFrameDeltaMs ? 1000 / this.lastFrameDeltaMs : 0,
    };
  }

  resize() {
    // Kept as an explicit lifecycle hook: no geometry or texture depends on
    // viewport size, so resize intentionally leaves the stable sun unchanged.
  }

  dispose() {
    this.suspend();
    this._disposeProof();
    this.galaxyLightTarget?.removeFromParent();
    this.galaxyKeyLight?.removeFromParent();
    this.galaxyFillLight?.removeFromParent();
    this.defaultAmbientLight?.removeFromParent();
    this.frameState = null;
    this.initialized = false;
  }

  _copyPlanetCenter(target) {
    const result = this.getPlanetCenter?.(target);
    if (result && result !== target) target.copy(result);
    return target;
  }

  _getLightProfile() {
    if (this.mode === 'universe-v3-reference') return UNIVERSE_V3_REFERENCE_LIGHTING;
    if (this.mode === 'hybrid-cinematic') return HYBRID_CINEMATIC_PROFILE;
    return DEFAULTS;
  }

  _applyLightProfile(profile) {
    this.galaxyKeyLight.color.set(profile.keyColor);
    this.galaxyFillLight.color.set(profile.fillColor);
    this.galaxyFillLight.groundColor.set(profile.fillGroundColor);
    this.defaultAmbientLight.color.set(profile.productionAmbientColor);
  }

  _computeCinematicDirection(cameraDirection, target) {
    this._side.copy(this.frameState.galaxyUp).cross(cameraDirection);
    if (this._side.lengthSq() < .0001) this._side.copy(this._lastStableSide);
    else this._side.normalize();
    if (this._side.dot(this._lastStableSide) < 0) this._side.multiplyScalar(-1);
    this._lastStableSide.lerp(this._side, .18).normalize();
    return target.copy(cameraDirection).multiplyScalar(.57)
      .addScaledVector(this._lastStableSide, .56)
      .addScaledVector(this.frameState.galaxyUp, .34)
      .normalize();
  }

  _applyLightTransforms() {
    if (!this.galaxyLightTarget) return;
    this.galaxyLightTarget.position.copy(this._center);
    this.galaxyKeyLight.position.copy(this._center).addScaledVector(this._currentKey, DEFAULTS.keyDistance);
    this.galaxyKeyLight.intensity = this.frameState.currentKeyIntensity;
    this.galaxyFillLight.intensity = this.frameState.currentFillIntensity;
    const profile = this._getLightProfile();
    const defaultMode = this.mode === 'default-globe';
    // A weak, scene-wide violet lift makes the key-to-shadow transition
    // gradual. It replaces neither the key nor the removed side/rim light.
    this.defaultAmbientLight.intensity = defaultMode
      ? DEFAULTS.defaultAmbientIntensity
      : profile.productionAmbientIntensity;
    this.defaultAmbientLight.visible = true;
    this.galaxyKeyLight.visible = true;
    this.galaxyFillLight.visible = !defaultMode && this.galaxyFillLight.intensity > .001;
    this.galaxyLightTarget.updateMatrixWorld?.(true);
  }

  _setProofVisible(visible) {
    if (visible) this._ensureProof();
    if (this._proof) this._proof.group.visible = visible;
  }

  _ensureProof() {
    if (this._proof) return;
    const { THREE } = this;
    const group = new THREE.Group();
    group.name = 'v7-light-direction-proof';
    const targetMarker = new THREE.Mesh(
      new THREE.SphereGeometry(1.35, 10, 8),
      new THREE.MeshBasicMaterial({ color: 0x53ff9a, depthTest: false, depthWrite: false }),
    );
    const sunArrow = new THREE.ArrowHelper(new THREE.Vector3(0, 1, 0), new THREE.Vector3(), 58, 0xffd45a, 7, 4);
    const cameraArrow = new THREE.ArrowHelper(new THREE.Vector3(0, 1, 0), new THREE.Vector3(), 36, 0xffffff, 6, 3);
    const upArrow = new THREE.ArrowHelper(new THREE.Vector3(0, 1, 0), new THREE.Vector3(), 32, 0x65e7ff, 5, 3);
    const cameraLineGeometry = new THREE.BufferGeometry();
    cameraLineGeometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(6), 3));
    const cameraLine = new THREE.Line(cameraLineGeometry, new THREE.LineBasicMaterial({ color: 0x9adfff, transparent: true, opacity: .55, depthWrite: false }));
    const keyHelper = new THREE.DirectionalLightHelper(this.galaxyKeyLight, 18, 0xffd45a);
    group.add(targetMarker, sunArrow, cameraArrow, upArrow, cameraLine, keyHelper);
    group.visible = false;
    this.scene.add(group);
    this._proof = { group, targetMarker, sunArrow, cameraArrow, upArrow, cameraLine, keyHelper };
  }

  _updateProof() {
    if (!this._proof?.group.visible || !this.frameState) return;
    const camera = this.getCamera();
    const { targetMarker, sunArrow, cameraArrow, upArrow, cameraLine, keyHelper } = this._proof;
    targetMarker.position.copy(this._center);
    sunArrow.position.copy(this._center);
    sunArrow.setDirection(this._currentKey);
    sunArrow.setLength(58, 7, 4);
    cameraArrow.position.copy(this._center);
    cameraArrow.setDirection(this._cameraDirection);
    cameraArrow.setLength(36, 6, 3);
    upArrow.position.copy(this._center);
    upArrow.setDirection(this.frameState.galaxyUp);
    upArrow.setLength(32, 5, 3);
    const attribute = cameraLine.geometry.getAttribute('position');
    attribute.setXYZ(0, this._center.x, this._center.y, this._center.z);
    attribute.setXYZ(1, camera.position.x, camera.position.y, camera.position.z);
    attribute.needsUpdate = true;
    keyHelper.update();
  }

  _disposeProof() {
    if (!this._proof) return;
    this._proof.group.traverse((object) => {
      object.geometry?.dispose?.();
      object.material?.dispose?.();
      object.dispose?.();
    });
    this._proof.group.removeFromParent();
    this._proof = null;
  }
}
