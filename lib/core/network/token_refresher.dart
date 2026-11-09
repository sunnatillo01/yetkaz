/// Obtains a fresh auth token when the API answers 401.
///
/// Implemented in the auth feature on top of Firebase Auth.
abstract interface class TokenRefresher {
  /// Returns a new token, or `null` when the user is no longer signed in.
  Future<String?> refreshToken();
}
