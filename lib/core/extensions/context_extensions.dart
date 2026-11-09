import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/l10n/gen/app_localizations.dart';
import 'package:food_delivery/core/theme/app_colors.dart';
import 'package:food_delivery/core/utils/money_formatter.dart';
import 'package:material_ui/material_ui.dart';

extension BuildContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;

  /// `45000` → `45 000 so'm` in the current language.
  String money(int amount) => l10n.currencySum(formatMoney(amount));

  void showSnack(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

extension FailureMessage on Failure {
  /// Human readable, localized message — never a technical one.
  String message(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    TimeoutFailure() => l10n.errorTimeout,
    ServerFailure() => l10n.errorServer,
    NotFoundFailure() => l10n.errorNotFound,
    CacheFailure() => l10n.errorCache,
    PermissionFailure() => l10n.errorPermission,
    UnknownFailure() => l10n.errorUnknown,
    AuthFailure(:final code) => switch (code) {
      AuthErrorCode.invalidCode => l10n.errorInvalidCode,
      AuthErrorCode.codeExpired => l10n.errorCodeExpired,
      AuthErrorCode.tooManyRequests => l10n.errorTooManyRequests,
      AuthErrorCode.invalidPhone => l10n.errorInvalidPhone,
      AuthErrorCode.sessionExpired => l10n.errorAuth,
      AuthErrorCode.unknown => l10n.errorUnknown,
    },
    BusinessFailure(:final code) => switch (code) {
      BusinessErrorCode.restaurantClosed => l10n.errorRestaurantClosed,
      BusinessErrorCode.belowMinOrder => l10n.errorMinOrder,
      BusinessErrorCode.notCancellable => l10n.errorOrderNotCancellable,
    },
    LocationFailure(:final code) => switch (code) {
      LocationErrorCode.serviceDisabled => l10n.locationServiceDisabled,
      LocationErrorCode.denied || LocationErrorCode.deniedForever => l10n.locationPermissionDenied,
    },
  };

  IconData get icon => switch (this) {
    NetworkFailure() => Icons.wifi_off_rounded,
    TimeoutFailure() => Icons.hourglass_empty_rounded,
    NotFoundFailure() => Icons.search_off_rounded,
    LocationFailure() => Icons.location_off_rounded,
    AuthFailure() => Icons.lock_outline_rounded,
    _ => Icons.error_outline_rounded,
  };
}
