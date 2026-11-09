import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/firebase/json_converters.dart';
import 'package:food_delivery/features/address/data/models/address_model.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/restaurant/data/models/restaurant_model.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'order_model.freezed.dart';
part 'order_model.g.dart';

@freezed
abstract class GeoModel with _$GeoModel {
  const factory GeoModel({
    @JsonKey(fromJson: doubleFromJson) required double lat,
    @JsonKey(fromJson: doubleFromJson) required double lng,
  }) = _GeoModel;
  const GeoModel._();

  factory GeoModel.fromJson(Map<String, dynamic> json) => _$GeoModelFromJson(json);

  Coordinates toEntity() => Coordinates(lat: lat, lng: lng);
}

@freezed
abstract class OrderItemModel with _$OrderItemModel {
  const factory OrderItemModel({
    required String itemId,
    required String name,
    @JsonKey(fromJson: intFromJson) required int price,
    @JsonKey(fromJson: intFromJson) required int qty,
    @Default([]) List<MenuOptionModel> options,
    @Default('') String imageUrl,
  }) = _OrderItemModel;
  const OrderItemModel._();

  factory OrderItemModel.fromJson(Map<String, dynamic> json) => _$OrderItemModelFromJson(json);

  OrderItem toEntity() => OrderItem(
    itemId: itemId,
    name: name,
    price: price,
    qty: qty,
    options: options.map((o) => o.toEntity()).toList(),
    imageUrl: imageUrl,
  );
}

@freezed
abstract class StatusChangeModel with _$StatusChangeModel {
  const factory StatusChangeModel({
    required String status,
    @TimestampConverter() required DateTime at,
  }) = _StatusChangeModel;

  factory StatusChangeModel.fromJson(Map<String, dynamic> json) =>
      _$StatusChangeModelFromJson(json);
}

@freezed
abstract class CourierModel with _$CourierModel {
  const factory CourierModel({
    @JsonKey(fromJson: doubleFromJson) required double lat,
    @JsonKey(fromJson: doubleFromJson) required double lng,
    @Default('') String name,
    @Default('') String phone,
  }) = _CourierModel;

  factory CourierModel.fromJson(Map<String, dynamic> json) => _$CourierModelFromJson(json);
}

/// `orders/{id}` document — written only by Cloud Functions.
@freezed
abstract class OrderModel with _$OrderModel {
  const factory OrderModel({
    required String userId,
    required String restaurantId,
    required AddressModel address,
    @Default('') String id,
    @Default('') String restaurantName,
    GeoModel? restaurantLocation,
    @Default([]) List<OrderItemModel> items,
    @JsonKey(fromJson: intFromJson) @Default(0) int subtotal,
    @JsonKey(fromJson: intFromJson) @Default(0) int deliveryFee,
    @JsonKey(fromJson: intFromJson) @Default(0) int serviceFee,
    @JsonKey(fromJson: intFromJson) @Default(0) int total,
    @Default('cash') String paymentMethod,
    @Default('created') String status,
    @Default([]) List<StatusChangeModel> statusHistory,
    @Default([]) List<GeoModel> route,
    CourierModel? courier,
    int? etaMinutes,
    @Default('') String note,
    @TimestampConverter() DateTime? createdAt,
  }) = _OrderModel;
  const OrderModel._();

  factory OrderModel.fromJson(Map<String, dynamic> json) => _$OrderModelFromJson(json);

  factory OrderModel.fromFirestore(String id, Map<String, dynamic> data) =>
      OrderModel.fromJson({...data, 'id': id});

  FoodOrder toEntity() => FoodOrder(
    id: id,
    userId: userId,
    restaurantId: restaurantId,
    restaurantName: restaurantName,
    restaurantLocation: restaurantLocation?.toEntity() ?? address.toEntity().location,
    items: items.map((i) => i.toEntity()).toList(),
    subtotal: subtotal,
    deliveryFee: deliveryFee,
    serviceFee: serviceFee,
    total: total,
    address: address.toEntity(),
    paymentMethod: PaymentMethod.values.firstWhere(
      (p) => p.name == paymentMethod,
      orElse: () => PaymentMethod.cash,
    ),
    status: OrderStatus.parse(status),
    createdAt: createdAt ?? DateTime.now(),
    statusHistory: [
      for (final s in statusHistory) StatusChange(status: OrderStatus.parse(s.status), at: s.at),
    ],
    route: route.map((p) => p.toEntity()).toList(),
    courier: courier == null
        ? null
        : Courier(
            location: Coordinates(lat: courier!.lat, lng: courier!.lng),
            name: courier!.name,
            phone: courier!.phone,
          ),
    etaMinutes: etaMinutes,
    note: note,
  );
}

/// Request body for `POST /createOrder`.
Map<String, dynamic> orderRequestToJson(OrderRequest r) => {
  'idempotencyKey': r.idempotencyKey,
  'restaurantId': r.restaurantId,
  'items': [
    for (final i in r.items) {'itemId': i.itemId, 'qty': i.qty, 'options': i.options},
  ],
  'address': AddressModel.fromEntity(r.address).toJson()..remove('id'),
  'paymentMethod': r.paymentMethod.name,
  'note': r.note,
};
