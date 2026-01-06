// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_chat_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NewChatNotifier)
const newChatProvider = NewChatNotifierProvider._();

final class NewChatNotifierProvider
    extends $NotifierProvider<NewChatNotifier, NewChatState> {
  const NewChatNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'newChatProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$newChatNotifierHash();

  @$internal
  @override
  NewChatNotifier create() => NewChatNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NewChatState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NewChatState>(value),
    );
  }
}

String _$newChatNotifierHash() => r'700e6fd5bda640ab24d5a68a6463e134c0b4cb25';

abstract class _$NewChatNotifier extends $Notifier<NewChatState> {
  NewChatState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<NewChatState, NewChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NewChatState, NewChatState>,
              NewChatState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
