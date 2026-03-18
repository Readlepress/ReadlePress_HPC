import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';
import { TrustLevel } from '../types';

export async function uploadEvidence(
  tenantId: string,
  userId: string,
  userRole: string,
  data: {
    storageProviderId: string;
    contentRef: string;
    contentType: string;
    mimeType: string;
    fileSizeBytes: number;
    originalFilename: string;
    contentHash: string;
    trustLevel: TrustLevel;
    classification?: string;
  }
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO evidence_records
         (tenant_id, storage_provider_id, content_ref, content_type, mime_type,
          file_size_bytes, original_filename, content_hash, trust_level,
          classification, uploaded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING id`,
      [
        tenantId, data.storageProviderId, data.contentRef, data.contentType,
        data.mimeType, data.fileSizeBytes, data.originalFilename,
        data.contentHash, data.trustLevel, data.classification || 'STANDARD', userId,
      ]
    );

    const evidenceId = result.rows[0].id;

    await client.query(
      `INSERT INTO evidence_custody_events
         (tenant_id, evidence_id, event_type, performed_by)
       VALUES ($1, $2, 'UPLOADED', $3)`,
      [tenantId, evidenceId, userId]
    );

    await insertAuditLog({
      tenantId,
      eventType: 'EVIDENCE.UPLOADED',
      entityType: 'EVIDENCE_RECORDS',
      entityId: evidenceId,
      performedBy: userId,
      afterState: {
        contentType: data.contentType,
        trustLevel: data.trustLevel,
        classification: data.classification,
      },
    }, client);

    return { id: evidenceId };
  }, tenantId, userId, userRole);
}

export async function getEvidence(
  tenantId: string,
  userId: string,
  userRole: string,
  evidenceId: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      'SELECT * FROM evidence_records WHERE id = $1',
      [evidenceId]
    );

    if (result.rows.length === 0) {
      throw new Error('EVIDENCE_NOT_FOUND');
    }

    const evidence = result.rows[0];

    if (evidence.classification === 'RESTRICTED') {
      const permCheck = await client.query(
        `SELECT 1 FROM role_permissions rp
         JOIN permissions p ON p.id = rp.permission_id
         JOIN role_assignments ra ON ra.role_code = rp.role_code
         WHERE ra.user_id = $1 AND p.code = 'EVIDENCE:READ_RESTRICTED' AND ra.is_active = TRUE`,
        [userId]
      );

      if (permCheck.rows.length === 0) {
        await client.query(
          `INSERT INTO evidence_access_log
             (tenant_id, evidence_id, accessed_by, access_type, access_granted, denial_reason)
           VALUES ($1, $2, $3, 'VIEW', FALSE, 'INSUFFICIENT_PERMISSION')`,
          [tenantId, evidenceId, userId]
        );
        throw new Error('EVIDENCE_READ_RESTRICTED_REQUIRED');
      }
    }

    await client.query(
      `INSERT INTO evidence_access_log
         (tenant_id, evidence_id, accessed_by, access_type, access_granted)
       VALUES ($1, $2, $3, 'VIEW', TRUE)`,
      [tenantId, evidenceId, userId]
    );

    return evidence;
  }, tenantId, userId, userRole);
}
