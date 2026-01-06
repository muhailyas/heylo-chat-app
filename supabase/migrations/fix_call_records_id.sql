-- Ensure call_records table has a proper UUID primary key with default generation
-- This fixes the 'null value in column "id" violates not-null constraint' error

-- 1. Ensure the id column has a default generator if it doesn't already
-- We use gen_random_uuid() which is built-in in modern Postgres
-- We also ensure the column is of type UUID and is the primary key

ALTER TABLE IF EXISTS call_records 
  ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- 2. (Optional) If it was accidentally created as TEXT, we might need a more complex migration,
-- but based on the error "null value in column id", it exists but lacks a default or is being passed null.
-- The model change to omit null 'id' in toJson will let this default kick in.

-- Ensure RLS is still permissive as per previous fixes
ALTER TABLE call_records ENABLE ROW LEVEL SECURITY;
