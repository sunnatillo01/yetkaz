import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/utils/phone_formatter.dart';
import 'package:food_delivery/core/utils/validators.dart';
import 'package:food_delivery/features/auth/domain/entities/phone_verification.dart';
import 'package:food_delivery/features/auth/domain/usecases/auth_usecases.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'phone_cubit.freezed.dart';

/// Arguments passed from the phone screen to the OTP screen.
@freezed
abstract class OtpArgs with _$OtpArgs {
  const factory OtpArgs({required String phone, required String verificationId, int? resendToken}) =
      _OtpArgs;
}

@freezed
sealed class PhoneState with _$PhoneState {
  const factory PhoneState.initial() = PhoneInitial;
  const factory PhoneState.loading() = PhoneLoading;
  const factory PhoneState.success(OtpArgs args) = PhoneSuccess;
  const factory PhoneState.failure(Failure failure) = PhoneFailure;
}

@injectable
class PhoneCubit extends Cubit<PhoneState> {
  PhoneCubit(this._sendOtp) : super(const PhoneState.initial());

  final SendOtp _sendOtp;
  StreamSubscription<PhoneVerification>? _subscription;

  /// [localDigits] — what the user typed after `+998`.
  Future<void> submit(String localDigits) async {
    if (state is PhoneLoading) return;
    if (!Validators.isValidPhone(localDigits)) {
      emit(const PhoneState.failure(Failure.auth(AuthErrorCode.invalidPhone)));
      return;
    }
    emit(const PhoneState.loading());
    final phone = PhoneUtils.toE164(localDigits);
    await _subscription?.cancel();
    _subscription = _sendOtp(phone).listen((event) {
      if (isClosed) return;
      switch (event) {
        case PhoneCodeSent(:final verificationId, :final resendToken):
          emit(
            PhoneState.success(
              OtpArgs(phone: phone, verificationId: verificationId, resendToken: resendToken),
            ),
          );
        case PhoneAutoVerified():
          // SessionCubit picks up the sign-in and the router redirects.
          emit(const PhoneState.initial());
        case PhoneVerificationFailed(:final failure):
          emit(PhoneState.failure(failure));
      }
    });
  }

  /// Called after navigation so returning to this screen is clean.
  void reset() => emit(const PhoneState.initial());

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
