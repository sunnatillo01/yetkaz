import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

abstract interface class NetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get onStatusChange;
}

@LazySingleton(as: NetworkInfo)
class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this._connectivity);

  final Connectivity _connectivity;

  static bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> get isConnected async => _online(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged.map(_online).distinct();
}
