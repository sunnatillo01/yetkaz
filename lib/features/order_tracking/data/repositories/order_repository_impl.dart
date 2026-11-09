import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:food_delivery/core/entities/paginated_list.dart';
import 'package:food_delivery/core/error/exception_mapper.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/order_tracking/data/datasources/order_data_sources.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/order_tracking/domain/repositories/order_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: OrderRepository)
class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl(this._api, this._firestore);

  final OrderApi _api;
  final OrderFirestoreDataSource _firestore;

  @override
  FutureEither<String> createOrder(OrderRequest request) => guard(() => _api.createOrder(request));

  @override
  Stream<Either<Failure, FoodOrder>> watchOrder(String id) =>
      eitherStream(() => _firestore.watch(id).map((m) => m.toEntity()));

  @override
  FutureEither<Unit> cancelOrder(String id) => guard(() async {
    await _api.cancelOrder(id);
    return unit;
  });

  @override
  FutureEither<PaginatedList<FoodOrder>> getOrders({
    required bool active,
    PageCursor? cursor,
    int limit = 10,
  }) => guard(() async {
    final models = await _firestore.getOrders(
      active: active,
      limit: limit,
      startAfter: cursor?.values,
    );
    final last = models.lastOrNull;
    return PaginatedList(
      items: models.map((m) => m.toEntity()).toList(),
      hasMore: models.length == limit,
      nextCursor: last == null
          ? null
          : PageCursor([Timestamp.fromDate(last.createdAt ?? DateTime.now()), last.id]),
    );
  });
}
