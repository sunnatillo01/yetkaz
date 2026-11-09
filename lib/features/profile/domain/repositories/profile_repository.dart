import 'package:food_delivery/core/usecase/usecase.dart';

enum AvatarSource { gallery, camera }

abstract interface class ProfileRepository {
  /// Picks an image, uploads it to Storage and updates the profile.
  /// Returns the new URL or `null` when the user cancelled picking.
  FutureEither<String?> changeAvatar(AvatarSource source);
}
