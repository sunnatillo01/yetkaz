import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/core/widgets/shimmer_box.dart';
import 'package:food_delivery/core/widgets/state_views.dart';
import 'package:food_delivery/features/home/presentation/widgets/restaurant_card.dart';
import 'package:food_delivery/features/search/presentation/bloc/search_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SearchBloc>()..add(const SearchEvent.started()),
      child: const SearchView(),
    );
  }
}

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _useHistory(String query) {
    _controller
      ..text = query
      ..selection = TextSelection.collapsed(offset: query.length);
    context.read<SearchBloc>().add(SearchEvent.submitted(query));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<SearchBloc>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: AppSpacing.lg,
        title: TextField(
          controller: _controller,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: l10n.clearHistory,
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        bloc.add(const SearchEvent.queryChanged(''));
                      },
                    ),
            ),
          ),
          onChanged: (q) => bloc.add(SearchEvent.queryChanged(q)),
          onSubmitted: (q) => bloc.add(SearchEvent.submitted(q)),
        ),
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) => switch (state) {
          SearchInitial(:final history) when history.isEmpty => EmptyView(
            icon: Icons.manage_search_rounded,
            title: l10n.searchStart,
          ),
          SearchInitial(:final history) => ListView(
            children: [
              SectionTitle(
                l10n.recentSearches,
                trailing: TextButton(
                  onPressed: () => bloc.add(const SearchEvent.historyCleared()),
                  child: Text(l10n.clearHistory),
                ),
              ),
              for (final q in history)
                ListTile(
                  leading: const Icon(Icons.history_rounded),
                  title: Text(q),
                  onTap: () => _useHistory(q),
                ),
            ],
          ),
          SearchLoading() => const SkeletonList(itemCount: 3, restaurant: true),
          SearchFailure(:final failure, :final query) => ErrorView(
            failure: failure,
            onRetry: () => bloc.add(SearchEvent.submitted(query)),
          ),
          SearchSuccess(:final results, :final query) when results.isEmpty => EmptyView(
            icon: Icons.search_off_rounded,
            title: l10n.searchEmpty(query),
          ),
          SearchSuccess(:final results) => ListView.builder(
            itemCount: results.length,
            itemBuilder: (context, i) => RestaurantCard(
              restaurant: results[i],
              onTap: () => context.push(Routes.restaurant(results[i].id)),
            ),
          ),
        },
      ),
    );
  }
}
