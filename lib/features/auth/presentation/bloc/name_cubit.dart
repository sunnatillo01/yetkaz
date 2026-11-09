import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/features/auth/domain/entities/app_user.dart';
import 'package:food_delivery/features/auth/domain/usecases/auth_usecases.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'name_cubit.freezed.dart';

@freezed
sealed class NameState with _$NameState {
  const factory NameState.initial() = NameInitial;
  const factory NameState.loading() = NameLoading;
  const factory NameState.success(AppUser user) = NameSuccess;
  const factory NameState.failure(Failure failure) = NameFailure;
}

@injectable
class NameCubit extends Cubit<NameState> {
  NameCubit(this._createProfile) : super(const NameState.initial());

  final CreateProfile _createProfile;

  Future<void> submit(String name) async {
    if (state is NameLoading) return;
    emit(const NameState.loading());
    final result = await _createProfile(name);
    if (isClosed) return;
    emit(result.fold(NameState.failure, NameState.success));
  }
}
