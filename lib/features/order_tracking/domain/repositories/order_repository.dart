import 'package:food_delivery/core/entities/paginated_list.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:fpdart/fpdart.dart';

abstract interface class OrderRepository {
  /// Returns the id of the created order. Idempotent by
  /// [OrderRequest.idempotencyKey]: retries never create a duplicate.
  FutureEither<String> createOrder(OrderRequest request);

  /// Real-time updates of a single order (Firestore snapshots).
  Stream<Either<Failure, FoodOrder>> watchOrder(String id);

  FutureEither<Unit> cancelOrder(String id);

  FutureEither<PaginatedList<FoodOrder>> getOrders({
    required bool active,
    PageCursor? cursor,
    int limit = 10,
  });
}
