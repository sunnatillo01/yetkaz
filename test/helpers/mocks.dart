import 'package:bloc_test/bloc_test.dart';
import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/entities/paginated_list.dart';
import 'package:food_delivery/core/network/connectivity_cubit.dart';
import 'package:food_delivery/core/network/network_info.dart';
import 'package:food_delivery/core/network/token_refresher.dart';
import 'package:food_delivery/core/storage/token_storage.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/core/utils/clock.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/domain/repositories/address_repository.dart';
import 'package:food_delivery/features/address/domain/usecases/address_usecases.dart';
import 'package:food_delivery/features/address/presentation/bloc/address_cubits.dart';
import 'package:food_delivery/features/auth/domain/repositories/auth_repository.dart';
import 'package:food_delivery/features/auth/domain/usecases/auth_usecases.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/cart/domain/repositories/cart_repository.dart';
import 'package:food_delivery/features/cart/domain/usecases/cart_usecases.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:food_delivery/features/checkout/domain/usecases/place_order.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:food_delivery/features/home/domain/repositories/home_repository.dart';
import 'package:food_delivery/features/home/domain/usecases/home_usecases.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/order_tracking/domain/repositories/order_repository.dart';
import 'package:food_delivery/features/order_tracking/domain/usecases/order_usecases.dart';
import 'package:food_delivery/features/profile/domain/repositories/profile_repository.dart';
import 'package:food_delivery/features/profile/domain/usecases/profile_usecases.dart';
import 'package:food_delivery/features/restaurant/domain/repositories/restaurant_repository.dart';
import 'package:food_delivery/features/restaurant/domain/usecases/get_restaurant_details.dart';
import 'package:food_delivery/features/search/domain/repositories/search_repository.dart';
import 'package:food_delivery/features/search/domain/usecases/search_usecases.dart';
import 'package:food_delivery/features/settings/domain/repositories/settings_repository.dart';
import 'package:food_delivery/features/settings/domain/usecases/settings_usecases.dart';
import 'package:mocktail/mocktail.dart';

import 'fixtures.dart';

// Repositories
class MockAuthRepository extends Mock implements AuthRepository;

class MockCartRepository extends Mock implements CartRepository;

class MockHomeRepository extends Mock implements HomeRepository;

class MockRestaurantRepository extends Mock implements RestaurantRepository;

class MockSearchRepository extends Mock implements SearchRepository;

class MockOrderRepository extends Mock implements OrderRepository;

class MockAddressRepository extends Mock implements AddressRepository;

class MockLocationRepository extends Mock implements LocationRepository;

class MockSettingsRepository extends Mock implements SettingsRepository;

class MockProfileRepository extends Mock implements ProfileRepository;

// Use cases
class MockSendOtp extends Mock implements SendOtp;

class MockVerifyOtp extends Mock implements VerifyOtp;

class MockCreateProfile extends Mock implements CreateProfile;

class MockWatchSession extends Mock implements WatchSession;

class MockGetCurrentSession extends Mock implements GetCurrentSession;

class MockLogout extends Mock implements Logout;

class MockDeleteAccount extends Mock implements DeleteAccount;

class MockLoadCart extends Mock implements LoadCart;

class MockAddToCart extends Mock implements AddToCart;

class MockSaveCart extends Mock implements SaveCart;

class MockClearCart extends Mock implements ClearCart;

class MockGetHomeContent extends Mock implements GetHomeContent;

class MockGetRestaurants extends Mock implements GetRestaurants;

class MockGetRestaurantDetails extends Mock implements GetRestaurantDetails;

class MockSearchRestaurants extends Mock implements SearchRestaurants;

class MockGetSearchHistory extends Mock implements GetSearchHistory;

class MockClearSearchHistory extends Mock implements ClearSearchHistory;

class MockPlaceOrder extends Mock implements PlaceOrder;

class MockWatchOrder extends Mock implements WatchOrder;

class MockCancelOrder extends Mock implements CancelOrder;

class MockGetOrders extends Mock implements GetOrders;

class MockGetCurrentAddress extends Mock implements GetCurrentAddress;

class MockSelectAddress extends Mock implements SelectAddress;

class MockWatchSavedAddresses extends Mock implements WatchSavedAddresses;

class MockDeleteAddress extends Mock implements DeleteAddress;

class MockSaveAddress extends Mock implements SaveAddress;

class MockGetMyLocation extends Mock implements GetMyLocation;

class MockResolveAddress extends Mock implements ResolveAddress;

class MockGetSettings extends Mock implements GetSettings;

class MockChangeLanguage extends Mock implements ChangeLanguage;

class MockChangeThemeMode extends Mock implements ChangeThemeMode;

class MockTogglePushNotifications extends Mock implements TogglePushNotifications;

class MockGetAppInfo extends Mock implements GetAppInfo;

class MockCompleteOnboarding extends Mock implements CompleteOnboarding;

class MockChangeAvatar extends Mock implements ChangeAvatar;

class MockReorder extends Mock implements Reorder;

// Infrastructure
class MockTokenStorage extends Mock implements TokenStorage;

class MockTokenRefresher extends Mock implements TokenRefresher;

class MockNetworkInfo extends Mock implements NetworkInfo;

class MockClock extends Mock implements Clock;

// Blocs (widget tests)
class MockCartCubit extends MockCubit<CartState> implements CartCubit;

class MockConnectivityCubit extends MockCubit<ConnectivityStatus> implements ConnectivityCubit;

class MockCurrentAddressCubit extends MockCubit<Address?> implements CurrentAddressCubit;

/// Registers fallback values for `any()` matchers once per test file.
void registerFallbacks() {
  registerFallbackValue(const NoParams());
  registerFallbackValue(Coordinates.tashkent);
  registerFallbackValue(Cart.empty);
  registerFallbackValue(tCartRestaurant);
  registerFallbackValue(tCartItem());
  registerFallbackValue(tAddress);
  registerFallbackValue(tOrder());
  registerFallbackValue(RestaurantFilter.initial);
  registerFallbackValue(const PageCursor([]));
  registerFallbackValue(
    const OrderRequest(
      idempotencyKey: 'k',
      restaurantId: 'r1',
      items: [],
      address: tAddress,
      paymentMethod: PaymentMethod.cash,
    ),
  );
  registerFallbackValue(
    AddToCartParams(cart: Cart.empty, restaurant: tCartRestaurant, item: tCartItem()),
  );
  registerFallbackValue(const GetRestaurantsParams(filter: RestaurantFilter.initial));
  registerFallbackValue(const GetOrdersParams(active: true));
  registerFallbackValue(const VerifyOtpParams(verificationId: 'v', code: '123456'));
  registerFallbackValue(
    const PlaceOrderParams(
      cart: Cart.empty,
      address: null,
      paymentMethod: PaymentMethod.cash,
      idempotencyKey: 'k',
    ),
  );
}
