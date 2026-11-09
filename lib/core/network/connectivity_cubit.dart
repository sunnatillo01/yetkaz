import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/network/network_info.dart';
import 'package:injectable/injectable.dart';

enum ConnectivityStatus { unknown, online, offline }

/// App-wide internet status; drives the "no internet" banner and
/// automatic refresh when the connection comes back.
@lazySingleton
class ConnectivityCubit extends Cubit<ConnectivityStatus> {
  ConnectivityCubit(this._networkInfo) : super(ConnectivityStatus.unknown) {
    unawaited(_init());
  }

  final NetworkInfo _networkInfo;
  StreamSubscription<bool>? _subscription;

  Future<void> _init() async {
    final connected = await _networkInfo.isConnected;
    if (isClosed) return;
    emit(connected ? ConnectivityStatus.online : ConnectivityStatus.offline);
    _subscription = _networkInfo.onStatusChange.listen(
      (online) => emit(online ? ConnectivityStatus.online : ConnectivityStatus.offline),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
