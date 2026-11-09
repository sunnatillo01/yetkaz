import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/features/cart/domain/entities/cart.dart';
import 'package:food_delivery/features/cart/domain/usecases/cart_usecases.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:material_ui/material_ui.dart';

/// Adds [item] to the cart; when the cart holds dishes of another
/// restaurant asks "Clear the cart?" first. Returns `true` when added.
Future<bool> addToCartWithConfirmation(
  BuildContext context,
  CartRestaurant restaurant,
  CartItem item,
) async {
  final cubit = context.read<CartCubit>();
  final result = await cubit.add(restaurant, item);
  if (result is! CartConflict) return result is AddedToCart;
  if (!context.mounted) return false;
  final l10n = context.l10n;
  final confirmed = await showConfirmDialog(
    context,
    title: l10n.clearCartQuestion,
    body: l10n.replaceCartBody,
    confirmLabel: l10n.yes,
  );
  if (!confirmed) return false;
  final replaced = await cubit.add(restaurant, item, replaceExisting: true);
  return replaced is AddedToCart;
}
