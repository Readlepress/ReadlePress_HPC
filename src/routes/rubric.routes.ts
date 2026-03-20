import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { submitRubricCompletion, getAssessmentContext } from '../services/rubric.service';
import { withTransaction } from '../config/database';

export default async function rubricRoutes(app: FastifyInstance) {
  app.get('/students/:id/assessment-context', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return getAssessmentContext(user.tenantId, user.userId, user.role, id);
  });

  app.post('/rubric-completions', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof submitRubricCompletion>[3];
    const result = await submitRubricCompletion(user.tenantId, user.userId, user.role, body);
    return reply.code(201).send(result);
  });

  app.get('/rubric-templates/active', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { stageCode, competencyUid } = request.query as { stageCode?: string; competencyUid?: string };
    return withTransaction(async (client) => {
      const conditions = ['rt.status = $1'];
      const params: unknown[] = ['ACTIVE'];
      if (stageCode) { conditions.push(`rt.stage_code = $${params.length + 1}`); params.push(stageCode); }
      if (competencyUid) { conditions.push(`rt.competency_uid = $${params.length + 1}`); params.push(competencyUid); }
      const where = conditions.join(' AND ');
      const result = await client.query(
        `SELECT rt.template_id, rt.name, rt.stage_code, rt.competency_uid,
                rt.version, rt.rubric_schema, rt.created_at
         FROM rubric_templates rt
         WHERE ${where}
         ORDER BY rt.name`,
        params
      );
      return { templates: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/rubric-completions/:id/verify', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { verified, notes } = request.body as { verified: boolean; notes?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE rubric_completions SET verification_status = $1, verified_by = $2,
                verified_at = NOW(), verification_notes = $3, updated_at = NOW()
         WHERE completion_id = $4
         RETURNING completion_id, verification_status, verified_by, verified_at`,
        [verified ? 'VERIFIED' : 'REJECTED', user.userId, notes || null, id]
      );
      if (result.rows.length === 0) throw new Error('COMPLETION_NOT_FOUND');
      return { completion: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/inter-rater-queue', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { status, limit, offset } = request.query as { status?: string; limit?: string; offset?: string };
    return withTransaction(async (client) => {
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      const conditions: string[] = [];
      const params: unknown[] = [lim, off];
      if (status) { conditions.push(`irq.status = $${params.length + 1}`); params.push(status); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const result = await client.query(
        `SELECT irq.queue_id, irq.completion_id_a, irq.completion_id_b,
                irq.divergence_score, irq.status, irq.created_at
         FROM inter_rater_queue irq
         ${where}
         ORDER BY irq.divergence_score DESC
         LIMIT $1 OFFSET $2`,
        params
      );
      return { queue: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/inter-rater-queue/:id/resolve', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { resolution, notes, winnerCompletionId } = request.body as {
      resolution: string;
      notes?: string;
      winnerCompletionId?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE inter_rater_queue SET status = 'RESOLVED', resolution = $1,
                resolution_notes = $2, winner_completion_id = $3,
                resolved_by = $4, resolved_at = NOW()
         WHERE queue_id = $5
         RETURNING queue_id, resolution, status, resolved_at`,
        [resolution, notes || null, winnerCompletionId || null, user.userId, id]
      );
      if (result.rows.length === 0) throw new Error('QUEUE_ITEM_NOT_FOUND');
      return { item: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/rubric-completions/:id/amend', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      reason: string;
      amendedScores?: Record<string, unknown>;
      amendedNotes?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO rubric_completion_amendments (completion_id, reason, amended_scores,
                                                    amended_notes, status, submitted_by)
         VALUES ($1, $2, $3, $4, 'PENDING', $5)
         RETURNING amendment_id, completion_id, reason, status, created_at`,
        [id, body.reason, body.amendedScores ? JSON.stringify(body.amendedScores) : null,
         body.amendedNotes || null, user.userId]
      );
      return reply.code(201).send({ amendment: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });
}
