-- Fix RLS policies for call_records table
-- The app uses phone numbers as user IDs without Supabase Auth
-- So we need to remove JWT-based policies and allow operations based on service role

-- Drop existing policies
DROP POLICY IF EXISTS "Users can view their own calls" ON call_records;
DROP POLICY IF EXISTS "Users can insert calls they initiated" ON call_records;
DROP POLICY IF EXISTS "Users can update their own calls" ON call_records;

-- Create new permissive policies that work without auth.uid()
-- These policies allow all authenticated operations since we're using service role key

-- Policy: Allow all SELECT operations (app-level auth via phone numbers)
CREATE POLICY "Allow all select on call_records"
  ON call_records
  FOR SELECT
  USING (true);

-- Policy: Allow all INSERT operations
CREATE POLICY "Allow all insert on call_records"
  ON call_records
  FOR INSERT
  WITH CHECK (true);

-- Policy: Allow all UPDATE operations
CREATE POLICY "Allow all update on call_records"
  ON call_records
  FOR UPDATE
  USING (true);

-- Policy: Allow all DELETE operations (optional, for cleanup)
CREATE POLICY "Allow all delete on call_records"
  ON call_records
  FOR DELETE
  USING (true);

-- Note: These policies are permissive because the app handles authentication
-- at the application level using phone numbers. The Supabase client is configured
-- with the service role key which bypasses RLS, but we keep RLS enabled for
-- potential future migration to proper Supabase Auth.
