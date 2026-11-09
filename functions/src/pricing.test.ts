import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { computeTotals, isOpen, priceItems, PricingError, serviceFee } from './pricing';
import { messageFor } from './notifications';
import { etaMinutes, generateRoute } from './route';

describe('serviceFee', () => {
  it('is 5% rounded half-up to 100 (same as the app)', () => {
    assert.equal(serviceFee(0), 0);
    assert.equal(serviceFee(45000), 2300);
    assert.equal(serviceFee(100000), 5000);
    assert.equal(serviceFee(1000), 100);
  });
});

describe('priceItems', () => {
  const menu = new Map([
    ['burger', { name: 'Burger', price: 30000, options: [{ name: 'Cheese', price: 5000 }] }],
    ['cola', { name: 'Cola', price: 8000, isAvailable: false }],
  ]);

  it('uses server prices, ignores anything the client sends', () => {
    const items = priceItems([{ itemId: 'burger', qty: 2, options: ['Cheese'] }], menu);
    assert.equal(items[0].price, 35000);
    assert.deepEqual(computeTotals(items, 10000), {
      subtotal: 70000,
      deliveryFee: 10000,
      serviceFee: 3500,
      total: 83500,
    });
  });

  it('rejects unavailable items, unknown options and bad quantity', () => {
    assert.throws(() => priceItems([{ itemId: 'cola', qty: 1 }], menu), PricingError);
    assert.throws(() => priceItems([{ itemId: 'burger', qty: 1, options: ['Gold'] }], menu), PricingError);
    assert.throws(() => priceItems([{ itemId: 'burger', qty: 0 }], menu), PricingError);
    assert.throws(() => priceItems([], menu), PricingError);
  });
});

describe('isOpen (Tashkent time)', () => {
  it('handles normal and overnight hours', () => {
    const noonTashkent = new Date(Date.UTC(2026, 0, 1, 7, 0)); // 12:00 UTC+5
    assert.equal(isOpen('09:00', '23:00', noonTashkent), true);
    assert.equal(isOpen('18:00', '03:00', noonTashkent), false);
    const oneAm = new Date(Date.UTC(2026, 0, 1, 20, 0)); // 01:00 UTC+5
    assert.equal(isOpen('18:00', '03:00', oneAm), true);
  });
});

describe('route', () => {
  it('starts and ends at the given points', () => {
    const r = generateRoute({ lat: 41.3, lng: 69.2 }, { lat: 41.35, lng: 69.3 }, 10);
    assert.equal(r.length, 11);
    assert.deepEqual(r[0], { lat: 41.3, lng: 69.2 });
    assert.deepEqual(r[10], { lat: 41.35, lng: 69.3 });
  });

  it('eta is at least one minute', () => {
    assert.equal(etaMinutes(0, 3), 1);
    assert.equal(etaMinutes(40, 3), 2);
  });
});

describe('push texts', () => {
  it('are localized with uz fallback', () => {
    assert.equal(messageFor('cooking', 'ru')?.title, 'Готовится');
    assert.equal(messageFor('cooking', 'de')?.body, 'Buyurtmangiz tayyorlanmoqda');
    assert.equal(messageFor('created', 'uz'), null);
  });
});
