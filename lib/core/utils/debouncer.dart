import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:rxdart/rxdart.dart';

/// Delays [run] calls until [duration] passes without a new call.
class Debouncer {
  Debouncer(this.duration);

  final Duration duration;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  bool get isPending => _timer?.isActive ?? false;

  void cancel() => _timer?.cancel();

  void dispose() => cancel();
}

/// Bloc event transformer: debounce, then cancel the previous handler.
EventTransformer<E> debounceRestartable<E>(Duration duration) =>
    (events, mapper) => events.debounceTime(duration).switchMap(mapper);
