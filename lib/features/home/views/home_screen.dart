import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/system_ui_handler.dart';
import '../../auth/view_model/notifiers/auth_notifier.dart';
import '../../profile/view_models/notifiers/profile_notifier.dart';
import '../view_models/states/chat_search_query_provider.dart';
import 'new_chat_screen.dart';
import 'tabs/calls_tab.dart';
import 'tabs/chats_tab.dart';
import 'tabs/explore_tab.dart';
import 'tabs/profile_tab.dart';
import 'widgets/bottom_nav_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      ref.read(chatSearchQueryProvider.notifier).update('');
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    // Greeting Logic
    final hour = DateTime.now().hour;
    String greeting = "Hello";
    if (hour < 12) {
      greeting = "Good Morning";
    } else if (hour < 17) {
      greeting = "Good Afternoon";
    } else {
      greeting = "Good Evening";
    }

    // Get User info
    final userId = ref.watch(authProvider).userId;
    // Watch profile if userId exists
    final profileAsync = userId != null
        ? ref.watch(profileByUidProvider(userId))
        : null;
    final name = profileAsync?.value?.name ?? 'Friend';
    final avatar = profileAsync?.value?.avatarUrl;

    return SystemUIHandler(
      scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      floatingActionButton: _index == 0
          ? InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NewChatScreen()),
                );
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary,
                  boxShadow: [
                    BoxShadow(
                      color: primary.withOpacity(.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.chat_bubble_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 24,
                ),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Dynamic Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: (_isSearching && _index == 0)
                        ? TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search chats...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: theme.colorScheme.onSurface.withOpacity(
                                  0.4,
                                ),
                                fontSize: 18,
                              ),
                            ),
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 18,
                            ),
                            onChanged: (val) {
                              ref
                                  .read(chatSearchQueryProvider.notifier)
                                  .update(val);
                            },
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_index == 0) ...[
                                Text(
                                  greeting,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  name.isNotEmpty ? name : 'Heylo',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ] else ...[
                                Text(
                                  _index == 1
                                      ? "Calls"
                                      : (_index == 2 ? "Explore" : "Profile"),
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),

                  // Actions
                  if (_index == 0) ...[
                    if (_isSearching)
                      IconButton(
                        onPressed: _stopSearch,
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.colorScheme.onSurface,
                          size: 28,
                        ),
                      )
                    else
                      IconButton(
                        onPressed: () {
                          setState(() => _isSearching = true);
                        },
                        icon: Icon(
                          Icons.search_rounded,
                          color: theme.colorScheme.onSurface,
                          size: 28,
                        ),
                      ),
                  ],

                  // Profile Avatar (Navigates to Profile Tab)
                  if (_index != 3 && !_isSearching)
                    GestureDetector(
                      onTap: () => setState(() => _index = 3),
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.primary.withOpacity(0.1),
                          image: (avatar != null && avatar.isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(avatar),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.1),
                          ),
                        ),
                        child: (avatar == null || avatar.isEmpty)
                            ? Icon(Icons.person, color: theme.primaryColor)
                            : null,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: IndexedStack(
                index: _index,
                children: const [
                  ChatsTab(),
                  CallsTab(),
                  ExploreTab(),
                  ProfileTab(),
                ],
              ),
            ),
            SizedBox(height: 84 + bottomInset),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
        child: HomeBottomNavBar(
          index: _index,
          onChange: (i) => setState(() => _index = i),
        ),
      ),
    );
  }
}
