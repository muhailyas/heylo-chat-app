---
description: Implement Linked Devices Feature
---

# Linked Devices Implementation Plan

This workflow outlines the steps to implement a functional "Linked Devices" feature using Supabase.

## 1. Supabase Schema Setup

Create the `user_devices` table to store device information for each user.

```sql
create table public.user_devices (
  id uuid not null default gen_random_uuid (),
  user_id uuid not null default auth.uid (),
  device_id text not null, -- Unique ID generated on the device
  device_name text not null, -- e.g., "iPhone 13", "Chrome (Mac)"
  platform text not null, -- "ios", "android", "web", "linux", "macos", "windows"
  last_active timestamp with time zone null default now(),
  fcm_token text null, -- For push notifications
  is_current boolean not null default false, -- (Virtual/Client-side logic mostly, but can store active status)
  created_at timestamp with time zone not null default now(),
  constraint user_devices_pkey primary key (id),
  constraint user_devices_user_id_fkey foreign key (user_id) references auth.users (id) on delete cascade,
  constraint user_devices_device_id_unique unique (user_id, device_id)
) tablespace pg_default;

-- RLS Policies
alter table public.user_devices enable row level security;

create policy "Users can view their own devices"
on public.user_devices
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can insert their own devices"
on public.user_devices
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can update their own devices"
on public.user_devices
for update
to authenticated
using (auth.uid() = user_id);

create policy "Users can delete their own devices"
on public.user_devices
for delete
to authenticated
using (auth.uid() = user_id);
```

**Action:**
- Since we don't have direct SQL access, we will use a `.sql` migration file and ask the USER to run it in their Supabase dashboard.

## 2. Flutter Implementation

### A. Device ID Generation
- Use `device_info_plus` (already in pubspec?) or `uuid` + `shared_preferences` to generate and persist a unique `device_id` for the app installation.
- This ID should be generated once and stored locally.

### B. Repository Methods
- Add `registerDevice` in `AuthRepo` or `UserRepo`.
  - Takes `device_id`, `name`, `platform`, `fcm_token`.
  - Performs an `upsert` on `user_devices`.
- Add `getLinkedDevices` in `UserRepo`.
  - Returns `List<UserDevice>`.
- Add `logoutDevice` in `UserRepo`.
  - Deletes the record from `user_devices`.

### C. Login Flow Integration
- Update `AuthNotifier` or post-login logic (in `home_screen.dart` or `splash_screen.dart`) to call `registerDevice`.

### D. Linked Devices Screen
- Update `LinkedDevicesScreen` to:
  - Fetch real data using `FutureBuilder` or Riverpod provider.
  - Implement real "Log Out" action.
  - Keep "Link a Device" as a placeholder (QR Scanner) for now, or implement a basic "Add current device" specific logic if testing on multiple simulators.

## 3. UI Updates
- Replace static `_devices` list with real data from Supabase.
- Add proper loading states.
- Handle errors.

## Execution Steps

1.  **Check Dependencies**: Ensure `device_info_plus` is available.
2.  **Create Migration**: Write `supabase_migrations/create_user_devices.sql`.
3.  **Update Repositories**: Modify `AuthRepo` (or create `DeviceRepo`).
4.  **Update View Models**: Add logic to fetch/manage devices.
5.  **Update UI**: Connect `LinkedDevicesScreen` to the data source.
6.  **Integrate Entry Point**: Register device on app startup/login.
