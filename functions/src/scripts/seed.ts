/**
 * Seeds categories, banners, restaurants and menus.
 *
 *   # Emulator
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 GCLOUD_PROJECT=yetkaz-dev npm run seed
 *   # Real project (service account JSON, never committed)
 *   GOOGLE_APPLICATION_CREDENTIALS=./service-account.json npm run seed
 */
import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'yetkaz-dev' });
const db = getFirestore();

const img = (id: string, w = 800) => `https://images.unsplash.com/${id}?w=${w}&q=80&auto=format&fit=crop`;

const IMAGES = {
  pizza: 'photo-1513104890138-7c749659a591',
  pizza2: 'photo-1565299624946-b28f40a0ae38',
  burger: 'photo-1568901346375-23c9450c58cd',
  sushi: 'photo-1579871494447-9811cf80d66c',
  plov: 'photo-1504674900247-0877df9cc836',
  kebab: 'photo-1555939594-58d7cb561ad1',
  salad: 'photo-1512621776951-a57141f2eefd',
  bowl: 'photo-1546069901-ba9599a7e63c',
  dessert: 'photo-1551024601-bec78aea704b',
  food: 'photo-1540189549336-e6e99c3679fe',
};

const categories = [
  { id: 'pizza', order: 1, name: { uz: 'Pitsa', ru: 'Пицца', en: 'Pizza' }, icon: IMAGES.pizza },
  { id: 'burger', order: 2, name: { uz: 'Burger', ru: 'Бургеры', en: 'Burgers' }, icon: IMAGES.burger },
  { id: 'national', order: 3, name: { uz: 'Milliy taomlar', ru: 'Национальная', en: 'National' }, icon: IMAGES.plov },
  { id: 'sushi', order: 4, name: { uz: 'Sushi', ru: 'Суши', en: 'Sushi' }, icon: IMAGES.sushi },
  { id: 'dessert', order: 5, name: { uz: 'Shirinliklar', ru: 'Десерты', en: 'Desserts' }, icon: IMAGES.dessert },
  { id: 'healthy', order: 6, name: { uz: 'Sog‘lom', ru: 'Здоровое', en: 'Healthy' }, icon: IMAGES.salad },
];

type Dish = { section: string; name: string; description: string; price: number; image: string; options?: { name: string; price: number }[] };

const MENUS: Record<string, Dish[]> = {
  pizza: [
    { section: 'Pitsalar', name: 'Margarita', description: 'Pomidor sousi, motsarella, rayhon', price: 59000, image: IMAGES.pizza, options: [{ name: 'Qo‘shimcha pishloq', price: 8000 }, { name: 'Qalampir', price: 3000 }] },
    { section: 'Pitsalar', name: 'Pepperoni', description: 'Pepperoni, motsarella, pomidor sousi', price: 72000, image: IMAGES.pizza2, options: [{ name: 'Qo‘shimcha pishloq', price: 8000 }] },
    { section: 'Pitsalar', name: 'To‘rt pishloq', description: 'Motsarella, parmezan, chedder, dor-blyu', price: 79000, image: IMAGES.pizza },
    { section: 'Salatlar', name: 'Sezar', description: 'Tovuq, romen, parmezan, kruton', price: 42000, image: IMAGES.salad },
    { section: 'Ichimliklar', name: 'Limonad', description: 'Uy limonadi, 0.5 l', price: 15000, image: IMAGES.food },
  ],
  burger: [
    { section: 'Burgerlar', name: 'Klassik burger', description: 'Mol go‘shti, chedder, bodring, sous', price: 35000, image: IMAGES.burger, options: [{ name: 'Pishloq', price: 5000 }, { name: 'Bekon', price: 7000 }, { name: 'Jalapeno', price: 3000 }] },
    { section: 'Burgerlar', name: 'Dabl burger', description: 'Ikki kotlet, ikki pishloq', price: 52000, image: IMAGES.burger, options: [{ name: 'Bekon', price: 7000 }] },
    { section: 'Burgerlar', name: 'Chiken burger', description: 'Qarsildoq tovuq, salat, mayonez', price: 32000, image: IMAGES.burger },
    { section: 'Garnirlar', name: 'Kartoshka fri', description: 'Tuz va ketchup bilan', price: 15000, image: IMAGES.food },
    { section: 'Ichimliklar', name: 'Kola', description: '0.5 l', price: 9000, image: IMAGES.food },
  ],
  national: [
    { section: 'Asosiy taomlar', name: 'Toshkent oshi', description: 'Mol go‘shti, sabzi, guruch, bedana tuxum', price: 45000, image: IMAGES.plov, options: [{ name: 'Qazi', price: 15000 }, { name: 'Bedana tuxum', price: 4000 }] },
    { section: 'Asosiy taomlar', name: 'Lag‘mon', description: 'Qo‘lda cho‘zilgan lag‘mon, go‘sht, sabzavot', price: 38000, image: IMAGES.bowl },
    { section: 'Kaboblar', name: 'Qo‘y kabob', description: '2 six, piyoz va non bilan', price: 40000, image: IMAGES.kebab },
    { section: 'Kaboblar', name: 'Tovuq kabob', description: '2 six, sous bilan', price: 30000, image: IMAGES.kebab },
    { section: 'Salatlar', name: 'Achchiq-chuchuk', description: 'Pomidor, piyoz, qalampir', price: 15000, image: IMAGES.salad },
  ],
  sushi: [
    { section: 'Rollar', name: 'Filadelfiya', description: 'Losos, krem-pishloq, bodring, 8 dona', price: 89000, image: IMAGES.sushi, options: [{ name: 'Qo‘shimcha imbir', price: 3000 }] },
    { section: 'Rollar', name: 'Kaliforniya', description: 'Krab, avokado, tobiko, 8 dona', price: 75000, image: IMAGES.sushi },
    { section: 'Setlar', name: 'Set "Oila"', description: '32 dona, 4 xil rol', price: 249000, image: IMAGES.sushi },
    { section: 'Sho‘rvalar', name: 'Miso sho‘rva', description: 'Tofu, vakame, piyoz', price: 29000, image: IMAGES.bowl },
  ],
  dessert: [
    { section: 'Tortlar', name: 'Chizkeyk', description: 'Nyu-York chizkeyki', price: 32000, image: IMAGES.dessert },
    { section: 'Tortlar', name: 'Napoleon', description: 'Uy usulida', price: 28000, image: IMAGES.dessert },
    { section: 'Donutlar', name: 'Shokoladli donut', description: 'Belgiya shokoladi', price: 15000, image: IMAGES.dessert, options: [{ name: 'Sepma', price: 2000 }] },
  ],
  healthy: [
    { section: 'Boullar', name: 'Poke bo‘ul', description: 'Losos, guruch, avokado, edamame', price: 69000, image: IMAGES.bowl, options: [{ name: 'Qo‘shimcha losos', price: 20000 }] },
    { section: 'Boullar', name: 'Kinoa salat', description: 'Kinoa, sabzavotlar, limon sousi', price: 45000, image: IMAGES.salad },
    { section: 'Ichimliklar', name: 'Smuzi', description: 'Banan, qulupnay, yogurt', price: 25000, image: IMAGES.food },
  ],
};

const restaurants = [
  { id: 'napoli', name: 'Napoli Pizza', cat: ['pizza'], menu: 'pizza', image: IMAGES.pizza, rating: 4.7, time: 30, fee: 10000, min: 50000, open: '10:00', close: '23:00', lat: 41.3111, lng: 69.2797, pop: 950 },
  { id: 'pizza-house', name: 'Pizza House', cat: ['pizza', 'burger'], menu: 'pizza', image: IMAGES.pizza2, rating: 4.3, time: 40, fee: 0, min: 60000, open: '09:00', close: '02:00', lat: 41.2995, lng: 69.2401, pop: 720 },
  { id: 'burger-lab', name: 'Burger Lab', cat: ['burger'], menu: 'burger', image: IMAGES.burger, rating: 4.8, time: 25, fee: 8000, min: 40000, open: '10:00', close: '00:00', lat: 41.3264, lng: 69.2285, pop: 990 },
  { id: 'grill-city', name: 'Grill City', cat: ['burger', 'national'], menu: 'burger', image: IMAGES.kebab, rating: 3.9, time: 35, fee: 12000, min: 45000, open: '11:00', close: '23:00', lat: 41.2856, lng: 69.2034, pop: 410 },
  { id: 'besh-qozon', name: 'Besh Qozon', cat: ['national'], menu: 'national', image: IMAGES.plov, rating: 4.9, time: 35, fee: 10000, min: 40000, open: '07:00', close: '21:00', lat: 41.3369, lng: 69.2853, pop: 1000 },
  { id: 'rayhon', name: 'Rayhon', cat: ['national'], menu: 'national', image: IMAGES.kebab, rating: 4.5, time: 45, fee: 15000, min: 50000, open: '10:00', close: '23:30', lat: 41.3049, lng: 69.2686, pop: 680 },
  { id: 'chorsu-kabob', name: 'Chorsu Kabob', cat: ['national'], menu: 'national', image: IMAGES.kebab, rating: 4.1, time: 30, fee: 0, min: 35000, open: '09:00', close: '22:00', lat: 41.3265, lng: 69.2348, pop: 530 },
  { id: 'tokyo-roll', name: 'Tokyo Roll', cat: ['sushi'], menu: 'sushi', image: IMAGES.sushi, rating: 4.6, time: 50, fee: 15000, min: 90000, open: '11:00', close: '23:00', lat: 41.3172, lng: 69.2522, pop: 640 },
  { id: 'sakura', name: 'Sakura Sushi', cat: ['sushi', 'healthy'], menu: 'sushi', image: IMAGES.sushi, rating: 4.2, time: 55, fee: 10000, min: 80000, open: '12:00', close: '00:00', lat: 41.2912, lng: 69.2611, pop: 380 },
  { id: 'sweet-bakery', name: 'Sweet Bakery', cat: ['dessert'], menu: 'dessert', image: IMAGES.dessert, rating: 4.8, time: 25, fee: 0, min: 30000, open: '08:00', close: '22:00', lat: 41.3094, lng: 69.2878, pop: 590 },
  { id: 'green-bowl', name: 'Green Bowl', cat: ['healthy'], menu: 'healthy', image: IMAGES.bowl, rating: 4.4, time: 30, fee: 9000, min: 45000, open: '08:00', close: '21:00', lat: 41.3301, lng: 69.2717, pop: 470 },
  { id: 'night-food', name: 'Night Food', cat: ['burger', 'pizza'], menu: 'burger', image: IMAGES.food, rating: 3.8, time: 40, fee: 12000, min: 40000, open: '18:00', close: '05:00', lat: 41.2817, lng: 69.2431, pop: 300 },
];

/** Lower-case prefixes (min 2 chars) of every word of [texts]. */
export function keywords(...texts: string[]): string[] {
  const set = new Set<string>();
  for (const text of texts) {
    for (const word of text.toLowerCase().split(/[^\p{L}\p{N}‘’']+/u)) {
      for (let i = 2; i <= word.length; i++) set.add(word.slice(0, i));
    }
  }
  return [...set];
}

async function seed() {
  const batch = db.batch();
  for (const c of categories) {
    batch.set(db.collection('categories').doc(c.id), { name: c.name, iconUrl: img(c.icon, 200), order: c.order });
  }
  ['napoli', 'besh-qozon', 'burger-lab'].forEach((id, i) => {
    const r = restaurants.find((x) => x.id === id)!;
    batch.set(db.collection('banners').doc(`banner-${i + 1}`), {
      imageUrl: img(r.image, 1200), restaurantId: id, order: i + 1, isActive: true,
    });
  });
  await batch.commit();

  for (const r of restaurants) {
    const dishes = MENUS[r.menu];
    const sections = [...new Set(dishes.map((d) => d.section))];
    const ref = db.collection('restaurants').doc(r.id);
    await ref.set({
      name: r.name,
      imageUrl: img(r.image),
      categoryIds: r.cat,
      rating: r.rating,
      deliveryTimeMin: r.time,
      deliveryFee: r.fee,
      minOrder: r.min,
      openTime: r.open,
      closeTime: r.close,
      lat: r.lat,
      lng: r.lng,
      popularity: r.pop,
      searchKeywords: keywords(r.name, ...dishes.map((d) => d.name)),
    });
    const menuBatch = db.batch();
    dishes.forEach((d, i) => {
      menuBatch.set(ref.collection('menu').doc(`${r.id}-${i + 1}`), {
        section: d.section,
        sectionOrder: sections.indexOf(d.section),
        order: i,
        name: d.name,
        description: d.description,
        price: d.price,
        imageUrl: img(d.image, 400),
        options: d.options ?? [],
        isAvailable: true,
      });
    });
    await menuBatch.commit();
  }
  console.log(`Seeded ${categories.length} categories, ${restaurants.length} restaurants.`);
}

if (require.main === module) {
  seed().catch((e) => {
    console.error(e);
    process.exit(1);
  });
}
