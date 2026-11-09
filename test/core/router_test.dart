import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/router/app_router.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/features/auth/presentation/bloc/session_cubit.dart';

import '../helpers/fixtures.dart';

void main() {
  String? redirect(SessionState s, String location) =>
      resolveRedirect(session: s, uri: Uri.parse(location));

  test('unknown session goes through splash and keeps the target', () {
    expect(redirect(const SessionState.initial(), '/order/1'), '/splash?from=%2Forder%2F1');
    expect(redirect(const SessionState.initial(), Routes.splash), isNull);
  });

  test('guest opening a protected route is sent to login with "from"', () {
    expect(
      redirect(const SessionState.unauthenticated(), '/order/42'),
      '/auth/phone?from=%2Forder%2F42',
    );
    expect(redirect(const SessionState.unauthenticated(), Routes.phone), isNull);
  });

  test('after login the user returns to the original location', () {
    expect(
      redirect(const SessionState.authenticated(tUser), '/auth/otp?from=%2Forder%2F42'),
      '/order/42',
    );
    expect(redirect(const SessionState.authenticated(tUser), Routes.phone), Routes.home);
    expect(redirect(const SessionState.authenticated(tUser), Routes.cart), isNull);
  });

  test('new user must enter the name first, "from" is preserved', () {
    expect(
      redirect(const SessionState.profileRequired(tNewUser), '/auth/otp?from=%2Fcart'),
      '/auth/name?from=%2Fcart',
    );
    expect(redirect(const SessionState.profileRequired(tNewUser), Routes.name), isNull);
  });

  test('custom scheme deep link is normalized', () {
    expect(normalizeDeepLink(Uri.parse('yetkaz://order/123')), '/order/123');
    expect(normalizeDeepLink(Uri.parse('https://yetkaz.app/order/123')), isNull);
    expect(redirect(const SessionState.authenticated(tUser), 'yetkaz://order/123'), '/order/123');
  });
}
