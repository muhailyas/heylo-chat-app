-- Add read_at column to messages table
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS read_at timestamp with time zone;

-- Update existing read messages to have a read_at timestamp (optional but helpful)
UPDATE public.messages SET read_at = created_at WHERE is_read = true AND read_at IS NULL;
