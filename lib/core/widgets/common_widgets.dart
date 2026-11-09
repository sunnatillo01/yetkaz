import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Filled button with an inline progress indicator.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(label),
      ),
    );
  }
}

/// `– 2 +` stepper with 48dp touch targets.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    required this.quantity,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.compact = false,
    super.key,
  });

  final int quantity;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.decreaseQuantity,
            visualDensity: compact ? VisualDensity.compact : null,
            onPressed: quantity > min ? () => onChanged(quantity - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Semantics(liveRegion: true, child: Text('$quantity', style: context.text.titleMedium)),
          IconButton(
            tooltip: l10n.increaseQuantity,
            visualDensity: compact ? VisualDensity.compact : null,
            onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

/// Star + rating number.
class RatingBadge extends StatelessWidget {
  const RatingBadge({required this.rating, super.key});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final value = rating.toStringAsFixed(1);
    return Semantics(
      label: context.l10n.ratingSemantics(value),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 18, color: context.appColors.rating),
          const SizedBox(width: 2),
          Text(value, style: context.text.labelLarge),
        ],
      ),
    );
  }
}

/// Yes/No confirmation dialog. Returns `true` when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final l10n = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.no)),
        TextButton(
          style: destructive ? TextButton.styleFrom(foregroundColor: context.colors.error) : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel ?? l10n.yes),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Section title used across screens.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: context.text.titleLarge)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
