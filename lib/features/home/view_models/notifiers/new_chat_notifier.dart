//────────────────────────────────────────────────────────────
// File: lib/features/home/view_model/notifiers/new_chat_notifier.dart
//────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/common_switch_state.dart';
import '../../../auth/view_model/notifiers/auth_notifier.dart';
import '../../models/contact_presence.dart';
import '../../repositories/contact_match_repo.dart';
import '../state/new_chat_state.dart';

part 'new_chat_notifier.g.dart';

@riverpod
class NewChatNotifier extends _$NewChatNotifier {
  @override
  NewChatState build() {
    return const NewChatState();
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

  Future<void> load() async {
    try {
      state = state.copyWith(status: ViewState.loading);

      final permission = await Permission.contacts.request();
      if (!permission.isGranted) {
        state = state.copyWith(status: ViewState.networkError);
        return;
      }

      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );

      // Get current user's phone number to exclude from list
      final myPhone = ref.read(authProvider).phone;

      final phoneToName = <String, String>{};
      final phones = <String>{};

      for (final c in contacts) {
        for (final p in c.phones) {
          final normalized = _normalizePhone(p.number);
          if (normalized == null) continue;

          // Skip if this is the current user's phone number
          if (normalized == myPhone) {
            print('[NewChatNotifier] Skipping own phone: $normalized');
            continue;
          }

          phones.add(normalized);
          phoneToName[normalized] = c.displayName;
        }
      }

      final repo = ContactMatchRepo(Supabase.instance.client);
      final heyloPhones = await repo.matchPhones(phones);

      final items = phones
          .map(
            (p) => ContactItem(
              name: phoneToName[p] ?? p,
              phone: p,
              presence: heyloPhones.containsKey(p)
                  ? ContactPresence.onHeylo
                  : ContactPresence.invite,
              uid: heyloPhones[p]?.uid,
              avatarUrl: heyloPhones[p]?.avatarUrl,
            ),
          )
          .toList();

      state = state.copyWith(
        contacts: items,
        status: items.isEmpty ? ViewState.noData : ViewState.loaded,
      );
    } on SocketException {
      state = state.copyWith(status: ViewState.networkError);
    } on PostgrestException {
      state = state.copyWith(status: ViewState.serverError);
    } catch (_) {
      state = state.copyWith(status: ViewState.error);
    }
  }

  void retry() => load();
}
