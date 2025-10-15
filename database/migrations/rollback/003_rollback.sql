-- =====================================================
-- Rollback: 003_add_encryption_docs
-- Description: Remove encryption documentation
-- Ticket: TICKET-003
-- Date: 2025-10-14
-- =====================================================

-- Remove database comment
COMMENT ON DATABASE current_database() IS NULL;

-- Revert column comments to original (or remove enhanced comments)
COMMENT ON COLUMN sites.contact_info IS 'Contact information for the site';
COMMENT ON COLUMN sites.address IS 'Site address information';
COMMENT ON COLUMN user_profiles.email IS 'User email address';
COMMENT ON COLUMN user_profiles.metadata IS 'Additional user metadata';

COMMENT ON COLUMN record_audit.patient_id IS 'Patient identifier';
COMMENT ON COLUMN record_state.patient_id IS 'Patient identifier';
COMMENT ON COLUMN user_site_assignments.patient_id IS 'Patient identifier';
COMMENT ON COLUMN user_site_assignments.study_patient_id IS 'Study-specific patient identifier';

COMMENT ON COLUMN record_audit.data IS 'Diary entry data';
COMMENT ON COLUMN record_state.current_data IS 'Current diary entry data';

DO $$
BEGIN
    RAISE NOTICE 'Rollback 003_add_encryption_docs completed successfully';
    RAISE NOTICE 'Note: External documentation files (spec/*.md) must be removed manually';
END $$;
