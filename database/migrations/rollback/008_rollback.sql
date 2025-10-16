-- =====================================================
-- Rollback Migration 008: Remove JSONB Validation Functions
-- =====================================================

-- Drop main validator
DROP FUNCTION IF EXISTS validate_diary_data(JSONB);

-- Drop event-specific validators
DROP FUNCTION IF EXISTS validate_survey_data(JSONB);
DROP FUNCTION IF EXISTS validate_epistaxis_data(JSONB);

-- Drop helper functions
DROP FUNCTION IF EXISTS is_valid_iso8601(TEXT);
DROP FUNCTION IF EXISTS is_valid_uuid(TEXT);

-- Restore original simple validator (from initial schema)
CREATE OR REPLACE FUNCTION validate_diary_data(data JSONB)
RETURNS BOOLEAN AS $$
BEGIN
    -- Check required fields exist
    IF NOT (data ? 'event_type') THEN
        RAISE EXCEPTION 'Missing required field: event_type';
    END IF;

    IF NOT (data ? 'date') THEN
        RAISE EXCEPTION 'Missing required field: date';
    END IF;

    -- Validate event_type is a string
    IF jsonb_typeof(data->'event_type') != 'string' THEN
        RAISE EXCEPTION 'event_type must be a string';
    END IF;

    -- Additional validation can be added here
    RETURN true;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validate_diary_data(JSONB) IS 'Validates diary entry data structure';

-- Verify rollback
DO $$
BEGIN
    -- Check new functions are gone
    PERFORM 1 FROM pg_proc WHERE proname = 'is_valid_uuid';
    IF FOUND THEN
        RAISE EXCEPTION 'Rollback failed: is_valid_uuid still exists';
    END IF;

    PERFORM 1 FROM pg_proc WHERE proname = 'validate_epistaxis_data';
    IF FOUND THEN
        RAISE EXCEPTION 'Rollback failed: validate_epistaxis_data still exists';
    END IF;

    -- Check simple validator restored
    PERFORM 1 FROM pg_proc WHERE proname = 'validate_diary_data';
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Rollback failed: validate_diary_data not restored';
    END IF;

    RAISE NOTICE 'Rollback 008: JSONB validation functions removed successfully';
END $$;
