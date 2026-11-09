import 'package:food_delivery/core/error/failures.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'phone_verification.freezed.dart';

/// Events of the phone verification flow.
@freezed
sealed class PhoneVerification with _$PhoneVerification {
  /// SMS was sent; the user has to type the code.
  const factory PhoneVerification.codeSent({required String verificationId, int? resendToken}) =
      PhoneCodeSent;

  /// Android read the SMS automatically and the user is already signed in.
  const factory PhoneVerification.autoVerified() = PhoneAutoVerified;

  const factory PhoneVerification.failed(Failure failure) = PhoneVerificationFailed;
}
