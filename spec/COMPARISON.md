# Database Design Comparison

Comparison between the two clinical trial database implementations:
- **dbtest/** (current directory) - Multi-site architecture
- **ctest/** - Single-user nosebleed diary

---

## Executive Summary

| Aspect | dbtest (Multi-Site) | ctest (Single-User) |
|--------|---------------------|---------------------|
| **Scope** | Multi-site clinical trial | Single-study patient diary |
| **Users** | Multiple roles across sites | Individual patients only |
| **Access Control** | Complex RBAC with site isolation | Simple user-only access |
| **Tables** | 12 tables | 5 tables |
| **Complexity** | High (enterprise) | Medium (focused) |
| **Use Case** | Investigator portal + patient app | Patient app only |

---

## Detailed Comparison

### 1. Architecture Philosophy

**dbtest (Current Directory):**
- **Multi-tenant, multi-site architecture**
- Supports USER, INVESTIGATOR, ANALYST, ADMIN roles
- Site-based data isolation
- Investigator annotations as separate layer
- Designed for investigator oversight and queries

**ctest:**
- **Single-user, single-study architecture**
- Users only interact with their own data
- No investigator layer
- Direct RAVE export focus
- Simpler offline sync model

### 2. Table Structure

**dbtest - 12 Tables:**
```
Core:
- sites                           ❌ Not in ctest
- record_audit (immutable log)    ✅ Similar to nosebleed_events_audit
- record_state (current view)     ✅ Similar to nosebleed_events_current (materialized view)
- investigator_annotations        ❌ Not in ctest

Access Control:
- user_site_assignments           ❌ Not in ctest
- investigator_site_assignments   ❌ Not in ctest
- analyst_site_assignments        ❌ Not in ctest
- user_profiles                   ✅ Similar to user_profiles in ctest

Supporting:
- sync_conflicts                  ⚠️ Different approach (vector_clock in ctest)
- admin_action_log               ❌ Not in ctest
- role_change_log                ❌ Not in ctest
- user_sessions                  ❌ Not in ctest (handled by Supabase Auth)
```

**ctest - 5 Tables:**
```
- user_profiles                   ✅ Similar concept
- nosebleed_events_audit         ✅ Similar to record_audit
- nosebleed_events_current       ✅ Materialized view vs. table
- client_sync_state              ⚠️ Different from sync_conflicts
- auth_audit_log                 ⚠️ Simpler than admin_action_log
- rave_export_log                ❌ Not in dbtest
```

### 3. Audit Trail Implementation

**dbtest:**
```sql
-- Separate state table (auto-updated by triggers)
record_audit (INSERT only)
    ↓ trigger
record_state (updated automatically)

-- Conflict tracking in separate table
sync_conflicts (for multi-device)
```

**Advantages:**
- State table is always current
- Queries against state are fast
- Conflicts tracked explicitly
- Easier to query current state

**ctest:**
```sql
-- Materialized view for current state
nosebleed_events_audit (append-only)
    ↓ trigger refresh
nosebleed_events_current (materialized view)

-- Vector clocks embedded in audit records
vector_clock JSONB field
```

**Advantages:**
- Simpler schema (fewer tables)
- Vector clock for distributed sync
- Explicit DISTINCT ON for latest version
- Materialized view can be rebuilt

### 4. Access Control & RLS

**dbtest - Complex RBAC:**
```sql
-- 4 distinct roles with different permissions
USER        → Own data only
INVESTIGATOR → All data at assigned sites
ANALYST     → Read-only at assigned sites
ADMIN       → Global access

-- Site isolation enforced at database level
CREATE POLICY investigator_site_access ON record_state
    USING (site_id IN (
        SELECT site_id FROM investigator_site_assignments
        WHERE investigator_id = current_user_id()
    ));
```

**ctest - Simple User-Only:**
```sql
-- Single role: authenticated users
CREATE POLICY "Users can view own events"
    ON nosebleed_events_audit
    USING (auth.uid() = user_id);

-- No site isolation
-- No investigator layer
-- RAVE export handled at app level
```

### 5. Conflict Resolution

**dbtest:**
```sql
-- Parent audit ID tracking
parent_audit_id BIGINT REFERENCES record_audit(audit_id)

-- Explicit conflict table
CREATE TABLE sync_conflicts (
    client_version INTEGER,
    server_version INTEGER,
    client_data JSONB,
    server_data JSONB,
    resolution_strategy TEXT
);

-- Conflict detection in triggers
IF parent_audit_id != current last_audit_id THEN
    -- Create conflict record
    -- Reject update until resolved
END IF;
```

**ctest:**
```sql
-- Vector clock embedded in audit records
vector_clock JSONB -- {"device_id": sequence_number}

-- Version number per event
version INTEGER NOT NULL
UNIQUE(event_id, version)

-- Last-Write-Wins using server timestamps
-- Handled at application layer, not database
```

### 6. Compliance Features

**Both support FDA 21 CFR Part 11:**
- ✅ Immutable audit trail
- ✅ Timestamped entries
- ✅ User identification
- ✅ Reason for change required
- ✅ Electronic signatures

**dbtest Additional:**
- ✅ Role-based access control
- ✅ Investigator annotations
- ✅ Admin action logging
- ✅ Role change audit

**ctest Additional:**
- ✅ GDPR compliance fields (anonymization)
- ✅ HIPAA auth audit log
- ✅ RAVE export tracking
- ✅ OAuth provider tracking

**Note:** Auth audit logging should be added to dbtest for full compliance (see auth_audit.sql)

### 7. Sync Architecture

**dbtest:**
```sql
-- Sync metadata in state table
sync_metadata JSONB

-- Explicit conflict tracking
sync_conflicts table

-- Parent audit ID for lineage
parent_audit_id tracking

-- Server enforces conflict resolution
```

**ctest:**
```sql
-- Device sync state tracking
CREATE TABLE client_sync_state (
    device_id VARCHAR(100),
    last_synced_audit_id BIGINT,
    device_sequence INTEGER
);

-- Vector clock in each audit entry
vector_clock JSONB

-- Client-side conflict resolution
-- Last-Write-Wins by default
```

### 8. Data Model Differences

**dbtest event structure:**
```json
{
  "event_type": "epistaxis",
  "date": "2025-02-15",
  "time": "14:30",
  "duration_minutes": 15,
  "intensity": "moderate",
  "side": "right",
  "notes": "Started after exercise"
}
```

**ctest event structure:**
```json
{
  "event_timestamp": "2025-10-14T14:30:00Z",
  "duration_minutes": 5,
  "severity": "mild|moderate|severe",
  "notes": "optional text",
  "recorded_device": "mobile|web"
}
```

**Key Differences:**
- dbtest: Separate date/time fields
- ctest: Combined ISO timestamp
- dbtest: "intensity" field
- ctest: "severity" field (more explicit values)
- ctest: Includes device tracking

### 9. Performance Optimization

**dbtest - 40+ indexes:**
- Composite indexes for common queries
- GIN indexes on JSONB
- Partial indexes for filtered queries
- Materialized views for reporting
- Partitioning strategy for audit table

**ctest - 10+ indexes:**
- Basic indexes on common fields
- GIN indexes on JSONB
- Focused on single-user queries
- One materialized view (current state)
- No partitioning (smaller scale)

### 10. User Management

**dbtest:**
```sql
-- Comprehensive user profiles
CREATE TABLE user_profiles (
    user_id TEXT,
    email TEXT,
    full_name TEXT,
    role TEXT,  -- USER, INVESTIGATOR, ANALYST, ADMIN
    two_factor_enabled BOOLEAN,
    metadata JSONB
);

-- Site assignments
user_site_assignments
investigator_site_assignments
analyst_site_assignments

-- Role change tracking
role_change_log
```

**ctest:**
```sql
-- Study-focused profiles
CREATE TABLE user_profiles (
    user_id UUID REFERENCES auth.users(id),
    study_id VARCHAR(50),
    subject_id VARCHAR(50),  -- De-identified
    site_id VARCHAR(50),
    consent_version VARCHAR(20),
    is_anonymized BOOLEAN
);

-- No role system
-- No site assignments
```

---

## Use Case Fit

### When to Use dbtest (Multi-Site):

✅ **Use this when you need:**
- Multiple clinical trial sites
- Investigator oversight and queries
- Site-based data isolation
- Multiple user roles (investigators, analysts, admins)
- Investigator annotations on patient data
- Complex access control requirements
- Central monitoring across sites
- Admin management of site assignments

**Examples:**
- Multi-center clinical trial
- Investigator portal with patient app
- Studies requiring site coordinators
- Trials with data analysts
- Studies with central monitoring

### When to Use ctest (Single-User):

✅ **Use this when you need:**
- Patient-only diary application
- Simple offline sync
- Direct RAVE export
- Single study focus
- GDPR anonymization post-trial
- No investigator interaction required
- Simpler data model

**Examples:**
- Patient-reported outcomes (PRO)
- Simple diary studies
- Single-site trials
- Self-reported data only
- Studies where patients submit directly to EDC

---

## Migration Path

### From ctest to dbtest:

If you start with ctest and need to add investigator features:

1. **Add site management:**
   ```sql
   -- Create sites table
   -- Add site_id to user_profiles
   -- Create site assignments
   ```

2. **Add roles:**
   ```sql
   -- Add role field to user_profiles
   -- Create investigator_site_assignments
   -- Update RLS policies
   ```

3. **Add annotations:**
   ```sql
   -- Create investigator_annotations table
   -- Link to events via event_uuid
   ```

4. **Update state management:**
   ```sql
   -- Convert materialized view to table
   -- Add triggers for auto-update
   ```

### From dbtest to ctest:

If you want to simplify:

1. **Remove multi-site features:**
   ```sql
   -- Drop site assignment tables
   -- Remove site_id from policies
   ```

2. **Simplify roles:**
   ```sql
   -- Remove all roles except USER
   -- Simplify RLS to user-only
   ```

3. **Simplify state:**
   ```sql
   -- Convert state table to materialized view
   -- Remove complex triggers
   ```

4. **Add RAVE export:**
   ```sql
   -- Create rave_export_log table
   ```

---

## Recommendations

### Choose dbtest if:
- ✅ You have multiple sites
- ✅ Investigators need to review/query data
- ✅ You need role-based access
- ✅ Central monitoring is required
- ✅ Site isolation is important
- ✅ Investigators add annotations
- ✅ You have data analysts

### Choose ctest if:
- ✅ Single study, simple diary
- ✅ Patients only interact with own data
- ✅ No investigator oversight needed
- ✅ Direct EDC export required
- ✅ GDPR anonymization needed
- ✅ Simpler is better
- ✅ Faster to implement

### Hybrid Approach:

You could combine the best of both:

```sql
-- Start with dbtest architecture
-- Add from ctest:
- GDPR anonymization fields
- RAVE export tracking
- Vector clock sync (optional)
- OAuth provider tracking
- More explicit HIPAA compliance
```

---

## Technical Debt Comparison

**dbtest:**
- ❌ More complex to maintain
- ❌ More tables to manage
- ❌ More RLS policies to test
- ✅ Better separation of concerns
- ✅ More scalable for growth
- ✅ Clearer role boundaries

**ctest:**
- ✅ Simpler to understand
- ✅ Fewer tables
- ✅ Faster initial development
- ❌ Harder to add multi-site later
- ❌ Limited role expansion
- ❌ Materialized view refresh overhead

---

## Performance Comparison

### Query Performance (estimated):

**dbtest:**
- Current state queries: **Very Fast** (indexed table)
- Audit history: **Fast** (partitioned + indexed)
- Site filtering: **Fast** (composite indexes)
- Investigator queries: **Medium** (site joins)
- Cross-site aggregation: **Medium** (multiple sites)

**ctest:**
- Current state queries: **Fast** (materialized view)
- Audit history: **Fast** (indexed)
- User filtering: **Very Fast** (single user)
- View refresh: **Medium** (REFRESH MATERIALIZED VIEW)

### Scale Estimates:

**dbtest:**
- Users: 10,000+
- Sites: 100+
- Events per user: Unlimited
- Audit records: 10M+

**ctest:**
- Users: 1,000-5,000
- Sites: 1 (or simple multi-site)
- Events per user: 1,000-10,000
- Audit records: 1M-5M

---

## Summary

**dbtest** is a **comprehensive enterprise solution** for multi-site clinical trials with complex access control and investigator oversight.

**ctest** is a **focused patient diary application** optimized for single-study use with direct RAVE export.

Both are FDA 21 CFR Part 11 compliant, but serve different use cases.

**Recommendation for your project:**
- If you need investigator oversight → **dbtest**
- If it's patient-only diary → **ctest**
- If unsure → Start with **ctest**, migrate to **dbtest** if needed

The migration path from ctest → dbtest is well-defined and can be done incrementally.
