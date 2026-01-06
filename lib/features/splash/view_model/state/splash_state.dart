// Freezed SplashState (generated, similar to AuthState)
// File: lib/features/splash/view_model/state/splash_state.dart

import 'package:freezed_annotation/freezed_annotation.dart';

part 'splash_state.freezed.dart';

@freezed
sealed class SplashState with _$SplashState {
  const factory SplashState({
    @Default(true) bool isLoading,
    @Default(false) bool isLoggedIn,
  }) = _SplashState;
}
