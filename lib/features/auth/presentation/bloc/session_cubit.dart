import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:food_delivery/features/auth/domain/entities/app_user.dart';
import 'package:food_delivery/features/auth/domain/usecases/auth_usecases.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';

part 'session_cubit.freezed.dart';

@freezed
sealed class SessionState with _$SessionState {
  /// Not resolved yet (splash is visible).
  const factory SessionState.initial() = SessionInitial;
  const factory SessionState.unauthenticated() = SessionUnauthenticated;

  /// Signed in by phone but the name has not been entered yet.
  const factory SessionState.profileRequired(AppUser user) = SessionProfileRequired;
  const factory SessionState.authenticated(AppUser user) = SessionAuthenticated;
}

/// Global auth state. The router listens to it for redirects.
@lazySingleton
class SessionCubit extends Cubit<SessionState> {
  SessionCubit(this._watchSession, this._getCurrentSession) : super(const SessionState.initial());

  final WatchSession _watchSession;
  final GetCurrentSession _getCurrentSession;
  StreamSubscription<AppUser?>? _subscription;

  /// Resolves the current session once, then keeps listening for changes.
  Future<void> start() async {
    _emitFor(await _getCurrentSession());
    await _subscription?.cancel();
    _subscription = _watchSession().listen(_emitFor);
  }

  Future<void> refresh() async => _emitFor(await _getCurrentSession());

  void _emitFor(AppUser? user) {
    if (isClosed) return;
    emit(switch (user) {
      null => const SessionState.unauthenticated(),
      final u when !u.hasProfile => SessionState.profileRequired(u),
      final u => SessionState.authenticated(u),
    });
  }

  AppUser? get user => switch (state) {
    SessionAuthenticated(:final user) => user,
    SessionProfileRequired(:final user) => user,
    _ => null,
  };

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
