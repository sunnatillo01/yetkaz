import 'package:injectable/injectable.dart';

/// Injectable time source so time-dependent logic is testable.
@lazySingleton
class Clock {
  const Clock();
  DateTime now() => DateTime.now();
}
