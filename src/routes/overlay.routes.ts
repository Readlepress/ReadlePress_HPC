import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { createOverlay, approveOverlay, getActiveOverlays } from '../services/overlay.service';
import { withTransaction } from '../config/database';

export default async function overlayRoutes(app: FastifyInstance) {
  app.post('/students/:id/overlays', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as Parameters<typeof createOverlay>[4];
    const result = await createOverlay(user.tenantId, user.userId, user.role, id, body);
    return reply.code(201).send(result);
  });

  app.post('/overlays/:id/approve', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { action, rejectionReason } = request.body as {
      action: 'APPROVED' | 'REJECTED';
      rejectionReason?: string;
    };
    return approveOverlay(user.tenantId, user.userId, user.role, id, action, rejectionReason);
  });

  app.get('/students/:id/overlays/active', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return { overlays: await getActiveOverlays(user.tenantId, user.userId, user.role, id) };
  });

  app.post('/students/:id/disability-profiles', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      disabilityType: string;
      severity: string;
      diagnosis?: string;
      certifyingAuthority?: string;
      certificateRef?: string;
      accommodations?: Record<string, unknown>;
      validFrom: string;
      validUntil?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO disability_profiles (student_id, disability_type, severity, diagnosis,
                                          certifying_authority, certificate_ref, accommodations,
                                          valid_from, valid_until, status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, 'ACTIVE', $10)
         RETURNING profile_id, student_id, disability_type, severity, status, created_at`,
        [id, body.disabilityType, body.severity, body.diagnosis || null,
         body.certifyingAuthority || null, body.certificateRef || null,
         body.accommodations ? JSON.stringify(body.accommodations) : null,
         body.validFrom, body.validUntil || null, user.userId]
      );
      return reply.code(201).send({ profile: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/overlays/:id/renew', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { newValidUntil, reason } = request.body as { newValidUntil: string; reason?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE overlays SET valid_until = $1, renewal_reason = $2, renewed_by = $3,
                renewed_at = NOW(), status = 'ACTIVE', updated_at = NOW()
         WHERE overlay_id = $4
         RETURNING overlay_id, status, valid_until, renewed_at`,
        [newValidUntil, reason || null, user.userId, id]
      );
      if (result.rows.length === 0) throw new Error('OVERLAY_NOT_FOUND');
      return { overlay: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/students/:id/assessment-context', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { includeOverlays, includeDisability } = request.query as {
      includeOverlays?: string;
      includeDisability?: string;
    };
    return withTransaction(async (client) => {
      const student = await client.query(
        `SELECT s.student_id, s.full_name, se.class_id, c.grade_level, c.stage_code
         FROM students s
         LEFT JOIN student_enrolments se ON se.student_id = s.student_id AND se.is_current = true
         LEFT JOIN classes c ON c.class_id = se.class_id
         WHERE s.student_id = $1`,
        [id]
      );
      const result: Record<string, unknown> = { student: student.rows[0] || null };

      if (includeOverlays === 'true') {
        const overlays = await client.query(
          `SELECT * FROM overlays WHERE student_id = $1 AND status = 'ACTIVE'`, [id]
        );
        result.activeOverlays = overlays.rows;
      }
      if (includeDisability === 'true') {
        const profiles = await client.query(
          `SELECT * FROM disability_profiles WHERE student_id = $1 AND status = 'ACTIVE'`, [id]
        );
        result.disabilityProfiles = profiles.rows;
      }
      return result;
    }, user.tenantId, user.userId, user.role);
  });
}
