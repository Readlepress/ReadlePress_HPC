import { Pool, PoolClient } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://app_rw:app_rw_dev_password@localhost:5432/readlepress',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

const adminPool = new Pool({
  connectionString: process.env.DATABASE_ADMIN_URL || 'postgresql://readlepress_admin:dev_password_only@localhost:5432/readlepress',
  max: 5,
});

export async function getClient(): Promise<PoolClient> {
  return pool.connect();
}

export async function getAdminClient(): Promise<PoolClient> {
  return adminPool.connect();
}

export async function setTenantContext(client: PoolClient, tenantId: string, userId: string, userRole: string): Promise<void> {
  await client.query(`SET LOCAL app.tenant_id = '${tenantId}'`);
  await client.query(`SET LOCAL app.user_id = '${userId}'`);
  await client.query(`SET LOCAL app.user_role = '${userRole}'`);
}

export async function query(text: string, params?: unknown[]) {
  return pool.query(text, params);
}

export async function withTransaction<T>(
  fn: (client: PoolClient) => Promise<T>,
  tenantId?: string,
  userId?: string,
  userRole?: string
): Promise<T> {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (tenantId && userId && userRole) {
      await setTenantContext(client, tenantId, userId, userRole);
    }
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

export { pool, adminPool };
export default pool;
