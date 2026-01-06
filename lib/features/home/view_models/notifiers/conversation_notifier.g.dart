// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'conversation_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ConversationNotifier)
const conversationProvider = ConversationNotifierProvider._();

final class ConversationNotifierProvider
    extends
        $AsyncNotifierProvider<ConversationNotifier, ConversationListState> {
  const ConversationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationNotifierHash();

  @$internal
  @override
  ConversationNotifier create() => ConversationNotifier();
}

String _$conversationNotifierHash() =>
    r'421a18ff0485d857b936614eb73c4a06a5e3a285';

abstract class _$ConversationNotifier
    extends $AsyncNotifier<ConversationListState> {
  FutureOr<ConversationListState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<AsyncValue<ConversationListState>, ConversationListState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ConversationListState>,
                ConversationListState
              >,
              AsyncValue<ConversationListState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
