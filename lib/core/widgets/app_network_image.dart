import 'package:cached_network_image/cached_network_image.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/widgets/shimmer_box.dart';
import 'package:material_ui/material_ui.dart';

/// Cached network image that decodes at the rendered size
/// (`memCacheWidth`) to keep memory and jank low.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.url,
    this.semanticLabel,
    this.fit = BoxFit.cover,
    this.borderRadius,
    super.key,
  });

  final String url;
  final String? semanticLabel;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: ColoredBox(
          color: context.colors.surfaceContainerHighest,
          child: Center(
            child: Icon(Icons.restaurant_rounded, color: context.colors.onSurfaceVariant),
          ),
        ),
      );
    }
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? (constraints.maxWidth * dpr).round() : null;
        return Semantics(
          image: true,
          label: semanticLabel,
          excludeSemantics: true,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            memCacheWidth: width,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => const ShimmerBox(),
            errorWidget: (context, _, _) => ColoredBox(
              color: context.colors.surfaceContainerHighest,
              child: Icon(Icons.restaurant_rounded, color: context.colors.onSurfaceVariant),
            ),
          ),
        );
      },
    );
    if (borderRadius == null) return image;
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}
