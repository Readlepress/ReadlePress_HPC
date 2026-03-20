import { Pool, PoolClient } from 'pg';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const ROLE_RE = /^[A-Z_]{2,40}$/;

function requireEnv(key: string, fallback?: string): string {
  const value = process.env[key];
  if (value) return value;
  if (fallback && process.env.NODE_ENV === 'development') return fallback;
  throw new Error(`Missing required environment variable: ${key}`);
}

const pool = new Pool({
  connectionString: requireEnv('DATABASE_URL', 'postgresql://app_rw:app_rw_dev_password@localhost:5432/readlepress'),
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
});

const adminPool = new Pool({
  connectionString: requireEnv('DATABASE_ADMIN_URL', 'postgresql://readlepress_admin:dev_password_only@localhost:5432/readlepress'),
  max: 5,
});

export async function getClient(): Promise<PoolClient> {
  return pool.connect();
}

export async function getAdminClient(): Promise<PoolClient> {
  return adminPool.connect();
}

export async function setTenantContext(client: PoolClient, tenantId: string, userId: string, userRole: string): Promise<void> {
  if (!UUID_RE.test(tenantId)) throw new Error('Invalid tenant_id format');
  if (!UUID_RE.test(userId)) throw new Error('Invalid user_id format');
  if (!ROLE_RE.test(userRole)) throw new Error('Invalid user_role format');

  await client.query('SELECT set_config($1, $2, true)', ['app.tenant_id', tenantId]);
  await client.query('SELECT set_config($1, $2, true)', ['app.user_id', userId]);
  await client.query('SELECT set_config($1, $2, true)', ['app.user_role', userRole]);
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
