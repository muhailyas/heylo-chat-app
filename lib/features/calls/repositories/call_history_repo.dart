import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/call_record.dart';

class CallHistoryRepo {
  CallHistoryRepo(this._client);
  final SupabaseClient _client;

  static const String _table = 'call_records';

  /// Insert a new call record
  Future<String?> logCall(CallRecord record) async {
    try {
      final json = record.toJson();
      // Use upsert on zego_call_id to avoid duplicates from caller/receiver both logging
      final response = await _client
          .from(_table)
          .upsert(
            json,
            onConflict: json['zego_call_id'] != null ? 'zego_call_id' : null,
          )
          .select('id')
          .single();
      return response['id'] as String?;
    } catch (e) {
      print('[CallHistoryRepo] Error logging call: $e');
      rethrow;
    }
  }

  /// Update an existing call record (e.g., to set end time and duration)
  Future<void> updateCallRecord(
    String id, {
    DateTime? endedAt,
    int? durationSeconds,
    String? status,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (endedAt != null) updates['ended_at'] = endedAt.toIso8601String();
      if (durationSeconds != null)
        updates['duration_seconds'] = durationSeconds;
      if (status != null) updates['status'] = status;

      if (updates.isEmpty) return;

      await _client.from(_table).update(updates).eq('id', id);
    } catch (e) {
      print('[CallHistoryRepo] Error updating call record: $e');
      rethrow;
    }
  }

  /// Get call history for a specific user
  Future<List<CallRecord>> getHistory(String userId) async {
    try {
      final res = await _client
          .from(_table)
          .select()
          .or('caller_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at', ascending: false);

      return (res as List).map((json) => CallRecord.fromJson(json)).toList();
    } catch (e) {
      print('[CallHistoryRepo] Error fetching call history: $e');
      rethrow;
    }
  }

  /// Get a specific call record by ID
  Future<CallRecord?> getRecord(String id) async {
    try {
      final res = await _client
          .from(_table)
          .select()
          .eq('id', id)
          .maybeSingle();

      if (res == null) return null;
      return CallRecord.fromJson(res);
    } catch (e) {
      print('[CallHistoryRepo] Error fetching record: $e');
      return null;
    }
  }

  /// Get call history stream for a user
  Stream<List<CallRecord>> getHistoryStream(String userId) {
    return _client.from(_table).stream(primaryKey: ['id']).map((list) {
      return list
          .where(
            (json) =>
                json['caller_id'] == userId || json['receiver_id'] == userId,
          )
          .map((json) => CallRecord.fromJson(json))
          .toList();
    });
  }

  RealtimeChannel subscribeRealtime(
    String userId,
    Function(Map<String, dynamic>) onChange,
  ) {
    return _client
        .channel('public:call_records_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) {
            onChange(payload.newRecord);
          },
        )
        .subscribe();
  }
}
