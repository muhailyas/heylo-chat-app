-- Comprehensive Fix for call_records: IDs and RLS
-- Run this in Supabase SQL Editor

-- 1. Ensure automatic UUID generation for the id column
ALTER TABLE IF EXISTS call_records 
  ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- 2. Reset and Re-apply RLS Policies
-- First, enable RLS
ALTER TABLE call_records ENABLE ROW LEVEL SECURITY;

-- Drop all potentially conflicting policies
DROP POLICY IF EXISTS "Allow all select on call_records" ON call_records;
DROP POLICY IF EXISTS "Allow all insert on call_records" ON call_records;
DROP POLICY IF EXISTS "Allow all update on call_records" ON call_records;
DROP POLICY IF EXISTS "Allow all delete on call_records" ON call_records;
DROP POLICY IF EXISTS "Users can view their own calls" ON call_records;
DROP POLICY IF EXISTS "Users can insert calls they initiated" ON call_records;
DROP POLICY IF EXISTS "Users can update their own calls" ON call_records;

-- Create fresh permissive policies for the 'anon' role (used by the mobile app)
-- Policy: SELECT
CREATE POLICY "Allow anon select on call_records"
ON call_records FOR SELECT
TO anon
USING (true);

-- Policy: INSERT
CREATE POLICY "Allow anon insert on call_records"
ON call_records FOR INSERT
TO anon
WITH CHECK (true);

-- Policy: UPDATE
CREATE POLICY "Allow anon update on call_records"
ON call_records FOR UPDATE
TO anon
USING (true);

-- Policy: DELETE
CREATE POLICY "Allow anon delete on call_records"
ON call_records FOR DELETE
TO anon
USING (true);
