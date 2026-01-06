import 'package:supabase_flutter/supabase_flutter.dart';

class GroupRepo {
  final SupabaseClient _client;
  GroupRepo(this._client);

  Future<String> createGroup({
    required String name,
    required String createdBy,
    String? avatarUrl,
    required List<String> memberUserIds,
  }) async {
    print('[GroupRepo] Creating group: $name by $createdBy');
    final List<dynamic> res = await _client
        .from('groups')
        .insert(<String, dynamic>{
          'name': name,
          'avatar_url': avatarUrl,
          'created_by': createdBy,
        })
        .select('id');

    if (res.isEmpty)
      throw Exception('Failed to create group: No data returned');
    final groupId = res.first['id'] as String;

    // 2. Add members (including creator)
    final memberRows = memberUserIds
        .map(
          (uid) => <String, dynamic>{
            'group_id': groupId,
            'user_id': uid,
            'role': uid == createdBy ? 'admin' : 'member',
          },
        )
        .toList();

    // Ensure creator is in the list
    if (!memberUserIds.contains(createdBy)) {
      memberRows.add(<String, dynamic>{
        'group_id': groupId,
        'user_id': createdBy,
        'role': 'admin',
      });
    }

    print('[GroupRepo] Adding ${memberRows.length} members to group: $groupId');
    await _client.from('group_members').insert(memberRows);

    return groupId;
  }

  Future<List<Map<String, dynamic>>> getMyGroups(String userId) async {
    final res = await _client
        .from('group_members')
        .select('groups(*)')
        .eq('user_id', userId);

    return List<Map<String, dynamic>>.from(
      res.map((e) => e['groups'] as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>?> getGroupDetails(String groupId) async {
    final res = await _client
        .from('groups')
        .select()
        .eq('id', groupId)
        .maybeSingle();
    return res;
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final res = await _client
        .from('group_members')
        .select()
        .eq('group_id', groupId);

    final members = List<Map<String, dynamic>>.from(res as List);
    if (members.isEmpty) return [];

    final uids = members.map((m) => m['user_id'] as String).toList();
    final usersRes = await _client.from('users').select().inFilter('uid', uids);
    final usersMap = {for (var u in (usersRes as List)) u['uid']: u};

    return members.map((m) {
      return {...m, 'users': usersMap[m['user_id']]};
    }).toList();
  }

  Future<void> updateGroupName(String groupId, String name) async {
    await _client.from('groups').update({'name': name}).eq('id', groupId);
  }

  Future<void> updateGroupAvatar(String groupId, String avatarUrl) async {
    await _client
        .from('groups')
        .update({'avatar_url': avatarUrl})
        .eq('id', groupId);
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    await _client
        .from('group_members')
        .update({'role': 'ex_member'})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<String?> getMyGroupRole(String groupId, String userId) async {
    final res = await _client
        .from('group_members')
        .select('role')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();
    return res?['role'] as String?;
  }

  Future<void> addMembers(String groupId, List<String> userIds) async {
    final rows = userIds
        .map((uid) => {'group_id': groupId, 'user_id': uid, 'role': 'member'})
        .toList();
    await _client.from('group_members').insert(rows);
  }
}
