-- Create messages table
create table public.messages (
  id uuid default gen_random_uuid() primary key,
  sender_id text not null,
  receiver_id text not null,
  content text,
  type text not null default 'text', -- text, image, voice, file
  status text not null default 'sent', -- sent, delivered, read
  reply_to_id uuid,
  media_url text,
  duration_ms int,
  created_at timestamp with time zone default now(),
  is_read boolean default false
);

-- Enable RLS
alter table public.messages enable row level security;

-- Policies
create policy "Users can insert their own messages"
on public.messages for insert
with check (auth.uid()::text = sender_id);

create policy "Users can view messages they sent or received"
on public.messages for select
using (auth.uid()::text = sender_id or auth.uid()::text = receiver_id);

create policy "Users can update messages they sent or received"
on public.messages for update
using (auth.uid()::text = sender_id or auth.uid()::text = receiver_id);
