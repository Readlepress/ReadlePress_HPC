import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { withTransaction } from '../config/database';

export default async function evidenceExtendedRoutes(app: FastifyInstance) {
  app.get('/evidence/:id/content', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT e.evidence_id, e.storage_provider_id, e.content_ref, e.content_type,
                e.mime_type, sp.base_url
         FROM evidence e
         LEFT JOIN storage_providers sp ON sp.provider_id = e.storage_provider_id
         WHERE e.evidence_id = $1`,
        [id]
      );
      if (result.rows.length === 0) throw new Error('EVIDENCE_NOT_FOUND');
      const row = result.rows[0] as Record<string, unknown>;
      const signedUrl = `${row.base_url || ''}/${row.content_ref}?token=${Date.now()}`;
      return { evidenceId: id, signedUrl, contentType: row.content_type, mimeType: row.mime_type };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/students/:id/evidence', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { contentType, limit, offset } = request.query as {
      contentType?: string;
      limit?: string;
      offset?: string;
    };
    return withTransaction(async (client) => {
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      const conditions = ['el.student_id = $1'];
      const params: unknown[] = [id, lim, off];
      if (contentType) {
        conditions.push(`e.content_type = $${params.length + 1}`);
        params.push(contentType);
      }
      const where = conditions.join(' AND ');
      const result = await client.query(
        `SELECT e.evidence_id, e.content_type, e.mime_type, e.trust_level,
                e.classification, e.original_filename, e.file_size_bytes,
                e.created_at, e.verification_status
         FROM evidence e
         JOIN evidence_links el ON el.evidence_id = e.evidence_id
         WHERE ${where}
         ORDER BY e.created_at DESC
         LIMIT $2 OFFSET $3`,
        params
      );
      return { evidence: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.patch('/evidence/:id/verify', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { status, notes } = request.body as { status: string; notes?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE evidence SET verification_status = $1, verified_by = $2, verified_at = NOW(),
                verification_notes = $3, updated_at = NOW()
         WHERE evidence_id = $4
         RETURNING evidence_id, verification_status, verified_by, verified_at`,
        [status, user.userId, notes || null, id]
      );
      if (result.rows.length === 0) throw new Error('EVIDENCE_NOT_FOUND');
      return { evidence: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/evidence/:id/redact', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { reason, redactionType } = request.body as { reason: string; redactionType: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO evidence_redaction_requests (evidence_id, reason, redaction_type, status, requested_by)
         VALUES ($1, $2, $3, 'PENDING', $4)
         RETURNING request_id, evidence_id, status, created_at`,
        [id, reason, redactionType, user.userId]
      );
      return reply.code(201).send({ redactionRequest: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/evidence/:id/redact/apply', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { requestId } = request.body as { requestId: string };
    return withTransaction(async (client) => {
      await client.query(
        `UPDATE evidence_redaction_requests SET status = 'APPLIED', applied_by = $1, applied_at = NOW()
         WHERE request_id = $2 AND evidence_id = $3`,
        [user.userId, requestId, id]
      );
      await client.query(
        `UPDATE evidence SET classification = 'REDACTED', content_ref = NULL, updated_at = NOW()
         WHERE evidence_id = $1`,
        [id]
      );
      return { evidenceId: id, status: 'REDACTED' };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/evidence/:id/custody-chain', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT event_id, evidence_id, event_type, actor_id, event_data, created_at
         FROM evidence_custody_events
         WHERE evidence_id = $1
         ORDER BY created_at ASC`,
        [id]
      );
      return { evidenceId: id, custodyChain: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/evidence/group-capture', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      studentIds: string[];
      evidenceData: {
        storageProviderId: string;
        contentRef: string;
        contentType: string;
        mimeType: string;
        fileSizeBytes: number;
        originalFilename: string;
        contentHash: string;
        trustLevel: string;
      };
    };
    return withTransaction(async (client) => {
      const evidence = await client.query(
        `INSERT INTO evidence (storage_provider_id, content_ref, content_type, mime_type,
                               file_size_bytes, original_filename, content_hash, trust_level, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING evidence_id`,
        [body.evidenceData.storageProviderId, body.evidenceData.contentRef,
         body.evidenceData.contentType, body.evidenceData.mimeType,
         body.evidenceData.fileSizeBytes, body.evidenceData.originalFilename,
         body.evidenceData.contentHash, body.evidenceData.trustLevel, user.userId]
      );
      const evidenceId = evidence.rows[0].evidence_id;
      for (const studentId of body.studentIds) {
        await client.query(
          `INSERT INTO evidence_links (evidence_id, student_id) VALUES ($1, $2)`,
          [evidenceId, studentId]
        );
      }
      return reply.code(201).send({
        evidenceId,
        linkedStudents: body.studentIds.length,
      });
    }, user.tenantId, user.userId, user.role);
  });
}
