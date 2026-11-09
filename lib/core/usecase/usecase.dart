import 'package:food_delivery/core/error/failures.dart';
import 'package:fpdart/fpdart.dart';

typedef FutureEither<T> = Future<Either<Failure, T>>;

/// Base contract for every use case: one public `call` method.
abstract interface class UseCase<T, Params> {
  FutureEither<T> call(Params params);
}

class NoParams {
  const NoParams();
}
