import 'dart:async';

import 'package:zego_zim/zego_zim.dart';

class ZegoZimService {
  ZegoZimService._();
  static final ZegoZimService instance = ZegoZimService._();

  ZIM? _zim;

  ZIM get zim => _zim!;

  Stream<List<ZIMMessage>> get onPeerMessageReceived =>
      _onPeerMessageReceivedController.stream;
  final _onPeerMessageReceivedController =
      StreamController<List<ZIMMessage>>.broadcast();

  Stream<List<ZIMConversationChangeInfo>> get onConversationChanged =>
      _onConversationChangedController.stream;
  final _onConversationChangedController =
      StreamController<List<ZIMConversationChangeInfo>>.broadcast();

  Stream<ZIMConnectionState> get onConnectionStateChanged =>
      _onConnectionStateChangedController.stream;
  final _onConnectionStateChangedController =
      StreamController<ZIMConnectionState>.broadcast();

  Stream<List<ZIMUserStatus>> get onUserStatusUpdated =>
      _onUserStatusUpdatedController.stream;
  final _onUserStatusUpdatedController =
      StreamController<List<ZIMUserStatus>>.broadcast();

  Stream<ZIMMessageReceiptInfo> get onMessageReceiptChanged =>
      _onMessageReceiptChangedController.stream;
  final _onMessageReceiptChangedController =
      StreamController<ZIMMessageReceiptInfo>.broadcast();

  Stream<List<ZIMMessageReceiptInfo>> get onConversationMessageReceiptChanged =>
      _onConversationMessageReceiptChangedController.stream;
  final _onConversationMessageReceiptChangedController =
      StreamController<List<ZIMMessageReceiptInfo>>.broadcast();

  Stream<List<ZIMRevokeMessage>> get onMessageRevoked =>
      _onMessageRevokedController.stream;
  final _onMessageRevokedController =
      StreamController<List<ZIMRevokeMessage>>.broadcast();

  // Add event handler
  void installEventHandlers() {
    final originalOnPeerMessageReceived = ZIMEventHandler.onPeerMessageReceived;
    ZIMEventHandler.onPeerMessageReceived =
        (
          ZIM zim,
          List<ZIMMessage> messageList,
          ZIMMessageReceivedInfo info,
          String fromUserID,
        ) {
          originalOnPeerMessageReceived?.call(
            zim,
            messageList,
            info,
            fromUserID,
          );
          _onPeerMessageReceivedController.add(messageList);
        };

    final originalOnConversationChanged = ZIMEventHandler.onConversationChanged;
    ZIMEventHandler.onConversationChanged =
        (ZIM zim, List<ZIMConversationChangeInfo> conversationChangeInfoList) {
          originalOnConversationChanged?.call(zim, conversationChangeInfoList);
          _onConversationChangedController.add(conversationChangeInfoList);
        };

    final originalOnConnectionStateChanged =
        ZIMEventHandler.onConnectionStateChanged;
    ZIMEventHandler.onConnectionStateChanged =
        (
          ZIM zim,
          ZIMConnectionState state,
          ZIMConnectionEvent event,
          Map extendedData,
        ) {
          originalOnConnectionStateChanged?.call(
            zim,
            state,
            event,
            extendedData,
          );
          print(
            '[ZegoZimService] Connection state changed: $state, event: $event',
          );
          _onConnectionStateChangedController.add(state);
        };

    final originalOnUserStatusUpdated = ZIMEventHandler.onUserStatusUpdated;
    ZIMEventHandler.onUserStatusUpdated =
        (ZIM zim, List<ZIMUserStatus> userStatusList) {
          originalOnUserStatusUpdated?.call(zim, userStatusList);
          _onUserStatusUpdatedController.add(userStatusList);
        };

    final originalOnMessageReceiptChanged =
        ZIMEventHandler.onMessageReceiptChanged;
    ZIMEventHandler.onMessageReceiptChanged =
        (ZIM zim, List<ZIMMessageReceiptInfo> info) {
          originalOnMessageReceiptChanged?.call(zim, info);
          for (var i in info) {
            _onMessageReceiptChangedController.add(i);
          }
        };

    final originalOnConversationMessageReceiptChanged =
        ZIMEventHandler.onConversationMessageReceiptChanged;
    ZIMEventHandler.onConversationMessageReceiptChanged =
        (ZIM zim, List<ZIMMessageReceiptInfo> infos) {
          originalOnConversationMessageReceiptChanged?.call(zim, infos);
          _onConversationMessageReceiptChangedController.add(infos);
        };

    final originalOnMessageRevokeReceived =
        ZIMEventHandler.onMessageRevokeReceived;
    ZIMEventHandler.onMessageRevokeReceived =
        (ZIM zim, List<ZIMRevokeMessage> messageList) {
          originalOnMessageRevokeReceived?.call(zim, messageList);
          _onMessageRevokedController.add(messageList);
        };
  }

  Future<void> init({required int appID, required String appSign}) async {
    if (_zim != null) return;

    final config = ZIMAppConfig()
      ..appID = appID
      ..appSign = appSign;

    _zim = ZIM.create(config);
    installEventHandlers();
  }

  // ... (login/logout methods unrelated changes omit for brevity if possible, keeping unchanged lines helps match context)

  Future<ZIMUsersStatusSubscribedResult> subscribeUsersStatus(
    List<String> userIDs,
  ) async {
    final config = ZIMUserStatusSubscribeConfig();
    config.subscriptionDuration = 10080; // 7 days
    return _zim!.subscribeUsersStatus(userIDs, config);
  }

  Future<ZIMUsersStatusUnsubscribedResult> unsubscribeUsersStatus(
    List<String> userIDs,
  ) async {
    return _zim!.unsubscribeUsersStatus(userIDs);
  }

  Future<ZIMUsersStatusQueriedResult> queryUsersStatus(
    List<String> userIDs,
  ) async {
    return _zim!.queryUsersStatus(userIDs);
  }

  Future<void> login({required String userID, required String userName}) async {
    final info = ZIMUserInfo()
      ..userID = userID
      ..userName = userName;

    final config = ZIMLoginConfig();
    config.userName =
        userName; // Set username here if supported, or pass info object if signature allows.
    // Based on typical usage:
    // If login takes (String, Config), then username is set in config or via updateUserName later.
    // Let's assume standard behavior and just timeout.

    try {
      print('[ZegoZimService] Logging in as $userID ($userName)...');
      await _zim!
          .login(info.userID, config)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Zego login timed out');
            },
          );

      // Update username if needed
      if (userName.isNotEmpty) {
        try {
          await _zim!.updateUserName(userName);
        } catch (e) {
          print('[ZegoZimService] Failed to update username: $e');
        }
      }
      print('[ZegoZimService] Login successful');
    } catch (e) {
      print('[ZegoZimService] Login failed: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    if (_zim == null) return;
    await _zim!.logout();
  }

  Future<ZIMMessageSentResult> sendPeerMessage({
    required String peerUserID,
    required String text,
    String? extendedData,
    ZIMMessageSendConfig? config,
  }) async {
    final message = ZIMTextMessage(message: text);
    if (extendedData != null) {
      message.extendedData = extendedData;
    }
    final sendConfig = config ?? ZIMMessageSendConfig();
    return _zim!.sendMessage(
      message,
      peerUserID,
      ZIMConversationType.peer,
      sendConfig..hasReceipt = true,
      ZIMMessageSendNotification(
        onMessageAttached: (message) {
          // Message attached to local database
        },
      ),
    );
  }

  Future<void> sendReceiptRead(String conversationID) async {
    await _zim!.sendConversationMessageReceiptRead(
      conversationID,
      ZIMConversationType.peer,
    );
  }

  Future<ZIMMessageRevokedResult> recallMessage(ZIMMessage message) async {
    return _zim!.revokeMessage(message, ZIMMessageRevokeConfig());
  }

  Future<ZIMMessageDeletedResult> deleteMessages(
    List<ZIMMessage> messageList,
    String conversationID,
    ZIMConversationType type,
  ) async {
    final config = ZIMMessageDeleteConfig();
    config.isAlsoDeleteServerMessage = true;
    return _zim!.deleteMessages(messageList, conversationID, type, config);
  }

  Future<ZIMMessageDeletedResult> deleteAllMessages(
    String conversationID,
    ZIMConversationType type,
  ) async {
    final config = ZIMMessageDeleteConfig();
    config.isAlsoDeleteServerMessage = true;
    return _zim!.deleteAllMessage(conversationID, type, config);
  }

  Future<ZIMConversationListQueriedResult> getConversationList({
    ZIMConversation? nextConversation,
    int count = 20,
  }) async {
    final config = ZIMConversationQueryConfig();
    config.nextConversation = nextConversation;
    config.count = count;
    return _zim!.queryConversationList(config);
  }

  Future<ZIMMessageQueriedResult> queryHistoryMessage(
    String conversationID, {
    ZIMMessage? nextMessage,
    int count = 20,
  }) async {
    final config = ZIMMessageQueryConfig();
    config.nextMessage = nextMessage;
    config.count = count;
    config.reverse = true; // Query latest first
    return _zim!.queryHistoryMessage(
      conversationID,
      ZIMConversationType.peer,
      config,
    );
  }

  Future<void> clearConversationUnreadMessageCount(
    String conversationID,
    ZIMConversationType type,
  ) async {
    await _zim!.clearConversationUnreadMessageCount(conversationID, type);
  }
}
