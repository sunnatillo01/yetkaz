import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/network/connectivity_cubit.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// Wraps the whole app and shows a banner on top while offline.
class NoInternetBanner extends StatelessWidget {
  const NoInternetBanner({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final offline = context.select<ConnectivityCubit, bool>(
      (c) => c.state == ConnectivityStatus.offline,
    );
    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: offline ? const _Banner() : const SizedBox(width: double.infinity),
        ),
        // The banner already covers the status bar: avoid double padding.
        Expanded(
          child: MediaQuery.removePadding(context: context, removeTop: offline, child: child),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Material(
      color: colors.offlineBanner,
      child: SafeArea(
        bottom: false,
        child: Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: colors.onOfflineBanner, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.l10n.noInternet,
                    style: context.text.bodyMedium?.copyWith(color: colors.onOfflineBanner),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
