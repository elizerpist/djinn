import { validatePixelMatch } from './universe4-pixel-match.js?rev=3';

export const U4_REQUIRED_HIDDEN_GLOBE_FRAMES = 3;

/**
 * Performs the entire calibrate → settle → measure gate while Globe.gl is
 * invisible. This module has no DOM, renderer or route ownership; the source
 * adapters supply the real projection measurements.
 */
export async function prepareInvisibleGlobeMatch({
  forceFrame,
  globeStage,
  stableFrameCount = U4_REQUIRED_HIDDEN_GLOBE_FRAMES,
} = {}) {
  if (!forceFrame?.center || !Number.isFinite(forceFrame.radius) || !globeStage) {
    throw new TypeError('A measured Force handoff frame and Globe stage are required');
  }
  const pose = globeStage.applyHandoffPose?.(forceFrame);
  if (!pose) throw new Error('The hidden Globe stage could not apply the Force pose');
  const stableFrames = await globeStage.waitForRenderedFrames?.(stableFrameCount);
  if (stableFrames < stableFrameCount) throw new Error('The hidden Globe stage did not render enough stable frames');
  const globeFrame = globeStage.captureHandoffFrame?.({ landmarks: forceFrame.landmarks });
  if (!globeFrame) throw new Error('The hidden Globe stage could not capture its projected frame');
  const match = validatePixelMatch({ inline: forceFrame, globe: globeFrame });
  return Object.freeze({
    valid: match.valid,
    forceFrame,
    globeFrame,
    pose,
    stableFrames,
    match,
  });
}
