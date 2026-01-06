// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_creator_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ChatRepository)
const chatRepositoryProvider = ChatRepositoryProvider._();

final class ChatRepositoryProvider
    extends $NotifierProvider<ChatRepository, ChatRepo> {
  const ChatRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatRepositoryHash();

  @$internal
  @override
  ChatRepository create() => ChatRepository();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatRepo value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatRepo>(value),
    );
  }
}

String _$chatRepositoryHash() => r'43418b10b7862d29d706469dbca6f86821bcd5c3';

abstract class _$ChatRepository extends $Notifier<ChatRepo> {
  ChatRepo build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ChatRepo, ChatRepo>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatRepo, ChatRepo>,
              ChatRepo,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(ChatCreatorNotifier)
const chatCreatorProvider = ChatCreatorNotifierProvider._();

final class ChatCreatorNotifierProvider
    extends $NotifierProvider<ChatCreatorNotifier, ChatCreateState> {
  const ChatCreatorNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatCreatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatCreatorNotifierHash();

  @$internal
  @override
  ChatCreatorNotifier create() => ChatCreatorNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatCreateState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatCreateState>(value),
    );
  }
}

String _$chatCreatorNotifierHash() =>
    r'ce5c7f4207faab7152806ab4219acd8901f6288a';

abstract class _$ChatCreatorNotifier extends $Notifier<ChatCreateState> {
  ChatCreateState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ChatCreateState, ChatCreateState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatCreateState, ChatCreateState>,
              ChatCreateState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
