import 'package:heylo/features/auth/view_model/notifiers/auth_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/session/session_store.dart';
import '../../../onboarding/data/onboarding_data.dart';
import '../state/splash_state.dart';

part 'splash_notifier.g.dart';

@Riverpod(keepAlive: true)
class SplashNotifier extends _$SplashNotifier {
  @override
  SplashState build() {
    return const SplashState();
  }

  Future<void> check({
    void Function({required bool showOnboarding, required bool isLoggedIn})?
    onDone,
  }) async {
    print('[SplashNotifier] Checking auth...');
    final seenOnboarding = await OnboardingStore.hasSeen();
    print('[SplashNotifier] seenOnboarding: $seenOnboarding');

    if (!seenOnboarding) {
      onDone?.call(showOnboarding: true, isLoggedIn: false);
      return;
    }

    final uid = await SessionStore.readUid();
    print('[SplashNotifier] readUid: $uid');

    if (uid == null) {
      onDone?.call(showOnboarding: false, isLoggedIn: false);
      return;
    }

    // Restore session via AuthNotifier (handles Zego Login)
    print('[SplashNotifier] Restoring session via AuthNotifier...');
    final ok = await ref.read(authProvider.notifier).restore(uid);
    print('[SplashNotifier] Restore result: $ok');

    onDone?.call(showOnboarding: false, isLoggedIn: ok);
  }
}
