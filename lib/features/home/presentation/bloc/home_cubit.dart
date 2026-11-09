import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/usecase/usecase.dart';
import 'package:food_delivery/features/home/domain/entities/home_entities.dart';
import 'package:food_delivery/features/home/domain/usecases/home_usecases.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'home_cubit.freezed.dart';

@freezed
sealed class HomeState with _$HomeState {
  const factory HomeState.initial() = HomeInitial;
  const factory HomeState.loading() = HomeLoading;
  const factory HomeState.success(HomeContent content) = HomeSuccess;
  const factory HomeState.failure(Failure failure) = HomeFailure;
}

/// Banners + categories of the home screen.
@injectable
class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._getHomeContent) : super(const HomeState.initial());

  final GetHomeContent _getHomeContent;

  Future<void> load({bool silent = false}) async {
    if (!silent || state is! HomeSuccess) emit(const HomeState.loading());
    final result = await _getHomeContent(const NoParams());
    if (isClosed) return;
    result.fold(
      // Keep showing old content if a silent refresh fails.
      (f) => state is HomeSuccess && silent ? null : emit(HomeState.failure(f)),
      (content) => emit(HomeState.success(content)),
    );
  }
}
