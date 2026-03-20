import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { withTransaction } from '../config/database';

export default async function businessRoutes(app: FastifyInstance) {
  app.get('/sla/definitions', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT definition_id, metric_name, description, threshold, unit,
                measurement_interval, status, created_at
         FROM sla_definitions
         ORDER BY metric_name`
      );
      return { definitions: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/sla/monitoring', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { tenantId } = request.query as { tenantId?: string };
    return withTransaction(async (client) => {
      const params: unknown[] = [];
      let where = '';
      if (tenantId) { where = 'WHERE sm.tenant_id = $1'; params.push(tenantId); }
      const result = await client.query(
        `SELECT sm.metric_id, sm.metric_name, sm.current_value, sm.threshold,
                sm.status, sm.measured_at, sm.tenant_id
         FROM sla_metrics sm
         ${where}
         ORDER BY sm.measured_at DESC`,
        params
      );
      return { metrics: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/onboarding/programmes', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      name: string;
      tenantId: string;
      description?: string;
      steps?: Record<string, unknown>[];
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO onboarding_programmes (name, tenant_id, description, steps, status, created_by)
         VALUES ($1, $2, $3, $4, 'ACTIVE', $5)
         RETURNING programme_id, name, tenant_id, status, created_at`,
        [body.name, body.tenantId, body.description || null,
         body.steps ? JSON.stringify(body.steps) : null, user.userId]
      );
      return reply.code(201).send({ programme: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/onboarding/:tenantId/status', { preHandler: [authenticate] }, async (request) => {
    const { tenantId } = request.params as { tenantId: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const programme = await client.query(
        `SELECT programme_id, name, status, steps, created_at
         FROM onboarding_programmes WHERE tenant_id = $1
         ORDER BY created_at DESC LIMIT 1`,
        [tenantId]
      );
      const progress = await client.query(
        `SELECT step_id, step_name, status, completed_at
         FROM onboarding_progress WHERE tenant_id = $1
         ORDER BY step_order`,
        [tenantId]
      );
      return {
        programme: programme.rows[0] || null,
        progress: progress.rows,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/training/modules', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      title: string;
      description?: string;
      contentUrl?: string;
      targetRoles?: string[];
      durationMinutes?: number;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO training_modules (title, description, content_url, target_roles,
                                        duration_minutes, status, created_by)
         VALUES ($1, $2, $3, $4, $5, 'ACTIVE', $6)
         RETURNING module_id, title, status, created_at`,
        [body.title, body.description || null, body.contentUrl || null,
         body.targetRoles ? JSON.stringify(body.targetRoles) : null,
         body.durationMinutes || null, user.userId]
      );
      return reply.code(201).send({ module: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/support-tickets', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      subject: string;
      description: string;
      priority: string;
      category?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO support_tickets (subject, description, priority, category,
                                       status, submitted_by)
         VALUES ($1, $2, $3, $4, 'OPEN', $5)
         RETURNING ticket_id, subject, priority, status, created_at`,
        [body.subject, body.description, body.priority, body.category || null, user.userId]
      );
      return reply.code(201).send({ ticket: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/support-tickets', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { status, priority, limit, offset } = request.query as {
      status?: string;
      priority?: string;
      limit?: string;
      offset?: string;
    };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (status) { conditions.push(`st.status = $${params.length + 1}`); params.push(status); }
      if (priority) { conditions.push(`st.priority = $${params.length + 1}`); params.push(priority); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      params.push(lim, off);

      const result = await client.query(
        `SELECT st.ticket_id, st.subject, st.priority, st.category, st.status,
                st.submitted_by, st.assigned_to, st.created_at, st.updated_at
         FROM support_tickets st
         ${where}
         ORDER BY st.created_at DESC
         LIMIT $${params.length - 1} OFFSET $${params.length}`,
        params
      );
      return { tickets: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/exit-procedures', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      tenantId: string;
      reason: string;
      requestedDate: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO exit_procedures (tenant_id, reason, requested_date, status, initiated_by)
         VALUES ($1, $2, $3, 'INITIATED', $4)
         RETURNING procedure_id, tenant_id, status, created_at`,
        [body.tenantId, body.reason, body.requestedDate, user.userId]
      );
      return reply.code(201).send({ procedure: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/onboarding/status', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    return withTransaction(async (client) => {
      const programme = await client.query(
        `SELECT programme_id, name, status, steps, created_at
         FROM onboarding_programmes
         WHERE tenant_id = (SELECT tenant_id FROM users WHERE user_id = $1 LIMIT 1)
         ORDER BY created_at DESC LIMIT 1`,
        [user.userId]
      );
      const progress = await client.query(
        `SELECT step_id, step_name, status, completed_at
         FROM onboarding_progress
         WHERE tenant_id = (SELECT tenant_id FROM users WHERE user_id = $1 LIMIT 1)
         ORDER BY step_order`,
        [user.userId]
      );
      return { programme: programme.rows[0] || null, progress: progress.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/onboarding/advance', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { stepId, notes } = request.body as { stepId: string; notes?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE onboarding_progress SET status = 'COMPLETED', completed_at = NOW(),
                completion_notes = $1, updated_at = NOW()
         WHERE step_id = $2
         RETURNING step_id, step_name, status, completed_at`,
        [notes || null, stepId]
      );
      if (result.rows.length === 0) throw new Error('STEP_NOT_FOUND');
      return { step: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/training/modules', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { role, status } = request.query as { role?: string; status?: string };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (status) { conditions.push(`tm.status = $${params.length + 1}`); params.push(status); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const result = await client.query(
        `SELECT tm.module_id, tm.title, tm.description, tm.content_url,
                tm.target_roles, tm.duration_minutes, tm.status, tm.created_at
         FROM training_modules tm
         ${where}
         ORDER BY tm.title`,
        params
      );
      let modules = result.rows;
      if (role) {
        modules = modules.filter((m: Record<string, unknown>) => {
          const roles = m.target_roles as string[] | null;
          return !roles || roles.length === 0 || (Array.isArray(roles) && roles.includes(role));
        });
      }
      return { modules };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/training/modules/:id/complete', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { score, feedback } = request.body as { score?: number; feedback?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO training_completions (module_id, user_id, score, feedback, completed_at)
         VALUES ($1, $2, $3, $4, NOW())
         ON CONFLICT (module_id, user_id) DO UPDATE SET score = $3, feedback = $4, completed_at = NOW()
         RETURNING completion_id, module_id, user_id, score, completed_at`,
        [id, user.userId, score || null, feedback || null]
      );
      return { completion: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.patch('/support-tickets/:id', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      status?: string;
      priority?: string;
      assignedTo?: string;
      resolution?: string;
    };
    return withTransaction(async (client) => {
      const sets: string[] = ['updated_at = NOW()'];
      const params: unknown[] = [];
      if (body.status) { sets.push(`status = $${params.length + 1}`); params.push(body.status); }
      if (body.priority) { sets.push(`priority = $${params.length + 1}`); params.push(body.priority); }
      if (body.assignedTo) { sets.push(`assigned_to = $${params.length + 1}`); params.push(body.assignedTo); }
      if (body.resolution) { sets.push(`resolution = $${params.length + 1}`); params.push(body.resolution); }
      params.push(id);

      const result = await client.query(
        `UPDATE support_tickets SET ${sets.join(', ')}
         WHERE ticket_id = $${params.length}
         RETURNING ticket_id, subject, status, priority, assigned_to, updated_at`,
        params
      );
      if (result.rows.length === 0) throw new Error('TICKET_NOT_FOUND');
      return { ticket: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/exit-procedures/initiate', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      tenantId: string;
      reason: string;
      requestedDate: string;
      contactEmail?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO exit_procedures (tenant_id, reason, requested_date, contact_email,
                                       status, initiated_by)
         VALUES ($1, $2, $3, $4, 'INITIATED', $5)
         RETURNING procedure_id, tenant_id, status, created_at`,
        [body.tenantId, body.reason, body.requestedDate, body.contactEmail || null, user.userId]
      );
      return reply.code(201).send({ procedure: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/exit-procedures/:id/status', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT procedure_id, tenant_id, reason, requested_date, status,
                progress_percent, current_step, initiated_by, created_at, completed_at
         FROM exit_procedures WHERE procedure_id = $1`,
        [id]
      );
      if (result.rows.length === 0) throw new Error('PROCEDURE_NOT_FOUND');
      return { procedure: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/audit-access-grants', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      auditorId: string;
      scope: string;
      tenantId: string;
      validFrom: string;
      validUntil: string;
      accessLevel: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO audit_access_grants (auditor_id, scope, tenant_id, valid_from,
                                           valid_until, access_level, status, granted_by)
         VALUES ($1, $2, $3, $4, $5, $6, 'ACTIVE', $7)
         RETURNING grant_id, auditor_id, scope, status, created_at`,
        [body.auditorId, body.scope, body.tenantId, body.validFrom,
         body.validUntil, body.accessLevel, user.userId]
      );
      return reply.code(201).send({ grant: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });
}
