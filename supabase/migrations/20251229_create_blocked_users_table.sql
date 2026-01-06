create table if not exists public.blocked_users (
    id uuid not null default gen_random_uuid(),
    created_at timestamp with time zone not null default now(),
    blocker_id uuid not null references auth.users(id) on delete cascade,
    blocked_id uuid not null, -- references auth.users(id) - assuming we want to allow blocking by ID even if not in auth yet, but standard ref is better. Let's stick to simple UUID for now or reference if we are sure users exist. Previous code uses 'messages' with sender_id as string (from auth.uid()). So references auth.users(id) is safe.
    constraint blocked_users_pkey primary key (id),
    constraint blocked_users_unique unique (blocker_id, blocked_id)
);

alter table public.blocked_users enable row level security;

create policy "Users can see who they blocked"
on public.blocked_users for select
to authenticated
using (auth.uid() = blocker_id);

create policy "Users can block others"
on public.blocked_users for insert
to authenticated
with check (auth.uid() = blocker_id);

create policy "Users can unblock others"
on public.blocked_users for delete
to authenticated
using (auth.uid() = blocker_id);
