# FIX: Real-time Updates (Chat & Home)

The chat is not updating instantly because Supabase needs to be explicitly told to "broadcast" table changes.

I have created a script to **Enable Realtime**.

## Steps

1. **Open Supabase Dashboard**
   - Go to [Supabase SQL Editor](https://zbagrsrnklpqyjibypkw.supabase.co/project/sql)

2. **Run `enable_realtime.sql`**
   - Copy the SQL code from `supabase/migrations/enable_realtime.sql`
   - Paste cleanly into the SQL Editor.
   - Click **Run**.

3. **Restart App**
   - Restart the Heylo app.

## Additional Fixes Included
- I will also update the app code to show a **Clock Icon** explicitly when a message is sending, instead of the loading spinner.
