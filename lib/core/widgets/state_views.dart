import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Round illustration used by empty / error states.
class StateIllustration extends StatelessWidget {
  const StateIllustration({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: context.appColors.illustrationBackground,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 56, color: context.colors.primary),
      ),
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({required this.icon, required this.title, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StateIllustration(icon: icon),
            const SizedBox(height: AppSpacing.xl),
            Text(title, textAlign: TextAlign.center, style: context.text.titleMedium),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state: reason-specific message + "Try again".
class ErrorView extends StatelessWidget {
  const ErrorView({required this.failure, this.onRetry, super.key});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      icon: failure.icon,
      title: failure.message(context.l10n),
      actionLabel: context.l10n.retry,
      onAction: onRetry,
    );
  }
}

/// Empty state: illustration + text + action button.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) =>
      _StateLayout(icon: icon, title: title, actionLabel: actionLabel, onAction: onAction);
}

/// Footer at the end of a paginated list: loader or small "Reload" button.
class PaginationFooter extends StatelessWidget {
  const PaginationFooter({
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    super.key,
  });

  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          children: [
            Text(context.l10n.loadMoreError, style: context.text.bodySmall),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.reload),
            ),
          ],
        ),
      );
    }
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: SizedBox.square(dimension: 28, child: CircularProgressIndicator(strokeWidth: 3)),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }
}
