import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:material_ui/material_ui.dart';

extension OrderStatusUi on OrderStatus {
  String label(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      OrderStatus.created => l10n.statusCreated,
      OrderStatus.accepted => l10n.statusAccepted,
      OrderStatus.cooking => l10n.statusCooking,
      OrderStatus.onTheWay => l10n.statusOnTheWay,
      OrderStatus.delivered => l10n.statusDelivered,
      OrderStatus.cancelled => l10n.statusCancelled,
    };
  }

  IconData get icon => switch (this) {
    OrderStatus.created => Icons.receipt_long_rounded,
    OrderStatus.accepted => Icons.storefront_rounded,
    OrderStatus.cooking => Icons.soup_kitchen_rounded,
    OrderStatus.onTheWay => Icons.delivery_dining_rounded,
    OrderStatus.delivered => Icons.check_circle_rounded,
    OrderStatus.cancelled => Icons.cancel_rounded,
  };
}

/// Vertical stepper: created → accepted → cooking → on the way → delivered.
class OrderStatusStepper extends StatelessWidget {
  const OrderStatusStepper({required this.order, super.key});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    if (order.status == OrderStatus.cancelled) {
      return ListTile(
        leading: Icon(OrderStatus.cancelled.icon, color: context.colors.error),
        title: Text(OrderStatus.cancelled.label(context), style: context.text.titleMedium),
      );
    }
    final currentIndex = OrderStatus.progress.indexOf(order.status);
    final times = {for (final s in order.statusHistory) s.status: s.at};
    return Semantics(
      label: order.status.label(context),
      liveRegion: true,
      child: Column(
        children: [
          for (var i = 0; i < OrderStatus.progress.length; i++)
            _StepRow(
              status: OrderStatus.progress[i],
              done: i < currentIndex,
              active: i == currentIndex,
              isLast: i == OrderStatus.progress.length - 1,
              time: times[OrderStatus.progress[i]],
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.status,
    required this.done,
    required this.active,
    required this.isLast,
    this.time,
  });

  final OrderStatus status;
  final bool done;
  final bool active;
  final bool isLast;
  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    final reached = done || active;
    final color = reached ? context.colors.primary : context.colors.outlineVariant;
    final timeText = time == null
        ? ''
        : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: reached ? color : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 2),
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : status.icon,
                    size: 18,
                    color: reached ? context.colors.onPrimary : color,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: done ? color : context.colors.outlineVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: AppSpacing.lg),
              child: Text(
                status.label(context),
                style: active
                    ? context.text.titleMedium
                    : context.text.bodyMedium?.copyWith(
                        color: reached ? null : context.colors.onSurfaceVariant,
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(timeText, style: context.text.bodySmall),
          ),
        ],
      ),
    );
  }
}

/// Items + totals of an order.
class OrderSummary extends StatelessWidget {
  const OrderSummary({required this.order, super.key});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget line(String label, int amount, {bool bold = false}) {
      final style = bold ? context.text.titleMedium : context.text.bodyMedium;
      return Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(context.money(amount), style: style),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.orderItems, style: context.text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${item.qty} × ', style: context.text.bodyMedium),
                Expanded(
                  child: Text(
                    [item.name, ...item.options.map((o) => o.name)].join(', '),
                    style: context.text.bodyMedium,
                  ),
                ),
                Text(context.money(item.lineTotal), style: context.text.bodyMedium),
              ],
            ),
          ),
        const Divider(),
        line(l10n.subtotal, order.subtotal),
        line(l10n.deliveryFee, order.deliveryFee),
        line(l10n.serviceFee, order.serviceFee),
        line(l10n.total, order.total, bold: true),
      ],
    );
  }
}
