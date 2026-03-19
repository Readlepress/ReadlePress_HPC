import { withTransaction, query } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function generatePortabilityPackage(
  tenantId: string,
  userId: string,
  userRole: string,
  studentId: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO portability_packages
         (tenant_id, student_id, generated_by, status, package_hash, signature)
       VALUES ($1, $2, $3, 'GENERATING', '', '')
       RETURNING id`,
      [tenantId, studentId, userId]
    );

    const packageId = result.rows[0].id;

    await insertAuditLog({
      tenantId,
      eventType: 'PORTABILITY_PACKAGE.GENERATED',
      entityType: 'PORTABILITY_PACKAGES',
      entityId: packageId,
      performedBy: userId,
      afterState: { studentId },
    }, client);

    return { packageId, status: 'GENERATING' };
  }, tenantId, userId, userRole);
}

export async function importPortabilityPackage(
  tenantId: string,
  userId: string,
  userRole: string,
  data: { packageData: string; sourceSchoolId?: string }
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO portability_packages
         (tenant_id, student_id, generated_by, status, package_hash, signature, is_import)
       VALUES ($1, NULL, $2, 'IMPORTING', '', '', TRUE)
       RETURNING id`,
      [tenantId, userId]
    );

    const packageId = result.rows[0].id;

    await insertAuditLog({
      tenantId,
      eventType: 'PORTABILITY_PACKAGE.IMPORTED',
      entityType: 'PORTABILITY_PACKAGES',
      entityId: packageId,
      performedBy: userId,
    }, client);

    return { packageId, status: 'IMPORTING' };
  }, tenantId, userId, userRole);
}

export async function getCrl() {
  const result = await query(
    `SELECT id, serial_number, revoked_at, reason, expires_at
     FROM credential_revocation_list
     WHERE expires_at > now()
     ORDER BY revoked_at DESC`
  );
  return result.rows;
}

export async function verifyPackageSignature(
  tenantId: string,
  userId: string,
  userRole: string,
  data: { packageHash: string; signature: string }
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT id, package_hash, signature, status
       FROM portability_packages
       WHERE package_hash = $1`,
      [data.packageHash]
    );

    if (result.rows.length === 0) {
      return { verified: false, reason: 'PACKAGE_NOT_FOUND' };
    }

    const pkg = result.rows[0];
    const signatureValid = pkg.signature === data.signature;

    const crlCheck = await client.query(
      `SELECT id FROM credential_revocation_list
       WHERE serial_number = $1 AND expires_at > now()`,
      [data.packageHash]
    );

    const isRevoked = crlCheck.rows.length > 0;

    return {
      verified: signatureValid && !isRevoked,
      signatureValid,
      isRevoked,
    };
  }, tenantId, userId, userRole);
}
