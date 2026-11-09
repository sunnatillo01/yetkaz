import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Bottom navigation with 4 tabs; each tab keeps its own navigation stack
/// (`StatefulShellRoute.indexedStack`).
class AppShell extends StatefulWidget {
  const AppShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastBackPress;

  static const _exitWindow = Duration(seconds: 2);

  /// Back on Home root: first press shows a hint, second press exits.
  /// Back on another tab's root: go to Home.
  void _onBack() {
    if (widget.shell.currentIndex != 0) {
      widget.shell.goBranch(0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackPress != null && now.difference(_lastBackPress!) < _exitWindow) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPress = now;
    context.showSnack(context.l10n.pressBackAgainToExit);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        body: widget.shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.shell.currentIndex,
          onDestinationSelected: (i) => widget.shell.goBranch(
            i,
            // Tapping the active tab returns to its root.
            initialLocation: i == widget.shell.currentIndex,
          ),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l10n.tabHome,
            ),
            NavigationDestination(icon: const Icon(Icons.search_rounded), label: l10n.tabSearch),
            NavigationDestination(
              icon: const _CartIcon(selected: false),
              selectedIcon: const _CartIcon(selected: true),
              label: l10n.tabCart,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: l10n.tabProfile,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cart icon with the number of dishes as a badge.
class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CartCubit, CartState, int>(
      selector: (state) => state.cart.itemCount,
      builder: (context, count) => Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: Icon(selected ? Icons.shopping_bag_rounded : Icons.shopping_bag_outlined),
      ),
    );
  }
}
