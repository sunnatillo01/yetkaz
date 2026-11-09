import 'package:food_delivery/core/entities/paginated_list.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/order_tracking/domain/repositories/order_repository.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

@injectable
class WatchOrder {
  const WatchOrder(this._repository);
  final OrderRepository _repository;

  Stream<Either<Failure, FoodOrder>> call(String orderId) => _repository.watchOrder(orderId);
}

@injectable
class CancelOrder implements UseCase<Unit, FoodOrder> {
  const CancelOrder(this._repository);
  final OrderRepository _repository;

  /// Checks the rule locally first; the server enforces it again.
  @override
  FutureEither<Unit> call(FoodOrder order) async {
    if (!order.canCancel) {
      return const Left(Failure.business(BusinessErrorCode.notCancellable));
    }
    return _repository.cancelOrder(order.id);
  }
}

class GetOrdersParams {
  const GetOrdersParams({required this.active, this.cursor, this.limit = 10});
  final bool active;
  final PageCursor? cursor;
  final int limit;
}

@injectable
class GetOrders implements UseCase<PaginatedList<FoodOrder>, GetOrdersParams> {
  const GetOrders(this._repository);
  final OrderRepository _repository;

  @override
  FutureEither<PaginatedList<FoodOrder>> call(GetOrdersParams p) =>
      _repository.getOrders(active: p.active, cursor: p.cursor, limit: p.limit);
}
