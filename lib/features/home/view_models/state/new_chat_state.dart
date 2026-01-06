import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:heylo/core/widgets/common_switch_state.dart';

import '../../models/contact_presence.dart';

part 'new_chat_state.freezed.dart';

@freezed
sealed class NewChatState with _$NewChatState {
  const factory NewChatState({
    @Default(ViewState.loading) ViewState status,
    @Default(<ContactItem>[]) List<ContactItem> contacts,
  }) = _NewChatState;
}
