-- =====================================================
-- Rollback Migration 009: Disable RLS and Remove Policies
-- =====================================================

-- =====================================================
-- DROP ALL POLICIES
-- =====================================================

-- Sites policies
DROP POLICY IF EXISTS sites_select_all ON sites;
DROP POLICY IF EXISTS sites_admin_all ON sites;

-- Record audit policies
DROP POLICY IF EXISTS audit_user_select ON record_audit;
DROP POLICY IF EXISTS audit_user_insert ON record_audit;
DROP POLICY IF EXISTS audit_investigator_select ON record_audit;
DROP POLICY IF EXISTS audit_investigator_insert ON record_audit;
DROP POLICY IF EXISTS audit_analyst_select ON record_audit;
DROP POLICY IF EXISTS audit_admin_all ON record_audit;

-- Record state policies
DROP POLICY IF EXISTS state_user_select ON record_state;
DROP POLICY IF EXISTS state_user_insert ON record_state;
DROP POLICY IF EXISTS state_user_update ON record_state;
DROP POLICY IF EXISTS state_user_delete ON record_state;
DROP POLICY IF EXISTS state_investigator_select ON record_state;
DROP POLICY IF EXISTS state_analyst_select ON record_state;
DROP POLICY IF EXISTS state_admin_select ON record_state;
DROP POLICY IF EXISTS state_service_all ON record_state;

-- Annotations policies
DROP POLICY IF EXISTS annotations_user_select ON investigator_annotations;
DROP POLICY IF EXISTS annotations_investigator_select ON investigator_annotations;
DROP POLICY IF EXISTS annotations_investigator_insert ON investigator_annotations;
DROP POLICY IF EXISTS annotations_investigator_update ON investigator_annotations;
DROP POLICY IF EXISTS annotations_admin_all ON investigator_annotations;

-- User assignments policies
DROP POLICY IF EXISTS user_assignments_select ON user_site_assignments;
DROP POLICY IF EXISTS user_assignments_investigator_select ON user_site_assignments;
DROP POLICY IF EXISTS user_assignments_admin_all ON user_site_assignments;

-- Investigator assignments policies
DROP POLICY IF EXISTS investigator_assignments_select ON investigator_site_assignments;
DROP POLICY IF EXISTS investigator_assignments_admin_all ON investigator_site_assignments;

-- Analyst assignments policies
DROP POLICY IF EXISTS analyst_assignments_select ON analyst_site_assignments;
DROP POLICY IF EXISTS analyst_assignments_admin_all ON analyst_site_assignments;

-- Conflicts policies
DROP POLICY IF EXISTS conflicts_user_select ON sync_conflicts;
DROP POLICY IF EXISTS conflicts_user_update ON sync_conflicts;
DROP POLICY IF EXISTS conflicts_investigator_select ON sync_conflicts;
DROP POLICY IF EXISTS conflicts_admin_all ON sync_conflicts;
DROP POLICY IF EXISTS conflicts_service_insert ON sync_conflicts;

-- Admin log policies
DROP POLICY IF EXISTS admin_log_select ON admin_action_log;
DROP POLICY IF EXISTS admin_log_insert ON admin_action_log;
DROP POLICY IF EXISTS admin_log_investigator_select ON admin_action_log;
DROP POLICY IF EXISTS admin_log_investigator_review ON admin_action_log;

-- =====================================================
-- DISABLE RLS ON ALL TABLES
-- =====================================================

ALTER TABLE sites DISABLE ROW LEVEL SECURITY;
ALTER TABLE record_audit DISABLE ROW LEVEL SECURITY;
ALTER TABLE record_state DISABLE ROW LEVEL SECURITY;
ALTER TABLE investigator_annotations DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_site_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE investigator_site_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE analyst_site_assignments DISABLE ROW LEVEL SECURITY;
ALTER TABLE sync_conflicts DISABLE ROW LEVEL SECURITY;
ALTER TABLE admin_action_log DISABLE ROW LEVEL SECURITY;

-- =====================================================
-- REVOKE PERMISSIONS (if needed)
-- =====================================================

-- Note: We keep basic grants in place as they're part of the base schema
-- Only revoke if you want to fully reset permissions

-- =====================================================
-- VERIFICATION
-- =====================================================

DO $$
DECLARE
    table_name TEXT;
    rls_enabled BOOLEAN;
    policy_count INTEGER;
BEGIN
    -- Check RLS is disabled on tables
    FOR table_name IN
        SELECT unnest(ARRAY['record_audit', 'record_state', 'sites'])
    LOOP
        SELECT relrowsecurity INTO rls_enabled
        FROM pg_class
        WHERE relname = table_name;

        IF rls_enabled THEN
            RAISE EXCEPTION 'RLS still enabled on table: %', table_name;
        END IF;

        -- Count policies
        SELECT COUNT(*) INTO policy_count
        FROM pg_policies
        WHERE tablename = table_name;

        IF policy_count > 0 THEN
            RAISE WARNING 'Policies still exist on table %: %', table_name, policy_count;
        END IF;
    END LOOP;

    RAISE NOTICE 'Rollback 009: RLS disabled and policies removed successfully';
END $$;
