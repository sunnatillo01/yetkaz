import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_delivery/features/auth/data/models/user_model.dart';
import 'package:food_delivery/features/auth/domain/entities/phone_verification.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  User? get currentUser => _auth.currentUser;

  /// `userChanges` also fires on displayName / photoURL updates.
  Stream<User?> userChanges() => _auth.userChanges();

  /// Wraps the callback based Firebase API into a stream.
  /// Errors are delivered as stream errors.
  Stream<PhoneVerification> verifyPhone(String phone, {int? resendToken}) {
    final controller = StreamController<PhoneVerification>();
    unawaited(
      _auth
          .verifyPhoneNumber(
            phoneNumber: phone,
            forceResendingToken: resendToken,
            timeout: const Duration(seconds: 60),
            verificationCompleted: (credential) async {
              // Android auto-retrieval: sign in without typing the code.
              try {
                await _auth.signInWithCredential(credential);
                controller.add(const PhoneVerification.autoVerified());
              } on Object catch (e, s) {
                controller.addError(e, s);
              }
            },
            verificationFailed: controller.addError,
            codeSent: (id, token) =>
                controller.add(PhoneVerification.codeSent(verificationId: id, resendToken: token)),
            codeAutoRetrievalTimeout: (_) {},
          )
          .catchError(controller.addError),
    );
    return controller.stream;
  }

  Future<User> signInWithCode(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user!;
  }

  Future<User> createProfile(String name) async {
    final user = _auth.currentUser!;
    final model = UserModel(name: name, phone: user.phoneNumber ?? '', createdAt: DateTime.now());
    await _userDoc(user.uid).set(model.toJson(), SetOptions(merge: true));
    await user.updateDisplayName(name);
    await user.reload();
    return _auth.currentUser!;
  }

  Future<String?> idToken({bool forceRefresh = false}) async =>
      _auth.currentUser?.getIdToken(forceRefresh);

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _userDoc(user.uid).delete();
    await user.delete();
  }
}
