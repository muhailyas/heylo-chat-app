import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_create_state.freezed.dart';

@freezed
class ChatCreateState with _$ChatCreateState {
  const factory ChatCreateState.idle() = _Idle;
  const factory ChatCreateState.loading() = _Loading;
  const factory ChatCreateState.success({required String chatId}) = _Success;
  const factory ChatCreateState.error({required String message}) = _Error;
}
