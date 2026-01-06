class CallRecord {
  final String? id;
  final String callerId;
  final String receiverId;
  final String callType;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String? zegoCallId;

  const CallRecord({
    this.id,
    required this.callerId,
    required this.receiverId,
    required this.callType,
    required this.status,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.zegoCallId,
  });

  /// O(n) where n = number of fields
  factory CallRecord.fromJson(Map<String, dynamic> map) {
    if (map.isEmpty) {
      throw ArgumentError.value(map, 'map', 'Cannot be empty');
    }

    final startedAtRaw = map['created_at'] ?? map['started_at'];
    final typeRaw = map['type'] ?? map['call_type'];
    if (startedAtRaw == null) {
      // Fallback for missing created_at/started_at in malformed records
      return CallRecord(
        id: map['id'] as String?,
        callerId: map['caller_id']?.toString() ?? 'unknown',
        receiverId: map['receiver_id']?.toString() ?? 'unknown',
        callType: typeRaw?.toString() ?? 'voice',
        status: map['status']?.toString() ?? 'unknown',
        startedAt: DateTime.now(),
      );
    }

    return CallRecord(
      id: map['id'] as String?,
      callerId: _safeString(map['caller_id'], 'caller_id'),
      receiverId: _safeString(map['receiver_id'], 'receiver_id'),
      callType: _safeString(typeRaw, 'call_type'),
      status: _safeString(map['status'], 'status'),
      startedAt: _parseDateTime(startedAtRaw, 'created_at'),
      endedAt: map['ended_at'] != null
          ? _parseDateTime(map['ended_at'], 'ended_at')
          : null,
      durationSeconds: (map['duration_seconds'] ?? map['duration']) is int
          ? (map['duration_seconds'] ?? map['duration']) as int
          : null,
      zegoCallId: map['zego_call_id'] as String?,
    );
  }

  /// O(n) where n = number of fields
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (id != null) 'id': id,
      'caller_id': callerId,
      'receiver_id': receiverId,
      'call_type': callType,
      'status': status,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'zego_call_id': zegoCallId,
    };
  }

  CallRecord copyWith({
    String? id,
    String? callerId,
    String? receiverId,
    String? callType,
    String? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? durationSeconds,
    String? zegoCallId,
    bool clearEndedAt = false,
  }) {
    return CallRecord(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      receiverId: receiverId ?? this.receiverId,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      durationSeconds: durationSeconds ?? this.durationSeconds,
      zegoCallId: zegoCallId ?? this.zegoCallId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CallRecord &&
        other.id == id &&
        other.callerId == callerId &&
        other.receiverId == receiverId &&
        other.callType == callType &&
        other.status == status &&
        other.startedAt == startedAt &&
        other.endedAt == endedAt &&
        other.durationSeconds == durationSeconds;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      callerId,
      receiverId,
      callType,
      status,
      startedAt,
      endedAt,
      durationSeconds,
    );
  }

  @override
  String toString() {
    return 'CallRecord('
        'id: $id, '
        'callerId: $callerId, '
        'receiverId: $receiverId, '
        'callType: $callType, '
        'status: $status, '
        'startedAt: $startedAt, '
        'endedAt: $endedAt, '
        'durationSeconds: $durationSeconds'
        ')';
  }

  static String _safeString(dynamic value, String key) {
    if (value is String) return value;
    return value?.toString() ?? '';
  }

  static DateTime _parseDateTime(dynamic value, String key) {
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw ArgumentError('$key must be a valid DateTime or ISO-8601 String');
  }
}
