import 'dart:async';
import 'dart:math' as math;

import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_ui/material_ui.dart';

LatLng _latLng(Coordinates c) => LatLng(c.lat, c.lng);

/// Map with restaurant, customer and courier markers plus the route.
///
/// The courier position arrives every ~3 s; instead of jumping, the marker
/// is interpolated between the previous and the new coordinate with an
/// [AnimationController] that lasts as long as the update interval.
class TrackingMap extends StatefulWidget {
  const TrackingMap({required this.order, this.bottomPadding = 0, super.key});

  final FoodOrder order;
  final double bottomPadding;

  /// Should match the simulator's update interval.
  static const courierAnimation = Duration(seconds: 3);

  @override
  State<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends State<TrackingMap> with SingleTickerProviderStateMixin {
  GoogleMapController? _map;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TrackingMap.courierAnimation,
  )..addListener(_onTick);

  Coordinates? _from;
  Coordinates? _to;
  Coordinates? _courier;
  double _rotation = 0;

  @override
  void initState() {
    super.initState();
    _courier = widget.order.courier?.location;
    _to = _courier;
  }

  @override
  void didUpdateWidget(covariant TrackingMap old) {
    super.didUpdateWidget(old);
    final next = widget.order.courier?.location;
    if (next == null || next == _to) return;
    if (_courier == null) {
      setState(() => _courier = _to = next);
      return;
    }
    _from = _courier;
    _to = next;
    _rotation = _from!.bearingTo(next);
    _controller.forward(from: 0);
  }

  void _onTick() {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final t = Curves.linear.transform(_controller.value);
    setState(() => _courier = from.lerp(to, t));
  }

  @override
  void dispose() {
    _controller.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _fitBounds() async {
    final points = [widget.order.restaurantLocation, widget.order.address.location, ?_courier];
    final south = points.map((p) => p.lat).reduce(math.min);
    final north = points.map((p) => p.lat).reduce(math.max);
    final west = points.map((p) => p.lng).reduce(math.min);
    final east = points.map((p) => p.lng).reduce(math.max);
    await _map?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)),
        64,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final order = widget.order;
    final route = order.route.isNotEmpty
        ? order.route
        : [order.restaurantLocation, order.address.location];
    final courier = _courier;
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: _latLng(order.address.location), zoom: 13),
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (c) {
        _map = c;
        // Wait for the first layout so bounds fit the visible area.
        Future<void>.delayed(const Duration(milliseconds: 300), _fitBounds);
      },
      polylines: {
        Polyline(
          polylineId: const PolylineId('route'),
          points: route.map(_latLng).toList(),
          color: context.appColors.route,
          width: 5,
        ),
      },
      markers: {
        Marker(
          markerId: const MarkerId('restaurant'),
          position: _latLng(order.restaurantLocation),
          infoWindow: InfoWindow(title: order.restaurantName),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
        Marker(
          markerId: const MarkerId('customer'),
          position: _latLng(order.address.location),
          infoWindow: InfoWindow(title: l10n.yourAddressMarker),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
        if (courier != null && order.status == OrderStatus.onTheWay)
          Marker(
            markerId: const MarkerId('courier'),
            position: _latLng(courier),
            rotation: _rotation,
            flat: true,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 2,
            infoWindow: InfoWindow(title: l10n.courier),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
      },
    );
  }
}
