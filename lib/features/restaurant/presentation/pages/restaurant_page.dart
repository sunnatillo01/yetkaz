import 'dart:async';

import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/app_network_image.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/core/widgets/shimmer_box.dart';
import 'package:food_delivery/core/widgets/state_views.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:food_delivery/features/cart/presentation/widgets/add_to_cart_helper.dart';
import 'package:food_delivery/features/home/presentation/widgets/restaurant_card.dart';
import 'package:food_delivery/features/restaurant/domain/entities/menu_item.dart';
import 'package:food_delivery/features/restaurant/presentation/bloc/restaurant_cubits.dart';
import 'package:food_delivery/features/restaurant/presentation/widgets/dish_details_sheet.dart';
import 'package:food_delivery/features/restaurant/presentation/widgets/menu_item_card.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class RestaurantPage extends StatelessWidget {
  const RestaurantPage({required this.restaurantId, super.key});

  final String restaurantId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<RestaurantCubit>()..load(restaurantId),
      child: RestaurantView(restaurantId: restaurantId),
    );
  }
}

class RestaurantView extends StatelessWidget {
  const RestaurantView({required this.restaurantId, super.key});

  final String restaurantId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RestaurantCubit, RestaurantState>(
      builder: (context, state) => switch (state) {
        RestaurantInitial() || RestaurantLoading() => _LoadingView(id: restaurantId),
        RestaurantFailure(:final failure) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(failure: failure, onRetry: context.read<RestaurantCubit>().retry),
        ),
        RestaurantSuccess(:final details, :final isOpen) => _MenuView(
          details: details,
          isOpen: isOpen,
        ),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(tag: restaurantHeroTag(id), child: const ShimmerBox(radius: 0)),
            ),
          ),
          SliverList.builder(itemCount: 5, itemBuilder: (_, _) => const ListTileSkeleton()),
        ],
      ),
    );
  }
}

/// Menu with sticky section tabs. Tapping a tab scrolls to its section and
/// scrolling the list updates the active tab.
class _MenuView extends StatefulWidget {
  const _MenuView({required this.details, required this.isOpen});

  final RestaurantDetails details;
  final bool isOpen;

  @override
  State<_MenuView> createState() => _MenuViewState();
}

class _MenuViewState extends State<_MenuView> with SingleTickerProviderStateMixin {
  static const _expandedHeight = 240.0;
  static const _tabBarHeight = 48.0;

  final _scroll = ScrollController();
  late final TabController _tabs = TabController(
    length: widget.details.sections.length,
    vsync: this,
  );
  late final List<GlobalKey> _sectionKeys = [for (final _ in widget.details.sections) GlobalKey()];

  /// True while we animate the scroll after a tab tap, so the scroll
  /// listener does not fight the tab controller.
  bool _scrollingToTab = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_syncTabWithScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _tabs.dispose();
    super.dispose();
  }

  double get _pinnedHeight => MediaQuery.paddingOf(context).top + kToolbarHeight + _tabBarHeight;

  double? _sectionOffset(int index) {
    final ctx = _sectionKeys[index].currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero).dy;
  }

  void _syncTabWithScroll() {
    if (_scrollingToTab || _sectionKeys.isEmpty) return;
    var active = 0;
    for (var i = 0; i < _sectionKeys.length; i++) {
      final dy = _sectionOffset(i);
      if (dy != null && dy <= _pinnedHeight + 8) active = i;
    }
    if (_tabs.index != active) _tabs.animateTo(active);
  }

  Future<void> _scrollToSection(int index) async {
    final dy = _sectionOffset(index);
    if (dy == null) return;
    final target = (_scroll.offset + dy - _pinnedHeight).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scrollingToTab = true;
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
    _scrollingToTab = false;
  }

  Future<void> _add(MenuItem item) async {
    final restaurant = widget.details.restaurant.toCartRestaurant();
    if (item.options.isNotEmpty) {
      return showDishDetailsSheet(
        context,
        item: item,
        restaurant: restaurant,
        enabled: widget.isOpen,
      );
    }
    final dish = DishState(item: item);
    await addToCartWithConfirmation(context, restaurant, dish.toCartItem());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = widget.details.restaurant;
    final sections = widget.details.sections;
    return Scaffold(
      bottomNavigationBar: _CartBar(restaurantId: r.id),
      body: CustomScrollView(
        controller: _scroll,
        // Menus are small: keep every section laid out so tab taps can
        // always find their target.
        scrollCacheExtent: const ScrollCacheExtent.pixels(10000),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: _expandedHeight,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              background: Hero(
                tag: restaurantHeroTag(r.id),
                child: AppNetworkImage(url: r.imageUrl, semanticLabel: l10n.imageOf(r.name)),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _InfoBlock(details: widget.details, isOpen: widget.isOpen),
          ),
          if (sections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(icon: Icons.menu_book_rounded, title: l10n.menuEmpty),
            )
          else ...[
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                height: _tabBarHeight,
                child: Material(
                  color: context.colors.surface,
                  child: TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    onTap: _scrollToSection,
                    tabs: [for (final s in sections) Tab(text: s.title)],
                  ),
                ),
              ),
            ),
            for (var i = 0; i < sections.length; i++) ...[
              SliverToBoxAdapter(key: _sectionKeys[i], child: SectionTitle(sections[i].title)),
              SliverList.builder(
                itemCount: sections[i].items.length,
                itemBuilder: (context, j) {
                  final item = sections[i].items[j];
                  return BlocSelector<CartCubit, CartState, int>(
                    selector: (s) => s.cart.restaurant?.id == r.id ? s.cart.quantityOf(item.id) : 0,
                    builder: (context, qty) => MenuItemCard(
                      item: item,
                      quantityInCart: qty,
                      enabled: widget.isOpen,
                      onAdd: () => _add(item),
                      onTap: () => showDishDetailsSheet(
                        context,
                        item: item,
                        restaurant: r.toCartRestaurant(),
                        enabled: widget.isOpen,
                      ),
                    ),
                  );
                },
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.details, required this.isOpen});

  final RestaurantDetails details;
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = details.restaurant;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              RatingBadge(rating: r.rating),
              Text(l10n.minutesShort(r.deliveryTimeMin)),
              Text(r.hasFreeDelivery ? l10n.freeDelivery : context.money(r.deliveryFee)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.workingHours(r.openTime, r.closeTime), style: context.text.bodyMedium),
          Text(l10n.minOrderLabel(context.money(r.minOrder)), style: context.text.bodyMedium),
          if (!isOpen) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.colors.errorContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_clock_rounded, color: context.colors.onErrorContainer),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        l10n.closedWarning,
                        style: TextStyle(color: context.colors.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom bar "Cart · total" visible when the cart has dishes of this
/// restaurant.
class _CartBar extends StatelessWidget {
  const _CartBar({required this.restaurantId});

  final String restaurantId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      buildWhen: (a, b) => a.cart != b.cart,
      builder: (context, state) {
        final cart = state.cart;
        if (state is! CartSuccess || cart.isEmpty || cart.restaurant?.id != restaurantId) {
          return const SizedBox.shrink();
        }
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: FilledButton(
              onPressed: () => context.go(Routes.cart),
              child: Row(
                children: [
                  Text(context.l10n.itemsCount(cart.itemCount)),
                  const Spacer(),
                  Text(context.money(state.totals.subtotal)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      SizedBox.expand(child: child);

  @override
  bool shouldRebuild(covariant _TabBarDelegate old) => old.child != child;
}
