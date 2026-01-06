// Centralized route generator
// File: lib/core/router/route_generator.dart

import 'package:flutter/material.dart';
import 'package:heylo/features/home/views/new_chat_screen.dart';
import 'package:heylo/features/home/views/tabs/chats_tab.dart';
import 'package:heylo/features/onboarding/views/onboarding_screen.dart';
import 'package:heylo/features/splash/views/splash_screen.dart';

import '../../features/auth/views/mobile_auth_screen.dart';
import '../../features/auth/views/otp_screen.dart';
import '../../features/auth/views/profile_setup_screen.dart';
import '../../features/chat/views/chat_room_screen.dart';
import '../../features/chat/views/create_group_members_screen.dart';
import '../../features/chat/views/group_details_screen.dart';
import '../../features/home/models/contact_presence.dart';
import '../../features/home/views/home_screen.dart';
import '../../features/profile/views/edit_group_screen.dart';
import '../../features/profile/views/profile_details_screen.dart';

class RouteGenerator {
  static Route<dynamic> generate(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _page(const SplashScreen());
      case onboarding:
        return _page(const OnboardingScreen());
      case authMobile:
        return _page(const MobileAuthScreen());
      case otp:
        final phoneNumber = settings.arguments as String?;
        if (phoneNumber == null) {
          throw ArgumentError('OTP route requires a phone number argument');
        }
        return _page(OtpScreen(phoneNumber: phoneNumber));
      case profileSetup:
        return _page(const ProfileSetupScreen());
      case home:
        return _page(const HomeScreen());
      case chatRoom:
        final args = settings.arguments as ChatRoomArgs?;
        return _page(
          ChatRoomScreen(
            name: args?.name ?? '',
            peerId: args?.peerId ?? '',
            avatarUrl: args?.avatarUrl ?? '',
            phone: args?.phone ?? '',
            isGroup: args?.isGroup ?? false,
            groupId: args?.groupId,
            highlightMessageId: args?.highlightMessageId,
            heroTag: args?.heroTag,
          ),
        );
      case newChatContact:
        return _page(const NewChatScreen());
      case createGroupMembers:
        final groupId = settings.arguments as String?;
        return _page(CreateGroupMembersScreen(existingGroupId: groupId));
      case groupDetails:
        final members = settings.arguments as List<ContactItem>?;
        return _page(GroupDetailsScreen(members: members ?? []));
      case editGroup:
        final args = settings.arguments as EditGroupArgs?;
        if (args == null) throw ArgumentError('EditGroup requires args');
        return _page(EditGroupScreen(args: args));
      case profileDetails:
        final args = settings.arguments as ProfileDetailsArgs?;
        if (args == null) throw ArgumentError('ProfileDetails requires args');
        return _page(
          ProfileDetailsScreen(
            name: args.name,
            peerId: args.peerId,
            phone: args.phone,
            avatarUrl: args.avatarUrl,
            isGroup: args.isGroup,
          ),
        );
      default:
        return _page(
          const Scaffold(body: Center(child: Text('Route not found'))),
        );
    }
  }

  // static MaterialPageRoute _page(Widget view) =>
  //     MaterialPageRoute(builder: (_) => view);
  /// OPAQUE fade route — eliminates white flash
  static PageRouteBuilder<T> _page<T>(Widget view) {
    return PageRouteBuilder<T>(
      opaque: true,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, _, _) => view,
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: child,
        );
      },
    );
  }

  static const splash = "/splash";
  static const authMobile = "/authMobile";
  static const home = "/home";
  static const otp = "/otp";
  static const onboarding = "/onboarding";
  static const profileSetup = "/profileSetup";
  static const chatRoom = "/chatRoom";
  static const newChatContact = "/newChatContact";
  static const createGroupMembers = "/createGroupMembers";
  static const groupDetails = "/groupDetails";
  static const profileDetails = "/profileDetails";
  static const editGroup = "/editGroup";
}

class ProfileDetailsArgs {
  final String name;
  final String peerId;
  final String phone;
  final String avatarUrl;
  final bool isGroup;

  ProfileDetailsArgs({
    required this.name,
    required this.peerId,
    required this.phone,
    required this.avatarUrl,
    this.isGroup = false,
  });
}
