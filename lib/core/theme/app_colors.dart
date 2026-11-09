import 'package:material_ui/material_ui.dart';

/// Semantic colors that are not part of [ColorScheme].
/// Every color in the app is defined here or in `AppTheme` — never inline.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.rating,
    required this.success,
    required this.warning,
    required this.courier,
    required this.route,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.offlineBanner,
    required this.onOfflineBanner,
    required this.illustrationBackground,
  });

  static const brand = Color(0xFFFF6A13);

  static const light = AppColors(
    rating: Color(0xFFFFB300),
    success: Color(0xFF2E7D32),
    warning: Color(0xFFE65100),
    courier: Color(0xFF1565C0),
    route: Color(0xFFFF6A13),
    shimmerBase: Color(0xFFE6E6E6),
    shimmerHighlight: Color(0xFFF5F5F5),
    offlineBanner: Color(0xFF424242),
    onOfflineBanner: Color(0xFFFFFFFF),
    illustrationBackground: Color(0xFFFFF0E6),
  );

  static const dark = AppColors(
    rating: Color(0xFFFFCA28),
    success: Color(0xFF81C784),
    warning: Color(0xFFFFB74D),
    courier: Color(0xFF64B5F6),
    route: Color(0xFFFF8A4C),
    shimmerBase: Color(0xFF2A2A2A),
    shimmerHighlight: Color(0xFF3A3A3A),
    offlineBanner: Color(0xFFB00020),
    onOfflineBanner: Color(0xFFFFFFFF),
    illustrationBackground: Color(0xFF3A2A20),
  );

  final Color rating;
  final Color success;
  final Color warning;
  final Color courier;
  final Color route;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color offlineBanner;
  final Color onOfflineBanner;
  final Color illustrationBackground;

  @override
  AppColors copyWith({
    Color? rating,
    Color? success,
    Color? warning,
    Color? courier,
    Color? route,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? offlineBanner,
    Color? onOfflineBanner,
    Color? illustrationBackground,
  }) => AppColors(
    rating: rating ?? this.rating,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    courier: courier ?? this.courier,
    route: route ?? this.route,
    shimmerBase: shimmerBase ?? this.shimmerBase,
    shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    offlineBanner: offlineBanner ?? this.offlineBanner,
    onOfflineBanner: onOfflineBanner ?? this.onOfflineBanner,
    illustrationBackground: illustrationBackground ?? this.illustrationBackground,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      rating: Color.lerp(rating, other.rating, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      courier: Color.lerp(courier, other.courier, t)!,
      route: Color.lerp(route, other.route, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      offlineBanner: Color.lerp(offlineBanner, other.offlineBanner, t)!,
      onOfflineBanner: Color.lerp(onOfflineBanner, other.onOfflineBanner, t)!,
      illustrationBackground: Color.lerp(illustrationBackground, other.illustrationBackground, t)!,
    );
  }
}
