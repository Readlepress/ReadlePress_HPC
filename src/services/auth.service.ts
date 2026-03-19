import bcrypt from 'bcrypt';
import { query, withTransaction, adminPool } from '../config/database';
import redis from '../config/redis';

const SALT_ROUNDS = 12;
const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_DURATION_MINUTES = 30;

export async function authenticateUser(email: string | undefined, phone: string | undefined, password: string) {
  const identifierField = email ? 'email' : 'phone';
  const identifierValue = email || phone;

  // Login queries bypass RLS (we don't know tenant_id yet)
  const result = await adminPool.query(
    `SELECT u.id, u.tenant_id, u.password_hash, u.status, u.failed_login_attempts, u.locked_until,
            ra.role_code
     FROM users u
     LEFT JOIN role_assignments ra ON ra.user_id = u.id AND ra.is_active = TRUE
     WHERE u.${identifierField} = $1
     LIMIT 1`,
    [identifierValue]
  );

  if (result.rows.length === 0) {
    throw new Error('INVALID_CREDENTIALS');
  }

  const user = result.rows[0];

  if (user.status !== 'ACTIVE') {
    throw new Error('ACCOUNT_INACTIVE');
  }

  if (user.locked_until && new Date(user.locked_until) > new Date()) {
    throw new Error('ACCOUNT_LOCKED');
  }

  const isValid = await bcrypt.compare(password, user.password_hash);

  if (!isValid) {
    const newAttempts = (user.failed_login_attempts || 0) + 1;
    const lockUntil = newAttempts >= MAX_LOGIN_ATTEMPTS
      ? new Date(Date.now() + LOCKOUT_DURATION_MINUTES * 60 * 1000)
      : null;

    await adminPool.query(
      'UPDATE users SET failed_login_attempts = $1, locked_until = $2 WHERE id = $3',
      [newAttempts, lockUntil, user.id]
    );

    throw new Error('INVALID_CREDENTIALS');
  }

  await adminPool.query(
    'UPDATE users SET failed_login_attempts = 0, locked_until = NULL, last_login_at = now() WHERE id = $1',
    [user.id]
  );

  return {
    userId: user.id,
    tenantId: user.tenant_id,
    role: user.role_code || 'STUDENT',
  };
}

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, SALT_ROUNDS);
}
