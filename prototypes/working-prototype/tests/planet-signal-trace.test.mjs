import assert from 'node:assert/strict';
import { createPlanetSignalTrace } from '../assets/universe4/globe/planet-signal-trace.js';

const trace = createPlanetSignalTrace({ limit: 2, now: () => 10 });
trace.record('pointer.tap', { variant: 'v5', cityId: 'pao2' });
trace.record('focus', { action: 'focus' });
trace.record('arc.commit', { assigned: 3 });

const entries = trace.entries();
assert.deepEqual(entries.map((entry) => entry.event), ['focus', 'arc.commit']);
assert.deepEqual(entries.map((entry) => entry.sequence), [2, 3]);
assert.ok(entries.every(Object.isFrozen), 'entries must be immutable snapshots');
assert.throws(() => { entries[0].event = 'changed'; }, TypeError);
assert.deepEqual(trace.entries().map((entry) => entry.event), ['focus', 'arc.commit']);

const serialized = trace.serialize();
assert.equal(serialized.split('\n').length, 2);
assert.match(serialized, /"event":"arc.commit"/);
assert.deepEqual(serialized.split('\n').map(JSON.parse).map((entry) => entry.event), ['focus', 'arc.commit']);

trace.clear();
assert.deepEqual(trace.entries(), []);
assert.equal(trace.serialize(), '');
