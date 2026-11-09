import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/auth/domain/entities/app_user.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';

const tUser = AppUser(uid: 'u1', phone: '+998901234567', name: 'Ali');
const tNewUser = AppUser(uid: 'u1', phone: '+998901234567');

Restaurant tRestaurant({
  String id = 'r1',
  int deliveryFee = 10000,
  int minOrder = 50000,
  String open = '09:00',
  String close = '23:00',
  double rating = 4.5,
  List<String> categories = const ['pizza'],
  Coordinates location = const Coordinates(lat: 41.31, lng: 69.27),
}) => Restaurant(
  id: id,
  name: 'Restaurant $id',
  imageUrl: 'https://example.com/$id.jpg',
  categoryIds: categories,
  rating: rating,
  deliveryTimeMin: 30,
  deliveryFee: deliveryFee,
  minOrder: minOrder,
  openTime: open,
  closeTime: close,
  location: location,
);

const tCheese = MenuOption(name: 'Cheese', price: 5000);

const tMenuItem = MenuItem(
  id: 'm1',
  section: 'Burgers',
  name: 'Burger',
  description: 'Tasty',
  price: 30000,
  imageUrl: 'https://example.com/m1.jpg',
  options: [tCheese],
);

const tCartRestaurant = CartRestaurant(
  id: 'r1',
  name: 'Restaurant r1',
  deliveryFee: 10000,
  minOrder: 50000,
);

CartItem tCartItem({
  String id = 'm1',
  int price = 30000,
  int qty = 1,
  List<MenuOption> options = const [],
}) => CartItem(
  menuItemId: id,
  name: 'Dish $id',
  imageUrl: '',
  basePrice: price,
  quantity: qty,
  options: options,
);

const tAddress = Address(
  id: 'a1',
  location: Coordinates(lat: 41.33, lng: 69.29),
  text: 'Amir Temur 1',
  label: AddressLabel.home,
);

const tCategory = Category(
  id: 'pizza',
  names: {'uz': 'Pitsa', 'ru': 'Пицца', 'en': 'Pizza'},
  iconUrl: '',
);

const tBanner = PromoBanner(id: 'b1', imageUrl: '', restaurantId: 'r1');

FoodOrder tOrder({
  String id = 'order-123456',
  OrderStatus status = OrderStatus.created,
  Courier? courier,
}) => FoodOrder(
  id: id,
  userId: 'u1',
  restaurantId: 'r1',
  restaurantName: 'Restaurant r1',
  restaurantLocation: const Coordinates(lat: 41.31, lng: 69.27),
  items: const [
    OrderItem(itemId: 'm1', name: 'Burger', price: 35000, qty: 2, options: [tCheese]),
  ],
  subtotal: 70000,
  deliveryFee: 10000,
  serviceFee: 3500,
  total: 83500,
  address: tAddress,
  paymentMethod: PaymentMethod.cash,
  status: status,
  createdAt: DateTime(2026, 11, 9, 12),
  courier: courier,
);
