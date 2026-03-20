import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  createOverrideRequest,
  approveOverrideRequest,
  listGovernanceAlerts,
  requestComplianceReconstruction,
} from '../services/governance.service';
import { withTransaction } from '../config/database';

export default async function governanceRoutes(app: FastifyInstance) {
  app.post('/override-requests', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof createOverrideRequest>[3];
    const result = await createOverrideRequest(user.tenantId, user.userId, user.role, body);
    return reply.code(201).send(result);
  });

  app.post('/override-requests/:id/approve', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as { decision: 'APPROVED' | 'REJECTED'; notes?: string };
    return approveOverrideRequest(user.tenantId, user.userId, user.role, id, body);
  });

  app.get('/governance-alerts', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const alerts = await listGovernanceAlerts(user.tenantId, user.userId, user.role);
    return { alerts };
  });

  app.post('/compliance-reconstruction', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as { entityType: string; entityId: string; reason: string };
    const result = await requestComplianceReconstruction(
      user.tenantId, user.userId, user.role, body
    );
    return reply.code(202).send(result);
  });

  app.post('/governance/override-requests', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      entityType: string;
      entityId: string;
      overrideType: string;
      justification: string;
      proposedValue?: Record<string, unknown>;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO governance_override_requests (entity_type, entity_id, override_type,
                                                    justification, proposed_value, status, requested_by)
         VALUES ($1, $2, $3, $4, $5, 'PENDING', $6)
         RETURNING request_id, entity_type, override_type, status, created_at`,
        [body.entityType, body.entityId, body.overrideType, body.justification,
         body.proposedValue ? JSON.stringify(body.proposedValue) : null, user.userId]
      );
      return reply.code(201).send({ request: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/governance/override-requests/:id/approve', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { decision, notes } = request.body as { decision: 'APPROVED' | 'REJECTED'; notes?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE governance_override_requests SET status = $1, reviewed_by = $2,
                reviewed_at = NOW(), review_notes = $3, updated_at = NOW()
         WHERE request_id = $4
         RETURNING request_id, status, reviewed_by, reviewed_at`,
        [decision, user.userId, notes || null, id]
      );
      if (result.rows.length === 0) throw new Error('REQUEST_NOT_FOUND');
      return { request: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/governance/override-requests/:id/apply', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const req = await client.query(
        `SELECT * FROM governance_override_requests WHERE request_id = $1 AND status = 'APPROVED'`, [id]
      );
      if (req.rows.length === 0) throw new Error('REQUEST_NOT_FOUND_OR_NOT_APPROVED');
      await client.query(
        `UPDATE governance_override_requests SET status = 'APPLIED', applied_by = $1,
                applied_at = NOW(), updated_at = NOW()
         WHERE request_id = $2`,
        [user.userId, id]
      );
      return { requestId: id, status: 'APPLIED' };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/governance/dashboard', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    return withTransaction(async (client) => {
      const overrides = await client.query(
        `SELECT status, COUNT(*) AS count FROM governance_override_requests GROUP BY status`
      );
      const alerts = await client.query(
        `SELECT severity, COUNT(*) AS count FROM governance_alerts GROUP BY severity`
      );
      const reconstructions = await client.query(
        `SELECT status, COUNT(*) AS count FROM reconstruction_requests GROUP BY status`
      );
      return {
        overridesByStatus: overrides.rows,
        alertsBySeverity: alerts.rows,
        reconstructionsByStatus: reconstructions.rows,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/governance/reconstruction-requests', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      entityType: string;
      entityId: string;
      reason: string;
      scope?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO reconstruction_requests (entity_type, entity_id, reason, scope,
                                               status, requested_by)
         VALUES ($1, $2, $3, $4, 'QUEUED', $5)
         RETURNING request_id, entity_type, entity_id, status, created_at`,
        [body.entityType, body.entityId, body.reason, body.scope || 'FULL', user.userId]
      );
      return reply.code(202).send({ request: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/governance/reconstruction-requests/:id/report', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const req = await client.query(
        `SELECT * FROM reconstruction_requests WHERE request_id = $1`, [id]
      );
      if (req.rows.length === 0) throw new Error('REQUEST_NOT_FOUND');
      const report = await client.query(
        `SELECT * FROM reconstruction_reports WHERE request_id = $1`, [id]
      );
      return { request: req.rows[0], report: report.rows[0] || null };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/governance/reconstruction-requests/:id/status', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT request_id, entity_type, entity_id, reason, scope, status,
                progress_percent, requested_by, created_at, completed_at
         FROM reconstruction_requests WHERE request_id = $1`,
        [id]
      );
      if (result.rows.length === 0) throw new Error('REQUEST_NOT_FOUND');
      return { request: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/governance/audit-chain-status', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    return withTransaction(async (client) => {
      const total = await client.query(
        `SELECT COUNT(*) AS total_entries FROM audit_log`
      );
      const lastEntry = await client.query(
        `SELECT log_id, hash, created_at FROM audit_log ORDER BY log_id DESC LIMIT 1`
      );
      const brokenLinks = await client.query(
        `SELECT COUNT(*) AS broken_count FROM audit_log a
         JOIN audit_log b ON b.log_id = a.log_id - 1
         WHERE a.previous_hash != b.hash`
      );
      return {
        totalEntries: parseInt(total.rows[0]?.total_entries || '0', 10),
        lastEntry: lastEntry.rows[0] || null,
        brokenLinks: parseInt(brokenLinks.rows[0]?.broken_count || '0', 10),
        chainIntegrity: parseInt(brokenLinks.rows[0]?.broken_count || '0', 10) === 0 ? 'INTACT' : 'BROKEN',
      };
    }, user.tenantId, user.userId, user.role);
  });
}
