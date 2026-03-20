import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  generateAiDraft,
  promoteAiDraft,
  listPendingAiDrafts,
} from '../services/ai.service';
import { withTransaction } from '../config/database';

export default async function aiRoutes(app: FastifyInstance) {
  app.post('/ai/generate', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof generateAiDraft>[3];
    const result = await generateAiDraft(user.tenantId, user.userId, user.role, body);
    return reply.code(202).send(result);
  });

  app.post('/ai/drafts/:id/promote', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return promoteAiDraft(user.tenantId, user.userId, user.role, id);
  });

  app.get('/ai/drafts', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const drafts = await listPendingAiDrafts(user.tenantId, user.userId, user.role);
    return { drafts };
  });

  app.post('/ai/drafts/:id/discard', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE ai_drafts SET status = 'DISCARDED', discarded_by = $1, discarded_at = NOW(),
                updated_at = NOW()
         WHERE draft_id = $2 AND status = 'PENDING'
         RETURNING draft_id, status, discarded_at`,
        [user.userId, id]
      );
      if (result.rows.length === 0) throw new Error('DRAFT_NOT_FOUND_OR_NOT_PENDING');
      return { draft: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/ai/generation-log', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { startDate, endDate, status, limit, offset } = request.query as {
      startDate?: string;
      endDate?: string;
      status?: string;
      limit?: string;
      offset?: string;
    };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (startDate) { conditions.push(`gl.created_at >= $${params.length + 1}`); params.push(startDate); }
      if (endDate) { conditions.push(`gl.created_at <= $${params.length + 1}`); params.push(endDate); }
      if (status) { conditions.push(`gl.status = $${params.length + 1}`); params.push(status); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      params.push(lim, off);

      const result = await client.query(
        `SELECT gl.log_id, gl.draft_id, gl.model_name, gl.prompt_tokens, gl.completion_tokens,
                gl.status, gl.created_at, gl.user_id
         FROM ai_generation_log gl
         ${where}
         ORDER BY gl.created_at DESC
         LIMIT $${params.length - 1} OFFSET $${params.length}`,
        params
      );
      return { entries: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/ai/bias-monitoring/latest', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT report_id, report_date, metrics, findings, recommendations, created_at
         FROM ai_bias_reports
         ORDER BY report_date DESC
         LIMIT 1`
      );
      return { report: result.rows[0] || null };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/ai/bias-monitoring/run', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const { scope, parameters } = request.body as {
      scope?: string;
      parameters?: Record<string, unknown>;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO ai_bias_reports (report_date, scope, parameters, status, triggered_by)
         VALUES (CURRENT_DATE, $1, $2, 'RUNNING', $3)
         RETURNING report_id, report_date, scope, status, created_at`,
        [scope || 'FULL', parameters ? JSON.stringify(parameters) : null, user.userId]
      );
      return reply.code(202).send({ report: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/ai/providers', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT provider_id, name, provider_type, model_name, status,
                config, rate_limit, created_at
         FROM ai_providers
         ORDER BY name`
      );
      return { providers: result.rows };
    }, user.tenantId, user.userId, user.role);
  });
}
