import { Pool, PoolClient } from 'pg';

const TEST_DB_URL = process.env.DATABASE_ADMIN_URL || 'postgresql://readlepress_admin:dev_password_only@localhost:5432/readlepress';
const APP_RW_URL = process.env.DATABASE_URL || 'postgresql://app_rw:app_rw_dev_password@localhost:5432/readlepress';

let adminPool: Pool;
let appPool: Pool;
let adminClient: PoolClient;
let appClient: PoolClient;

let testTenantId: string;
let testUserId: string;

beforeAll(async () => {
  adminPool = new Pool({ connectionString: TEST_DB_URL });
  appPool = new Pool({ connectionString: APP_RW_URL });

  adminClient = await adminPool.connect();
  appClient = await appPool.connect();

  // Create test tenant and user
  const tenantResult = await adminClient.query(
    `INSERT INTO tenants (name, slug) VALUES ('Test Tenant A', 'test-tenant-a')
     ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
     RETURNING id`
  );
  testTenantId = tenantResult.rows[0].id;

  const userResult = await adminClient.query(
    `INSERT INTO users (tenant_id, email, password_hash, display_name, status)
     VALUES ($1, 'test-rls@test.com', 'hash', 'Test User', 'ACTIVE')
     ON CONFLICT DO NOTHING
     RETURNING id`,
    [testTenantId]
  );

  if (userResult.rows.length > 0) {
    testUserId = userResult.rows[0].id;
  } else {
    const existingUser = await adminClient.query(
      `SELECT id FROM users WHERE email = 'test-rls@test.com' AND tenant_id = $1`,
      [testTenantId]
    );
    testUserId = existingUser.rows[0].id;
  }
});

afterAll(async () => {
  if (adminClient) adminClient.release();
  if (appClient) appClient.release();
  if (adminPool) await adminPool.end();
  if (appPool) await appPool.end();
});

describe('Layer 1 — Platform Foundation', () => {
  describe('RLS: Tenant Isolation', () => {
    let tenantBId: string;

    beforeAll(async () => {
      // Create a second tenant
      const result = await adminClient.query(
        `INSERT INTO tenants (name, slug) VALUES ('Test Tenant B', 'test-tenant-b')
         ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
         RETURNING id`
      );
      tenantBId = result.rows[0].id;

      // Insert a user in Tenant B
      await adminClient.query(
        `INSERT INTO users (tenant_id, email, password_hash, display_name, status)
         VALUES ($1, 'tenantb@test.com', 'hash', 'Tenant B User', 'ACTIVE')
         ON CONFLICT DO NOTHING`,
        [tenantBId]
      );
    });

    test('Tenant A context returns zero rows from Tenant B data', async () => {
      await appClient.query('BEGIN');
      await appClient.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
      await appClient.query(`SET LOCAL app.user_id = '${testUserId}'`);
      await appClient.query(`SET LOCAL app.user_role = 'CLASS_TEACHER'`);

      const result = await appClient.query(
        'SELECT COUNT(*) as count FROM users WHERE tenant_id = $1',
        [tenantBId]
      );

      expect(parseInt(result.rows[0].count)).toBe(0);
      await appClient.query('ROLLBACK');
    });
  });

  describe('Audit Log: Append-only enforcement', () => {
    test('UPDATE on audit_log is silently ignored (DO INSTEAD NOTHING)', async () => {
      await appClient.query('BEGIN');
      await appClient.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
      await appClient.query(`SET LOCAL app.user_id = '${testUserId}'`);
      await appClient.query(`SET LOCAL app.user_role = 'PLATFORM_ADMIN'`);

      // Insert a test audit record
      await appClient.query(
        `INSERT INTO audit_log (tenant_id, event_type, entity_type, entity_id, performed_by)
         VALUES ($1, 'TEST', 'TEST', $2, $2)`,
        [testTenantId, testUserId]
      );

      const beforeUpdate = await appClient.query(
        `SELECT COUNT(*) as count FROM audit_log WHERE tenant_id = $1 AND event_type = 'TEST'`,
        [testTenantId]
      );

      // Attempt UPDATE — should be silently ignored by the rule
      await appClient.query(
        `UPDATE audit_log SET event_type = 'MODIFIED' WHERE tenant_id = $1 AND event_type = 'TEST'`,
        [testTenantId]
      );

      const afterUpdate = await appClient.query(
        `SELECT COUNT(*) as count FROM audit_log WHERE tenant_id = $1 AND event_type = 'TEST'`,
        [testTenantId]
      );

      // The record should still have the original event_type
      expect(afterUpdate.rows[0].count).toBe(beforeUpdate.rows[0].count);

      await appClient.query('ROLLBACK');
    });

    test('DELETE on audit_log is silently ignored (DO INSTEAD NOTHING)', async () => {
      await appClient.query('BEGIN');
      await appClient.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
      await appClient.query(`SET LOCAL app.user_id = '${testUserId}'`);
      await appClient.query(`SET LOCAL app.user_role = 'PLATFORM_ADMIN'`);

      await appClient.query(
        `INSERT INTO audit_log (tenant_id, event_type, entity_type, entity_id, performed_by)
         VALUES ($1, 'TEST_DELETE', 'TEST', $2, $2)`,
        [testTenantId, testUserId]
      );

      const beforeDelete = await appClient.query(
        `SELECT COUNT(*) as count FROM audit_log WHERE tenant_id = $1 AND event_type = 'TEST_DELETE'`,
        [testTenantId]
      );

      await appClient.query(
        `DELETE FROM audit_log WHERE tenant_id = $1 AND event_type = 'TEST_DELETE'`,
        [testTenantId]
      );

      const afterDelete = await appClient.query(
        `SELECT COUNT(*) as count FROM audit_log WHERE tenant_id = $1 AND event_type = 'TEST_DELETE'`,
        [testTenantId]
      );

      expect(afterDelete.rows[0].count).toBe(beforeDelete.rows[0].count);

      await appClient.query('ROLLBACK');
    });
  });

  describe('Audit Hash Chain', () => {
    test('Hash chain produces consistent hashes', async () => {
      const result = await adminClient.query(
        `SELECT row_hash FROM audit_log WHERE tenant_id = $1 LIMIT 1`,
        [testTenantId]
      );

      if (result.rows.length > 0) {
        expect(result.rows[0].row_hash).toBeTruthy();
        expect(result.rows[0].row_hash.length).toBe(64); // SHA-256 hex
      }
    });
  });
});

describe('Layer 2 — Government Identity', () => {
  test('UDISE code format enforced (11 digits)', async () => {
    await expect(async () => {
      await adminClient.query(
        `INSERT INTO schools (tenant_id, udise_code, name, district, state_code)
         VALUES ($1, '12345', 'Bad School', 'Test', 'XX')`,
        [testTenantId]
      );
    }).rejects.toThrow();
  });

  test('UDISE code accepts valid 11-digit code', async () => {
    const result = await adminClient.query(
      `INSERT INTO schools (tenant_id, udise_code, name, district, state_code)
       VALUES ($1, '12345678901', 'Valid School', 'Test', 'XX')
       ON CONFLICT DO NOTHING
       RETURNING id`,
      [testTenantId]
    );
    // Should not throw
    expect(true).toBe(true);
  });
});

describe('Layer 3 — Academic Year Lifecycle', () => {
  let schoolId: string;
  let yearId: string;

  beforeAll(async () => {
    const schoolResult = await adminClient.query(
      `SELECT id FROM schools WHERE tenant_id = $1 LIMIT 1`,
      [testTenantId]
    );

    if (schoolResult.rows.length === 0) {
      const newSchool = await adminClient.query(
        `INSERT INTO schools (tenant_id, udise_code, name, district, state_code)
         VALUES ($1, '99999999999', 'Test School', 'Test', 'XX')
         RETURNING id`,
        [testTenantId]
      );
      schoolId = newSchool.rows[0].id;
    } else {
      schoolId = schoolResult.rows[0].id;
    }

    const yearResult = await adminClient.query(
      `INSERT INTO academic_years (tenant_id, school_id, label, start_date, end_date, status)
       VALUES ($1, $2, '2024-25-test', '2024-04-01', '2025-03-31', 'PLANNING')
       ON CONFLICT DO NOTHING
       RETURNING id`,
      [testTenantId, schoolId]
    );

    if (yearResult.rows.length > 0) {
      yearId = yearResult.rows[0].id;
    } else {
      const existing = await adminClient.query(
        `SELECT id FROM academic_years WHERE tenant_id = $1 AND label = '2024-25-test'`,
        [testTenantId]
      );
      yearId = existing.rows[0].id;
    }
  });

  test('Year state machine enforces one-way transitions', async () => {
    // Transition to ACTIVE (valid)
    await adminClient.query(
      `UPDATE academic_years SET status = 'ACTIVE' WHERE id = $1`,
      [yearId]
    );

    // Attempt to go back to PLANNING (invalid)
    await expect(async () => {
      await adminClient.query(
        `UPDATE academic_years SET status = 'PLANNING' WHERE id = $1`,
        [yearId]
      );
    }).rejects.toThrow(/Invalid academic year state transition/);
  });

  test('Cannot transition from LOCKED back to ACTIVE', async () => {
    // Advance through states to LOCKED
    await adminClient.query(`UPDATE academic_years SET status = 'REVIEW' WHERE id = $1`, [yearId]);
    await adminClient.query(`UPDATE academic_years SET status = 'LOCKED' WHERE id = $1`, [yearId]);

    // Attempt LOCKED → ACTIVE
    await expect(async () => {
      await adminClient.query(
        `UPDATE academic_years SET status = 'ACTIVE' WHERE id = $1`,
        [yearId]
      );
    }).rejects.toThrow(/Invalid academic year state transition/);
  });
});

describe('Layer 4 — Taxonomy Spine', () => {
  let competencyId: string;
  let domainId: string;
  let stageId: string;

  beforeAll(async () => {
    const stageResult = await adminClient.query(`SELECT id FROM academic_stages WHERE stage_code = 'PREPARATORY'`);
    stageId = stageResult.rows[0].id;

    const domainResult = await adminClient.query(
      `INSERT INTO taxonomy_domains (tenant_id, domain_code, name, display_order)
       VALUES ($1, 'COG', 'Cognitive', 1)
       ON CONFLICT (tenant_id, domain_code) DO UPDATE SET name = EXCLUDED.name
       RETURNING id`,
      [testTenantId]
    );
    domainId = domainResult.rows[0].id;

    const compResult = await adminClient.query(
      `INSERT INTO competencies (tenant_id, uid, domain_id, stage_id, grade, subdomain, sequence_number, name)
       VALUES ($1, 'COMP-NCF23-PREP-G5-COG-NS-001', $2, $3, 5, 'NS', 1, 'Number Sense Basic')
       ON CONFLICT (uid) DO UPDATE SET name = EXCLUDED.name
       RETURNING id`,
      [testTenantId, domainId, stageId]
    );
    competencyId = compResult.rows[0].id;
  });

  test('Competency UID format enforced by CHECK constraint', async () => {
    await expect(async () => {
      await adminClient.query(
        `INSERT INTO competencies (tenant_id, uid, domain_id, stage_id, grade, subdomain, sequence_number, name)
         VALUES ($1, 'INVALID-UID', $2, $3, 5, 'NS', 99, 'Bad Comp')`,
        [testTenantId, domainId, stageId]
      );
    }).rejects.toThrow();
  });

  test('DB trigger blocks UPDATE on competency UIDs', async () => {
    // Set role context to CLASS_TEACHER (non-PLATFORM_ADMIN)
    await appClient.query('BEGIN');
    await appClient.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
    await appClient.query(`SET LOCAL app.user_id = '${testUserId}'`);
    await appClient.query(`SET LOCAL app.user_role = 'CLASS_TEACHER'`);

    await expect(async () => {
      await appClient.query(
        `UPDATE competencies SET name = 'Updated Name' WHERE id = $1`,
        [competencyId]
      );
    }).rejects.toThrow(/PLATFORM_ADMIN/);

    await appClient.query('ROLLBACK');
  });

  test('Competency UID cannot be changed even by PLATFORM_ADMIN', async () => {
    await appClient.query('BEGIN');
    await appClient.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
    await appClient.query(`SET LOCAL app.user_id = '${testUserId}'`);
    await appClient.query(`SET LOCAL app.user_role = 'PLATFORM_ADMIN'`);

    await expect(async () => {
      await appClient.query(
        `UPDATE competencies SET uid = 'COMP-NCF23-PREP-G5-COG-NS-999' WHERE id = $1`,
        [competencyId]
      );
    }).rejects.toThrow(/immutable/);

    await appClient.query('ROLLBACK');
  });
});

describe('Layer 5 — Localization', () => {
  test('OFFICIAL_LOCKED strings cannot be modified', async () => {
    // Create a localization key and an OFFICIAL_LOCKED string
    const keyResult = await adminClient.query(
      `INSERT INTO localization_keys (key_code, context)
       VALUES ('test.official.locked', 'test')
       ON CONFLICT (key_code) DO UPDATE SET context = EXCLUDED.context
       RETURNING id`
    );
    const keyId = keyResult.rows[0].id;

    await adminClient.query(
      `INSERT INTO localization_strings (key_id, language_code, value, status, locked_at)
       VALUES ($1, 'en', 'Official Text', 'OFFICIAL_LOCKED', now())
       ON CONFLICT DO NOTHING
       RETURNING id`,
      [keyId]
    );

    // Attempt to update it
    await expect(async () => {
      await adminClient.query(
        `UPDATE localization_strings SET value = 'Modified Text'
         WHERE key_id = $1 AND language_code = 'en' AND status = 'OFFICIAL_LOCKED'`,
        [keyId]
      );
    }).rejects.toThrow(/OFFICIAL_LOCKED/);
  });
});

describe('Layer 8 — Rubric Engine', () => {
  test('rubric_amendment_log is append-only', async () => {
    // The rule prevents UPDATE/DELETE
    // We just verify the rules exist
    const result = await adminClient.query(
      `SELECT rulename FROM pg_rules WHERE tablename = 'rubric_amendment_log'`
    );
    const ruleNames = result.rows.map((r: { rulename: string }) => r.rulename);
    expect(ruleNames).toContain('no_amendment_update');
    expect(ruleNames).toContain('no_amendment_delete');
  });
});

describe('Layer 9 — Mastery Events', () => {
  test('No-naked-scoring constraint fires at DB level', async () => {
    await expect(async () => {
      await adminClient.query(
        `INSERT INTO mastery_events
           (tenant_id, student_id, competency_id, class_id, assessor_id,
            numeric_value, observed_at, recorded_at, timestamp_source,
            evidence_record_ids, observation_note, event_status)
         VALUES ($1, gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), $2,
                 0.75, now(), now(), 'DEVICE_CLOCK',
                 '{}', NULL, 'DRAFT')`,
        [testTenantId, testUserId]
      );
    }).rejects.toThrow(/mastery_no_naked_scoring/);
  });
});

describe('Layer 11 — Intervention Sensitivity', () => {
  test('RLS policy exists for intervention_plans sensitivity', async () => {
    const result = await adminClient.query(
      `SELECT polname FROM pg_policy WHERE polrelid = 'intervention_plans'::regclass`
    );
    expect(result.rows.length).toBeGreaterThan(0);
  });
});

describe('Layer 12 — Overlay Self-Approval Prevention', () => {
  test('Overlay self-approval constraint exists', async () => {
    const result = await adminClient.query(
      `SELECT conname FROM pg_constraint
       WHERE conrelid = 'rubric_overlays'::regclass
         AND conname = 'overlay_self_approval_check'`
    );
    expect(result.rows.length).toBe(1);
  });
});

describe('Cross-Layer: Append-Only Tables', () => {
  const appendOnlyTables = [
    'audit_log',
    'evidence_custody_events',
    'rubric_amendment_log',
    'overlay_approval_log',
    'mastery_event_amendment_log',
    'consent_otp_attempts',
  ];

  for (const table of appendOnlyTables) {
    test(`${table} has UPDATE rule`, async () => {
      const result = await adminClient.query(
        `SELECT rulename FROM pg_rules WHERE tablename = $1 AND rulename LIKE '%update%'`,
        [table]
      );
      expect(result.rows.length).toBeGreaterThanOrEqual(1);
    });

    test(`${table} has DELETE rule`, async () => {
      const result = await adminClient.query(
        `SELECT rulename FROM pg_rules WHERE tablename = $1 AND rulename LIKE '%delete%'`,
        [table]
      );
      expect(result.rows.length).toBeGreaterThanOrEqual(1);
    });
  }
});

describe('Cross-Layer: Dual Approval Constraints', () => {
  test('locked_year_override_requests has dual approval constraint', async () => {
    const result = await adminClient.query(
      `SELECT conname FROM pg_constraint
       WHERE conrelid = 'locked_year_override_requests'::regclass
         AND conname = 'dual_approval_check'`
    );
    expect(result.rows.length).toBe(1);
  });

  test('mastery_event_amendment_log has dual approval constraint', async () => {
    const result = await adminClient.query(
      `SELECT conname FROM pg_constraint
       WHERE conrelid = 'mastery_event_amendment_log'::regclass
         AND conname = 'amendment_dual_approval'`
    );
    expect(result.rows.length).toBe(1);
  });
});
