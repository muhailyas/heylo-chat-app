import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/features/auth/view_model/notifiers/auth_notifier.dart';
import 'package:heylo/features/chat/repositories/chat_repo.dart';
import 'package:heylo/features/home/view_models/states/chat_search_query_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final messageSearchProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final query = ref.watch(chatSearchQueryProvider);

      if (query.trim().isEmpty) {
        return [];
      }

      // Debounce logic
      await Future.delayed(const Duration(milliseconds: 500));

      final myId =
          ref.watch(authProvider).userId ??
          Supabase.instance.client.auth.currentUser?.id;

      if (myId == null) {
        debugPrint('[MessageSearchProvider] userId is NULL - returning empty');
        return [];
      }

      debugPrint('[MessageSearchProvider] myId: $myId. Calling repo...');
      final repo = ChatRepo(Supabase.instance.client);

      try {
        final results = await repo.searchMessages(query: query, myId: myId);
        debugPrint('[MessageSearchProvider] SUCCESS: ${results.length} found');
        return results;
      } catch (e, stack) {
        debugPrint('[MessageSearchProvider] ERROR: $e');
        debugPrint(stack.toString());
        rethrow;
      }
    });
