import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function generateExport(
  tenantId: string,
  userId: string,
  userRole: string,
  data: {
    exportType: string;
    targetIds: string[];
    format?: string;
    templateId?: string;
  }
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO export_jobs
         (tenant_id, export_type, target_ids, format, template_id,
          requested_by, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'PENDING')
       RETURNING id`,
      [
        tenantId, data.exportType, data.targetIds,
        data.format || 'PDF', data.templateId || null, userId,
      ]
    );

    const jobId = result.rows[0].id;

    await insertAuditLog({
      tenantId,
      eventType: 'EXPORT.REQUESTED',
      entityType: 'EXPORT_JOBS',
      entityId: jobId,
      performedBy: userId,
      afterState: { exportType: data.exportType, targetCount: data.targetIds.length },
    }, client);

    return { jobId, status: 'PENDING' };
  }, tenantId, userId, userRole);
}

export async function getExportJobStatus(
  tenantId: string,
  userId: string,
  userRole: string,
  jobId: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT id, export_type, status, format, started_at, completed_at,
              error_message, created_at
       FROM export_jobs
       WHERE id = $1`,
      [jobId]
    );

    if (result.rows.length === 0) {
      throw new Error('EXPORT_JOB_NOT_FOUND');
    }

    return result.rows[0];
  }, tenantId, userId, userRole);
}

export async function getExportDocument(
  tenantId: string,
  userId: string,
  userRole: string,
  jobId: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT edr.id, edr.document_hash, edr.signature, edr.storage_path,
              edr.mime_type, edr.file_size, edr.created_at
       FROM export_document_records edr
       WHERE edr.export_job_id = $1`,
      [jobId]
    );

    if (result.rows.length === 0) {
      throw new Error('EXPORT_DOCUMENT_NOT_FOUND');
    }

    return result.rows[0];
  }, tenantId, userId, userRole);
}

export async function verifyExportDocument(
  tenantId: string,
  userId: string,
  userRole: string,
  jobId: string,
  data: { documentHash: string; signature: string }
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT document_hash, signature
       FROM export_document_records
       WHERE export_job_id = $1`,
      [jobId]
    );

    if (result.rows.length === 0) {
      throw new Error('EXPORT_DOCUMENT_NOT_FOUND');
    }

    const doc = result.rows[0];
    const hashValid = doc.document_hash === data.documentHash;
    const signatureValid = doc.signature === data.signature;

    return { hashValid, signatureValid, verified: hashValid && signatureValid };
  }, tenantId, userId, userRole);
}
