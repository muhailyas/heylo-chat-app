// Supabase client singleton (DB-only usage)
// File: lib/core/supabase/supabase_client.dart

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDbAuthRepoClient {
  SupabaseDbAuthRepoClient._();

  static final SupabaseClient instance = Supabase.instance.client;
}
