import 'package:food_delivery/core/firebase/json_converters.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// `users/{uid}` document.
@freezed
abstract class UserModel with _$UserModel {
  const factory UserModel({
    required String name,
    required String phone,
    String? avatarUrl,
    String? fcmToken,
    String? language,
    @Default(true) bool notificationsEnabled,
    @TimestampConverter() DateTime? createdAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}
