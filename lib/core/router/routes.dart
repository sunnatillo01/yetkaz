/// All route paths in one place.
abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const phone = '/auth/phone';
  static const otp = '/auth/otp';
  static const name = '/auth/name';
  static const home = '/home';
  static const search = '/search';
  static const cart = '/cart';
  static const profile = '/profile';
  static const orders = '/profile/orders';
  static const addresses = '/profile/addresses';
  static const settings = '/settings';
  static const checkout = '/checkout';
  static const addressPick = '/address/pick';

  static String restaurant(String id) => '/restaurant/$id';
  static String order(String id) => '/order/$id';

  /// Routes reachable without signing in.
  static bool isPublic(String path) =>
      path == splash || path == onboarding || path.startsWith('/auth/');
}
