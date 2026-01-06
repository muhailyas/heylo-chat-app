-- FIX: chat_id Not Null Constraint
-- The application logic uses sender_id and receiver_id to identify chats.
-- The 'chat_id' column is enforcing a Not Null constraint which causes inserts to fail.
-- We will make this column nullable (optional) or drop the constraint.

ALTER TABLE messages ALTER COLUMN chat_id DROP NOT NULL;

-- Optional: If you want to drop the column entirely if it's unused:
-- ALTER TABLE messages DROP COLUMN chat_id;
-- But making it nullable is safer to avoid breaking other unknown dependencies.
