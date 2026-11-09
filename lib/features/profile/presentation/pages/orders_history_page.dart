import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/shimmer_box.dart';
import 'package:food_delivery/core/widgets/state_views.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:food_delivery/features/order_tracking/domain/entities/order.dart';
import 'package:food_delivery/features/order_tracking/presentation/widgets/order_widgets.dart';
import 'package:food_delivery/features/profile/presentation/bloc/profile_cubits.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

class OrdersHistoryPage extends StatelessWidget {
  const OrdersHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider(
      create: (_) => getIt<ReorderCubit>(),
      child: BlocListener<ReorderCubit, ReorderState>(
        listener: (context, state) {
          switch (state) {
            case ReorderSuccess():
              context
                ..read<CartCubit>().load()
                ..showSnack(l10n.reorderDone)
                ..go(Routes.cart);
            case ReorderFailure(:final failure):
              context.showSnack(failure.message(l10n));
            default:
          }
        },
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text(l10n.myOrders),
              bottom: TabBar(
                tabs: [
                  Tab(text: l10n.activeOrders),
                  Tab(text: l10n.completedOrders),
                ],
              ),
            ),
            body: const TabBarView(
              children: [
                _OrdersTab(tab: OrdersTab.active, key: PageStorageKey(OrdersTab.active)),
                _OrdersTab(tab: OrdersTab.completed, key: PageStorageKey(OrdersTab.completed)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.tab, super.key});

  final OrdersTab tab;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OrdersHistoryBloc>(param1: tab)..add(const OrdersHistoryEvent.started()),
      child: const _OrdersList(),
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<OrdersHistoryBloc>();
    return BlocBuilder<OrdersHistoryBloc, OrdersHistoryState>(
      builder: (context, state) => switch (state) {
        OrdersHistoryInitial() || OrdersHistoryLoading() => const SkeletonList(),
        OrdersHistoryFailure(:final failure) => ErrorView(
          failure: failure,
          onRetry: () => bloc.add(const OrdersHistoryEvent.started()),
        ),
        OrdersHistorySuccess(:final orders) when orders.isEmpty => EmptyView(
          icon: Icons.receipt_long_outlined,
          title: l10n.noOrders,
          actionLabel: l10n.cartEmptyAction,
          onAction: () => context.go(Routes.home),
        ),
        final OrdersHistorySuccess s => RefreshIndicator(
          onRefresh: () async => bloc.add(const OrdersHistoryEvent.started()),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.extentAfter < 400) {
                bloc.add(const OrdersHistoryEvent.nextPageRequested());
              }
              return false;
            },
            child: ListView.builder(
              itemCount: s.orders.length + 1,
              itemBuilder: (context, i) {
                if (i == s.orders.length) {
                  return PaginationFooter(
                    isLoading: s.isLoadingMore,
                    hasError: s.loadMoreFailure != null,
                    onRetry: () => bloc.add(const OrdersHistoryEvent.nextPageRequested()),
                  );
                }
                return OrderTile(order: s.orders[i]);
              },
            ),
          ),
        ),
      },
    );
  }
}

class OrderTile extends StatelessWidget {
  const OrderTile({required this.order, super.key});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMd(locale).add_Hm().format(order.createdAt);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: InkWell(
        onTap: () => context.push(Routes.order(order.id)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(order.restaurantName, style: context.text.titleMedium)),
                  Icon(order.status.icon, size: 18, color: context.colors.primary),
                  const SizedBox(width: 4),
                  Text(order.status.label(context), style: context.text.labelMedium),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(date, style: context.text.bodySmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${l10n.itemsCount(order.itemCount)} · ${context.money(order.total)}',
                style: context.text.bodyMedium,
              ),
              if (!order.isActive)
                Align(
                  alignment: Alignment.centerRight,
                  child: BlocBuilder<ReorderCubit, ReorderState>(
                    builder: (context, state) {
                      final loading = state is ReorderLoading && state.orderId == order.id;
                      return TextButton.icon(
                        onPressed: loading
                            ? null
                            : () => context.read<ReorderCubit>().reorder(order),
                        icon: loading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.replay_rounded),
                        label: Text(l10n.reorder),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
