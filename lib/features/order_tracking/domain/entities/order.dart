import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'order.freezed.dart';

/// created → accepted → cooking → on_the_way → delivered (or cancelled).
enum OrderStatus {
  created('created'),
  accepted('accepted'),
  cooking('cooking'),
  onTheWay('on_the_way'),
  delivered('delivered'),
  cancelled('cancelled');

  OrderStatus(this.value);
  final String value;

  static OrderStatus parse(String? value) =>
      OrderStatus.values.firstWhere((s) => s.value == value, orElse: () => OrderStatus.created);

  /// Steps shown in the tracking stepper (cancelled is terminal, not a step).
  static const List<OrderStatus> progress = [created, accepted, cooking, onTheWay, delivered];

  bool get isFinal => this == delivered || this == cancelled;
}

enum PaymentMethod { cash, card }

@freezed
abstract class OrderItem with _$OrderItem {
  const factory OrderItem({
    required String itemId,
    required String name,

    /// Unit price including options.
    required int price,
    required int qty,
    @Default([]) List<MenuOption> options,
    @Default('') String imageUrl,
  }) = _OrderItem;
  const OrderItem._();

  int get lineTotal => price * qty;
}

@freezed
abstract class StatusChange with _$StatusChange {
  const factory StatusChange({required OrderStatus status, required DateTime at}) = _StatusChange;
}

@freezed
abstract class Courier with _$Courier {
  const factory Courier({
    required Coordinates location,
    @Default('') String name,
    @Default('') String phone,
  }) = _Courier;
}

@freezed
abstract class FoodOrder with _$FoodOrder {
  const factory FoodOrder({
    required String id,
    required String userId,
    required String restaurantId,
    required String restaurantName,
    required Coordinates restaurantLocation,
    required List<OrderItem> items,
    required int subtotal,
    required int deliveryFee,
    required int serviceFee,
    required int total,
    required Address address,
    required PaymentMethod paymentMethod,
    required OrderStatus status,
    required DateTime createdAt,
    @Default([]) List<StatusChange> statusHistory,
    @Default([]) List<Coordinates> route,
    Courier? courier,
    int? etaMinutes,
    @Default('') String note,
  }) = _FoodOrder;
  const FoodOrder._();

  /// Cancellation is allowed only before the restaurant accepts the order.
  bool get canCancel => status == OrderStatus.created;

  bool get isActive => !status.isFinal;

  int get itemCount => items.fold(0, (s, i) => s + i.qty);

  /// Short human id shown in UI: last 6 chars.
  String get shortId =>
      id.length <= 6 ? id.toUpperCase() : id.substring(id.length - 6).toUpperCase();
}

/// What the client sends to the `createOrder` Cloud Function.
/// Prices are deliberately absent: the server recalculates them.
@freezed
abstract class OrderRequest with _$OrderRequest {
  const factory OrderRequest({
    required String idempotencyKey,
    required String restaurantId,
    required List<OrderRequestItem> items,
    required Address address,
    required PaymentMethod paymentMethod,
    @Default('') String note,
  }) = _OrderRequest;
}

@freezed
abstract class OrderRequestItem with _$OrderRequestItem {
  const factory OrderRequestItem({
    required String itemId,
    required int qty,
    @Default([]) List<String> options,
  }) = _OrderRequestItem;
}
