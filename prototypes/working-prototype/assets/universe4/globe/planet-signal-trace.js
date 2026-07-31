export function createPlanetSignalTrace({ limit = 200, now = () => Date.now() } = {}) {
  const events = [];
  let sequence = 0;

  return {
    record(event, payload = {}) {
      events.push(Object.freeze({ sequence: ++sequence, at: now(), event, ...payload }));
      while (events.length > limit) events.shift();
    },
    entries() {
      return events.map((entry) => Object.freeze({ ...entry }));
    },
    clear() {
      events.length = 0;
    },
    serialize() {
      return events.map((entry) => JSON.stringify(entry)).join('\n');
    },
  };
}
