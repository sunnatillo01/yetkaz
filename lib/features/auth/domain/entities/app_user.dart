import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String uid,
    required String phone,
    String? name,
    String? avatarUrl,
  }) = _AppUser;
  const AppUser._();

  /// A new user signs in with the phone first and enters the name after.
  bool get hasProfile => (name ?? '').trim().isNotEmpty;
}
