import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/network/connectivity_cubit.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/core/widgets/shimmer_box.dart';
import 'package:food_delivery/core/widgets/state_views.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/presentation/bloc/address_cubits.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:food_delivery/features/home/presentation/bloc/home_cubit.dart';
import 'package:food_delivery/features/home/presentation/bloc/restaurants_bloc.dart';
import 'package:food_delivery/features/home/presentation/widgets/filter_sheet.dart';
import 'package:food_delivery/features/home/presentation/widgets/home_widgets.dart';
import 'package:food_delivery/features/home/presentation/widgets/restaurant_card.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => getIt<HomeCubit>()..load()),
        BlocProvider(
          create: (_) => getIt<RestaurantsBloc>()..add(const RestaurantsEvent.started()),
        ),
      ],
      child: const HomeView(),
    );
  }
}

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 600) {
      context.read<RestaurantsBloc>().add(const RestaurantsEvent.nextPageRequested());
    }
  }

  Future<void> _refresh() async {
    final completer = Completer<void>();
    context.read<RestaurantsBloc>().add(RestaurantsEvent.refreshed(completer: completer));
    unawaited(context.read<HomeCubit>().load(silent: true));
    await completer.future;
  }

  void _setFilter(RestaurantFilter filter) =>
      context.read<RestaurantsBloc>().add(RestaurantsEvent.filterChanged(filter));

  Future<void> _openFilters(List<Category> categories) async {
    final current = context.read<RestaurantsBloc>().state.filter;
    final result = await showFilterSheet(context, initial: current, categories: categories);
    if (result != null && result != current) _setFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MultiBlocListener(
      listeners: [
        // Internet is back → refresh automatically.
        BlocListener<ConnectivityCubit, ConnectivityStatus>(
          listenWhen: (a, b) => a == ConnectivityStatus.offline && b == ConnectivityStatus.online,
          listener: (context, _) {
            context.read<HomeCubit>().load(silent: true);
            context.read<RestaurantsBloc>().add(const RestaurantsEvent.refreshed());
          },
        ),
        // Address changed → "nearest" sort depends on it.
        BlocListener<CurrentAddressCubit, Address?>(
          listenWhen: (a, b) => a?.location != b?.location,
          listener: (context, _) {
            final bloc = context.read<RestaurantsBloc>();
            if (bloc.state.filter.sort == RestaurantSort.nearest) {
              bloc.add(const RestaurantsEvent.refreshed());
            }
          },
        ),
      ],
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  sliver: SliverToBoxAdapter(child: AddressHeader()),
                ),
                SliverToBoxAdapter(child: _SearchRow(onFilters: _openFilters)),
                SliverToBoxAdapter(
                  child: BlocBuilder<HomeCubit, HomeState>(
                    builder: (context, state) => switch (state) {
                      HomeInitial() || HomeLoading() => const HomeHeaderSkeleton(),
                      HomeFailure() => const SizedBox.shrink(),
                      HomeSuccess(:final content) => Column(
                        children: [
                          BannerCarousel(banners: content.banners),
                          SectionTitle(l10n.categories),
                          BlocSelector<RestaurantsBloc, RestaurantsState, String?>(
                            selector: (s) => s.filter.categoryId,
                            builder: (context, selected) => CategoryList(
                              categories: content.categories,
                              selectedId: selected,
                              onSelected: (id) => _setFilter(
                                context.read<RestaurantsBloc>().state.filter.copyWith(
                                  categoryId: id,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    },
                  ),
                ),
                SliverToBoxAdapter(child: SectionTitle(l10n.restaurants)),
                const _RestaurantsSliver(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.onFilters});

  final ValueChanged<List<Category>> onFilters;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = switch (context.watch<HomeCubit>().state) {
      HomeSuccess(:final content) => content.categories,
      _ => <Category>[],
    };
    final activeFilters = context.select<RestaurantsBloc, int>((b) => b.state.filter.activeCount);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                onTap: () => context.go(Routes.search),
                child: Container(
                  height: AppSpacing.minTouch,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: context.colors.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.searchHint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Badge(
            isLabelVisible: activeFilters > 0,
            label: Text('$activeFilters'),
            child: IconButton.filledTonal(
              tooltip: l10n.filters,
              onPressed: () => onFilters(categories),
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantsSliver extends StatelessWidget {
  const _RestaurantsSliver();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<RestaurantsBloc>();
    return BlocBuilder<RestaurantsBloc, RestaurantsState>(
      builder: (context, state) => switch (state) {
        RestaurantsInitial() || RestaurantsLoading() => SliverList.builder(
          itemCount: 3,
          itemBuilder: (_, _) => const RestaurantCardSkeleton(),
        ),
        RestaurantsFailure(:final failure) => SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorView(
            failure: failure,
            onRetry: () => bloc.add(const RestaurantsEvent.started()),
          ),
        ),
        RestaurantsSuccess(:final items, :final filter) when items.isEmpty => SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyView(
            icon: Icons.storefront_rounded,
            title: l10n.emptyRestaurants,
            actionLabel: filter.isDefault ? null : l10n.emptyRestaurantsAction,
            onAction: () =>
                bloc.add(const RestaurantsEvent.filterChanged(RestaurantFilter.initial)),
          ),
        ),
        final RestaurantsSuccess s => SliverList.builder(
          itemCount: s.items.length + 2,
          itemBuilder: (context, i) {
            if (i == 0) {
              return s.fromCache
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Text(
                        l10n.showingCachedData,
                        style: context.text.bodySmall?.copyWith(color: context.appColors.warning),
                      ),
                    )
                  : const SizedBox.shrink();
            }
            if (i == s.items.length + 1) {
              return PaginationFooter(
                isLoading: s.isLoadingMore,
                hasError: s.loadMoreFailure != null,
                onRetry: () => bloc.add(const RestaurantsEvent.nextPageRequested()),
              );
            }
            final r = s.items[i - 1];
            return RestaurantCard(
              restaurant: r,
              onTap: () => context.push(Routes.restaurant(r.id)),
            );
          },
        ),
      },
    );
  }
}
