import bcrypt from 'bcrypt';
import { query, withTransaction } from '../config/database';
import redis from '../config/redis';
import { insertAuditLog } from './audit.service';

const OTP_EXPIRY_MINUTES = 10;
const MAX_OTP_ATTEMPTS = 3;
const OTP_COOLDOWN_SECONDS = 60;

function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

export async function initiateConsent(tenantId: string, phone: string, purpose: string, userId: string) {
  const cooldownKey = `otp:cooldown:${phone}`;
  const exists = await redis.exists(cooldownKey);
  if (exists) {
    throw new Error('OTP_COOLDOWN_ACTIVE');
  }

  const otp = generateOTP();
  const otpHash = await bcrypt.hash(otp, 10);
  const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60 * 1000);

  await query(
    `INSERT INTO consent_otp_attempts (tenant_id, phone, otp_hash, purpose, expires_at)
     VALUES ($1, $2, $3, $4, $5)`,
    [tenantId, phone, otpHash, purpose, expiresAt]
  );

  await redis.setex(cooldownKey, OTP_COOLDOWN_SECONDS, '1');
  await redis.setex(`otp:attempts:${phone}:${purpose}`, OTP_EXPIRY_MINUTES * 60, '0');

  // In production: send via MSG91 DLT-registered template
  // For dev: return OTP (would never do this in production)
  return {
    message: 'OTP sent successfully',
    expiresAt: expiresAt.toISOString(),
    ...(process.env.NODE_ENV === 'development' ? { otp } : {}),
  };
}

export async function verifyConsent(
  tenantId: string,
  phone: string,
  otp: string,
  purposes: string[],
  studentId: string,
  userId: string,
  policyVersionId?: string
) {
  const attemptsKey = `otp:attempts:${phone}:${purposes[0]}`;
  const currentAttempts = parseInt(await redis.get(attemptsKey) || '0');

  if (currentAttempts >= MAX_OTP_ATTEMPTS) {
    throw new Error('MAX_OTP_ATTEMPTS_EXCEEDED');
  }

  const result = await query(
    `SELECT id, otp_hash, expires_at
     FROM consent_otp_attempts
     WHERE tenant_id = $1 AND phone = $2 AND purpose = $3
       AND is_successful = FALSE AND expires_at > now()
     ORDER BY attempted_at DESC LIMIT 1`,
    [tenantId, phone, purposes[0]]
  );

  if (result.rows.length === 0) {
    throw new Error('NO_VALID_OTP');
  }

  const otpRecord = result.rows[0];
  const isValid = await bcrypt.compare(otp, otpRecord.otp_hash);

  if (!isValid) {
    await redis.incr(attemptsKey);
    throw new Error('INVALID_OTP');
  }

  return withTransaction(async (client) => {
    const consentRecords = [];

    for (const purpose of purposes) {
      const consentResult = await client.query(
        `INSERT INTO data_consent_records
           (tenant_id, student_id, consenting_user_id, consent_purpose_code, verification_method, policy_version_id)
         VALUES ($1, $2, $3, $4, 'OTP', $5)
         ON CONFLICT (tenant_id, student_id, consent_purpose_code, consent_status) DO NOTHING
         RETURNING id`,
        [tenantId, studentId, userId, purpose, policyVersionId || null]
      );

      if (consentResult.rows.length > 0) {
        consentRecords.push({ id: consentResult.rows[0].id, purpose });
      }
    }

    await insertAuditLog({
      tenantId,
      eventType: 'CONSENT.GRANTED',
      entityType: 'DATA_CONSENT_RECORDS',
      entityId: studentId,
      performedBy: userId,
      afterState: { purposes, verificationMethod: 'OTP' },
    }, client);

    return { consentRecords };
  }, tenantId, userId, 'PARENT');
}
