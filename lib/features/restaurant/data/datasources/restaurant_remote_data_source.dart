import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/features/restaurant/data/models/restaurant_model.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class RestaurantRemoteDataSource {
  RestaurantRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _restaurants =>
      _firestore.collection('restaurants');

  Future<RestaurantModel> getRestaurant(String id) async {
    final doc = await _restaurants.doc(id).get();
    final data = doc.data();
    if (!doc.exists || data == null) throw const NotFoundException();
    return RestaurantModel.fromFirestore(doc.id, data);
  }

  Future<List<MenuItemModel>> getMenu(String restaurantId) async {
    final snapshot = await _restaurants.doc(restaurantId).collection('menu').get();
    return snapshot.docs.map((d) => MenuItemModel.fromFirestore(d.id, d.data())).toList();
  }
}
