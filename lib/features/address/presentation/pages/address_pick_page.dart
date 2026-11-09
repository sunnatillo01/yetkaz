import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/di/injection.dart';
import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/extensions/context_extensions.dart';
import 'package:food_delivery/core/theme/app_theme.dart';
import 'package:food_delivery/core/widgets/common_widgets.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/presentation/bloc/address_cubits.dart';
import 'package:food_delivery/features/address/presentation/widgets/address_label_text.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:material_ui/material_ui.dart';

class AddressPickPage extends StatelessWidget {
  const AddressPickPage({this.initial, super.key});

  /// Address being edited, or `null` for a new one.
  final Address? initial;

  @override
  Widget build(BuildContext context) {
    final language = Localizations.localeOf(context).languageCode;
    return BlocProvider(
      create: (_) => getIt<AddressPickerCubit>()..init(initial: initial, languageCode: language),
      child: AddressPickView(initial: initial),
    );
  }
}

class AddressPickView extends StatefulWidget {
  const AddressPickView({this.initial, super.key});

  final Address? initial;

  @override
  State<AddressPickView> createState() => _AddressPickViewState();
}

class _AddressPickViewState extends State<AddressPickView> {
  GoogleMapController? _map;
  late final _entrance = TextEditingController(text: widget.initial?.entrance);
  late final _floor = TextEditingController(text: widget.initial?.floor);
  late final _apartment = TextEditingController(text: widget.initial?.apartment);
  late final _note = TextEditingController(text: widget.initial?.note);
  late AddressLabel _label = widget.initial?.label ?? AddressLabel.home;
  Coordinates _cameraCenter = Coordinates.tashkent;

  @override
  void dispose() {
    _entrance.dispose();
    _floor.dispose();
    _apartment.dispose();
    _note.dispose();
    _map?.dispose();
    super.dispose();
  }

  void _save() {
    context.read<AddressPickerCubit>().save(
      (widget.initial ?? const Address(location: Coordinates.tashkent, text: '')).copyWith(
        label: _label,
        entrance: _entrance.text.trim(),
        floor: _floor.text.trim(),
        apartment: _apartment.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final start = widget.initial?.location ?? Coordinates.tashkent;
    return BlocConsumer<AddressPickerCubit, AddressPickerState>(
      listenWhen: (a, b) =>
          a.cameraTarget != b.cameraTarget || a.failure != b.failure || a.saved != b.saved,
      listener: (context, state) {
        final target = state.cameraTarget;
        if (target != null && target != _cameraCenter) {
          unawaited(
            _map?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(target.lat, target.lng), 16)),
          );
        }
        if (state.saved != null) {
          context.read<CurrentAddressCubit>().select(state.saved!);
          context.pop(state.saved);
        }
        final failure = state.failure;
        if (failure is LocationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(failure.message(l10n)),
              action: SnackBarAction(
                label: l10n.openSettings,
                onPressed: context.read<AddressPickerCubit>().openSettings,
              ),
            ),
          );
        } else if (failure != null) {
          context.showSnack(failure.message(l10n));
        }
      },
      builder: (context, state) {
        final cubit = context.read<AddressPickerCubit>();
        return Scaffold(
          appBar: AppBar(title: Text(l10n.pickAddressTitle)),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(start.lat, start.lng),
                        zoom: 15,
                      ),
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      onMapCreated: (c) => _map = c,
                      onCameraMoveStarted: cubit.cameraMoving,
                      onCameraMove: (p) => _cameraCenter = Coordinates(
                        lat: p.target.latitude,
                        lng: p.target.longitude,
                      ),
                      onCameraIdle: () => cubit.cameraIdle(_cameraCenter),
                    ),
                    // Pin stays in the centre; its tip marks the location.
                    IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: AnimatedSlide(
                          duration: const Duration(milliseconds: 150),
                          offset: state.isResolving ? const Offset(0, -0.15) : Offset.zero,
                          child: Icon(Icons.location_pin, size: 48, color: context.colors.primary),
                        ),
                      ),
                    ),
                    Positioned(
                      right: AppSpacing.lg,
                      bottom: AppSpacing.lg,
                      child: FloatingActionButton.small(
                        heroTag: 'my-location',
                        tooltip: l10n.myLocation,
                        onPressed: state.isLocating ? null : cubit.locateMe,
                        child: state.isLocating
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.my_location_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              _DetailsPanel(
                state: state,
                label: _label,
                onLabelChanged: (l) => setState(() => _label = l),
                entrance: _entrance,
                floor: _floor,
                apartment: _apartment,
                note: _note,
                onSave: _save,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({
    required this.state,
    required this.label,
    required this.onLabelChanged,
    required this.entrance,
    required this.floor,
    required this.apartment,
    required this.note,
    required this.onSave,
  });

  final AddressPickerState state;
  final AddressLabel label;
  final ValueChanged<AddressLabel> onLabelChanged;
  final TextEditingController entrance;
  final TextEditingController floor;
  final TextEditingController apartment;
  final TextEditingController note;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = state.addressText;
    return Material(
      elevation: 8,
      color: context.colors.surface,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.5),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.place_outlined, color: context.colors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        state.isResolving || text == null || text.isEmpty
                            ? l10n.determiningAddress
                            : text,
                        style: context.text.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final l in AddressLabel.values)
                      ChoiceChip(
                        avatar: Icon(l.icon, size: 18),
                        label: Text(l.title(context)),
                        selected: l == label,
                        onSelected: (_) => onLabelChanged(l),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(child: _field(entrance, l10n.entrance, number: true)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _field(floor, l10n.floor, number: true)),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _field(apartment, l10n.apartment, number: true)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _field(note, l10n.addressNote),
                const SizedBox(height: AppSpacing.lg),
                LoadingButton(
                  label: l10n.confirmAddress,
                  isLoading: state.isSaving,
                  onPressed: state.isResolving || (text ?? '').isEmpty ? null : onSave,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool number = false}) => TextField(
    controller: c,
    keyboardType: number ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(labelText: label, isDense: true),
  );
}
