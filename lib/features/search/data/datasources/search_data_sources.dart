import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery/core/storage/hive_boxes.dart';
import 'package:food_delivery/features/restaurant/data/models/restaurant_model.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:injectable/injectable.dart';

/// Firestore has no full-text search, so the seed script stores a
/// `searchKeywords` array (lower-case prefixes of restaurant and dish
/// names). We query by the first word and filter the rest on the client.
@lazySingleton
class SearchRemoteDataSource {
  SearchRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  Future<List<RestaurantModel>> search(String normalizedQuery) async {
    final words = normalizedQuery.split(' ');
    final snapshot = await _firestore
        .collection('restaurants')
        .where('searchKeywords', arrayContains: words.first)
        .limit(30)
        .get();
    return snapshot.docs
        .where((d) {
          final keywords = List<String>.from(
            d.data()['searchKeywords'] as List<dynamic>? ?? const [],
          );
          return words.every((w) => keywords.any((k) => k.startsWith(w)));
        })
        .map((d) => RestaurantModel.fromFirestore(d.id, d.data()))
        .toList();
  }
}

@lazySingleton
class SearchHistoryDataSource {
  SearchHistoryDataSource(@Named(HiveBoxes.searchHistory) this._box);

  final Box<String> _box;
  static const _key = 'items';

  List<String> read() {
    final raw = _box.get(_key);
    if (raw == null) return [];
    return List<String>.from(jsonDecode(raw) as List<dynamic>);
  }

  Future<void> write(List<String> items) => _box.put(_key, jsonEncode(items));

  Future<void> clear() => _box.delete(_key);
}
