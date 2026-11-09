import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:material_ui/material_ui.dart';

/// Returns the new filter, or `null` when dismissed.
Future<RestaurantFilter?> showFilterSheet(
  BuildContext context, {
  required RestaurantFilter initial,
  required List<Category> categories,
}) => showModalBottomSheet<RestaurantFilter>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => FilterSheet(initial: initial, categories: categories),
);

class FilterSheet extends StatefulWidget {
  const FilterSheet({required this.initial, required this.categories, super.key});

  final RestaurantFilter initial;
  final List<Category> categories;

  /// Delivery fee options (so'm); `0` = free.
  static const feeOptions = [0, 10000, 15000];

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late RestaurantFilter _filter = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.filters, style: context.text.titleLarge),
          _title(l10n.filterCategory),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: Text(l10n.all),
                selected: _filter.categoryId == null,
                onSelected: (_) => setState(() => _filter = _filter.copyWith(categoryId: null)),
              ),
              for (final c in widget.categories)
                ChoiceChip(
                  label: Text(c.name(lang)),
                  selected: _filter.categoryId == c.id,
                  onSelected: (_) => setState(() => _filter = _filter.copyWith(categoryId: c.id)),
                ),
            ],
          ),
          _title(l10n.filterRating),
          FilterChip(
            avatar: const Icon(Icons.star_rounded),
            label: Text(l10n.rating4Plus),
            selected: _filter.topRated,
            onSelected: (v) => setState(() => _filter = _filter.copyWith(topRated: v)),
          ),
          _title(l10n.filterDeliveryFee),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              ChoiceChip(
                label: Text(l10n.deliveryFeeAny),
                selected: _filter.maxDeliveryFee == null,
                onSelected: (_) => setState(() => _filter = _filter.copyWith(maxDeliveryFee: null)),
              ),
              for (final fee in FilterSheet.feeOptions)
                ChoiceChip(
                  label: Text(
                    fee == 0 ? l10n.deliveryFeeFree : l10n.deliveryFeeUpTo(context.money(fee)),
                  ),
                  selected: _filter.maxDeliveryFee == fee,
                  onSelected: (_) =>
                      setState(() => _filter = _filter.copyWith(maxDeliveryFee: fee)),
                ),
            ],
          ),
          _title(l10n.sortBy),
          SegmentedButton<RestaurantSort>(
            segments: [
              ButtonSegment(value: RestaurantSort.popular, label: Text(l10n.sortPopular)),
              ButtonSegment(value: RestaurantSort.nearest, label: Text(l10n.sortNearest)),
              ButtonSegment(value: RestaurantSort.rating, label: Text(l10n.sortRating)),
            ],
            selected: {_filter.sort},
            onSelectionChanged: (s) => setState(() => _filter = _filter.copyWith(sort: s.first)),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(RestaurantFilter.initial),
                  child: Text(l10n.resetFilters),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(_filter),
                  child: Text(l10n.applyFilters),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _title(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
    child: Text(text, style: context.text.titleSmall),
  );
}
