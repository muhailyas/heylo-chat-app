// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LocalContacts)
const localContactsProvider = LocalContactsProvider._();

final class LocalContactsProvider
    extends $AsyncNotifierProvider<LocalContacts, Map<String, String>> {
  const LocalContactsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localContactsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localContactsHash();

  @$internal
  @override
  LocalContacts create() => LocalContacts();
}

String _$localContactsHash() => r'241dd8b12ae373ba39bb23a051f3343ed6d1a56a';

abstract class _$LocalContacts extends $AsyncNotifier<Map<String, String>> {
  FutureOr<Map<String, String>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<Map<String, String>>, Map<String, String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Map<String, String>>, Map<String, String>>,
              AsyncValue<Map<String, String>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
