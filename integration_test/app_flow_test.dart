// Full user flow against the Firebase Emulator Suite:
// login → restaurant → add to cart → place order → tracking.
//
//   firebase emulators:start --project yetkaz-dev
//   (cd functions && FIRESTORE_EMULATOR_HOST=localhost:8080 npm run seed)
//   flutter test integration_test --flavor dev \
//     --dart-define-from-file=env/dev.json \
//     --dart-define=USE_FIREBASE_EMULATOR=true \
//     --dart-define=FUNCTIONS_BASE_URL=http://10.0.2.2:5001/yetkaz-dev/europe-west1/api
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/bootstrap.dart';
import 'package:food_delivery/core/config/app_config.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/presentation/bloc/address_cubits.dart';
import 'package:food_delivery/features/home/presentation/widgets/restaurant_card.dart';
import 'package:food_delivery/features/order_tracking/presentation/widgets/order_widgets.dart';
import 'package:food_delivery/features/restaurant/presentation/widgets/menu_item_card.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: 'yetkaz-dev');
const _emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
const _testPhoneLocal = '901234567';

/// The Auth emulator exposes sent SMS codes over REST.
Future<String> _latestSmsCode() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.parse('http://$_emulatorHost:9099/emulator/v1/projects/$_projectId/verificationCodes'),
    );
    final response = await request.close();
    final body = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
    final codes = (body['verificationCodes'] as List<dynamic>).cast<Map<String, dynamic>>();
    return codes.last['code'] as String;
  } finally {
    client.close();
  }
}

extension on WidgetTester {
  /// `pumpAndSettle` never settles with shimmer animations, so poll instead.
  Future<void> pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await pump(const Duration(milliseconds: 200));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Timed out waiting for $finder');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('new user signs in, orders and tracks the courier', (tester) async {
    await bootstrap(Flavor.dev);
    await tester.pump();

    // Onboarding: language + 3 slides.
    final next = find.byKey(const Key('onboarding_next'));
    await tester.pumpUntilFound(next);
    for (var i = 0; i < 4; i++) {
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 400));
    }

    // Phone → OTP (code read from the emulator) → name.
    await tester.pumpUntilFound(find.byKey(const Key('phone_field')));
    await tester.enterText(find.byKey(const Key('phone_field')), _testPhoneLocal);
    await tester.tap(find.byKey(const Key('phone_submit')));
    await tester.pumpUntilFound(find.byKey(const Key('otp_field')));
    await tester.enterText(find.byKey(const Key('otp_field')), await _latestSmsCode());
    await tester.pumpUntilFound(find.byKey(const Key('name_field')));
    await tester.enterText(find.byKey(const Key('name_field')), 'Test');
    await tester.testTextInput.receiveAction(TextInputAction.done);

    // Map interaction is out of scope: select a delivery address directly.
    await getIt<CurrentAddressCubit>().select(
      const Address(location: Coordinates(lat: 41.3111, lng: 69.2797), text: 'Amir Temur 1'),
    );

    // Home → first restaurant → add dishes until the minimum order is reached.
    await tester.pumpUntilFound(find.byType(RestaurantCard));
    await tester.tap(find.byType(RestaurantCard).first);
    await tester.pumpUntilFound(find.byType(MenuItemCard));
    final add = find.descendant(
      of: find.byType(MenuItemCard).first,
      matching: find.byIcon(Icons.add_rounded),
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(add);
      await tester.pump(const Duration(milliseconds: 300));
      // Dishes with extras open a sheet — confirm it.
      final sheetButton = find.textContaining('·');
      if (sheetButton.evaluate().isNotEmpty) {
        await tester.tap(sheetButton.last);
        await tester.pump(const Duration(milliseconds: 300));
      }
    }

    // Cart → checkout → place order.
    await tester.tap(find.byIcon(Icons.shopping_bag_outlined).last);
    await tester.pumpUntilFound(find.byKey(const Key('cart_checkout')));
    await tester.tap(find.byKey(const Key('cart_checkout')));
    await tester.pumpUntilFound(find.byKey(const Key('place_order')));
    await tester.tap(find.byKey(const Key('place_order')));

    // Tracking screen receives real-time status from Firestore.
    await tester.pumpUntilFound(find.textContaining('#'), timeout: const Duration(seconds: 40));
    expect(find.byType(OrderStatusStepper), findsOneWidget);
  });
}
