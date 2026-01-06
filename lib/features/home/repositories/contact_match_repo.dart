// File: lib/features/chat/repositories/contact_match_repo.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class ContactInfo {
  final String uid;
  final String? avatarUrl;

  const ContactInfo({required this.uid, this.avatarUrl});
}

class ContactMatchRepo {
  ContactMatchRepo(this._client);

  final SupabaseClient _client;

  static const int _batchSize = 200;

  Future<Map<String, ContactInfo>> matchPhones(Set<String> phones) async {
    final result = <String, ContactInfo>{};
    final list = phones.toList();

    for (var i = 0; i < list.length; i += _batchSize) {
      final batch = list.sublist(
        i,
        i + _batchSize > list.length ? list.length : i + _batchSize,
      );

      final res = await _client
          .from('users')
          .select('phone, uid, avatar_url')
          .inFilter('phone', batch);

      for (final row in res) {
        final phone = row['phone'] as String?;
        final id = row['uid'] as String?;
        final avatarUrl = row['avatar_url'] as String?;
        if (phone != null && id != null) {
          result[phone] = ContactInfo(uid: id, avatarUrl: avatarUrl);
        }
      }
    }

    return result;
  }
}
