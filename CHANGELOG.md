# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/), versiyalash: [SemVer](https://semver.org/).

## [1.0.0] - 2026-11-09

### Added
- Splash, onboarding (3 slayd) va birinchi ochilishda til tanlash.
- Telefon orqali kirish: mask, SMS kod, 60 s qayta yuborish taymeri, Android avtomatik o'qish, ism kiritish.
- Dio `AuthInterceptor`: token secure storage'dan, 401 bo'lsa yangilab so'rovni qaytaradi.
- Bosh sahifa: manzil, bannerlar, kategoriyalar, cheksiz scroll (10 tadan), pull-to-refresh, filtrlar, offline kesh.
- Qidiruv: 400 ms debounce, oxirgi 5 ta qidiruv tarixi.
- Restoran sahifasi: SliverAppBar, Hero, sticky tablar ↔ scroll, taom tafsilotlari, yopiq restoran holati.
- Savatcha (Hive): bitta restoran qoidasi, swipe bilan o'chirish, int summalar, minimal summa, badge.
- Checkout: xaritada manzil tanlash, reverse geocoding, "Mening joylashuvim", to'lov usuli, izoh, idempotent buyurtma.
- Real vaqtda kuzatish: stepper, silliq kuryer markeri, marshrut, ETA, bekor qilish, fon/qaytish lifecycle.
- Push bildirishnomalar va deep link (`yetkaz://order/<id>`, `https://yetkaz.app/order/<id>`).
- Profil: avatar, buyurtmalar tarixi, qayta buyurtma, saqlangan manzillar, hisobni o'chirish.
- Sozlamalar: til, mavzu, bildirishnomalar, versiya/flavor.
- Cloud Functions: `api` (createOrder/cancelOrder), `simulateCourier`, `notifyOrderStatus`, seed skripti.
- Firestore/Storage Security Rules va indekslar.
- dev/prod flavor'lar, GitHub Actions (CI + release APK).
