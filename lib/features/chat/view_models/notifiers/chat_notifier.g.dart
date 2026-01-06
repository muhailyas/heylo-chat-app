// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ChatNotifier)
const chatProvider = ChatNotifierFamily._();

final class ChatNotifierProvider
    extends $NotifierProvider<ChatNotifier, ChatRoomState> {
  const ChatNotifierProvider._({
    required ChatNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatNotifierHash();

  @override
  String toString() {
    return r'chatProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChatNotifier create() => ChatNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatRoomState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatRoomState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatNotifierHash() => r'b612fcc464dd6b10038df5c61bee3f61e91f645d';

final class ChatNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ChatNotifier,
          ChatRoomState,
          ChatRoomState,
          ChatRoomState,
          String
        > {
  const ChatNotifierFamily._()
    : super(
        retry: null,
        name: r'chatProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ChatNotifierProvider call(String roomId) =>
      ChatNotifierProvider._(argument: roomId, from: this);

  @override
  String toString() => r'chatProvider';
}

abstract class _$ChatNotifier extends $Notifier<ChatRoomState> {
  late final _$args = ref.$arg as String;
  String get roomId => _$args;

  ChatRoomState build(String roomId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<ChatRoomState, ChatRoomState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatRoomState, ChatRoomState>,
              ChatRoomState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
