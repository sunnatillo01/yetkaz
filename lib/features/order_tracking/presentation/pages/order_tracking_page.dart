import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/core/widgets/shimmer_box.dart';
import 'package:food_delivery/core/widgets/state_views.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/order_tracking/presentation/bloc/order_tracking_bloc.dart';
import 'package:food_delivery/features/order_tracking/presentation/widgets/order_widgets.dart';
import 'package:food_delivery/features/order_tracking/presentation/widgets/tracking_map.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class OrderTrackingPage extends StatelessWidget {
  const OrderTrackingPage({required this.orderId, super.key});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OrderTrackingBloc>()..add(OrderTrackingEvent.started(orderId)),
      child: const OrderTrackingView(),
    );
  }
}

class OrderTrackingView extends StatefulWidget {
  const OrderTrackingView({super.key});

  @override
  State<OrderTrackingView> createState() => _OrderTrackingViewState();
}

class _OrderTrackingViewState extends State<OrderTrackingView> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Background → stop the Firestore stream; foreground → reconnect.
    final bloc = context.read<OrderTrackingBloc>();
    _lifecycle = AppLifecycleListener(
      onPause: () => bloc.add(const OrderTrackingEvent.paused()),
      onResume: () => bloc.add(const OrderTrackingEvent.resumed()),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocConsumer<OrderTrackingBloc, OrderTrackingState>(
      listenWhen: (a, b) =>
          b is OrderTrackingSuccess &&
          b.actionFailure != null &&
          (a is! OrderTrackingSuccess || a.actionFailure != b.actionFailure),
      listener: (context, state) {
        final failure = (state as OrderTrackingSuccess).actionFailure!;
        context.showSnack(failure.message(l10n));
      },
      builder: (context, state) => switch (state) {
        OrderTrackingInitial() || OrderTrackingLoading() => Scaffold(
          appBar: AppBar(),
          body: const Column(
            children: [
              Expanded(child: ShimmerBox(radius: 0)),
              SizedBox(height: 240, child: SkeletonList(itemCount: 3)),
            ],
          ),
        ),
        OrderTrackingFailure(:final failure) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(failure: failure, onRetry: context.read<OrderTrackingBloc>().retry),
        ),
        OrderTrackingSuccess(:final order, :final isCancelling) => _TrackingContent(
          order: order,
          isCancelling: isCancelling,
        ),
      },
    );
  }
}

class _TrackingContent extends StatelessWidget {
  const _TrackingContent({required this.order, required this.isCancelling});

  final FoodOrder order;
  final bool isCancelling;

  Future<void> _cancel(BuildContext context) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.cancelOrderQuestion,
      confirmLabel: l10n.cancelOrder,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<OrderTrackingBloc>().add(const OrderTrackingEvent.cancelRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final height = MediaQuery.sizeOf(context).height;
    final courier = order.courier;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderTitle(order.shortId))),
      body: Stack(
        children: [
          Positioned.fill(
            child: TrackingMap(order: order, bottomPadding: height * 0.4),
          ),
          DraggableScrollableSheet(
            initialChildSize: 0.45,
            minChildSize: 0.2,
            maxChildSize: 0.9,
            builder: (context, scroll) => Material(
              elevation: 8,
              color: context.colors.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radius)),
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: context.colors.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(order.restaurantName, style: context.text.titleLarge),
                  if (order.isActive && order.etaMinutes != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.etaMinutes(order.etaMinutes!),
                        style: context.text.titleMedium?.copyWith(color: context.colors.primary),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  OrderStatusStepper(order: order),
                  if (courier != null &&
                      courier.phone.isNotEmpty &&
                      order.status == OrderStatus.onTheWay)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: context.colors.primaryContainer,
                        child: Icon(Icons.person_rounded, color: context.appColors.courier),
                      ),
                      title: Text(courier.name),
                      subtitle: Text(l10n.courier),
                      trailing: IconButton.filledTonal(
                        tooltip: l10n.callCourier,
                        icon: const Icon(Icons.call_rounded),
                        onPressed: () => launchUrl(Uri(scheme: 'tel', path: courier.phone)),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  OrderSummary(order: order),
                  if (order.canCancel) ...[
                    const SizedBox(height: AppSpacing.xl),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: context.colors.error),
                      onPressed: isCancelling ? null : () => _cancel(context),
                      icon: isCancelling
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.close_rounded),
                      label: Text(l10n.cancelOrder),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
