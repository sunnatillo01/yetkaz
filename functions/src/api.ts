import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onRequest } from 'firebase-functions/v2/https';
import type { Request } from 'firebase-functions/v2/https';
import type { Response } from 'express';
import {
  computeTotals,
  isOpen,
  MenuItemDoc,
  priceItems,
  PricingError,
  RequestItem,
} from './pricing';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

class HttpError extends Error {
  constructor(public readonly status: number, public readonly code: string) {
    super(code);
  }
}

/** Verifies `Authorization: Bearer <Firebase ID token>`; 401 lets the app refresh. */
async function authenticate(req: Request): Promise<string> {
  const header = req.get('Authorization') ?? '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : '';
  if (!token) throw new HttpError(401, 'unauthenticated');
  try {
    const decoded = await getAuth().verifyIdToken(token);
    return decoded.uid;
  } catch {
    throw new HttpError(401, 'token_expired');
  }
}

interface CreateOrderBody {
  idempotencyKey: string;
  restaurantId: string;
  items: RequestItem[];
  address: Record<string, unknown>;
  paymentMethod: 'cash' | 'card';
  note?: string;
}

/**
 * Creates an order. Idempotent: the document id is the client-generated
 * idempotency key, so a retried request returns the same order instead of
 * creating a duplicate.
 */
async function createOrder(uid: string, body: CreateOrderBody): Promise<string> {
  const db = getFirestore();
  if (!UUID.test(body.idempotencyKey ?? '')) throw new HttpError(400, 'bad_idempotency_key');
  if (!['cash', 'card'].includes(body.paymentMethod)) throw new HttpError(400, 'bad_payment');
  const address = body.address ?? {};
  if (typeof address.lat !== 'number' || typeof address.lng !== 'number') {
    throw new HttpError(400, 'bad_address');
  }

  const orderRef = db.collection('orders').doc(body.idempotencyKey);
  const restaurantRef = db.collection('restaurants').doc(String(body.restaurantId));

  return db.runTransaction(async (tx) => {
    const existing = await tx.get(orderRef);
    if (existing.exists) {
      if (existing.get('userId') !== uid) throw new HttpError(409, 'conflict');
      return orderRef.id; // duplicate submit → same order
    }

    const restaurant = await tx.get(restaurantRef);
    if (!restaurant.exists) throw new HttpError(404, 'restaurant_not_found');
    const r = restaurant.data()!;
    if (!isOpen(r.openTime ?? '00:00', r.closeTime ?? '00:00', new Date())) {
      throw new HttpError(409, 'restaurant_closed');
    }

    const ids = [...new Set((body.items ?? []).map((i) => String(i.itemId)))];
    const menuDocs = await Promise.all(ids.map((id) => tx.get(restaurantRef.collection('menu').doc(id))));
    const menu = new Map<string, MenuItemDoc>();
    menuDocs.forEach((d) => d.exists && menu.set(d.id, d.data() as MenuItemDoc));

    let priced;
    try {
      priced = priceItems(body.items, menu);
    } catch (e) {
      if (e instanceof PricingError) throw new HttpError(422, e.code);
      throw e;
    }
    const totals = computeTotals(priced, r.deliveryFee ?? 0);
    if (totals.subtotal < (r.minOrder ?? 0)) throw new HttpError(422, 'below_min_order');

    const now = Timestamp.now();
    tx.create(orderRef, {
      userId: uid,
      restaurantId: restaurant.id,
      restaurantName: r.name,
      restaurantLocation: { lat: r.lat, lng: r.lng },
      items: priced,
      ...totals,
      address: {
        lat: address.lat,
        lng: address.lng,
        text: String(address.text ?? ''),
        title: String(address.title ?? 'other'),
        entrance: String(address.entrance ?? ''),
        floor: String(address.floor ?? ''),
        apartment: String(address.apartment ?? ''),
        note: String(address.note ?? ''),
      },
      paymentMethod: body.paymentMethod,
      note: String(body.note ?? '').slice(0, 300),
      status: 'created',
      statusHistory: [{ status: 'created', at: now }],
      route: [],
      etaMinutes: r.deliveryTimeMin ?? 30,
      pricedByServer: true,
      createdAt: FieldValue.serverTimestamp(),
    });
    return orderRef.id;
  });
}

/** Cancellation is allowed only while the order is still `created`. */
async function cancelOrder(uid: string, orderId: string): Promise<void> {
  const db = getFirestore();
  const ref = db.collection('orders').doc(String(orderId));
  await db.runTransaction(async (tx) => {
    const order = await tx.get(ref);
    if (!order.exists || order.get('userId') !== uid) throw new HttpError(404, 'not_found');
    if (order.get('status') !== 'created') throw new HttpError(409, 'not_cancellable');
    tx.update(ref, {
      status: 'cancelled',
      statusHistory: FieldValue.arrayUnion({ status: 'cancelled', at: Timestamp.now() }),
    });
  });
}

/** Single HTTPS entry point: `POST /createOrder`, `POST /cancelOrder`. */
export const api = onRequest(
  { region: 'europe-west1', cors: false, maxInstances: 10 },
  async (req: Request, res: Response) => {
    try {
      if (req.method !== 'POST') throw new HttpError(405, 'method_not_allowed');
      const uid = await authenticate(req);
      switch (req.path) {
        case '/createOrder': {
          const orderId = await createOrder(uid, req.body as CreateOrderBody);
          res.status(200).json({ orderId });
          return;
        }
        case '/cancelOrder':
          await cancelOrder(uid, req.body?.orderId);
          res.status(200).json({ ok: true });
          return;
        default:
          throw new HttpError(404, 'not_found');
      }
    } catch (e) {
      if (e instanceof HttpError) {
        res.status(e.status).json({ error: e.code });
        return;
      }
      logger.error('api error', e);
      res.status(500).json({ error: 'internal' });
    }
  },
);
