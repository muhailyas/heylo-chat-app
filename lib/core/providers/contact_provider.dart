import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'contact_provider.g.dart';

@riverpod
class LocalContacts extends _$LocalContacts {
  @override
  Future<Map<String, String>> build() async {
    final hasPermission = await FlutterContacts.requestPermission();
    if (!hasPermission) return {};

    final contacts = await FlutterContacts.getContacts(withProperties: true);
    final map = <String, String>{};

    for (final contact in contacts) {
      for (final phone in contact.phones) {
        final normalized = _normalizePhone(phone.number);
        if (normalized != null) {
          map[normalized] = contact.displayName;
        }
      }
    }
    return map;
  }

  String? _normalizePhone(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return null;
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 11 && digits.startsWith('0')) {
      return '+91${digits.substring(1)}';
    }
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    if (digits.length > 12) return '+91${digits.substring(digits.length - 10)}';
    return null;
  }
}

final contactNameProvider = Provider.family<String?, String>((ref, phone) {
  final contacts = ref.watch(localContactsProvider);
  return contacts.maybeWhen(data: (map) => map[phone], orElse: () => null);
});
