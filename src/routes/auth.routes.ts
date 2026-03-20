import { FastifyInstance } from 'fastify';
import { authenticateUser } from '../services/auth.service';
import { authenticate, getUser, requireRole } from '../middleware/auth';
import { withTransaction } from '../config/database';

export default async function authRoutes(app: FastifyInstance) {
  app.post('/auth/login', async (request, reply) => {
    const { email, phone, password } = request.body as {
      email?: string;
      phone?: string;
      password: string;
    };

    if (!email && !phone) {
      return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Email or phone required' });
    }

    try {
      const user = await authenticateUser(email, phone, password);
      const token = app.jwt.sign({
        userId: user.userId,
        tenantId: user.tenantId,
        role: user.role,
        email,
        phone,
      });

      return { token, user };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      if (message === 'INVALID_CREDENTIALS') {
        return reply.code(401).send({ error: 'INVALID_CREDENTIALS', message: 'Invalid email/phone or password' });
      }
      if (message === 'ACCOUNT_LOCKED') {
        return reply.code(423).send({ error: 'ACCOUNT_LOCKED', message: 'Account temporarily locked due to failed attempts' });
      }
      if (message === 'ACCOUNT_INACTIVE') {
        return reply.code(403).send({ error: 'ACCOUNT_INACTIVE', message: 'Account is not active' });
      }
      throw err;
    }
  });

  app.post('/auth/logout', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    return withTransaction(async (client) => {
      await client.query(
        `UPDATE user_sessions SET revoked_at = NOW() WHERE user_id = $1 AND revoked_at IS NULL`,
        [user.userId]
      );
      return { message: 'Session revoked' };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/me', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    return withTransaction(async (client) => {
      const profile = await client.query(
        `SELECT u.user_id, u.email, u.phone, u.full_name, u.status,
                u.created_at, u.updated_at
         FROM users u WHERE u.user_id = $1`,
        [user.userId]
      );
      const roles = await client.query(
        `SELECT ra.assignment_id, r.role_name, r.role_code, ra.scope_type, ra.scope_id, ra.assigned_at
         FROM role_assignments ra
         JOIN roles r ON r.role_id = ra.role_id
         WHERE ra.user_id = $1 AND ra.revoked_at IS NULL`,
        [user.userId]
      );
      const permissions = await client.query(
        `SELECT DISTINCT p.permission_code
         FROM role_assignments ra
         JOIN role_permissions rp ON rp.role_id = ra.role_id
         JOIN permissions p ON p.permission_id = rp.permission_id
         WHERE ra.user_id = $1 AND ra.revoked_at IS NULL`,
        [user.userId]
      );
      return {
        user: profile.rows[0] || null,
        roles: roles.rows,
        permissions: permissions.rows.map((r: { permission_code: string }) => r.permission_code),
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/admin/users/:userId/roles', { preHandler: [authenticate, requireRole('ADMIN', 'PLATFORM_ADMIN')] }, async (request, reply) => {
    const { userId } = request.params as { userId: string };
    const { roleId, scopeType, scopeId } = request.body as {
      roleId: string;
      scopeType?: string;
      scopeId?: string;
    };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO role_assignments (user_id, role_id, scope_type, scope_id, assigned_by)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING assignment_id, user_id, role_id, scope_type, scope_id, assigned_at`,
        [userId, roleId, scopeType || null, scopeId || null, user.userId]
      );
      return reply.code(201).send({ assignment: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.delete('/admin/users/:userId/roles/:assignmentId', { preHandler: [authenticate, requireRole('ADMIN', 'PLATFORM_ADMIN')] }, async (request) => {
    const { userId, assignmentId } = request.params as { userId: string; assignmentId: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      await client.query(
        `UPDATE role_assignments SET revoked_at = NOW(), revoked_by = $1
         WHERE assignment_id = $2 AND user_id = $3 AND revoked_at IS NULL`,
        [user.userId, assignmentId, userId]
      );
      return { message: 'Role assignment revoked' };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/platform/tenants', { preHandler: [authenticate, requireRole('PLATFORM_ADMIN')] }, async (request, reply) => {
    const user = getUser(request);
    const { name, slug, config } = request.body as {
      name: string;
      slug: string;
      config?: Record<string, unknown>;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO tenants (name, slug, config, created_by)
         VALUES ($1, $2, $3, $4)
         RETURNING tenant_id, name, slug, created_at`,
        [name, slug, config ? JSON.stringify(config) : '{}', user.userId]
      );
      return reply.code(201).send({ tenant: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/audit-log', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { entityType, entityId, action, actorId, startDate, endDate, limit, offset } = request.query as {
      entityType?: string;
      entityId?: string;
      action?: string;
      actorId?: string;
      startDate?: string;
      endDate?: string;
      limit?: string;
      offset?: string;
    };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      let idx = 1;

      if (entityType) { conditions.push(`entity_type = $${idx++}`); params.push(entityType); }
      if (entityId) { conditions.push(`entity_id = $${idx++}`); params.push(entityId); }
      if (action) { conditions.push(`action = $${idx++}`); params.push(action); }
      if (actorId) { conditions.push(`actor_id = $${idx++}`); params.push(actorId); }
      if (startDate) { conditions.push(`created_at >= $${idx++}`); params.push(startDate); }
      if (endDate) { conditions.push(`created_at <= $${idx++}`); params.push(endDate); }

      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);

      params.push(lim, off);
      const result = await client.query(
        `SELECT * FROM audit_log ${where} ORDER BY created_at DESC LIMIT $${idx++} OFFSET $${idx++}`,
        params
      );
      return { entries: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/platform/audit-log/verify-chain', { preHandler: [authenticate, requireRole('PLATFORM_ADMIN', 'ADMIN')] }, async (request) => {
    const user = getUser(request);
    const { startId, endId } = request.body as { startId?: string; endId?: string };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      let idx = 1;
      if (startId) { conditions.push(`log_id >= $${idx++}`); params.push(startId); }
      if (endId) { conditions.push(`log_id <= $${idx++}`); params.push(endId); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      const result = await client.query(
        `SELECT log_id, hash, previous_hash FROM audit_log ${where} ORDER BY log_id ASC`,
        params
      );
      const rows = result.rows as Array<{ log_id: string; hash: string; previous_hash: string | null }>;
      let valid = true;
      const breaks: string[] = [];
      for (let i = 1; i < rows.length; i++) {
        if (rows[i].previous_hash !== rows[i - 1].hash) {
          valid = false;
          breaks.push(rows[i].log_id);
        }
      }
      return { valid, totalChecked: rows.length, chainBreaks: breaks };
    }, user.tenantId, user.userId, user.role);
  });
}
