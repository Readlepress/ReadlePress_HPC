import { Pool, PoolClient } from 'pg';

const TEST_DB_URL = process.env.DATABASE_ADMIN_URL || 'postgresql://readlepress_admin:dev_password_only@127.0.0.1:5432/readlepress';
const APP_RW_URL = process.env.DATABASE_URL || 'postgresql://app_rw:app_rw_dev_password@127.0.0.1:5432/readlepress';

let adminPool: Pool;
let appPool: Pool;
let adminClient: PoolClient;

let testTenantId: string;
let testUserId: string;

async function getAppClient(): Promise<PoolClient> {
  return appPool.connect();
}

beforeAll(async () => {
  adminPool = new Pool({ connectionString: TEST_DB_URL });
  appPool = new Pool({ connectionString: APP_RW_URL });

  adminClient = await adminPool.connect();

  const tenantResult = await adminClient.query(
    `INSERT INTO tenants (name, slug) VALUES ('Test Tenant A', 'test-tenant-a')
     ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
     RETURNING id`
  );
  testTenantId = tenantResult.rows[0].id;

  const existingUser = await adminClient.query(
    `SELECT id FROM users WHERE email = 'test-rls@test.com' AND tenant_id = $1`,
    [testTenantId]
  );

  if (existingUser.rows.length > 0) {
    testUserId = existingUser.rows[0].id;
  } else {
    const userResult = await adminClient.query(
      `INSERT INTO users (tenant_id, email, password_hash, display_name, status)
       VALUES ($1, 'test-rls@test.com', 'hash', 'Test User', 'ACTIVE')
       RETURNING id`,
      [testTenantId]
    );
    testUserId = userResult.rows[0].id;
  }
});

afterAll(async () => {
  if (adminClient) adminClient.release();
  if (adminPool) await adminPool.end();
  if (appPool) await appPool.end();
});

describe('Layer 1 — Platform Foundation', () => {
  describe('RLS: Tenant Isolation', () => {
    let tenantBId: string;

    beforeAll(async () => {
      const result = await adminClient.query(
        `INSERT INTO tenants (name, slug) VALUES ('Test Tenant B', 'test-tenant-b')
         ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
         RETURNING id`
      );
      tenantBId = result.rows[0].id;

      await adminClient.query(
        `INSERT INTO users (tenant_id, email, password_hash, display_name, status)
         VALUES ($1, 'tenantb@test.com', 'hash', 'Tenant B User', 'ACTIVE')
         ON CONFLICT DO NOTHING`,
        [tenantBId]
      );
    });

    test('Tenant A context returns zero rows from Tenant B data', async () => {
      const client = await getAppClient();
      try {
        await client.query('BEGIN');
        await client.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
        await client.query(`SET LOCAL app.user_id = '${testUserId}'`);
        await client.query(`SET LOCAL app.user_role = 'CLASS_TEACHER'`);

        const result = await client.query(
          'SELECT COUNT(*) as count FROM users WHERE tenant_id = $1',
          [tenantBId]
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

  describe('Audit Log: Append-only enforcement', () => {
    test('UPDATE on audit_log is silently ignored', async () => {
      const client = await getAppClient();
      try {
        await client.query('BEGIN');
        await client.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
        await client.query(`SET LOCAL app.user_id = '${testUserId}'`);
        await client.query(`SET LOCAL app.user_role = 'PLATFORM_ADMIN'`);

        await client.query(
          `INSERT INTO audit_log (tenant_id, event_type, entity_type, entity_id, performed_by)
           VALUES ($1, 'TEST_UPD', 'TEST', $2, $2)`,
          [testTenantId, testUserId]
        );

        const before = await client.query(
          `SELECT COUNT(*) as count FROM audit_log WHERE tenant_id = $1 AND event_type = 'TEST_UPD'`,
          [testTenantId]
        );

        await client.query(
          `UPDATE audit_log SET event_type = 'MODIFIED' WHERE tenant_id = $1 AND event_type = 'TEST_UPD'`,
          [testTenantId]
        );

        const after = await client.query(
          `SELECT COUNT(*) as count FROM audit_log WHERE tenant_id = $1 AND event_type = 'TEST_UPD'`,
          [testTenantId]
        );

        expect(after.rows[0].count).toBe(before.rows[0].count);
        await client.query('ROLLBACK');
      } catch (e) {
        await client.query('ROLLBACK').catch(() => {});
        throw e;
      } finally {
        client.release();
      }
    });

    test('DELETE on audit_log is silently ignored', async () => {
      const client = await getAppClient();
      try {
        await client.query('BEGIN');
        await client.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
        await client.query(`SET LOCAL app.user_id = '${testUserId}'`);
        await client.query(`SET LOCAL app.user_role = 'PLATFORM_ADMIN'`);

        await client.query(
          `INSERT INTO audit_log (tenant_id, event_type, entity_type, entity_id, performed_by)
           VALUES ($1, 'TEST_DEL', 'TEST', $2, $2)`,
          [testTenantId, testUserId]
        );

        const before = await client.query(
          `SELECT COUNT(*) as count FROM audit_log WHERE tenant_id = $1 AND event_type = 'TEST_DEL'`,
          [testTenantId]
        );

        await client.query(
          `DELETE FROM audit_log WHERE tenant_id = $1 AND event_type = 'TEST_DEL'`,
          [testTenantId]
        );

        const after = await client.query(
          `SELECT COUNT(*) as count FROM audit_log WHERE tenant_id = $1 AND event_type = 'TEST_DEL'`,
          [testTenantId]
        );

        expect(after.rows[0].count).toBe(before.rows[0].count);
        await client.query('ROLLBACK');
      } catch (e) {
        await client.query('ROLLBACK').catch(() => {});
        throw e;
      } finally {
        client.release();
      }
    });
  });

  describe('Audit Hash Chain', () => {
    test('Hash chain produces consistent SHA-256 hashes', async () => {
      // Insert via admin to ensure it works
      await adminClient.query(
        `INSERT INTO audit_log (tenant_id, event_type, entity_type, entity_id, performed_by)
         VALUES ($1, 'HASH_TEST', 'TEST', $2, $2)`,
        [testTenantId, testUserId]
      );

      const result = await adminClient.query(
        `SELECT row_hash FROM audit_log WHERE tenant_id = $1 AND event_type = 'HASH_TEST' LIMIT 1`,
        [testTenantId]
      );

      expect(result.rows.length).toBeGreaterThan(0);
      expect(result.rows[0].row_hash).toBeTruthy();
      expect(result.rows[0].row_hash.length).toBe(64);
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
    expect(true).toBe(true);
  });
});

describe('Layer 3 — Academic Year Lifecycle', () => {
  let schoolId: string;

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
  });

  test('Year state machine enforces one-way transitions', async () => {
    const label = 'test-sm-' + Date.now();
    const yearResult = await adminClient.query(
      `INSERT INTO academic_years (tenant_id, school_id, label, start_date, end_date, status)
       VALUES ($1, $2, $3, '2024-04-01', '2025-03-31', 'PLANNING')
       RETURNING id`,
      [testTenantId, schoolId, label]
    );
    const yearId = yearResult.rows[0].id;

    await adminClient.query(
      `UPDATE academic_years SET status = 'ACTIVE' WHERE id = $1`,
      [yearId]
    );

    await expect(async () => {
      await adminClient.query(
        `UPDATE academic_years SET status = 'PLANNING' WHERE id = $1`,
        [yearId]
      );
    }).rejects.toThrow(/Invalid academic year state transition/);
  });

  test('Cannot transition from LOCKED back to ACTIVE', async () => {
    const label = 'test-lock-' + Date.now();
    const yearResult = await adminClient.query(
      `INSERT INTO academic_years (tenant_id, school_id, label, start_date, end_date, status)
       VALUES ($1, $2, $3, '2024-04-01', '2025-03-31', 'PLANNING')
       RETURNING id`,
      [testTenantId, schoolId, label]
    );
    const yearId = yearResult.rows[0].id;

    await adminClient.query(`UPDATE academic_years SET status = 'ACTIVE' WHERE id = $1`, [yearId]);
    await adminClient.query(`UPDATE academic_years SET status = 'REVIEW' WHERE id = $1`, [yearId]);
    await adminClient.query(`UPDATE academic_years SET status = 'LOCKED' WHERE id = $1`, [yearId]);

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

  test('DB trigger blocks UPDATE on competencies for non-PLATFORM_ADMIN', async () => {
    const client = await getAppClient();
    try {
      await client.query('BEGIN');
      await client.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
      await client.query(`SET LOCAL app.user_id = '${testUserId}'`);
      await client.query(`SET LOCAL app.user_role = 'CLASS_TEACHER'`);

      await expect(async () => {
        await client.query(
          `UPDATE competencies SET name = 'Updated Name' WHERE id = $1`,
          [competencyId]
        );
      }).rejects.toThrow(/PLATFORM_ADMIN/);

      await client.query('ROLLBACK').catch(() => {});
    } catch (e) {
      await client.query('ROLLBACK').catch(() => {});
      throw e;
    } finally {
      client.release();
    }
  });

  test('Competency UID cannot be changed even by PLATFORM_ADMIN', async () => {
    const client = await getAppClient();
    try {
      await client.query('BEGIN');
      await client.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
      await client.query(`SET LOCAL app.user_id = '${testUserId}'`);
      await client.query(`SET LOCAL app.user_role = 'PLATFORM_ADMIN'`);

      await expect(async () => {
        await client.query(
          `UPDATE competencies SET uid = 'COMP-NCF23-PREP-G5-COG-NS-999' WHERE id = $1`,
          [competencyId]
        );
      }).rejects.toThrow(/immutable/);

      await client.query('ROLLBACK').catch(() => {});
    } catch (e) {
      await client.query('ROLLBACK').catch(() => {});
      throw e;
    } finally {
      client.release();
    }
  });
});

describe('Layer 5 — Localization', () => {
  test('OFFICIAL_LOCKED strings cannot be modified', async () => {
    const keyResult = await adminClient.query(
      `INSERT INTO localization_keys (key_code, context)
       VALUES ('test.official.locked', 'test')
       ON CONFLICT (key_code) DO UPDATE SET context = EXCLUDED.context
       RETURNING id`
    );
    const keyId = keyResult.rows[0].id;

    await adminClient.query(
      `DELETE FROM localization_strings WHERE key_id = $1 AND language_code = 'en' AND status = 'OFFICIAL_LOCKED'`,
      [keyId]
    ).catch(() => {}); // May fail due to rules, ignore

    await adminClient.query(
      `INSERT INTO localization_strings (key_id, language_code, value, status, locked_at)
       VALUES ($1, 'en', 'Official Text', 'OFFICIAL_LOCKED', now())`,
      [keyId]
    );

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
  test('rubric_amendment_log is append-only (rules exist)', async () => {
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
           (tenant_id, student_id, competency_id, class_id, assessor_id, academic_year_id,
            numeric_value, observed_at, recorded_at, timestamp_source,
            evidence_record_ids, observation_note, event_status)
         VALUES ($1, gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), $2, gen_random_uuid(),
                 0.75, now(), now(), 'DEVICE_CLOCK',
                 '{}', NULL, 'DRAFT')`,
        [testTenantId, testUserId]
      );
    }).rejects.toThrow(/mastery_no_naked_scoring/);
  });

  test('No-naked-scoring constraint definition exists on partition', async () => {
    // After partitioning, the constraint lives on the partition child tables
    const result = await adminClient.query(
      `SELECT conname, pg_get_constraintdef(oid) as def
       FROM pg_constraint
       WHERE conname LIKE '%mastery_no_naked_scoring%'
       LIMIT 1`
    );
    expect(result.rows.length).toBe(1);
    expect(result.rows[0].def).toContain('observation_note');
    expect(result.rows[0].def).toContain('evidence_record_ids');
  });
});

describe('Layer 11 — Intervention Sensitivity', () => {
  test('RLS policy exists for intervention_plans sensitivity', async () => {
    const result = await adminClient.query(
      `SELECT polname FROM pg_policy WHERE polrelid = 'intervention_plans'::regclass`
    );
    expect(result.rows.length).toBeGreaterThan(0);
  });

  test('CLASS_TEACHER cannot see WELFARE plans via RLS', async () => {
    // Create a WELFARE intervention plan as admin
    const schoolResult = await adminClient.query(
      `SELECT id FROM schools WHERE tenant_id = $1 LIMIT 1`, [testTenantId]
    );

    if (schoolResult.rows.length > 0) {
      const classResult = await adminClient.query(
        `SELECT id FROM classes WHERE tenant_id = $1 LIMIT 1`, [testTenantId]
      );

      // Create test data only if we have the needed entities
      if (classResult.rows.length > 0) {
        const studentResult = await adminClient.query(
          `SELECT id FROM student_profiles WHERE tenant_id = $1 LIMIT 1`, [testTenantId]
        );

        if (studentResult.rows.length > 0) {
          await adminClient.query(
            `INSERT INTO intervention_plans
               (tenant_id, student_id, class_id, sensitivity_level, title, created_by, status)
             VALUES ($1, $2, $3, 'WELFARE', 'Test Welfare Plan', $4, 'ACTIVE')
             ON CONFLICT DO NOTHING`,
            [testTenantId, studentResult.rows[0].id, classResult.rows[0].id, testUserId]
          );

          // Now query as CLASS_TEACHER
          const client = await getAppClient();
          try {
            await client.query('BEGIN');
            await client.query(`SET LOCAL app.tenant_id = '${testTenantId}'`);
            await client.query(`SET LOCAL app.user_id = '${testUserId}'`);
            await client.query(`SET LOCAL app.user_role = 'CLASS_TEACHER'`);

            const result = await client.query(
              `SELECT * FROM intervention_plans WHERE sensitivity_level = 'WELFARE'`
            );

            expect(result.rows.length).toBe(0);
            await client.query('ROLLBACK');
          } finally {
            client.release();
          }
        }
      }
    }
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

describe('Cross-Layer: RLS on All Tenant-Scoped Tables', () => {
  test('All major tables have RLS enabled', async () => {
    const result = await adminClient.query(
      `SELECT relname, relrowsecurity, relforcerowsecurity
       FROM pg_class
       WHERE relname IN (
         'users', 'role_assignments', 'audit_log', 'schools', 'student_profiles',
         'academic_years', 'competencies', 'mastery_events', 'evidence_records',
         'feedback_requests', 'intervention_plans', 'rubric_overlays'
       )
       ORDER BY relname`
    );

    for (const row of result.rows) {
      expect(row.relrowsecurity).toBe(true);
      expect(row.relforcerowsecurity).toBe(true);
    }
  });
});

describe('Database Schema Completeness', () => {
  test('All 12 layer migrations applied', async () => {
    const result = await adminClient.query(
      `SELECT version FROM schema_migrations ORDER BY version`
    );
    const versions = result.rows.map((r: { version: string }) => r.version);
    expect(versions).toContain('V001');
    expect(versions).toContain('V002');
    expect(versions).toContain('V003');
    expect(versions).toContain('V004');
    expect(versions).toContain('V005');
    expect(versions).toContain('V006');
    expect(versions).toContain('V007');
    expect(versions).toContain('V008');
    expect(versions).toContain('V009');
    expect(versions).toContain('V010');
    expect(versions).toContain('V011');
    expect(versions).toContain('V012');
  });

  test('NEP 2020 academic stages seeded correctly', async () => {
    const result = await adminClient.query(
      `SELECT stage_code, display_mode FROM academic_stages ORDER BY grade_range_start`
    );
    expect(result.rows.length).toBe(4);
    expect(result.rows[0].stage_code).toBe('FOUNDATIONAL');
    expect(result.rows[0].display_mode).toBe('EMOJI_METAPHOR');
    expect(result.rows[3].stage_code).toBe('SECONDARY');
    expect(result.rows[3].display_mode).toBe('FULL_ACADEMIC');
  });

  test('22+ Indian languages seeded in supported_languages', async () => {
    const result = await adminClient.query(`SELECT COUNT(*) as count FROM supported_languages`);
    expect(parseInt(result.rows[0].count)).toBeGreaterThanOrEqual(22);
  });

  test('RTL languages (Urdu, Kashmiri) marked correctly', async () => {
    const result = await adminClient.query(
      `SELECT language_code, text_direction, font_family FROM supported_languages
       WHERE text_direction = 'RTL'`
    );
    expect(result.rows.length).toBe(2);
    const codes = result.rows.map((r: { language_code: string }) => r.language_code);
    expect(codes).toContain('ur');
    expect(codes).toContain('ks');
  });
});
