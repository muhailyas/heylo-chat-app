-- Create call_records table for tracking call history
CREATE TABLE IF NOT EXISTS call_records (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  caller_id TEXT NOT NULL,
  receiver_id TEXT NOT NULL,
  call_type TEXT NOT NULL CHECK (call_type IN ('video', 'voice')),
  status TEXT NOT NULL CHECK (status IN ('completed', 'missed', 'rejected', 'cancelled')),
  started_at TIMESTAMP WITH TIME ZONE NOT NULL,
  ended_at TIMESTAMP WITH TIME ZONE,
  duration_seconds INTEGER,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_call_records_caller ON call_records(caller_id);
CREATE INDEX IF NOT EXISTS idx_call_records_receiver ON call_records(receiver_id);
CREATE INDEX IF NOT EXISTS idx_call_records_started_at ON call_records(started_at DESC);

-- Enable Row Level Security
ALTER TABLE call_records ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own call records (as caller or receiver)
CREATE POLICY "Users can view their own calls"
  ON call_records
  FOR SELECT
  USING (
    caller_id = current_setting('request.jwt.claims', true)::json->>'sub'
    OR receiver_id = current_setting('request.jwt.claims', true)::json->>'sub'
  );

-- Policy: Users can insert their own call records (as caller)
CREATE POLICY "Users can insert calls they initiated"
  ON call_records
  FOR INSERT
  WITH CHECK (
    caller_id = current_setting('request.jwt.claims', true)::json->>'sub'
  );

-- Policy: Users can update their own call records
CREATE POLICY "Users can update their own calls"
  ON call_records
  FOR UPDATE
  USING (
    caller_id = current_setting('request.jwt.claims', true)::json->>'sub'
    OR receiver_id = current_setting('request.jwt.claims', true)::json->>'sub'
  );

-- Note: Since we're using phone numbers as user IDs, you may need to adjust the RLS policies
-- to use the phone number directly instead of JWT claims. Example:
-- 
-- DROP POLICY IF EXISTS "Users can view their own calls" ON call_records;
-- CREATE POLICY "Users can view their own calls"
--   ON call_records
--   FOR SELECT
--   USING (auth.uid()::text = caller_id OR auth.uid()::text = receiver_id);
