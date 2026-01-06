import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:heylo/core/session/session_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://zbagrsrnklpqyjibypkw.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpiYWdyc3Jua2xwcXlqaWJ5cGt3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3ODA2MjgsImV4cCI6MjA4MTM1NjYyOH0.NRSaSVbAxviGbWg-l26Afj5358Iij5SFj7UZ2B3y3Yo',
  );

  runApp(const MaterialApp(home: Scaffold(body: DebugScreen())));
}

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _log = 'Starting Debug...\n';

  void log(String msg) {
    setState(() {
      _log += '$msg\n';
    });
    print(msg);
  }

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    try {
      final uid = await SessionStore.readUid();
      log('Current UID: $uid');

      if (uid == null) {
        log('ERROR: No UID found. Please login first.');
        return;
      }

      // Test 1: Write to messages
      log('Test 1: Writing to messages...');
      final msgId = await _testWriteMessage(uid);
      if (msgId != null) {
        log('SUCCESS: Message written with ID: $msgId');
        // Test 2: Read from messages
        log('Test 2: Reading message...');
        await _testReadMessage(msgId);
      } else {
        log('FAIL: Could not write message');
      }

      // Test 3: Write to call_records
      log('Test 3: Writing to call_records...');
      await _testWriteCall(uid);
    } catch (e, stack) {
      log('CRITICAL ERROR: $e');
      print(stack);
    }
  }

  Future<String?> _testWriteMessage(String uid) async {
    try {
      final res = await Supabase.instance.client
          .from('messages')
          .insert({
            'sender_id': uid,
            'receiver_id': uid, // Self message
            'content': 'DEBUG MESSAGE ${DateTime.now()}',
            'type': 'text',
          })
          .select()
          .single();
      return res['id'] as String;
    } catch (e) {
      log('Message Write Error: $e');
      return null;
    }
  }

  Future<void> _testReadMessage(String id) async {
    try {
      final res = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('id', id)
          .single();
      log('Read Success: ${res['content']}');
    } catch (e) {
      log('Message Read Error: $e');
    }
  }

  Future<void> _testWriteCall(String uid) async {
    try {
      final res = await Supabase.instance.client
          .from('call_records')
          .insert({
            'caller_id': uid,
            'receiver_id': uid,
            'call_type': 'voice',
            'status': 'completed',
            'started_at': DateTime.now().toIso8601String(),
            'duration_seconds': 10,
          })
          .select()
          .single();
      log('SUCCESS: Call record written with ID: ${res['id']}');
    } catch (e) {
      log('Call Record Write Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Text(
            _log,
            style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
          ),
        ),
      ),
    );
  }
}
