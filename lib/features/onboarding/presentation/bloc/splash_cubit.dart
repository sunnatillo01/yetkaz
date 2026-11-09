import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/auth/domain/usecases/auth_usecases.dart';
import 'package:food_delivery/features/settings/domain/usecases/settings_usecases.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'splash_cubit.freezed.dart';

enum SplashDestination { onboarding, login, profile, home }

@freezed
sealed class SplashState with _$SplashState {
  const factory SplashState.initial() = SplashInitial;
  const factory SplashState.loading() = SplashLoading;
  const factory SplashState.success(SplashDestination destination) = SplashSuccess;
  const factory SplashState.failure(Failure failure) = SplashFailure;
}

/// Shows the logo, checks the onboarding flag and the stored session/token,
/// then decides where to go.
@injectable
class SplashCubit extends Cubit<SplashState> {
  SplashCubit(this._getSettings, this._getCurrentSession) : super(const SplashState.initial());

  final GetSettings _getSettings;
  final GetCurrentSession _getCurrentSession;

  static const minDisplay = Duration(milliseconds: 700);

  Future<void> start() async {
    emit(const SplashState.loading());
    final (_, user) = await (Future<void>.delayed(minDisplay), _getCurrentSession()).wait;
    if (isClosed) return;
    final settings = _getSettings();
    final destination = switch (user) {
      _ when !settings.onboardingSeen || settings.language == null => SplashDestination.onboarding,
      null => SplashDestination.login,
      final u when !u.hasProfile => SplashDestination.profile,
      _ => SplashDestination.home,
    };
    emit(SplashState.success(destination));
  }
}
