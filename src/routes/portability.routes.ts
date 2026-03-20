import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  generatePortabilityPackage,
  importPortabilityPackage,
  getCrl,
  verifyPackageSignature,
} from '../services/portability.service';
import { withTransaction } from '../config/database';

export default async function portabilityRoutes(app: FastifyInstance) {
  app.post('/portability/generate', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const { studentId } = request.body as { studentId: string };
    const result = await generatePortabilityPackage(
      user.tenantId, user.userId, user.role, studentId
    );
    return reply.code(202).send(result);
  });

  app.post('/portability/import', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as { packageData: string; sourceSchoolId?: string };
    const result = await importPortabilityPackage(user.tenantId, user.userId, user.role, body);
    return reply.code(202).send(result);
  });

  app.get('/portability/crl', async () => {
    const entries = await getCrl();
    return { entries };
  });

  app.post('/portability/verify', async (request) => {
    const body = request.body as { packageHash: string; signature: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT pp.package_id, pp.student_id, pp.signature, pp.package_hash, pp.status
         FROM portability_packages pp
         WHERE pp.package_hash = $1`,
        [body.packageHash]
      );
      if (result.rows.length === 0) return { valid: false, message: 'Package not found' };
      const row = result.rows[0] as Record<string, unknown>;
      const valid = row.signature === body.signature && row.status !== 'REVOKED';
      return { valid, packageId: row.package_id, status: row.status };
    });
  });

  app.post('/portability/packages', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      studentId: string;
      format?: string;
      sections?: string[];
      includeEvidence?: boolean;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO portability_packages (student_id, format, sections, include_evidence,
                                            status, requested_by)
         VALUES ($1, $2, $3, $4, 'QUEUED', $5)
         RETURNING package_id, student_id, format, status, created_at`,
        [body.studentId, body.format || 'HPC_JSON', body.sections ? JSON.stringify(body.sections) : null,
         body.includeEvidence ?? true, user.userId]
      );
      return reply.code(202).send({ package: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/portability/packages/:id/status', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT package_id, student_id, format, status, progress_percent,
                error_message, created_at, completed_at
         FROM portability_packages WHERE package_id = $1`,
        [id]
      );
      if (result.rows.length === 0) throw new Error('PACKAGE_NOT_FOUND');
      return { package: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/portability/packages/:id/download', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT pp.package_id, pp.content_ref, pp.file_size_bytes, pp.mime_type,
                sp.base_url
         FROM portability_packages pp
         LEFT JOIN storage_providers sp ON sp.provider_id = pp.storage_provider_id
         WHERE pp.package_id = $1 AND pp.status = 'COMPLETED'`,
        [id]
      );
      if (result.rows.length === 0) throw new Error('PACKAGE_NOT_FOUND_OR_NOT_READY');
      const row = result.rows[0] as Record<string, unknown>;
      return {
        packageId: id,
        downloadUrl: `${row.base_url || ''}/${row.content_ref}?token=${Date.now()}`,
        mimeType: row.mime_type,
        fileSizeBytes: row.file_size_bytes,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/portability/import/:id/bridge-report', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const job = await client.query(
        `SELECT import_id, status, source_school_id, student_id, created_at
         FROM portability_imports WHERE import_id = $1`,
        [id]
      );
      if (job.rows.length === 0) throw new Error('IMPORT_NOT_FOUND');
      const report = await client.query(
        `SELECT report_id, competency_mappings, unmapped_competencies,
                confidence_scores, recommendations, created_at
         FROM portability_bridge_reports WHERE import_id = $1`,
        [id]
      );
      return { import: job.rows[0], bridgeReport: report.rows[0] || null };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/portability/import/:id/accept', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { acceptedMappings, notes } = request.body as {
      acceptedMappings?: Record<string, unknown>;
      notes?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE portability_imports SET status = 'ACCEPTED', accepted_by = $1,
                accepted_at = NOW(), accepted_mappings = $2, acceptance_notes = $3,
                updated_at = NOW()
         WHERE import_id = $4
         RETURNING import_id, status, accepted_by, accepted_at`,
        [user.userId, acceptedMappings ? JSON.stringify(acceptedMappings) : null,
         notes || null, id]
      );
      if (result.rows.length === 0) throw new Error('IMPORT_NOT_FOUND');
      return { import: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/portability/packages/:id/revoke', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { reason } = request.body as { reason: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE portability_packages SET status = 'REVOKED', revoked_by = $1,
                revoked_at = NOW(), revocation_reason = $2, updated_at = NOW()
         WHERE package_id = $3
         RETURNING package_id, status, revoked_at`,
        [user.userId, reason, id]
      );
      if (result.rows.length === 0) throw new Error('PACKAGE_NOT_FOUND');
      return { package: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });
}
