import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/core/utils/debouncer.dart';
import 'package:food_delivery/features/address/domain/entities/address.dart';
import 'package:food_delivery/features/address/domain/repositories/address_repository.dart';
import 'package:food_delivery/features/address/domain/usecases/address_usecases.dart';
import 'package:fpdart/fpdart.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'address_cubits.freezed.dart';

/// Currently selected delivery address (shown in the home header and
/// used by checkout).
@lazySingleton
class CurrentAddressCubit extends Cubit<Address?> {
  CurrentAddressCubit(this._getCurrent, this._select) : super(null);

  final GetCurrentAddress _getCurrent;
  final SelectAddress _select;

  void load() => emit(_getCurrent());

  Future<void> select(Address address) async {
    await _select(address);
    emit(address);
  }

  void reset() => emit(null);
}

@freezed
sealed class SavedAddressesState with _$SavedAddressesState {
  const factory SavedAddressesState.initial() = SavedAddressesInitial;
  const factory SavedAddressesState.loading() = SavedAddressesLoading;
  const factory SavedAddressesState.success(List<Address> addresses) = SavedAddressesSuccess;
  const factory SavedAddressesState.failure(Failure failure) = SavedAddressesFailure;
}

@injectable
class SavedAddressesCubit extends Cubit<SavedAddressesState> {
  SavedAddressesCubit(this._watch, this._delete) : super(const SavedAddressesState.initial());

  final WatchSavedAddresses _watch;
  final DeleteAddress _delete;
  StreamSubscription<Either<Failure, List<Address>>>? _subscription;

  Future<void> start() async {
    emit(const SavedAddressesState.loading());
    await _subscription?.cancel();
    _subscription = _watch().listen(
      (result) => emit(result.fold(SavedAddressesState.failure, SavedAddressesState.success)),
    );
  }

  Future<Failure?> delete(String id) async {
    final result = await _delete(id);
    return result.fold((f) => f, (_) => null);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}

@freezed
abstract class AddressPickerState with _$AddressPickerState {
  const factory AddressPickerState({
    required Coordinates center,
    String? addressText,
    @Default(false) bool isResolving,
    @Default(false) bool isLocating,
    @Default(false) bool isSaving,
    Failure? failure,

    /// Set when the camera must move programmatically (e.g. "my location").
    Coordinates? cameraTarget,
    Address? saved,
  }) = _AddressPickerState;
}

/// Map screen: the pin stays in the centre, moving the map re-resolves
/// the street address via reverse geocoding (debounced).
@injectable
class AddressPickerCubit extends Cubit<AddressPickerState> {
  AddressPickerCubit(this._getMyLocation, this._resolve, this._save, this._repo)
    : super(const AddressPickerState(center: Coordinates.tashkent));

  final GetMyLocation _getMyLocation;
  final ResolveAddress _resolve;
  final SaveAddress _save;
  final LocationRepository _repo;
  final _debouncer = Debouncer(const Duration(milliseconds: 500));
  String? _languageCode;
  int _resolveRequest = 0;

  void init({Address? initial, String? languageCode}) {
    _languageCode = languageCode;
    if (initial != null) {
      emit(
        state.copyWith(
          center: initial.location,
          addressText: initial.text,
          cameraTarget: initial.location,
        ),
      );
    } else {
      unawaited(locateMe(silent: true));
    }
  }

  void cameraMoving() => emit(state.copyWith(isResolving: true, failure: null));

  void cameraIdle(Coordinates center) {
    emit(state.copyWith(center: center, isResolving: true));
    _debouncer.run(() => unawaited(_resolveAddress(center)));
  }

  Future<void> _resolveAddress(Coordinates point) async {
    final request = ++_resolveRequest;
    final result = await _resolve(point, languageCode: _languageCode);
    // Ignore stale results when the user kept moving the map.
    if (isClosed || request != _resolveRequest) return;
    emit(
      state.copyWith(
        isResolving: false,
        addressText: result.getOrElse((_) => state.addressText ?? ''),
      ),
    );
  }

  /// [silent] — do not show an error on first open if permission is missing.
  Future<void> locateMe({bool silent = false}) async {
    emit(state.copyWith(isLocating: true, failure: null));
    final result = await _getMyLocation(const NoParams());
    if (isClosed) return;
    result.fold((f) => emit(state.copyWith(isLocating: false, failure: silent ? null : f)), (
      point,
    ) {
      emit(state.copyWith(isLocating: false, cameraTarget: point, center: point));
      unawaited(_resolveAddress(point));
    });
  }

  Future<void> openSettings() async {
    final failure = state.failure;
    if (failure is LocationFailure && failure.code == LocationErrorCode.serviceDisabled) {
      await _repo.openLocationSettings();
    } else {
      await _repo.openAppSettings();
    }
  }

  Future<void> save(Address draft) async {
    if (state.isSaving) return;
    emit(state.copyWith(isSaving: true, failure: null));
    final result = await _save(
      draft.copyWith(location: state.center, text: state.addressText ?? draft.text),
    );
    if (isClosed) return;
    result.fold(
      (f) => emit(state.copyWith(isSaving: false, failure: f)),
      (saved) => emit(state.copyWith(isSaving: false, saved: saved)),
    );
  }

  @override
  Future<void> close() {
    _debouncer.dispose();
    return super.close();
  }
}
