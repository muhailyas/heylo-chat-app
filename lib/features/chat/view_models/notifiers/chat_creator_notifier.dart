import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../repositories/chat_repo.dart';
import '../state/chat_create_state.dart';

part 'chat_creator_notifier.g.dart';

@riverpod
class ChatRepository extends _$ChatRepository {
  @override
  ChatRepo build() {
    final client = Supabase.instance.client;
    return ChatRepo(client);
  }
}

@riverpod
class ChatCreatorNotifier extends _$ChatCreatorNotifier {
  late final ChatRepo _repo;
  @override
  ChatCreateState build() {
    _repo = ref.read(chatRepositoryProvider);
    return const ChatCreateState.idle();
  }

  // Future<String> createOrGet({required String peerUserId}) async {
  //   state = const ChatCreateState.loading();

  //   final myUserId = Supabase.instance.client.auth.currentUser?.id;
  //   if (myUserId == null) {
  //     state = const ChatCreateState.error(message: 'User not authenticated');
  //     throw StateError('Unauthenticated');
  //   }

  //   try {
  //     final chatId = await ref
  //         .read(chatRepositoryProvider)
  //         .getOrCreateOneToOneChat(myUserId: myUserId, peerUserId: peerUserId);

  //     state = ChatCreateState.success(chatId: chatId);
  //     return chatId;
  //   } catch (e) {
  //     state = ChatCreateState.error(message: e.toString());
  //     rethrow;
  //   }
  // }
  Future<String> createOrGet({required String peerUserId}) async {
    state = const ChatCreateState.loading();

    final myUserId = Supabase.instance.client.auth.currentUser?.id;
    if (myUserId == null) {
      state = const ChatCreateState.error(message: 'User not authenticated');
      throw StateError('Unauthenticated');
    }

    try {
      final chatId = await _repo.getOrCreateOneToOneChat(
        myUserId: myUserId,
        peerUserId: peerUserId,
      );

      state = ChatCreateState.success(chatId: chatId);
      return chatId;
    } catch (e) {
      state = ChatCreateState.error(message: e.toString());
      rethrow;
    }
  }
}
