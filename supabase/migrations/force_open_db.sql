-- FORCE OPEN DATABASE (The "Fix Everything" Script)
-- This script does two things:
-- 1. Disables Row Level Security (RLS) policies completely
-- 2. Grants explicit permissions to the 'anon' role (which is what your app uses)

BEGIN;

-- 1. MESSAGES TABLE
ALTER TABLE messages DISABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE messages TO anon;
GRANT ALL ON TABLE messages TO authenticated;
GRANT ALL ON TABLE messages TO service_role;

-- 2. USERS TABLE
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE users TO anon;
GRANT ALL ON TABLE users TO authenticated;
GRANT ALL ON TABLE users TO service_role;

-- 3. CALL RECORDS TABLE
ALTER TABLE call_records DISABLE ROW LEVEL SECURITY;
GRANT ALL ON TABLE call_records TO anon;
GRANT ALL ON TABLE call_records TO authenticated;
GRANT ALL ON TABLE call_records TO service_role;

-- 4. STORAGE (Buckets)
-- Ensure 'chat_media' is public and accessible
UPDATE storage.buckets SET public = true WHERE id = 'chat_media';
INSERT INTO storage.buckets (id, name, public) VALUES ('chat_media', 'chat_media', true) ON CONFLICT (id) DO NOTHING;

-- Grant storage permissions
GRANT ALL ON TABLE storage.objects TO anon;
GRANT ALL ON TABLE storage.objects TO authenticated;
GRANT ALL ON TABLE storage.objects TO service_role;

COMMIT;

-- Verify
SELECT 'Database is now open.' as status;
