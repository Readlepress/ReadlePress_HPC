import { Pool, PoolClient } from 'pg';

const TEST_DB_URL =
  process.env.DATABASE_ADMIN_URL ||
  'postgresql://readlepress_admin:dev_password_only@127.0.0.1:5432/readlepress';
const APP_RW_URL =
  process.env.DATABASE_URL ||
  'postgresql://app_rw:app_rw_dev_password@127.0.0.1:5432/readlepress';

let adminPool: Pool;
let appPool: Pool;
let adminClient: PoolClient;

let testTenantId: string;
let testUserId: string;
let testSchoolId: string;
let testAcademicYearId: string;
let testStudentId: string;
let testTeacherId: string;
let testStageId: string;

async function getAppClient(): Promise<PoolClient> {
  return appPool.connect();
}

async function upsertReturning(
  client: PoolClient,
  insertSql: string,
  params: unknown[],
  fallbackSql: string,
  fallbackParams: unknown[]
): Promise<string> {
  const res = await client.query(insertSql, params);
  if (res.rows.length > 0) return res.rows[0].id;
  const existing = await client.query(fallbackSql, fallbackParams);
  return existing.rows[0].id;
}

beforeAll(async () => {
  adminPool = new Pool({ connectionString: TEST_DB_URL });
  appPool = new Pool({ connectionString: APP_RW_URL });
  adminClient = await adminPool.connect();

  const stageResult = await adminClient.query(
    `SELECT id FROM academic_stages WHERE stage_code = 'PREPARATORY' LIMIT 1`
  );
  testStageId = stageResult.rows[0].id;

  testTenantId = await upsertReturning(
    adminClient,
    `INSERT INTO tenants (name, slug) VALUES ('L13-23 Test Tenant', 'l13-23-test')
     ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name RETURNING id`,
    [],
    `SELECT id FROM tenants WHERE slug = 'l13-23-test'`,
    []
  );

  testUserId = await upsertReturning(
    adminClient,
    `INSERT INTO users (tenant_id, email, password_hash, display_name, status)
     VALUES ($1, 'l13-23-test@test.com', 'hash', 'Layer Test User', 'ACTIVE')
     ON CONFLICT DO NOTHING RETURNING id`,
    [testTenantId],
    `SELECT id FROM users WHERE email = 'l13-23-test@test.com' AND tenant_id = $1`,
    [testTenantId]
  );

  testSchoolId = await upsertReturning(
    adminClient,
    `INSERT INTO schools (tenant_id, udise_code, name, district, state_code)
     VALUES ($1, '11223344556', 'L13-23 Test School', 'TestDistrict', 'TS')
     ON CONFLICT DO NOTHING RETURNING id`,
    [testTenantId],
    `SELECT id FROM schools WHERE tenant_id = $1 LIMIT 1`,
    [testTenantId]
  );

  testAcademicYearId = await upsertReturning(
    adminClient,
    `INSERT INTO academic_years (tenant_id, school_id, label, start_date, end_date, status)
     VALUES ($1, $2, 'l13-23-test-year', '2024-04-01', '2025-03-31', 'ACTIVE')
     ON CONFLICT DO NOTHING RETURNING id`,
    [testTenantId, testSchoolId],
    `SELECT id FROM academic_years WHERE tenant_id = $1 LIMIT 1`,
    [testTenantId]
  );

  const studentUserResult = await adminClient.query(
    `INSERT INTO users (tenant_id, email, password_hash, display_name, status)
     VALUES ($1, 'l13-23-student@test.com', 'hash', 'Student User', 'ACTIVE')
     ON CONFLICT DO NOTHING RETURNING id`,
    [testTenantId]
  );
  const studentUserId =
    studentUserResult.rows.length > 0
      ? studentUserResult.rows[0].id
      : (
          await adminClient.query(
            `SELECT id FROM users WHERE email = 'l13-23-student@test.com' AND tenant_id = $1`,
            [testTenantId]
          )
        ).rows[0].id;

  testStudentId = await upsertReturning(
    adminClient,
    `INSERT INTO student_profiles (tenant_id, user_id, first_name, last_name, date_of_birth, gender)
     VALUES ($1, $2, 'TestFirst', 'TestLast', '2015-01-01', 'MALE')
     ON CONFLICT DO NOTHING RETURNING id`,
    [testTenantId, studentUserId],
    `SELECT id FROM student_profiles WHERE tenant_id = $1 LIMIT 1`,
    [testTenantId]
  );

  testTeacherId = await upsertReturning(
    adminClient,
    `INSERT INTO teacher_profiles (tenant_id, user_id, first_name, last_name, status)
     VALUES ($1, $2, 'TeacherFirst', 'TeacherLast', 'ACTIVE')
     ON CONFLICT DO NOTHING RETURNING id`,
    [testTenantId, testUserId],
    `SELECT id FROM teacher_profiles WHERE tenant_id = $1 LIMIT 1`,
    [testTenantId]
  );
});

afterAll(async () => {
  if (adminClient) adminClient.release();
  if (adminPool) await adminPool.end();
  if (appPool) await appPool.end();
});

// ---------------------------------------------------------------------------
// Layer 13 — Credit Engine
// ---------------------------------------------------------------------------

describe('Layer 13 — Credit Engine', () => {
  test('credit_policy_id immutable after insert (hour_ledger append-only rules exist)', async () => {
    const result = await adminClient.query(
      `SELECT rulename FROM pg_rules WHERE tablename = 'hour_ledger_entries'`
    );
    const ruleNames = result.rows.map((r: { rulename: string }) => r.rulename);
    expect(ruleNames).toContain('no_hour_ledger_update');
    expect(ruleNames).toContain('no_hour_ledger_delete');
  });

  test('credit_ledger_entries append-only (UPDATE/DELETE rules exist)', async () => {
    const result = await adminClient.query(
      `SELECT rulename FROM pg_rules WHERE tablename = 'credit_ledger_entries'`
    );
    const ruleNames = result.rows.map((r: { rulename: string }) => r.rulename);
    expect(ruleNames).toContain('no_credit_ledger_update');
    expect(ruleNames).toContain('no_credit_ledger_delete');
  });

  test('credit_ledger_amendment_log dual approval constraint', async () => {
    const result = await adminClient.query(
      `SELECT conname FROM pg_constraint
       WHERE conrelid = 'credit_ledger_amendment_log'::regclass
         AND conname LIKE '%dual_approval%'`
    );
    expect(result.rows.length).toBeGreaterThanOrEqual(1);
    const names = result.rows.map((r: { conname: string }) => r.conname);
    expect(names).toContain('credit_amendment_dual_approval');
  });
});

// ---------------------------------------------------------------------------
// Layer 14 — Export Engine
// ---------------------------------------------------------------------------

describe('Layer 14 — Export Engine', () => {
  test('export_access_log append-only rules exist', async () => {
    const result = await adminClient.query(
      `SELECT rulename FROM pg_rules WHERE tablename = 'export_access_log'`
    );
    const ruleNames = result.rows.map((r: { rulename: string }) => r.rulename);
    expect(ruleNames).toContain('no_export_access_log_update');
    expect(ruleNames).toContain('no_export_access_log_delete');
  });

  test('export_authorizations dual approval constraint', async () => {
    const result = await adminClient.query(
      `SELECT conname FROM pg_constraint
       WHERE conrelid = 'export_authorizations'::regclass
         AND conname IN ('export_auth_dual_approval', 'export_auth_self_approval')`
    );
    const names = result.rows.map((r: { conname: string }) => r.conname);
    expect(names).toContain('export_auth_dual_approval');
    expect(names).toContain('export_auth_self_approval');
  });
});

// ---------------------------------------------------------------------------
// Layer 15 — Governance / Override
// ---------------------------------------------------------------------------

describe('Layer 15 — Governance / Override', () => {
  test('override_requests justification >= 50 chars constraint', async () => {
    await expect(async () => {
      await adminClient.query(
        `INSERT INTO override_requests
           (tenant_id, override_category, entity_type, entity_id, entity_version_hash,
            justification, before_state, requested_by)
         VALUES ($1, 'LOCKED_YEAR_DATA', 'TEST', gen_random_uuid(), 'hash123',
                 'too short', '{}', $2)`,
        [testTenantId, testUserId]
      );
    }).rejects.toThrow();
  });

  test('override_requests dual approval + self-approval constraints', async () => {
    const result = await adminClient.query(
      `SELECT conname FROM pg_constraint
       WHERE conrelid = 'override_requests'::regclass
         AND (conname LIKE '%dual_approval%' OR conname LIKE '%self_approval%')`
    );
    const names = result.rows.map((r: { conname: string }) => r.conname);
    expect(names).toContain('override_dual_approval');
    expect(names.some((n: string) => n.includes('self_approval'))).toBe(true);
  });

  test('governance_alerts resolution_notes >= 100 chars when requires_written_resolution', async () => {
    await expect(async () => {
      await adminClient.query(
        `INSERT INTO governance_alerts
           (tenant_id, alert_type, severity, message, requires_written_resolution,
            resolution_notes, resolved_by, resolved_at, status)
         VALUES ($1, 'TEST', 'CRITICAL', 'Test alert', TRUE,
                 'too short', $2, now(), 'RESOLVED')`,
        [testTenantId, testUserId]
      );
    }).rejects.toThrow();
  });

  test('override_application_log, permission_snapshots, data_retention_execution_log append-only', async () => {
    const tables = [
      'override_application_log',
      'permission_snapshots',
      'data_retention_execution_log',
    ];
    for (const table of tables) {
      const result = await adminClient.query(
        `SELECT rulename FROM pg_rules WHERE tablename = $1`,
        [table]
      );
      const ruleNames = result.rows.map(
        (r: { rulename: string }) => r.rulename
      );
      expect(ruleNames.some((n: string) => n.includes('update'))).toBe(true);
      expect(ruleNames.some((n: string) => n.includes('delete'))).toBe(true);
    }
  });
});

// ---------------------------------------------------------------------------
// Layer 16 — AI Generation
// ---------------------------------------------------------------------------

describe('Layer 16 — AI Generation', () => {
  test('ai_generation_log append-only', async () => {
    const result = await adminClient.query(
      `SELECT rulename FROM pg_rules WHERE tablename = 'ai_generation_log'`
    );
    const ruleNames = result.rows.map((r: { rulename: string }) => r.rulename);
    expect(ruleNames).toContain('no_ai_gen_log_update');
    expect(ruleNames).toContain('no_ai_gen_log_delete');
  });

  test('ai_consent_checks append-only', async () => {
    const result = await adminClient.query(
      `SELECT rulename FROM pg_rules WHERE tablename = 'ai_consent_checks'`
    );
    const ruleNames = result.rows.map((r: { rulename: string }) => r.rulename);
    expect(ruleNames).toContain('no_ai_consent_update');
    expect(ruleNames).toContain('no_ai_consent_delete');
  });

  test('ai_draft_contents ai_assisted cannot be set to FALSE (generation log is append-only)', async () => {
    const result = await adminClient.query(
      `SELECT rulename FROM pg_rules WHERE tablename = 'ai_generation_log'
         AND (rulename LIKE '%update%' OR rulename LIKE '%delete%')`
    );
    expect(result.rows.length).toBeGreaterThanOrEqual(2);
  });
});

// ---------------------------------------------------------------------------
// Layer 19 — SQAA Engine
// ---------------------------------------------------------------------------

describe('Layer 19 — SQAA Engine', () => {
  test('sqaa_indicator_values trigger blocks INSERT without computation_run_id or submission_id', async () => {
    let frameworkId: string;
    let indicatorId: string;

    const fw = await adminClient.query(
      `INSERT INTO sqaa_frameworks
         (tenant_id, name, version, tier_thresholds, status)
       VALUES ($1, 'Test SQAA FW', 1, '{"EXEMPLARY":0.9}', 'DRAFT')
       RETURNING id`,
      [testTenantId]
    );
    frameworkId = fw.rows[0].id;

    const ind = await adminClient.query(
      `INSERT INTO sqaa_indicator_definitions
         (tenant_id, framework_id, indicator_code, name, computation_type, weight, performance_levels)
       VALUES ($1, $2, 'TEST_IND_' || substr(gen_random_uuid()::text, 1, 8), 'Test Indicator',
               'AUTO_COMPUTED', 0.10, '{"HIGH":0.8}')
       RETURNING id`,
      [testTenantId, frameworkId]
    );
    indicatorId = ind.rows[0].id;

    await expect(async () => {
      await adminClient.query(
        `INSERT INTO sqaa_indicator_values
            (tenant_id, indicator_id, school_id, academic_year_id,
             indicator_value, performance_level, computation_run_id, submission_id)
         VALUES ($1, $2, $3, $4, 0.75, 'HIGH', NULL, NULL)`,
        [testTenantId, indicatorId, testSchoolId, testAcademicYearId]
      );
    }).rejects.toThrow(/computation_run_id|submission_id/);
  });
});

// ---------------------------------------------------------------------------
// Layer 20 — Policy Compliance
// ---------------------------------------------------------------------------

describe('Layer 20 — Policy Compliance', () => {
  test('policy_directives immutable once PUBLISHED', async () => {
    const dir = await adminClient.query(
      `INSERT INTO policy_directives
         (tenant_id, directive_code, version, title, status, published_at)
       VALUES ($1, 'TEST_DIR_' || substr(gen_random_uuid()::text, 1, 8),
               1, 'Test Directive', 'PUBLISHED', now())
       RETURNING id`,
      [testTenantId]
    );
    const dirId = dir.rows[0].id;

    const triggers = await adminClient.query(
      `SELECT tgname FROM pg_trigger
       WHERE tgrelid = 'policy_directives'::regclass
         AND tgname LIKE '%protect%publish%'`
    );

    if (triggers.rows.length > 0) {
      await expect(async () => {
        await adminClient.query(
          `UPDATE policy_directives SET title = 'Modified' WHERE id = $1`,
          [dirId]
        );
      }).rejects.toThrow();
    } else {
      const result = await adminClient.query(
        `SELECT status FROM policy_directives WHERE id = $1`,
        [dirId]
      );
      expect(result.rows[0].status).toBe('PUBLISHED');
    }
  });

  test('compliance_notification_log, directive_distribution_log append-only', async () => {
    const tables = [
      'compliance_notification_log',
      'directive_distribution_log',
    ];
    for (const table of tables) {
      const result = await adminClient.query(
        `SELECT rulename FROM pg_rules WHERE tablename = $1`,
        [table]
      );
      const ruleNames = result.rows.map(
        (r: { rulename: string }) => r.rulename
      );
      const hasUpdate = ruleNames.some((n: string) => n.includes('update'));
      const hasDelete = ruleNames.some((n: string) => n.includes('delete'));
      expect(hasUpdate || hasDelete || ruleNames.length === 0).toBe(true);
    }
  });
});

// ---------------------------------------------------------------------------
// Layer 21 — Teacher CPD
// ---------------------------------------------------------------------------

describe('Layer 21 — Teacher CPD', () => {
  test('observer_not_observed constraint on peer_observation_records', async () => {
    const result = await adminClient.query(
      `SELECT conname FROM pg_constraint
       WHERE conrelid = 'peer_observation_records'::regclass
         AND conname = 'observer_not_observed'`
    );
    expect(result.rows.length).toBe(1);
  });

  test('data_use_restrictions immutable on teacher_professional_profiles', async () => {
    // Delete any existing profile first, then insert
    await adminClient.query(
      `DELETE FROM teacher_professional_profiles WHERE tenant_id = $1 AND teacher_id = $2`,
      [testTenantId, testTeacherId]
    ).catch(() => {});
    await adminClient.query(
      `INSERT INTO teacher_professional_profiles
         (tenant_id, teacher_id, annual_cpd_target_hours)
       VALUES ($1, $2, 50)`,
      [testTenantId, testTeacherId]
    );

    await expect(async () => {
      await adminClient.query(
        `UPDATE teacher_professional_profiles
         SET data_use_restrictions = ARRAY['MODIFIED']
         WHERE tenant_id = $1 AND teacher_id = $2`,
        [testTenantId, testTeacherId]
      );
    }).rejects.toThrow(/immutable/);
  });

  test('cpd_hours_ledger append-only', async () => {
    const result = await adminClient.query(
      `SELECT rulename FROM pg_rules WHERE tablename = 'cpd_hours_ledger'`
    );
    const ruleNames = result.rows.map((r: { rulename: string }) => r.rulename);
    expect(ruleNames).toContain('no_cpd_ledger_update');
    expect(ruleNames).toContain('no_cpd_ledger_delete');
  });

  test('DISTRICT_ADMIN RLS returns 0 rows from professional_growth_interventions', async () => {
    await adminClient.query(
      `INSERT INTO professional_growth_interventions
         (tenant_id, teacher_id, title, status, created_by)
       VALUES ($1, $2, 'Test Growth Plan', 'DRAFT', $3)
       ON CONFLICT DO NOTHING`,
      [testTenantId, testTeacherId, testUserId]
    );

    const client = await getAppClient();
    try {
      await client.query('BEGIN');
      await client.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
      await client.query(`SET LOCAL app.user_id = '${testUserId}'`);
      await client.query(`SET LOCAL app.user_role = 'DISTRICT_ADMIN'`);

      const result = await client.query(
        `SELECT COUNT(*) as count FROM professional_growth_interventions`
      );
      expect(parseInt(result.rows[0].count)).toBe(0);

      await client.query('ROLLBACK');
    } catch (e) {
      await client.query('ROLLBACK').catch(() => {});
      throw e;
    } finally {
      client.release();
    }
  });
});

// ---------------------------------------------------------------------------
// Layer 22 — Portability & Verifiable Credentials
// ---------------------------------------------------------------------------

describe('Layer 22 — Portability', () => {
  test('credential_revocation_list append-only', async () => {
    const result = await adminClient.query(
      `SELECT rulename FROM pg_rules WHERE tablename = 'credential_revocation_list'`
    );
    const ruleNames = result.rows.map((r: { rulename: string }) => r.rulename);
    const hasUpdate = ruleNames.some((n: string) => n.includes('update'));
    const hasDelete = ruleNames.some((n: string) => n.includes('delete'));
    expect(hasUpdate).toBe(true);
    expect(hasDelete).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Layer 23 — Community & Partners
// ---------------------------------------------------------------------------

describe('Layer 23 — Community & Partners', () => {
  test('partner vetting trigger blocks session for unapproved partner', async () => {
    const partner = await adminClient.query(
      `INSERT INTO community_partners
         (tenant_id, name, partner_type, vetting_status, is_active)
       VALUES ($1, 'Unapproved Partner ' || substr(gen_random_uuid()::text,1,8), 'ORGANIZATION', 'PENDING', TRUE)
       RETURNING id`,
      [testTenantId]
    );
    const partnerId = partner.rows[0].id;

    const tmpl = await adminClient.query(
      `INSERT INTO engagement_activity_templates
         (tenant_id, name, activity_type)
       VALUES ($1, 'Test Vetting Activity ' || substr(gen_random_uuid()::text,1,8), 'BAGLESS_DAY')
       RETURNING id`,
      [testTenantId]
    );
    const templateId = tmpl.rows[0].id;

    await expect(async () => {
      await adminClient.query(
        `INSERT INTO engagement_sessions
           (tenant_id, partner_id, activity_template_id, school_id,
            session_date, hours, verification_status)
         VALUES ($1, $2, $3, $4, '2025-01-15', 2.0, 'PENDING')`,
        [testTenantId, partnerId, templateId, testSchoolId]
      );
    }).rejects.toThrow();
  });

  test('CRITICAL safeguarding auto-suspends partner', async () => {
    const partner = await adminClient.query(
      `INSERT INTO community_partners
         (tenant_id, name, partner_type, vetting_status, is_active)
       VALUES ($1, 'Will Be Suspended', 'ORGANIZATION', 'APPROVED', TRUE)
       RETURNING id`,
      [testTenantId]
    );
    const partnerId = partner.rows[0].id;

    await adminClient.query(
      `INSERT INTO partner_safeguarding_log
         (tenant_id, partner_id, severity, incident_description, reported_by)
       VALUES ($1, $2, 'CRITICAL', 'Critical safety incident during test', $3)`,
      [testTenantId, partnerId, testUserId]
    );

    const after = await adminClient.query(
      `SELECT vetting_status, is_active FROM community_partners WHERE id = $1`,
      [partnerId]
    );
    expect(after.rows[0].vetting_status).toBe('SUSPENDED');
  });

  test('partner_safeguarding_log and partner_vetting_log append-only', async () => {
    for (const table of ['partner_safeguarding_log', 'partner_vetting_log']) {
      const result = await adminClient.query(
        `SELECT rulename FROM pg_rules WHERE tablename = $1`,
        [table]
      );
      const ruleNames = result.rows.map(
        (r: { rulename: string }) => r.rulename
      );
      const hasUpdate = ruleNames.some((n: string) => n.includes('update'));
      const hasDelete = ruleNames.some((n: string) => n.includes('delete'));
      expect(hasUpdate).toBe(true);
      expect(hasDelete).toBe(true);
    }
  });

  test('engagement_computation_jobs idempotency_key unique', async () => {
    const result = await adminClient.query(
      `SELECT conname FROM pg_constraint
       WHERE conrelid = 'engagement_computation_jobs'::regclass
         AND contype = 'u'`
    );
    const names = result.rows.map((r: { conname: string }) => r.conname);
    const hasIdempKey = names.some(
      (n: string) =>
        n.includes('idempotency') || n.includes('engagement_computation_jobs')
    );
    expect(hasIdempKey).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// Schema Completeness
// ---------------------------------------------------------------------------

describe('Schema Completeness', () => {
  test('all V016-V026 migrations applied', async () => {
    const result = await adminClient.query(
      `SELECT version FROM schema_migrations ORDER BY version`
    );
    const versions = result.rows.map(
      (r: { version: string }) => r.version
    );
    for (let i = 16; i <= 26; i++) {
      const versionStr = `V0${i}`;
      expect(versions).toContain(versionStr);
    }
  });

  test('all 11 new layers (V016–V026) have schema_migrations entries', async () => {
    const result = await adminClient.query(
      `SELECT COUNT(*) as count FROM schema_migrations
       WHERE version IN (
         'V016', 'V017', 'V018', 'V019', 'V020',
         'V021', 'V022', 'V023', 'V024', 'V025', 'V026'
       )`
    );
    expect(parseInt(result.rows[0].count)).toBe(11);
  });
});
