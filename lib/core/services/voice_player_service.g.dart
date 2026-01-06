// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'voice_player_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(VoicePlayerService)
const voicePlayerServiceProvider = VoicePlayerServiceProvider._();

final class VoicePlayerServiceProvider
    extends $NotifierProvider<VoicePlayerService, VoicePlayerState> {
  const VoicePlayerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'voicePlayerServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$voicePlayerServiceHash();

  @$internal
  @override
  VoicePlayerService create() => VoicePlayerService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(VoicePlayerState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<VoicePlayerState>(value),
    );
  }
}

String _$voicePlayerServiceHash() =>
    r'57eaf84560261d1850a6c7f6f8aaa328d6268642';

abstract class _$VoicePlayerService extends $Notifier<VoicePlayerState> {
  VoicePlayerState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<VoicePlayerState, VoicePlayerState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<VoicePlayerState, VoicePlayerState>,
              VoicePlayerState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
