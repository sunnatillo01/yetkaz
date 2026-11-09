import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/app_network_image.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/features/restaurant/domain/entities/restaurant.dart';
import 'package:material_ui/material_ui.dart';

/// Hero tag shared by the list card and the restaurant page header.
String restaurantHeroTag(String id) => 'restaurant-image-$id';

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({required this.restaurant, required this.onTap, super.key});

  final Restaurant restaurant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = restaurant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Semantics(
        button: true,
        label: r.name,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radius),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 8,
                child: Hero(
                  tag: restaurantHeroTag(r.id),
                  child: AppNetworkImage(
                    url: r.imageUrl,
                    semanticLabel: l10n.imageOf(r.name),
                    borderRadius: BorderRadius.circular(AppSpacing.radius),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      r.name,
                      style: context.text.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  RatingBadge(rating: r.rating),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _Meta(icon: Icons.schedule_rounded, text: l10n.minutesShort(r.deliveryTimeMin)),
                  _Meta(
                    icon: Icons.delivery_dining_rounded,
                    text: r.hasFreeDelivery ? l10n.freeDelivery : context.money(r.deliveryFee),
                    highlight: r.hasFreeDelivery,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.highlight = false});

  final IconData icon;
  final String text;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? context.appColors.success : context.colors.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(text, style: context.text.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}
