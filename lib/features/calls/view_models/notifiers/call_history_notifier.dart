import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/call_record.dart';
import '../../repositories/call_history_repo.dart';

part 'call_history_notifier.g.dart';

@riverpod
class CallHistoryNotifier extends _$CallHistoryNotifier {
  late CallHistoryRepo _repo;
  @override
  FutureOr<List<CallRecord>> build(String userId) {
    _repo = CallHistoryRepo(Supabase.instance.client);

    // Subscribe to real-time updates for this user
    final channel = _repo.subscribeRealtime(userId, (payload) {
      // Small delay to ensure DB consistency before refresh
      Future.delayed(const Duration(milliseconds: 500), () {
        if (ref.mounted) {
          refresh();
        }
      });
    });

    ref.onDispose(() {
      Supabase.instance.client.removeChannel(channel);
    });

    return _repo.getHistory(userId);
  }

  Future<List<CallRecord>> refresh() async {
    if (!ref.mounted) return [];
    state = const AsyncValue.loading();
    final list = await _repo.getHistory(userId);
    if (ref.mounted) {
      state = AsyncValue.data(list);
    }
    return list;
  }

  /// Log a new call and return its ID
  Future<String?> logCall(CallRecord record) async {
    final id = await _repo.logCall(record);
    await refresh();
    return id;
  }

  /// Update an existing call record
  Future<void> updateCallRecord(
    String id, {
    DateTime? endedAt,
    int? durationSeconds,
    String? status,
  }) async {
    await _repo.updateCallRecord(
      id,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      status: status,
    );
    await refresh();
  }
}
