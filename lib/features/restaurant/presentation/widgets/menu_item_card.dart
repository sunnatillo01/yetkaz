import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/app_network_image.dart';
import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:material_ui/material_ui.dart';

class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    required this.item,
    required this.quantityInCart,
    required this.enabled,
    required this.onTap,
    required this.onAdd,
    super.key,
  });

  final MenuItem item;
  final int quantityInCart;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final available = enabled && item.isAvailable;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: context.text.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    item.isAvailable ? context.money(item.price) : l10n.unavailable,
                    style: context.text.titleSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: item.isAvailable ? 1 : 0.4,
                      child: AppNetworkImage(
                        url: item.imageUrl,
                        semanticLabel: l10n.imageOf(item.name),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Badge(
                      isLabelVisible: quantityInCart > 0,
                      label: Text('$quantityInCart'),
                      child: IconButton.filled(
                        tooltip: l10n.addToCart,
                        onPressed: available ? onAdd : null,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
