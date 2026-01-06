-- MASTER INITIALIZATION SCRIPT (Full Reset & Start Initially)
-- This script drops all tables and recreates them from scratch with all latest features.
-- Run this in the Supabase SQL Editor.

--------------------------------------------------------------------------------
-- 1. CLEANUP (DROP EVERYTHING)
--------------------------------------------------------------------------------
DROP TABLE IF EXISTS public.group_members CASCADE;
DROP TABLE IF EXISTS public.groups CASCADE;
DROP TABLE IF EXISTS public.messages CASCADE;
DROP TABLE IF EXISTS public.call_records CASCADE;
DROP TABLE IF EXISTS public.blocked_users CASCADE;
DROP TABLE IF EXISTS public.users CASCADE;

--------------------------------------------------------------------------------
-- 2. CREATE CORE TABLES
--------------------------------------------------------------------------------

-- Profiles table (Linked to Auth UID by text)
CREATE TABLE public.users (
    uid text PRIMARY KEY,
    phone text NOT NULL UNIQUE,
    name text,
    email text,
    avatar_url text,
    created_at timestamp with time zone DEFAULT now(),
    last_seen timestamp with time zone DEFAULT now()
);

-- Groups table
CREATE TABLE public.groups (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    description text,
    avatar_url text,
    created_by text REFERENCES public.users(uid) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now()
);

-- Group Members table
CREATE TABLE public.group_members (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    group_id uuid REFERENCES public.groups(id) ON DELETE CASCADE,
    user_id text REFERENCES public.users(uid) ON DELETE CASCADE,
    role text DEFAULT 'member', -- admin, member
    joined_at timestamp with time zone DEFAULT now(),
    UNIQUE(group_id, user_id)
);

-- Messages table (Supports both P2P and Group)
CREATE TABLE public.messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    sender_id text NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    receiver_id text REFERENCES public.users(uid) ON DELETE CASCADE, -- Null for groups
    group_id uuid REFERENCES public.groups(id) ON DELETE CASCADE,   -- Null for P2P
    content text,
    type text NOT NULL DEFAULT 'text', -- text, image, voice, file, contact, call
    status text NOT NULL DEFAULT 'sent', -- sent, delivered, read
    reply_to_id uuid,
    media_url text,
    duration_ms int,
    created_at timestamp with time zone DEFAULT now(),
    is_read boolean DEFAULT false,
    read_at timestamp with time zone
);

-- Call Records table
CREATE TABLE public.call_records (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    caller_id text NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    receiver_id text NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    call_type text NOT NULL DEFAULT 'voice',
    status text DEFAULT 'initiated', 
    started_at timestamp with time zone DEFAULT now(),
    ended_at timestamp with time zone,
    duration_seconds int DEFAULT 0,
    zego_call_id text UNIQUE,
    created_at timestamp with time zone DEFAULT now()
);

-- Blocked Users table
CREATE TABLE public.blocked_users (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    blocker_id text NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    blocked_id text NOT NULL REFERENCES public.users(uid) ON DELETE CASCADE,
    created_at timestamp with time zone DEFAULT now(),
    UNIQUE(blocker_id, blocked_id)
);

--------------------------------------------------------------------------------
-- 3. STORAGE SETUP (Buckets)
--------------------------------------------------------------------------------

-- Ensure buckets exist and are public
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true) 
ON CONFLICT (id) DO UPDATE SET public = true;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('chat_media', 'chat_media', true) 
ON CONFLICT (id) DO UPDATE SET public = true;

--------------------------------------------------------------------------------
-- 4. REALTIME SETUP
--------------------------------------------------------------------------------

-- Drop publication if it exists to avoid errors on recreation
-- (Usually 'supabase_realtime' exists, so we just add to it)
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    CREATE PUBLICATION supabase_realtime;
  END IF;
END $$;

ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.groups;
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;
ALTER PUBLICATION supabase_realtime ADD TABLE public.group_members;

--------------------------------------------------------------------------------
-- 5. ACCESS CONTROL (Open Development Mode)
--------------------------------------------------------------------------------

-- Disable RLS for easier development (as per your current setup)
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.call_records DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users DISABLE ROW LEVEL SECURITY;

-- Grant permissions to ANON and AUTHENTICATED roles
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;

-- Storage policies
CREATE POLICY "Public Access" ON storage.objects FOR SELECT USING (true);
CREATE POLICY "Public Insert" ON storage.objects FOR INSERT WITH CHECK (true);
CREATE POLICY "Public Update" ON storage.objects FOR UPDATE USING (true);

--------------------------------------------------------------------------------
-- FINISHED
--------------------------------------------------------------------------------
SELECT 'Database successfully reset and rebuilt!' as status;
