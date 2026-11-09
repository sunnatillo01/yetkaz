import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/auth/domain/entities/app_user.dart';
import 'package:food_delivery/features/auth/domain/entities/phone_verification.dart';
import 'package:food_delivery/features/auth/domain/usecases/auth_usecases.dart';
import 'package:food_delivery/features/auth/presentation/bloc/phone_cubit.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'otp_cubit.freezed.dart';

@freezed
sealed class OtpState with _$OtpState {
  const factory OtpState.initial() = OtpInitial;
  const factory OtpState.loading() = OtpLoading;
  const factory OtpState.success(AppUser user) = OtpSuccess;
  const factory OtpState.failure(Failure failure) = OtpFailure;
}

@injectable
class OtpCubit extends Cubit<OtpState> {
  OtpCubit(this._verifyOtp, this._sendOtp) : super(const OtpState.initial());

  final VerifyOtp _verifyOtp;
  final SendOtp _sendOtp;
  late OtpArgs _args;
  StreamSubscription<PhoneVerification>? _resendSubscription;

  OtpArgs get args => _args;

  // ignore: use_setters_to_change_properties
  void init(OtpArgs args) => _args = args;

  Future<void> verify(String code) async {
    if (state is OtpLoading) return;
    emit(const OtpState.loading());
    final result = await _verifyOtp(
      VerifyOtpParams(verificationId: _args.verificationId, code: code),
    );
    if (isClosed) return;
    emit(result.fold(OtpState.failure, OtpState.success));
  }

  /// Requests a new SMS using the resend token from the previous request.
  Future<void> resend() async {
    await _resendSubscription?.cancel();
    _resendSubscription = _sendOtp(_args.phone, resendToken: _args.resendToken).listen((event) {
      if (isClosed) return;
      switch (event) {
        case PhoneCodeSent(:final verificationId, :final resendToken):
          _args = _args.copyWith(verificationId: verificationId, resendToken: resendToken);
          emit(const OtpState.initial());
        case PhoneAutoVerified():
          break;
        case PhoneVerificationFailed(:final failure):
          emit(OtpState.failure(failure));
      }
    });
  }

  @override
  Future<void> close() async {
    await _resendSubscription?.cancel();
    return super.close();
  }
}

/// 60-second countdown before the code can be re-sent.
@injectable
class ResendTimerCubit extends Cubit<int> {
  ResendTimerCubit() : super(0);

  static const duration = 60;
  Timer? _timer;

  void start([int seconds = duration]) {
    _timer?.cancel();
    emit(seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state <= 1) {
        timer.cancel();
        emit(0);
      } else {
        emit(state - 1);
      }
    });
  }

  bool get canResend => state == 0;

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
