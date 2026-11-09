import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/app_network_image.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/cart/presentation/widgets/add_to_cart_helper.dart';
import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:food_delivery/features/restaurant/presentation/bloc/restaurant_cubits.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showDishDetailsSheet(
  BuildContext context, {
  required MenuItem item,
  required CartRestaurant restaurant,
  required bool enabled,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => BlocProvider(
    create: (_) => getIt<DishCubit>(param1: item),
    child: DishDetailsSheet(restaurant: restaurant, enabled: enabled),
  ),
);

class DishDetailsSheet extends StatelessWidget {
  const DishDetailsSheet({required this.restaurant, required this.enabled, super.key});

  final CartRestaurant restaurant;

  /// `false` when the restaurant is closed or the dish unavailable.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<DishCubit, DishState>(
      builder: (context, state) {
        final item = state.item;
        final cubit = context.read<DishCubit>();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: AppNetworkImage(
                        url: item.imageUrl,
                        semanticLabel: l10n.imageOf(item.name),
                        borderRadius: BorderRadius.circular(AppSpacing.radius),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(item.name, style: context.text.headlineSmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(context.money(item.price), style: context.text.titleMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(item.description, style: context.text.bodyMedium),
                    if (item.options.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(l10n.extras, style: context.text.titleSmall),
                      for (final option in item.options)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: state.selectedOptions.contains(option.name),
                          onChanged: (_) => cubit.toggleOption(option.name),
                          title: Text(option.name),
                          secondary: Text('+${context.money(option.price)}'),
                        ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    QuantityStepper(quantity: state.quantity, onChanged: cubit.setQuantity),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: !enabled || !item.isAvailable
                            ? null
                            : () async {
                                final added = await addToCartWithConfirmation(
                                  context,
                                  restaurant,
                                  state.toCartItem(),
                                );
                                if (added && context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                        child: Text(
                          l10n.addToCartWithPrice(context.money(state.total)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
