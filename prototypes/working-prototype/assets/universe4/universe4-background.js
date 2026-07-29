export const U4_BACKGROUND_PROFILES = Object.freeze({
  force: Object.freeze({
    id: 'force',
    label: 'ForceGraph · világosabb',
    color: '#0B0A17',
  }),
  globe: Object.freeze({
    id: 'globe',
    label: 'Globe.gl · sötétebb',
    color: '#03091D',
  }),
});

export function resolveUniverse4Background(id) {
  return U4_BACKGROUND_PROFILES[id] || U4_BACKGROUND_PROFILES.force;
}
