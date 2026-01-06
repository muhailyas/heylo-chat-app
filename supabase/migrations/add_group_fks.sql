-- Add foreign key to group_members user_id
ALTER TABLE public.group_members
ADD CONSTRAINT group_members_user_id_fkey
FOREIGN KEY (user_id)
REFERENCES public.users(uid)
ON DELETE CASCADE;

-- Also add for groups created_by if it's not there
ALTER TABLE public.groups
ADD CONSTRAINT groups_created_by_fkey
FOREIGN KEY (created_by)
REFERENCES public.users(uid)
ON DELETE CASCADE;
