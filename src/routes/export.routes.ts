import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  generateExport,
  getExportJobStatus,
  getExportDocument,
  verifyExportDocument,
} from '../services/export.service';
import { withTransaction } from '../config/database';

export default async function exportRoutes(app: FastifyInstance) {
  app.post('/exports/generate', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof generateExport>[3];
    const result = await generateExport(user.tenantId, user.userId, user.role, body);
    return reply.code(202).send(result);
  });

  app.get('/exports/:id', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return getExportJobStatus(user.tenantId, user.userId, user.role, id);
  });

  app.get('/exports/:id/document', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return getExportDocument(user.tenantId, user.userId, user.role, id);
  });

  app.post('/exports/:id/verify', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as { documentHash: string; signature: string };
    return verifyExportDocument(user.tenantId, user.userId, user.role, id, body);
  });

  app.post('/exports/single', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      studentId: string;
      format: string;
      sections?: string[];
      academicYearId?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO export_jobs (student_id, export_type, format, sections,
                                   academic_year_id, status, requested_by)
         VALUES ($1, 'SINGLE', $2, $3, $4, 'QUEUED', $5)
         RETURNING job_id, student_id, export_type, status, created_at`,
        [body.studentId, body.format, body.sections ? JSON.stringify(body.sections) : null,
         body.academicYearId || null, user.userId]
      );
      return reply.code(202).send({ job: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/exports/bulk', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      studentIds: string[];
      format: string;
      sections?: string[];
      academicYearId?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO export_jobs (student_ids, export_type, format, sections,
                                   academic_year_id, status, requested_by)
         VALUES ($1, 'BULK', $2, $3, $4, 'QUEUED', $5)
         RETURNING job_id, export_type, status, created_at`,
        [JSON.stringify(body.studentIds), body.format,
         body.sections ? JSON.stringify(body.sections) : null,
         body.academicYearId || null, user.userId]
      );
      return reply.code(202).send({ job: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/exports/:id/status', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT job_id, export_type, status, progress_percent, error_message,
                created_at, completed_at
         FROM export_jobs WHERE job_id = $1`,
        [id]
      );
      if (result.rows.length === 0) throw new Error('JOB_NOT_FOUND');
      return { job: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/exports/:id/documents/:docId/download', { preHandler: [authenticate] }, async (request) => {
    const { id, docId } = request.params as { id: string; docId: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT ed.document_id, ed.filename, ed.content_ref, ed.mime_type, ed.file_size_bytes,
                sp.base_url
         FROM export_documents ed
         LEFT JOIN storage_providers sp ON sp.provider_id = ed.storage_provider_id
         WHERE ed.job_id = $1 AND ed.document_id = $2`,
        [id, docId]
      );
      if (result.rows.length === 0) throw new Error('DOCUMENT_NOT_FOUND');
      const row = result.rows[0] as Record<string, unknown>;
      return {
        documentId: docId,
        filename: row.filename,
        downloadUrl: `${row.base_url || ''}/${row.content_ref}?token=${Date.now()}`,
        mimeType: row.mime_type,
        fileSizeBytes: row.file_size_bytes,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/exports/verify', async (request) => {
    const body = request.body as { documentHash: string; signature: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT ed.document_id, ed.job_id, ed.document_hash, ed.signature, ed.verified
         FROM export_documents ed
         WHERE ed.document_hash = $1`,
        [body.documentHash]
      );
      if (result.rows.length === 0) {
        return { valid: false, message: 'Document not found' };
      }
      const row = result.rows[0] as Record<string, unknown>;
      const valid = row.signature === body.signature;
      return { valid, documentId: row.document_id, jobId: row.job_id };
    });
  });

  app.post('/export-authorizations', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      studentId: string;
      purpose: string;
      requestedBy: string;
      expiresAt?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO export_authorizations (student_id, purpose, requested_by,
                                             expires_at, status, created_by)
         VALUES ($1, $2, $3, $4, 'PENDING', $5)
         RETURNING authorization_id, student_id, purpose, status, created_at`,
        [body.studentId, body.purpose, body.requestedBy, body.expiresAt || null, user.userId]
      );
      return reply.code(201).send({ authorization: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/export-authorizations/:id/approve', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { decision, notes } = request.body as { decision: 'APPROVED' | 'REJECTED'; notes?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE export_authorizations SET status = $1, reviewed_by = $2, reviewed_at = NOW(),
                review_notes = $3, updated_at = NOW()
         WHERE authorization_id = $4
         RETURNING authorization_id, status, reviewed_by, reviewed_at`,
        [decision, user.userId, notes || null, id]
      );
      if (result.rows.length === 0) throw new Error('AUTHORIZATION_NOT_FOUND');
      return { authorization: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });
}
