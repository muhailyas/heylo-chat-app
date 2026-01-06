-- Relax RLS for call_records to allow phone number based IDs
-- This matches the approach taken in user_devices.sql

DROP POLICY IF EXISTS "Users can view their own calls" ON call_records;
DROP POLICY IF EXISTS "Users can insert calls they initiated" ON call_records;
DROP POLICY IF EXISTS "Users can update their own calls" ON call_records;

CREATE POLICY "Enable access to all users"
ON public.call_records
FOR ALL
USING (true)
WITH CHECK (true);

-- Add zego_call_id column for deduplication if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='call_records' AND column_name='zego_call_id') THEN
        ALTER TABLE call_records ADD COLUMN zego_call_id TEXT UNIQUE;
    END IF;
END $$;

-- Grant access to anon/authenticated roles
GRANT ALL ON TABLE public.call_records TO anon, authenticated;

-- Enable Realtime for call history updates
ALTER PUBLICATION supabase_realtime ADD TABLE public.call_records;
