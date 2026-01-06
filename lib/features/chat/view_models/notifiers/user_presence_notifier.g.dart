// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_presence_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserPresence)
const userPresenceProvider = UserPresenceProvider._();

final class UserPresenceProvider
    extends $NotifierProvider<UserPresence, Map<String, bool>> {
  const UserPresenceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userPresenceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userPresenceHash();

  @$internal
  @override
  UserPresence create() => UserPresence();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, bool> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, bool>>(value),
    );
  }
}

String _$userPresenceHash() => r'bcf599f4f7e594ea397b76f561b982a992474bc1';

abstract class _$UserPresence extends $Notifier<Map<String, bool>> {
  Map<String, bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Map<String, bool>, Map<String, bool>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, bool>, Map<String, bool>>,
              Map<String, bool>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
