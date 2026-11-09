import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/order_tracking/data/models/order_model.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:injectable/injectable.dart';

/// HTTPS Cloud Functions called through Dio (token added by interceptor).
@lazySingleton
class OrderApi {
  OrderApi(this._dio);

  final Dio _dio;

  Future<String> createOrder(OrderRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/createOrder',
      data: orderRequestToJson(request),
    );
    return response.data!['orderId'] as String;
  }

  Future<void> cancelOrder(String orderId) =>
      _dio.post<void>('/cancelOrder', data: {'orderId': orderId});
}

@lazySingleton
class OrderFirestoreDataSource {
  OrderFirestoreDataSource(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _orders => _firestore.collection('orders');

  /// `includeMetadataChanges: false` — only real data updates.
  Stream<OrderModel> watch(String id) => _orders.doc(id).snapshots().map((doc) {
    final data = doc.data();
    if (!doc.exists || data == null) throw const NotFoundException();
    return OrderModel.fromFirestore(doc.id, data);
  });

  static const activeStatuses = ['created', 'accepted', 'cooking', 'on_the_way'];
  static const finishedStatuses = ['delivered', 'cancelled'];

  Future<List<OrderModel>> getOrders({
    required bool active,
    required int limit,
    List<Object?>? startAfter,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException(AuthErrorCode.sessionExpired);
    var query = _orders
        .where('userId', isEqualTo: uid)
        .where('status', whereIn: active ? activeStatuses : finishedStatuses)
        .orderBy('createdAt', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit);
    if (startAfter != null) query = query.startAfter(startAfter);
    final snapshot = await query.get();
    return snapshot.docs.map((d) => OrderModel.fromFirestore(d.id, d.data())).toList();
  }
}
