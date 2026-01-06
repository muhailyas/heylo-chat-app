-- Create groups table
create table public.groups (
  id uuid default gen_random_uuid() primary key,
  name text not null,
  description text,
  avatar_url text,
  created_by text not null,
  created_at timestamp with time zone default now()
);

-- Create group_members table
create table public.group_members (
  id uuid default gen_random_uuid() primary key,
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id text not null,
  role text not null default 'member', -- admin, member
  joined_at timestamp with time zone default now(),
  unique(group_id, user_id)
);

-- Update messages table to support groups
-- We will add group_id column. If group_id is not null, it's a group message.
-- If group_id is null, it's a P2P message (existing behavior).
alter table public.messages add column group_id uuid references public.groups(id) on delete cascade;

-- Update RLS for groups
alter table public.groups enable row level security;
alter table public.group_members enable row level security;

create policy "Users can view groups they are members of"
on public.groups for select
using (
  exists (
    select 1 from public.group_members
    where group_members.group_id = groups.id
    and group_members.user_id = auth.uid()::text
  )
);

create policy "Users can update groups they are admins of"
on public.groups for update
using (
  exists (
    select 1 from public.group_members
    where group_members.group_id = groups.id
    and group_members.user_id = auth.uid()::text
    and group_members.role = 'admin'
  )
);

create policy "Users can view members of their groups"
on public.group_members for select
using (
  exists (
    select 1 from public.group_members as gm
    where gm.group_id = group_members.group_id
    and gm.user_id = auth.uid()::text
  )
);

-- Update messages RLS for groups
create policy "Users can view messages in their groups"
on public.messages for select
using (
  group_id is not null and exists (
    select 1 from public.group_members
    where group_members.group_id = messages.group_id
    and group_members.user_id = auth.uid()::text
  )
);

create policy "Users can insert messages in their groups"
on public.messages for insert
with check (
  group_id is not null and exists (
    select 1 from public.group_members
    where group_members.group_id = messages.group_id
    and group_members.user_id = auth.uid()::text
  )
);
