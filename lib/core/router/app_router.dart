import 'dart:async';

import 'package:food_delivery/core/router/app_shell.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/presentation/pages/address_pick_page.dart';
import 'package:food_delivery/features/address/presentation/pages/saved_addresses_page.dart';
import 'package:food_delivery/features/auth/presentation/bloc/phone_cubit.dart';
import 'package:food_delivery/features/auth/presentation/bloc/session_cubit.dart';
import 'package:food_delivery/features/auth/presentation/pages/name_page.dart';
import 'package:food_delivery/features/auth/presentation/pages/otp_page.dart';
import 'package:food_delivery/features/auth/presentation/pages/phone_page.dart';
import 'package:food_delivery/features/cart/presentation/pages/cart_page.dart';
import 'package:food_delivery/features/checkout/presentation/pages/checkout_page.dart';
import 'package:food_delivery/features/home/presentation/pages/home_page.dart';
import 'package:food_delivery/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:food_delivery/features/onboarding/presentation/pages/splash_page.dart';
import 'package:food_delivery/features/order_tracking/presentation/pages/order_tracking_page.dart';
import 'package:food_delivery/features/profile/presentation/pages/orders_history_page.dart';
import 'package:food_delivery/features/profile/presentation/pages/profile_page.dart';
import 'package:food_delivery/features/restaurant/presentation/pages/restaurant_page.dart';
import 'package:food_delivery/features/search/presentation/pages/search_page.dart';
import 'package:food_delivery/features/settings/presentation/pages/settings_page.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Rebuilds router redirects whenever the session changes.
class _SessionListenable extends ChangeNotifier {
  _SessionListenable(Stream<SessionState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<SessionState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

/// Maps `yetkaz://order/123` (host = "order") to the in-app path.
String? normalizeDeepLink(Uri uri) {
  if (uri.scheme == 'yetkaz' && uri.host.isNotEmpty) {
    return '/${uri.host}${uri.path}';
  }
  return null;
}

/// Pure redirect logic — unit tested without widgets.
String? resolveRedirect({required SessionState session, required Uri uri}) {
  final deepLink = normalizeDeepLink(uri);
  if (deepLink != null) return deepLink;

  final path = uri.path;
  final from = uri.queryParameters['from'];
  String withFrom(String target, String? origin) => origin == null || origin.isEmpty
      ? target
      : Uri(path: target, queryParameters: {'from': origin}).toString();

  if (session is SessionInitial) {
    return path == Routes.splash ? null : withFrom(Routes.splash, uri.toString());
  }
  if (path == Routes.splash || path == Routes.onboarding) return null;

  switch (session) {
    case SessionProfileRequired():
      return path == Routes.name ? null : withFrom(Routes.name, from);
    case SessionUnauthenticated():
      if (path == Routes.name) return Routes.phone;
      if (Routes.isPublic(path)) return null;
      // Remember where the user wanted to go and return after login.
      return withFrom(Routes.phone, uri.toString());
    case SessionAuthenticated():
      if (path.startsWith('/auth/')) return from ?? Routes.home;
      return null;
    case SessionInitial():
      return null;
  }
}

GoRouter createRouter({
  required SessionCubit session,
  String initialLocation = Routes.splash,
  List<NavigatorObserver> observers = const [],
}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    observers: observers,
    refreshListenable: _SessionListenable(session.stream),
    redirect: (context, state) => resolveRedirect(session: session.state, uri: state.uri),
    onException: (context, state, router) => router.go(normalizeDeepLink(state.uri) ?? Routes.home),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, state) => SplashPage(from: state.uri.queryParameters['from']),
      ),
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingPage()),
      GoRoute(
        path: Routes.phone,
        builder: (_, state) => PhonePage(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: Routes.otp,
        redirect: (_, state) => state.extra is OtpArgs ? null : Routes.phone,
        builder: (_, state) => OtpPage(args: state.extra! as OtpArgs),
      ),
      GoRoute(path: Routes.name, builder: (_, _) => const NamePage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomePage()),
              // In the home branch so the Hero image animates from the list.
              GoRoute(
                path: '/restaurant/:id',
                builder: (_, state) => RestaurantPage(restaurantId: state.pathParameters['id']!),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.search, builder: (_, _) => const SearchPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.cart, builder: (_, _) => const CartPage())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfilePage(),
                routes: [
                  GoRoute(path: 'orders', builder: (_, _) => const OrdersHistoryPage()),
                  GoRoute(
                    path: 'addresses',
                    builder: (_, state) =>
                        SavedAddressesPage(selectMode: state.uri.queryParameters['select'] == '1'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.checkout,
        builder: (_, _) => const CheckoutPage(),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.addressPick,
        builder: (_, state) => AddressPickPage(initial: state.extra as Address?),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: '/order/:id',
        builder: (_, state) => OrderTrackingPage(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        parentNavigatorKey: rootKey,
        path: Routes.settings,
        builder: (_, _) => const SettingsPage(),
      ),
    ],
  );
}
