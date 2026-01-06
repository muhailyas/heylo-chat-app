-- Migration: Fix call_records schema alignment
-- This migration ensures the call_records table has the correct column names used by the Flutter app.

DO $$ 
BEGIN 
    -- 1. Rename 'type' to 'call_type' if it exists and 'call_type' does not
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='call_records' AND column_name='type') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='call_records' AND column_name='call_type') THEN
        ALTER TABLE call_records RENAME COLUMN type TO call_type;
        RAISE NOTICE 'Renamed type to call_type';
    END IF;

    -- 2. Add 'call_type' if it still doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='call_records' AND column_name='call_type') THEN
        ALTER TABLE call_records ADD COLUMN call_type TEXT DEFAULT 'voice';
        RAISE NOTICE 'Added call_type column';
    END IF;

    -- 3. Add 'started_at' if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='call_records' AND column_name='started_at') THEN
        ALTER TABLE call_records ADD COLUMN started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
        -- Copy from created_at if it exists
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='call_records' AND column_name='created_at') THEN
            UPDATE call_records SET started_at = created_at;
        END IF;
        RAISE NOTICE 'Added started_at column';
    END IF;

    -- 4. Add 'ended_at' if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='call_records' AND column_name='ended_at') THEN
        ALTER TABLE call_records ADD COLUMN ended_at TIMESTAMP WITH TIME ZONE;
        RAISE NOTICE 'Added ended_at column';
    END IF;

    -- 5. Rename 'duration' to 'duration_seconds' if it exists and 'duration_seconds' does not
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='call_records' AND column_name='duration') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='call_records' AND column_name='duration_seconds') THEN
        ALTER TABLE call_records RENAME COLUMN duration TO duration_seconds;
        RAISE NOTICE 'Renamed duration to duration_seconds';
    END IF;

    -- 6. Add 'duration_seconds' if it still doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='call_records' AND column_name='duration_seconds') THEN
        ALTER TABLE call_records ADD COLUMN duration_seconds INTEGER DEFAULT 0;
        RAISE NOTICE 'Added duration_seconds column';
    END IF;

    -- 7. Add 'zego_call_id' if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='call_records' AND column_name='zego_call_id') THEN
        ALTER TABLE call_records ADD COLUMN zego_call_id TEXT;
        -- Add unique constraint
        ALTER TABLE call_records ADD CONSTRAINT call_records_zego_call_id_key UNIQUE (zego_call_id);
        RAISE NOTICE 'Added zego_call_id column and unique constraint';
    END IF;

END $$;
