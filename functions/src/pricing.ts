/**
 * Pricing rules — must stay identical to `CartCalculator` in the Flutter app
 * (lib/features/cart/domain/entities/cart_totals.dart). All amounts are
 * integer so'm. The server never trusts totals sent by the client.
 */

export interface MenuOption {
  name: string;
  price: number;
}

export interface MenuItemDoc {
  name: string;
  price: number;
  imageUrl?: string;
  options?: MenuOption[];
  isAvailable?: boolean;
}

export interface RequestItem {
  itemId: string;
  qty: number;
  options?: string[];
}

export interface PricedItem {
  itemId: string;
  name: string;
  price: number; // unit price incl. options
  qty: number;
  options: MenuOption[];
  imageUrl: string;
}

export class PricingError extends Error {
  constructor(public readonly code: string) {
    super(code);
  }
}

/** 5% of subtotal, rounded half-up to the nearest 100 so'm. */
export function serviceFee(subtotal: number): number {
  if (subtotal <= 0) return 0;
  return Math.floor((subtotal * 5 + 5000) / 10000) * 100;
}

export function priceItems(
  items: RequestItem[],
  menu: Map<string, MenuItemDoc>,
): PricedItem[] {
  if (!Array.isArray(items) || items.length === 0) throw new PricingError('empty_cart');
  return items.map((req) => {
    const doc = menu.get(req.itemId);
    if (!doc || doc.isAvailable === false) throw new PricingError('item_unavailable');
    const qty = Math.trunc(req.qty);
    if (!Number.isFinite(qty) || qty < 1 || qty > 99) throw new PricingError('bad_quantity');
    const options = (req.options ?? []).map((name) => {
      const option = (doc.options ?? []).find((o) => o.name === name);
      if (!option) throw new PricingError('bad_option');
      return { name: option.name, price: Math.trunc(option.price) };
    });
    const unit = Math.trunc(doc.price) + options.reduce((s, o) => s + o.price, 0);
    return {
      itemId: req.itemId,
      name: doc.name,
      price: unit,
      qty,
      options,
      imageUrl: doc.imageUrl ?? '',
    };
  });
}

export interface Totals {
  subtotal: number;
  deliveryFee: number;
  serviceFee: number;
  total: number;
}

export function computeTotals(items: PricedItem[], deliveryFee: number): Totals {
  const subtotal = items.reduce((s, i) => s + i.price * i.qty, 0);
  const service = serviceFee(subtotal);
  const delivery = Math.trunc(deliveryFee);
  return { subtotal, deliveryFee: delivery, serviceFee: service, total: subtotal + delivery + service };
}

/** Minutes since midnight in Asia/Tashkent (UTC+5, no DST). */
export function tashkentMinutes(date: Date): number {
  const utcMinutes = date.getUTCHours() * 60 + date.getUTCMinutes();
  return (utcMinutes + 5 * 60) % (24 * 60);
}

/** Same rule as `Restaurant.isOpenAt` in the app (supports overnight hours). */
export function isOpen(openTime: string, closeTime: string, date: Date): boolean {
  const toMin = (hhmm: string) => {
    const [h, m] = hhmm.split(':').map(Number);
    return h * 60 + m;
  };
  const open = toMin(openTime);
  const close = toMin(closeTime);
  const now = tashkentMinutes(date);
  if (open === close) return true;
  if (open < close) return now >= open && now < close;
  return now >= open || now < close;
}
