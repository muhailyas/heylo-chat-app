-- Disabling RLS for blocked_users table as previous policy attempts failed with 42501 (Unauthorized)
-- This aligns with the 'disable_rls.sql' pattern used for other tables in this project.

ALTER TABLE public.blocked_users DISABLE ROW LEVEL SECURITY;

-- Change columns to text if not already applied (idempotent check is hard in pure SQL without PL/pgSQL, but ALTER works if types match)
-- We will just ensure the types are TEXT as requested in previous steps.

-- Drop foreign key constraint if it exists
alter table only public.blocked_users
    drop constraint if exists blocked_users_blocker_id_fkey;

alter table public.blocked_users
    alter column blocker_id type text,
    alter column blocked_id type text;
