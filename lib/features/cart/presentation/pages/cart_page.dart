import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/app_network_image.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/core/widgets/shimmer_box.dart';
import 'package:food_delivery/core/widgets/state_views.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/cart/domain/entities/cart_totals.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Uses the app-wide [CartCubit] provided above the router.
class CartPage extends StatelessWidget {
  const CartPage({super.key});

  Future<void> _clear(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.clearCartQuestion,
      destructive: true,
    );
    if (confirmed && context.mounted) await context.read<CartCubit>().clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        final hasItems = state is CartSuccess && !state.cart.isEmpty;
        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.cartTitle),
            actions: [
              if (hasItems)
                IconButton(
                  tooltip: l10n.clearCart,
                  onPressed: () => _clear(context),
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
            ],
          ),
          body: switch (state) {
            CartInitial() || CartLoading() => const SkeletonList(itemCount: 3),
            CartFailure(:final failure) => ErrorView(
              failure: failure,
              onRetry: context.read<CartCubit>().load,
            ),
            CartSuccess(:final cart) when cart.isEmpty => EmptyView(
              icon: Icons.shopping_bag_outlined,
              title: l10n.cartEmpty,
              actionLabel: l10n.cartEmptyAction,
              onAction: () => context.go(Routes.home),
            ),
            CartSuccess(:final cart, :final totals) => _CartContent(cart: cart, totals: totals),
          },
        );
      },
    );
  }
}

class _CartContent extends StatelessWidget {
  const _CartContent({required this.cart, required this.totals});

  final Cart cart;
  final CartTotals totals;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CartCubit>();
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              if (cart.restaurant != null)
                ListTile(
                  leading: const Icon(Icons.storefront_rounded),
                  title: Text(cart.restaurant!.name, style: context.text.titleMedium),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(Routes.restaurant(cart.restaurant!.id)),
                ),
              for (final item in cart.items)
                Dismissible(
                  key: ValueKey(item.key),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                    color: context.colors.errorContainer,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: context.colors.onErrorContainer,
                    ),
                  ),
                  onDismissed: (_) => cubit.remove(item.key),
                  child: CartItemTile(
                    item: item,
                    onQuantityChanged: (q) => cubit.changeQuantity(item.key, q),
                  ),
                ),
            ],
          ),
        ),
        _TotalsPanel(totals: totals, onCheckout: () => context.push(Routes.checkout)),
      ],
    );
  }
}

class CartItemTile extends StatelessWidget {
  const CartItemTile({required this.item, required this.onQuantityChanged, super.key});

  final CartItem item;
  final ValueChanged<int> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 64,
            child: AppNetworkImage(
              url: item.imageUrl,
              semanticLabel: l10n.imageOf(item.name),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: context.text.titleSmall),
                if (item.options.isNotEmpty)
                  Text(
                    item.options.map((o) => o.name).join(', '),
                    style: context.text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: AppSpacing.xs),
                Text(context.money(item.lineTotal), style: context.text.titleSmall),
              ],
            ),
          ),
          QuantityStepper(
            quantity: item.quantity,
            min: 0,
            compact: true,
            onChanged: onQuantityChanged,
          ),
        ],
      ),
    );
  }
}

class _TotalsPanel extends StatelessWidget {
  const _TotalsPanel({required this.totals, required this.onCheckout});

  final CartTotals totals;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      elevation: 8,
      color: context.colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _row(context, l10n.subtotal, totals.subtotal),
              _row(context, l10n.deliveryFee, totals.deliveryFee),
              _row(context, l10n.serviceFee, totals.serviceFee),
              const Divider(),
              _row(context, l10n.total, totals.total, bold: true),
              if (!totals.reachedMinOrder) ...[
                const SizedBox(height: AppSpacing.sm),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    l10n.minOrderRemaining(context.money(totals.minOrderRemaining)),
                    style: context.text.bodyMedium?.copyWith(color: context.appColors.warning),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              LoadingButton(
                key: const Key('cart_checkout'),
                label: l10n.goToCheckout,
                onPressed: totals.reachedMinOrder ? onCheckout : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, int amount, {bool bold = false}) {
    final style = bold ? context.text.titleMedium : context.text.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(context.money(amount), style: style),
        ],
      ),
    );
  }
}
