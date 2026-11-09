import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/app_network_image.dart';
import 'package:food_delivery/core/widgets/shimmer_box.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/presentation/bloc/address_cubits.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Current delivery address; tap opens the address picker.
class AddressHeader extends StatelessWidget {
  const AddressHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<CurrentAddressCubit, Address?>(
      builder: (context, address) => Semantics(
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          onTap: () =>
              context.push(address == null ? Routes.addressPick : '${Routes.addresses}?select=1'),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: AppSpacing.minTouch),
            child: Row(
              children: [
                Icon(Icons.place_rounded, color: context.colors.primary),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.deliverTo, style: context.text.labelSmall),
                      Text(
                        address?.text ?? l10n.chooseAddress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleSmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Auto-scrolling promo carousel.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({required this.banners, super.key});

  final List<PromoBanner> banners;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_controller.hasClients || widget.banners.length < 2) return;
      _page = (_page + 1) % widget.banners.length;
      _controller.animateToPage(
        _page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 2.4,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final b = widget.banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: GestureDetector(
                  onTap: b.restaurantId == null
                      ? null
                      : () => context.push(Routes.restaurant(b.restaurantId!)),
                  child: AppNetworkImage(
                    url: b.imageUrl,
                    semanticLabel: context.l10n.bannerSemantics,
                    borderRadius: BorderRadius.circular(AppSpacing.radius),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.banners.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? context.colors.primary : context.colors.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontal list of categories; selecting one filters restaurants.
class CategoryList extends StatelessWidget {
  const CategoryList({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
    super.key,
  });

  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, i) {
          final c = categories[i];
          final selected = c.id == selectedId;
          return Semantics(
            button: true,
            selected: selected,
            label: c.name(lang),
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radius),
              onTap: () => onSelected(selected ? null : c.id),
              child: SizedBox(
                width: 76,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? context.colors.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(child: AppNetworkImage(url: c.iconUrl)),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      c.name(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(
                        color: selected ? context.colors.primary : null,
                        fontWeight: selected ? FontWeight.w700 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Skeleton for banners + categories.
class HomeHeaderSkeleton extends StatelessWidget {
  const HomeHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: AspectRatio(aspectRatio: 2.4, child: ShimmerBox(radius: AppSpacing.radius)),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            itemCount: 6,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (_, _) => const Column(
              children: [
                ShimmerBox(width: 64, height: 64, radius: 32),
                SizedBox(height: AppSpacing.xs),
                ShimmerBox(width: 56, height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
