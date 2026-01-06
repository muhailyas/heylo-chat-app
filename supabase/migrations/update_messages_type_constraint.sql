-- Update messages_type_check constraint to allow 'contact', 'revoked', and 'call'
ALTER TABLE public.messages DROP CONSTRAINT IF EXISTS messages_type_check;

ALTER TABLE public.messages ADD CONSTRAINT messages_type_check 
CHECK (type IN ('text', 'image', 'voice', 'file', 'revoked', 'contact', 'call'));
