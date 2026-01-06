-- Comprehensive RLS Fix for All Tables
-- Run this in Supabase SQL Editor

-- 1. FIX USERS TABLE (Required for Contact Matching)
-- Allow anyone to read users (needed for contact matching by phone)
DROP POLICY IF EXISTS "Allow public read users" ON users;
DROP POLICY IF EXISTS "Allow all select on users" ON users;

CREATE POLICY "Allow all select on users"
ON users FOR SELECT
USING (true);

-- Allow all insert/update to users (for profile creation/update)
DROP POLICY IF EXISTS "Allow all insert on users" ON users;
DROP POLICY IF EXISTS "Allow all update on users" ON users;

CREATE POLICY "Allow all insert on users"
ON users FOR INSERT
WITH CHECK (true);

CREATE POLICY "Allow all update on users"
ON users FOR UPDATE
USING (true);

-- 2. FIX MESSAGES TABLE (Chat)
DROP POLICY IF EXISTS "Allow all select on messages" ON messages;
DROP POLICY IF EXISTS "Allow all insert on messages" ON messages;
DROP POLICY IF EXISTS "Allow all update on messages" ON messages;
DROP POLICY IF EXISTS "Allow all delete on messages" ON messages;

CREATE POLICY "Allow all select on messages"
ON messages FOR SELECT USING (true);

CREATE POLICY "Allow all insert on messages"
ON messages FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow all update on messages"
ON messages FOR UPDATE USING (true);

CREATE POLICY "Allow all delete on messages"
ON messages FOR DELETE USING (true);

-- 3. FIX CALL RECORDS TABLE (Calls)
DROP POLICY IF EXISTS "Allow all select on call_records" ON call_records;
DROP POLICY IF EXISTS "Allow all insert on call_records" ON call_records;
DROP POLICY IF EXISTS "Allow all update on call_records" ON call_records;
DROP POLICY IF EXISTS "Allow all delete on call_records" ON call_records;

CREATE POLICY "Allow all select on call_records"
ON call_records FOR SELECT USING (true);

CREATE POLICY "Allow all insert on call_records"
ON call_records FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow all update on call_records"
ON call_records FOR UPDATE USING (true);

CREATE POLICY "Allow all delete on call_records"
ON call_records FOR DELETE USING (true);

-- 4. FIX BUCKETS (Storage for Images/Voice)
-- This is often overlooked. If RLS is on for storage.objects, uploads fail.
-- We can't easily script storage policies via SQL editor usually without knowing bucket structure, 
-- but we can ensure the bucket 'chat_media' exists and is public.

INSERT INTO storage.buckets (id, name, public) 
VALUES ('chat_media', 'chat_media', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Allow public access to chat_media
CREATE POLICY "Public Access"
ON storage.objects FOR SELECT
USING ( bucket_id = 'chat_media' );

CREATE POLICY "Public Upload"
ON storage.objects FOR INSERT
WITH CHECK ( bucket_id = 'chat_media' );
