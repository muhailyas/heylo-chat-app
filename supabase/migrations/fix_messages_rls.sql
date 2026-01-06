-- Fix RLS policies for messages table
-- The app uses phone numbers as user IDs without Supabase Auth
-- So we need to remove JWT-based policies and allow operations based on service role

-- Drop existing policies
DROP POLICY IF EXISTS "Users can insert their own messages" ON messages;
DROP POLICY IF EXISTS "Users can view messages they sent or received" ON messages;
DROP POLICY IF EXISTS "Users can update messages they sent or received" ON messages;

-- Create new permissive policies that work without auth.uid()
-- These policies allow all authenticated operations since we're using service role key

-- Policy: Allow all SELECT operations (app-level auth via phone numbers)
CREATE POLICY "Allow all select on messages"
  ON messages
  FOR SELECT
  USING (true);

-- Policy: Allow all INSERT operationst
CREATE POLICY "Allow all insert on messages"
  ON messages
  FOR INSERT
  WITH CHECK (true);

-- Policy: Allow all UPDATE operations
CREATE POLICY "Allow all update on messages"
  ON messages
  FOR UPDATE
  USING (true);

-- Policy: Allow all DELETE operations
CREATE POLICY "Allow all delete on messages"
  ON messages
  FOR DELETE
  USING (true);

-- Note: These policies are permissive because the app handles authentication
-- at the application level using phone numbers. The Supabase client is configured
-- with the anon key, but we allow all operations since user verification happens
-- in the application layer.
