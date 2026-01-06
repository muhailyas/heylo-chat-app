// File: lib/features/profile/views/linked_devices_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/session/session_store.dart';
import '../../auth/repositories/auth_repo.dart';

class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  final _repo = SupabaseDbAuthRepo(Supabase.instance.client);
  late Future<List<Map<String, dynamic>>> _future;
  String? _myId;
  String? _currentDeviceId;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myId = await SessionStore.readUid();
    _currentDeviceId = await SessionStore.getDeviceId();
    _refresh();
  }

  void _refresh() {
    if (_myId != null) {
      setState(() {
        _future = _repo.getLinkedDevices(_myId!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0,
        title: Text(
          "Active Sessions",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _myId == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header / Link Button
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.cardColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.security_rounded,
                          size: 60,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Manage Active Sessions",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Review devices where you are currently logged in.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Hidden for now since there is no web app to link to
                      // SizedBox(
                      //   width: double.infinity,
                      //   child: ElevatedButton( ... ),
                      // ),
                    ],
                  ),
                ),

                Divider(color: theme.dividerColor.withOpacity(0.1), height: 1),

                // Device List
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}'));
                      }
                      final devices = snapshot.data ?? [];
                      if (devices.isEmpty) {
                        return Center(
                          child: Text(
                            'No linked devices',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withOpacity(
                                0.5,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: devices.length,
                        itemBuilder: (context, index) {
                          final device = devices[index];
                          return _buildDeviceTile(device);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildDeviceTile(Map<String, dynamic> device) {
    // Check if this row matches current (mock logic for now for 'current')
    // Real logic: compare device['device_id'] with locally stored ID
    final isCurrent =
        device['device_id'] == _currentDeviceId; // Placeholder match
    final platform = device['platform'] as String? ?? 'unknown';

    IconData icon;
    if (platform.toLowerCase().contains('ios') ||
        platform.toLowerCase().contains('iphone')) {
      icon = Icons.phone_iphone_rounded;
    } else if (platform.toLowerCase().contains('android')) {
      icon = Icons.phone_android_rounded;
    } else if (platform.toLowerCase().contains('web') ||
        platform.toLowerCase().contains('chrome')) {
      icon = Icons.web_rounded;
    } else {
      icon = Icons.laptop_mac_rounded;
    }

    // Format time
    // final lastActive = device['last_active'] ... (use intl or timeago)
    final lastActiveStr = device['last_active'] != null
        ? DateTime.parse(
            device['last_active'],
          ).toLocal().toString().split('.')[0]
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.1),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
          ),
        ),
        title: Text(
          device['device_name'] ?? 'Unknown Device',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          isCurrent ? 'Active now' : 'Last active: $lastActiveStr',
          style: TextStyle(
            color: isCurrent
                ? Theme.of(context).primaryColor
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontSize: 13,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: isCurrent
            ? null
            : IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                onPressed: () => _confirmLogout(device),
              ),
      ),
    );
  }

  void _confirmLogout(Map<String, dynamic> device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Log out device?",
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          "Are you sure you want to log out from ${device['device_name']}?",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              if (_myId != null) {
                try {
                  await _repo.logoutDevice(
                    userId: _myId!,
                    deviceId: device['device_id'],
                  );
                  _refresh();
                  messenger.showSnackBar(
                    const SnackBar(content: Text("Device logged out")),
                  );
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              }
            },
            child: const Text(
              "Log Out",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
