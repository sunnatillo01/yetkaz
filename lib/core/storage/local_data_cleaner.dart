import 'package:food_delivery/core/storage/hive_boxes.dart';
import 'package:food_delivery/core/storage/token_storage.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:injectable/injectable.dart';

/// Wipes every piece of user data stored on the device (used on logout and
/// account deletion). Device preferences (language, theme) are kept.
@lazySingleton
class LocalDataCleaner {
  LocalDataCleaner(this._tokenStorage);

  final TokenStorage _tokenStorage;

  Future<void> clearUserData() async {
    await _tokenStorage.clear();
    for (final name in HiveBoxes.userScoped) {
      if (Hive.isBoxOpen(name)) await Hive.box<String>(name).clear();
    }
  }
}
