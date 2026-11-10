import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildSeed, keywords, toValue } from './scripts/seed';

test('seed contains 20 restaurants, each with a menu', () => {
  const docs = buildSeed();
  const restaurants = docs.filter((d) => /^restaurants\/[^/]+$/.test(d.path));
  assert.equal(restaurants.length, 20);
  for (const r of restaurants) {
    assert.ok(docs.some((d) => d.path.startsWith(`${r.path}/menu/`)), `${r.path} has no menu`);
  }
});

test('seed document ids are unique', () => {
  const paths = buildSeed().map((d) => d.path);
  assert.equal(new Set(paths).size, paths.length);
});

test('prices are integers (so‘m)', () => {
  for (const d of buildSeed()) {
    if ('price' in d.data) assert.ok(Number.isInteger(d.data.price), d.path);
  }
});

test('toValue maps JS values to Firestore REST values', () => {
  assert.deepEqual(toValue('a'), { stringValue: 'a' });
  assert.deepEqual(toValue(5000), { integerValue: '5000' });
  assert.deepEqual(toValue(4.5), { doubleValue: 4.5 });
  assert.deepEqual(toValue(true), { booleanValue: true });
  assert.deepEqual(toValue(['x']), { arrayValue: { values: [{ stringValue: 'x' }] } });
  assert.deepEqual(toValue({ uz: 'Pitsa' }), { mapValue: { fields: { uz: { stringValue: 'Pitsa' } } } });
});

test('keywords are lower-case prefixes', () => {
  assert.deepEqual(keywords('Osh'), ['os', 'osh']);
});
