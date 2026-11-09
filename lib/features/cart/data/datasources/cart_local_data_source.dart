import 'dart:convert';

import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/core/storage/hive_boxes.dart';
import 'package:food_delivery/features/cart/data/models/cart_model.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class CartLocalDataSource {
  CartLocalDataSource(@Named(HiveBoxes.cart) this._box);

  final Box<String> _box;
  static const _key = 'current';

  CartModel read() {
    final raw = _box.get(_key);
    if (raw == null) return const CartModel();
    try {
      return CartModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      throw const CacheException();
    }
  }

  Future<void> write(CartModel cart) => _box.put(_key, jsonEncode(cart.toJson()));

  Future<void> clear() => _box.delete(_key);
}
