import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton placeholder block. Use instead of spinners for loading states.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({this.width, this.height, this.radius = AppSpacing.radiusSm, super.key});

  final double? width;
  final double? height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Shimmer.fromColors(
      baseColor: colors.shimmerBase,
      highlightColor: colors.shimmerHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: colors.shimmerBase,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton for a restaurant card (image + 2 text lines).
class RestaurantCardSkeleton extends StatelessWidget {
  const RestaurantCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 8,
            child: ShimmerBox(radius: AppSpacing.radius),
          ),
          SizedBox(height: AppSpacing.sm),
          ShimmerBox(width: 180, height: 18),
          SizedBox(height: AppSpacing.xs),
          ShimmerBox(width: 120, height: 14),
        ],
      ),
    );
  }
}

/// Skeleton for list tiles (orders, addresses, menu items).
class ListTileSkeleton extends StatelessWidget {
  const ListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: Row(
        children: [
          ShimmerBox(width: 72, height: 72),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 16),
                SizedBox(height: AppSpacing.sm),
                ShimmerBox(width: 140, height: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen list skeleton.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.itemCount = 6, this.restaurant = false, super.key});

  final int itemCount;
  final bool restaurant;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, _) => restaurant ? const RestaurantCardSkeleton() : const ListTileSkeleton(),
    );
  }
}
