import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/router/routes.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/core/widgets/shimmer_box.dart';
import 'package:food_delivery/core/widgets/state_views.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/presentation/bloc/address_cubits.dart';
import 'package:food_delivery/features/address/presentation/widgets/address_label_text.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

class SavedAddressesPage extends StatelessWidget {
  const SavedAddressesPage({this.selectMode = false, super.key});

  /// When `true`, tapping an address selects it and closes the screen.
  final bool selectMode;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SavedAddressesCubit>()..start(),
      child: SavedAddressesView(selectMode: selectMode),
    );
  }
}

class SavedAddressesView extends StatelessWidget {
  const SavedAddressesView({this.selectMode = false, super.key});

  final bool selectMode;

  Future<void> _delete(BuildContext context, Address address) async {
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteAddressQuestion,
      confirmLabel: l10n.delete,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final failure = await context.read<SavedAddressesCubit>().delete(address.id!);
    if (failure != null && context.mounted) {
      context.showSnack(failure.message(l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = context.watch<CurrentAddressCubit>().state;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.savedAddresses)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.addressPick),
        icon: const Icon(Icons.add_location_alt_rounded),
        label: Text(l10n.addAddress),
      ),
      body: BlocBuilder<SavedAddressesCubit, SavedAddressesState>(
        builder: (context, state) => switch (state) {
          SavedAddressesInitial() || SavedAddressesLoading() => const SkeletonList(),
          SavedAddressesFailure(:final failure) => ErrorView(
            failure: failure,
            onRetry: context.read<SavedAddressesCubit>().start,
          ),
          SavedAddressesSuccess(:final addresses) when addresses.isEmpty => EmptyView(
            icon: Icons.location_off_rounded,
            title: l10n.noSavedAddresses,
            actionLabel: l10n.addAddress,
            onAction: () => context.push(Routes.addressPick),
          ),
          SavedAddressesSuccess(:final addresses) => ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: addresses.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final a = addresses[i];
              return ListTile(
                leading: Icon(a.label.icon),
                title: Text(a.label.title(context)),
                subtitle: Text(
                  [a.text, ...a.details].join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                selected: current?.id == a.id,
                onTap: () {
                  context.read<CurrentAddressCubit>().select(a);
                  if (selectMode) context.pop(a);
                },
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: l10n.edit,
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => context.push(Routes.addressPick, extra: a),
                    ),
                    IconButton(
                      tooltip: l10n.delete,
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _delete(context, a),
                    ),
                  ],
                ),
              );
            },
          ),
        },
      ),
    );
  }
}
