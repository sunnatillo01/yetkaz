import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/profile/domain/repositories/profile_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class ProfileRemoteDataSource {
  ProfileRemoteDataSource(this._auth, this._firestore, this._storage, this._picker);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final ImagePicker _picker;

  Future<String?> changeAvatar(AvatarSource source) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(AuthErrorCode.sessionExpired);

    // Downscale on device: smaller upload, faster loading everywhere.
    final file = await _picker.pickImage(
      source: source == AvatarSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (file == null) return null;

    final ref = _storage.ref('avatars/${user.uid}.jpg');
    await ref.putData(await file.readAsBytes(), SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();

    await _firestore.collection('users').doc(user.uid).set({
      'avatarUrl': url,
    }, SetOptions(merge: true));
    await user.updatePhotoURL(url);
    await user.reload();
    return url;
  }
}
