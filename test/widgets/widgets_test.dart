import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/network/connectivity_cubit.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/core/widgets/no_internet_banner.dart';
import 'package:food_delivery/core/widgets/state_views.dart';
import 'package:food_delivery/features/auth/presentation/bloc/phone_cubit.dart';
import 'package:food_delivery/features/auth/presentation/pages/phone_page.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/cart/domain/entities/cart_totals.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:food_delivery/features/cart/presentation/pages/cart_page.dart';
import 'package:food_delivery/features/home/presentation/widgets/restaurant_card.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/order_tracking/presentation/widgets/order_widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';
import '../helpers/pump_app.dart';

class _MockPhoneCubit extends MockCubit<PhoneState> implements PhoneCubit;

void main() {
  final l10n = uzL10n;

  group('state views', () {
    testWidgets('ErrorView shows a human message and retries', (tester) async {
      var retried = 0;
      await tester.pumpApp(
        Scaffold(
          body: ErrorView(failure: const Failure.network(), onRetry: () => retried++),
        ),
      );
      expect(find.text(l10n.errorNetwork), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      await tester.tap(find.text(l10n.retry));
      expect(retried, 1);
    });

    testWidgets('EmptyView shows text and action', (tester) async {
      var tapped = false;
      await tester.pumpApp(
        Scaffold(
          body: EmptyView(
            icon: Icons.shopping_bag_outlined,
            title: l10n.cartEmpty,
            actionLabel: l10n.cartEmptyAction,
            onAction: () => tapped = true,
          ),
        ),
      );
      expect(find.text(l10n.cartEmpty), findsOneWidget);
      await tester.tap(find.text(l10n.cartEmptyAction));
      expect(tapped, isTrue);
    });

    testWidgets('PaginationFooter: small reload button on error, loader otherwise', (tester) async {
      var retried = false;
      await tester.pumpApp(
        Scaffold(
          body: PaginationFooter(isLoading: false, hasError: true, onRetry: () => retried = true),
        ),
      );
      await tester.tap(find.text(l10n.reload));
      expect(retried, isTrue);

      await tester.pumpApp(
        Scaffold(body: PaginationFooter(isLoading: true, hasError: false, onRetry: () {})),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  testWidgets('NoInternetBanner appears only offline', (tester) async {
    final connectivity = MockConnectivityCubit();
    whenListen(
      connectivity,
      Stream.fromIterable([ConnectivityStatus.offline]),
      initialState: ConnectivityStatus.online,
    );
    await tester.pumpApp(
      BlocProvider<ConnectivityCubit>.value(
        value: connectivity,
        child: const NoInternetBanner(child: Scaffold(body: Text('content'))),
      ),
    );
    expect(find.text(l10n.noInternet), findsNothing);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(l10n.noInternet), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('QuantityStepper respects min and max', (tester) async {
    final values = <int>[];
    await tester.pumpApp(Scaffold(body: QuantityStepper(quantity: 1, onChanged: values.add)));
    await tester.tap(find.byTooltip(l10n.decreaseQuantity));
    await tester.tap(find.byTooltip(l10n.increaseQuantity));
    expect(values, [2]);
  });

  group('PhoneView (login form)', () {
    late _MockPhoneCubit cubit;
    setUp(() {
      cubit = _MockPhoneCubit();
      when(() => cubit.state).thenReturn(const PhoneState.initial());
      when(() => cubit.submit(any())).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester) =>
        tester.pumpApp(BlocProvider<PhoneCubit>.value(value: cubit, child: const PhoneView()));

    testWidgets('formats the number with the mask', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('phone_field')), '901234567');
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.controller.text, '90 123 45 67');
      expect(find.text('+998 '), findsOneWidget);
    });

    testWidgets('incomplete number shows a validation error', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('phone_field')), '9012');
      await tester.tap(find.byKey(const Key('phone_submit')));
      await tester.pump();
      expect(find.text(l10n.phoneInvalid), findsOneWidget);
      verifyNever(() => cubit.submit(any()));
    });

    testWidgets('valid number is submitted', (tester) async {
      await pump(tester);
      await tester.enterText(find.byKey(const Key('phone_field')), '901234567');
      await tester.tap(find.byKey(const Key('phone_submit')));
      await tester.pump();
      verify(() => cubit.submit('90 123 45 67')).called(1);
    });

    testWidgets('shows a loader while sending', (tester) async {
      when(() => cubit.state).thenReturn(const PhoneState.loading());
      await pump(tester);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('CartPage', () {
    late MockCartCubit cubit;
    setUp(() => cubit = MockCartCubit());

    Future<void> pump(WidgetTester tester, Cart cart) {
      when(() => cubit.state)
          .thenReturn(CartState.success(cart: cart, totals: CartCalculator.calculate(cart)));
      return tester.pumpApp(BlocProvider<CartCubit>.value(value: cubit, child: const CartPage()));
    }

    String money(int v) => l10n.currencySum(
      v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' '),
    );

    testWidgets('empty cart shows the empty state with an action', (tester) async {
      await pump(tester, Cart.empty);
      expect(find.text(l10n.cartEmpty), findsOneWidget);
      expect(find.text(l10n.cartEmptyAction), findsOneWidget);
    });

    testWidgets('shows the bill and blocks checkout below the minimum', (tester) async {
      await pump(tester, Cart.empty.add(tCartRestaurant, tCartItem(price: 20000)));
      expect(find.text(l10n.total), findsOneWidget);
      expect(find.text(money(20000)), findsWidgets);
      expect(find.text(l10n.minOrderRemaining(money(30000))), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('cart_checkout')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('checkout is enabled once the minimum is reached', (tester) async {
      await pump(tester, Cart.empty.add(tCartRestaurant, tCartItem(qty: 2)));
      expect(find.textContaining(l10n.minOrderRemaining('').split(' ').first), findsNothing);
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('cart_checkout')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('swipe removes an item', (tester) async {
      when(() => cubit.remove(any())).thenAnswer((_) async {});
      final item = tCartItem(qty: 2);
      await pump(tester, Cart.empty.add(tCartRestaurant, item));
      await tester.drag(find.text(item.name), const Offset(-600, 0));
      await tester.pumpAndSettle();
      verify(() => cubit.remove(item.key)).called(1);
    });
  });

  testWidgets('RestaurantCard shows name, time and free delivery', (tester) async {
    final r = tRestaurant(deliveryFee: 0).copyWith(imageUrl: '');
    var tapped = false;
    await tester.pumpApp(
      Scaffold(
        body: RestaurantCard(restaurant: r, onTap: () => tapped = true),
      ),
    );
    expect(find.text(r.name), findsOneWidget);
    expect(find.text(l10n.freeDelivery), findsOneWidget);
    expect(find.text(l10n.minutesShort(30)), findsOneWidget);
    await tester.tap(find.text(r.name));
    expect(tapped, isTrue);
  });

  testWidgets('OrderStatusStepper highlights the current status', (tester) async {
    await tester.pumpApp(
      Scaffold(
        body: OrderStatusStepper(order: tOrder(status: OrderStatus.cooking)),
      ),
    );
    expect(find.text(l10n.statusCooking), findsOneWidget);
    expect(find.text(l10n.statusDelivered), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));

    await tester.pumpApp(
      Scaffold(
        body: OrderStatusStepper(order: tOrder(status: OrderStatus.cancelled)),
      ),
    );
    expect(find.text(l10n.statusCancelled), findsOneWidget);
  });

  test('CartTotals.zero is consistent', () {
    expect(CartTotals.zero.total, 0);
  });
}
