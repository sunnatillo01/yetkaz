import 'package:food_delivery/core/network/token_refresher.dart';
import 'package:food_delivery/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:injectable/injectable.dart';

/// Forces Firebase to mint a new ID token (used after a 401).
@LazySingleton(as: TokenRefresher)
class FirebaseTokenRefresher implements TokenRefresher {
  FirebaseTokenRefresher(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Future<String?> refreshToken() => _remote.idToken(forceRefresh: true);
}
