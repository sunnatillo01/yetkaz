import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/core/storage/hive_boxes.dart';
import 'package:food_delivery/features/home/data/models/home_models.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:food_delivery/features/restaurant/data/models/restaurant_model.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class HomeRemoteDataSource {
  HomeRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  /// Last documents of loaded pages, used for `startAfterDocument`, which
  /// also handles Firestore's implicit order-by on inequality fields.
  final Map<String, DocumentSnapshot<Map<String, dynamic>>> _cursorDocs = {};

  CollectionReference<Map<String, dynamic>> get _restaurants =>
      _firestore.collection('restaurants');

  Future<List<BannerModel>> getBanners() async {
    final s = await _firestore.collection('banners').where('isActive', isEqualTo: true).get();
    return s.docs.map((d) => BannerModel.fromJson({...d.data(), 'id': d.id})).toList();
  }

  Future<List<CategoryModel>> getCategories() async {
    final s = await _firestore.collection('categories').orderBy('order').get();
    return s.docs.map((d) => CategoryModel.fromJson({...d.data(), 'id': d.id})).toList();
  }

  Query<Map<String, dynamic>> _query(RestaurantFilter f) {
    Query<Map<String, dynamic>> q = _restaurants;
    if (f.categoryId != null) {
      q = q.where('categoryIds', arrayContains: f.categoryId);
    }
    if (f.topRated) q = q.where('rating', isGreaterThanOrEqualTo: 4.0);
    if (f.maxDeliveryFee != null) {
      q = q.where('deliveryFee', isLessThanOrEqualTo: f.maxDeliveryFee);
    }
    final sortField = f.sort == RestaurantSort.rating ? 'rating' : 'popularity';
    return q.orderBy(sortField, descending: true).orderBy(FieldPath.documentId);
  }

  /// [afterId] — id of the last restaurant of the previous page.
  Future<List<RestaurantModel>> getRestaurants({
    required RestaurantFilter filter,
    required int limit,
    String? afterId,
  }) async {
    var query = _query(filter).limit(limit);
    if (afterId != null) {
      final cursor = _cursorDocs[afterId];
      if (cursor == null) throw const NotFoundException();
      query = query.startAfterDocument(cursor);
    }
    final snapshot = await query.get();
    if (snapshot.docs.isNotEmpty) {
      final last = snapshot.docs.last;
      _cursorDocs[last.id] = last;
    }
    return snapshot.docs.map((d) => RestaurantModel.fromFirestore(d.id, d.data())).toList();
  }
}

/// Offline cache of the last loaded first page.
@lazySingleton
class HomeLocalDataSource {
  HomeLocalDataSource(@Named(HiveBoxes.cache) this._box);

  final Box<String> _box;
  static const _restaurantsKey = 'restaurants_first_page';

  Future<void> cacheRestaurants(List<RestaurantModel> items) =>
      _box.put(_restaurantsKey, jsonEncode(items.map((r) => r.toJson()).toList()));

  List<RestaurantModel> cachedRestaurants() {
    final raw = _box.get(_restaurantsKey);
    if (raw == null) throw const CacheException();
    return (jsonDecode(raw) as List<dynamic>)
        .map((e) => RestaurantModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
