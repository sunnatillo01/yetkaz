import { FieldValue, getFirestore, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { computeTotals, MenuItemDoc, priceItems } from './pricing';
import { etaMinutes, generateRoute, Point } from './route';

/** Seconds between courier position updates (the app animates over this). */
export const COURIER_INTERVAL_SEC = 3;
const ROUTE_STEPS = 30;
const COURIERS = [
  { name: 'Jasur', phone: '+998901112233' },
  { name: 'Aziz', phone: '+998935554433' },
  { name: 'Sardor', phone: '+998977778899' },
];

const sleep = (s: number) => new Promise((r) => setTimeout(r, s * 1000));

/**
 * Courier simulator. Moves the order through
 * created → accepted → cooking → on_the_way → delivered on a timer and
 * writes the courier position every 3 seconds. Stops if the user cancels.
 */
export const simulateCourier = onDocumentCreated(
  { document: 'orders/{orderId}', region: 'europe-west1', timeoutSeconds: 540, memory: '256MiB' },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const ref = snap.ref;
    const order = snap.data();

    // Orders written directly by a client are re-priced here: the client
    // total is never trusted.
    if (!order.pricedByServer) await reprice(ref, order);

    const advance = async (expected: string, next: string, extra: Record<string, unknown> = {}) => {
      const current = (await ref.get()).get('status');
      if (current !== expected) return false; // cancelled or changed manually
      await ref.update({
        status: next,
        statusHistory: FieldValue.arrayUnion({ status: next, at: Timestamp.now() }),
        ...extra,
      });
      return true;
    };

    const from: Point = order.restaurantLocation;
    const to: Point = { lat: order.address.lat, lng: order.address.lng };
    const route = generateRoute(from, to, ROUTE_STEPS);
    const courier = COURIERS[Math.floor(Math.random() * COURIERS.length)];

    await sleep(8);
    if (!(await advance('created', 'accepted', { route }))) return;
    await sleep(10);
    if (!(await advance('accepted', 'cooking'))) return;
    await sleep(15);
    if (
      !(await advance('cooking', 'on_the_way', {
        courier: { ...courier, ...from },
        etaMinutes: etaMinutes(route.length, COURIER_INTERVAL_SEC),
      }))
    ) {
      return;
    }

    for (let i = 1; i < route.length; i++) {
      await sleep(COURIER_INTERVAL_SEC);
      await ref.update({
        'courier.lat': route[i].lat,
        'courier.lng': route[i].lng,
        etaMinutes: etaMinutes(route.length - 1 - i, COURIER_INTERVAL_SEC),
      });
    }
    await advance('on_the_way', 'delivered', { etaMinutes: 0 });
    logger.info(`Order ${ref.id} delivered`);
  },
);

async function reprice(
  ref: FirebaseFirestore.DocumentReference,
  order: FirebaseFirestore.DocumentData,
): Promise<void> {
  const db = getFirestore();
  const restaurant = await db.collection('restaurants').doc(order.restaurantId).get();
  const menuSnap = await restaurant.ref.collection('menu').get();
  const menu = new Map<string, MenuItemDoc>(menuSnap.docs.map((d) => [d.id, d.data() as MenuItemDoc]));
  try {
    const items = priceItems(
      (order.items ?? []).map((i: { itemId: string; qty: number; options?: { name: string }[] }) => ({
        itemId: i.itemId,
        qty: i.qty,
        options: (i.options ?? []).map((o) => o.name),
      })),
      menu,
    );
    const r = restaurant.data() ?? {};
    await ref.update({
      items,
      ...computeTotals(items, r.deliveryFee ?? 0),
      restaurantName: r.name ?? '',
      restaurantLocation: { lat: r.lat, lng: r.lng },
      pricedByServer: true,
    });
  } catch (e) {
    logger.warn(`Order ${ref.id} rejected while repricing`, e);
    await ref.update({
      status: 'cancelled',
      statusHistory: FieldValue.arrayUnion({ status: 'cancelled', at: Timestamp.now() }),
    });
  }
}
