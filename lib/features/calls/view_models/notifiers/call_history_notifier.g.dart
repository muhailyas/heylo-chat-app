// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'call_history_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CallHistoryNotifier)
const callHistoryProvider = CallHistoryNotifierFamily._();

final class CallHistoryNotifierProvider
    extends $AsyncNotifierProvider<CallHistoryNotifier, List<CallRecord>> {
  const CallHistoryNotifierProvider._({
    required CallHistoryNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'callHistoryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$callHistoryNotifierHash();

  @override
  String toString() {
    return r'callHistoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CallHistoryNotifier create() => CallHistoryNotifier();

  @override
  bool operator ==(Object other) {
    return other is CallHistoryNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$callHistoryNotifierHash() =>
    r'602295d29508c90fa736a824f910daae0be7d96a';

final class CallHistoryNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          CallHistoryNotifier,
          AsyncValue<List<CallRecord>>,
          List<CallRecord>,
          FutureOr<List<CallRecord>>,
          String
        > {
  const CallHistoryNotifierFamily._()
    : super(
        retry: null,
        name: r'callHistoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CallHistoryNotifierProvider call(String userId) =>
      CallHistoryNotifierProvider._(argument: userId, from: this);

  @override
  String toString() => r'callHistoryProvider';
}

abstract class _$CallHistoryNotifier extends $AsyncNotifier<List<CallRecord>> {
  late final _$args = ref.$arg as String;
  String get userId => _$args;

  FutureOr<List<CallRecord>> build(String userId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<AsyncValue<List<CallRecord>>, List<CallRecord>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<CallRecord>>, List<CallRecord>>,
              AsyncValue<List<CallRecord>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
