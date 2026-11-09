import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Names of the Hive boxes used by the app. Values are stored as JSON
/// strings / primitives so no type adapters are required.
abstract final class HiveBoxes {
  static const settings = 'settings';
  static const cart = 'cart';
  static const searchHistory = 'search_history';
  static const cache = 'cache';
  static const address = 'address';

  /// Boxes that contain user data and must be wiped on logout.
  static const List<String> userScoped = [cart, searchHistory, cache, address];

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<dynamic>(settings),
      Hive.openBox<String>(cart),
      Hive.openBox<String>(searchHistory),
      Hive.openBox<String>(cache),
      Hive.openBox<String>(address),
    ]);
  }
}
