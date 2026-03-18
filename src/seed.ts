import { Pool } from 'pg';
import bcrypt from 'bcrypt';

const adminPool = new Pool({
  connectionString: process.env.DATABASE_ADMIN_URL || 'postgresql://readlepress_admin:dev_password_only@localhost:5432/readlepress',
});

async function seed() {
  const client = await adminPool.connect();

  try {
    console.log('Seeding database...');

    // Create a test tenant
    const tenantResult = await client.query(
      `INSERT INTO tenants (name, slug, status)
       VALUES ('Demo District', 'demo-district', 'ACTIVE')
       ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name
       RETURNING id`
    );
    const tenantId = tenantResult.rows[0].id;
    console.log(`  Tenant: ${tenantId}`);

    // Create admin user
    const passwordHash = await bcrypt.hash('admin123', 12);
    const adminResult = await client.query(
      `INSERT INTO users (tenant_id, email, phone, password_hash, display_name, status)
       VALUES ($1, 'admin@readlepress.dev', '+919999999999', $2, 'Admin User', 'ACTIVE')
       ON CONFLICT ON CONSTRAINT users_email_or_phone DO NOTHING
       RETURNING id`,
      [tenantId, passwordHash]
    );

    if (adminResult.rows.length > 0) {
      const adminId = adminResult.rows[0].id;

      // Seed permissions
      const permissionCodes = [
        ['MASTERY_EVENT:CREATE', 'Create mastery events', 'MASTERY'],
        ['MASTERY_EVENT:VERIFY', 'Verify mastery events', 'MASTERY'],
        ['MASTERY_EVENT:READ', 'Read mastery events', 'MASTERY'],
        ['EVIDENCE:CREATE', 'Upload evidence', 'EVIDENCE'],
        ['EVIDENCE:READ', 'Read evidence', 'EVIDENCE'],
        ['EVIDENCE:READ_RESTRICTED', 'Read restricted evidence', 'EVIDENCE'],
        ['STUDENT:READ', 'Read student profiles', 'STUDENT'],
        ['STUDENT:WRITE', 'Write student profiles', 'STUDENT'],
        ['STUDENT:READ_SENSITIVE', 'Read sensitive student data', 'STUDENT'],
        ['CONSENT:MANAGE', 'Manage consent records', 'CONSENT'],
        ['YEAR:CLOSE', 'Close academic year', 'YEAR'],
        ['INTERVENTION:CREATE', 'Create interventions', 'INTERVENTION'],
        ['INTERVENTION:READ_WELFARE', 'Read welfare cases', 'INTERVENTION'],
        ['OVERLAY:CREATE', 'Create overlays', 'INCLUSION'],
        ['OVERLAY:APPROVE', 'Approve overlays', 'INCLUSION'],
      ];

      for (const [code, desc, category] of permissionCodes) {
        await client.query(
          `INSERT INTO permissions (code, description, category)
           VALUES ($1, $2, $3)
           ON CONFLICT (code) DO NOTHING`,
          [code, desc, category]
        );
      }

      // Assign PLATFORM_ADMIN role
      await client.query(
        `INSERT INTO role_assignments (tenant_id, user_id, role_code, assigned_by)
         VALUES ($1, $2, 'PLATFORM_ADMIN', $2)
         ON CONFLICT ON CONSTRAINT unique_role_per_scope DO NOTHING`,
        [tenantId, adminId]
      );

      // Create a demo school
      await client.query(
        `INSERT INTO schools (tenant_id, udise_code, name, district, state_code)
         VALUES ($1, '27010100101', 'Government Primary School Demo', 'Mumbai', 'MH')
         ON CONFLICT ON CONSTRAINT unique_udise_per_tenant DO NOTHING`,
        [tenantId]
      );

      // Seed default aggregation policies
      const alphaDefaults = [
        ['DIRECT_OBSERVATION', 0.400],
        ['SELF_ASSESSMENT', 0.200],
        ['PEER_ASSESSMENT', 0.200],
        ['HISTORICAL_ENTRY', 0.120],
      ];

      for (const [sourceType, alpha] of alphaDefaults) {
        await client.query(
          `INSERT INTO aggregation_policy (tenant_id, source_type, alpha)
           VALUES ($1, $2, $3)
           ON CONFLICT (tenant_id, source_type) DO NOTHING`,
          [tenantId, sourceType, alpha]
        );
      }

      console.log(`  Admin user: ${adminId}`);
    }

    console.log('Seeding complete.');
  } catch (err) {
    console.error('Seed failed:', err);
    throw err;
  } finally {
    client.release();
    await adminPool.end();
  }
}

seed();
