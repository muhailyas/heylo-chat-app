-- ENABLE REALTIME FOR MESSAGES
-- This is critical for the chat to work in real-time.
-- By default, Supabase does NOT broadcast changes to tables unless you tell it to.

BEGIN;

-- Add 'messages' table to the publication that Supabase Realtime listens to
ALTER PUBLICATION supabase_realtime ADD TABLE messages;

-- Also add 'call_records' if you want real-time call logs
ALTER PUBLICATION supabase_realtime ADD TABLE call_records;

-- Also add 'users' if you want real-time contact updates
ALTER PUBLICATION supabase_realtime ADD TABLE users;

COMMIT;
