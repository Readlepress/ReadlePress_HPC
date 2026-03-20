import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { withTransaction } from '../config/database';

export default async function districtRoutes(app: FastifyInstance) {
  app.get('/governance-nodes', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { parentId, level } = request.query as { parentId?: string; level?: string };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (parentId) { conditions.push(`gn.parent_node_id = $${params.length + 1}`); params.push(parentId); }
      if (level) { conditions.push(`gn.level = $${params.length + 1}`); params.push(level); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const result = await client.query(
        `SELECT gn.node_id, gn.name, gn.level, gn.parent_node_id,
                gn.metadata, gn.created_at
         FROM governance_nodes gn
         ${where}
         ORDER BY gn.level, gn.name`,
        params
      );
      return { nodes: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/governance-nodes', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      name: string;
      level: string;
      parentNodeId?: string;
      metadata?: Record<string, unknown>;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO governance_nodes (name, level, parent_node_id, metadata, created_by)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING node_id, name, level, parent_node_id, created_at`,
        [body.name, body.level, body.parentNodeId || null,
         body.metadata ? JSON.stringify(body.metadata) : null, user.userId]
      );
      return reply.code(201).send({ node: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/policy-packs/:nodeId', { preHandler: [authenticate] }, async (request) => {
    const { nodeId } = request.params as { nodeId: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT pp.pack_id, pp.node_id, pp.version, pp.policies, pp.status,
                pp.effective_from, pp.created_at
         FROM policy_packs pp
         WHERE pp.node_id = $1 AND pp.status = 'ACTIVE'
         ORDER BY pp.effective_from DESC
         LIMIT 1`,
        [nodeId]
      );
      return { policyPack: result.rows[0] || null };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/policy-packs', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      nodeId: string;
      version: string;
      policies: Record<string, unknown>;
      effectiveFrom: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO policy_packs (node_id, version, policies, effective_from, status, published_by)
         VALUES ($1, $2, $3, $4, 'ACTIVE', $5)
         RETURNING pack_id, node_id, version, status, effective_from, created_at`,
        [body.nodeId, body.version, JSON.stringify(body.policies), body.effectiveFrom, user.userId]
      );
      return reply.code(201).send({ policyPack: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/protected-evidence-access', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      evidenceId: string;
      reason: string;
      accessLevel: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO protected_evidence_access_requests (evidence_id, reason, access_level,
                                                          status, requested_by)
         VALUES ($1, $2, $3, 'PENDING', $4)
         RETURNING request_id, evidence_id, access_level, status, created_at`,
        [body.evidenceId, body.reason, body.accessLevel, user.userId]
      );
      return reply.code(201).send({ request: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/district/compliance-dashboard', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { districtNodeId } = request.query as { districtNodeId?: string };
    return withTransaction(async (client) => {
      const params: unknown[] = [];
      let nodeFilter = '';
      if (districtNodeId) {
        nodeFilter = 'WHERE gn.node_id = $1 OR gn.parent_node_id = $1';
        params.push(districtNodeId);
      }
      const schools = await client.query(
        `SELECT COUNT(*) AS total_schools FROM governance_nodes gn
         ${nodeFilter ? nodeFilter + " AND gn.level = 'SCHOOL'" : "WHERE gn.level = 'SCHOOL'"}`,
        params
      );
      const compliance = await client.query(
        `SELECT cc.status, COUNT(*) AS count
         FROM compliance_checklists cc
         GROUP BY cc.status`
      );
      const risks = await client.query(
        `SELECT risk_level, COUNT(*) AS count
         FROM compliance_risk_items
         GROUP BY risk_level`
      );
      return {
        totalSchools: parseInt(schools.rows[0]?.total_schools || '0', 10),
        complianceByStatus: compliance.rows,
        risksByLevel: risks.rows,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/district/schools', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { districtNodeId, limit, offset } = request.query as {
      districtNodeId?: string;
      limit?: string;
      offset?: string;
    };
    return withTransaction(async (client) => {
      const conditions = ["gn.level = 'SCHOOL'"];
      const params: unknown[] = [];
      if (districtNodeId) { conditions.push(`gn.parent_node_id = $${params.length + 1}`); params.push(districtNodeId); }
      const where = conditions.join(' AND ');
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      params.push(lim, off);

      const result = await client.query(
        `SELECT gn.node_id, gn.name, gn.metadata, gn.created_at
         FROM governance_nodes gn
         WHERE ${where}
         ORDER BY gn.name
         LIMIT $${params.length - 1} OFFSET $${params.length}`,
        params
      );
      return { schools: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/protected-evidence-access-requests', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      evidenceId: string;
      reason: string;
      accessLevel: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO protected_evidence_access_requests (evidence_id, reason, access_level,
                                                          status, requested_by)
         VALUES ($1, $2, $3, 'PENDING', $4)
         RETURNING request_id, evidence_id, access_level, status, created_at`,
        [body.evidenceId, body.reason, body.accessLevel, user.userId]
      );
      return reply.code(201).send({ request: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/protected-evidence-access-requests/:id/approve', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { decision, notes } = request.body as { decision: 'APPROVED' | 'REJECTED'; notes?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE protected_evidence_access_requests SET status = $1, reviewed_by = $2,
                reviewed_at = NOW(), review_notes = $3, updated_at = NOW()
         WHERE request_id = $4
         RETURNING request_id, status, reviewed_by, reviewed_at`,
        [decision, user.userId, notes || null, id]
      );
      if (result.rows.length === 0) throw new Error('REQUEST_NOT_FOUND');
      return { request: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/inter-district-transfers', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      studentId: string;
      sourceDistrictId: string;
      targetDistrictId: string;
      reason: string;
      effectiveDate?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO inter_district_transfers (student_id, source_district_id, target_district_id,
                                                reason, effective_date, status, initiated_by)
         VALUES ($1, $2, $3, $4, COALESCE($5, CURRENT_DATE), 'PENDING', $6)
         RETURNING transfer_id, student_id, source_district_id, target_district_id, status, created_at`,
        [body.studentId, body.sourceDistrictId, body.targetDistrictId,
         body.reason, body.effectiveDate || null, user.userId]
      );
      return reply.code(201).send({ transfer: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/state/compliance-directives', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { status, limit, offset } = request.query as {
      status?: string;
      limit?: string;
      offset?: string;
    };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (status) { conditions.push(`cd.status = $${params.length + 1}`); params.push(status); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      params.push(lim, off);

      const result = await client.query(
        `SELECT cd.directive_id, cd.title, cd.description, cd.category,
                cd.effective_date, cd.status, cd.issued_by, cd.created_at
         FROM compliance_directives cd
         ${where}
         ORDER BY cd.effective_date DESC
         LIMIT $${params.length - 1} OFFSET $${params.length}`,
        params
      );
      return { directives: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/state/compliance-directives', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      title: string;
      description: string;
      category: string;
      effectiveDate: string;
      requirements?: Record<string, unknown>;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO compliance_directives (title, description, category, effective_date,
                                             requirements, status, issued_by)
         VALUES ($1, $2, $3, $4, $5, 'ACTIVE', $6)
         RETURNING directive_id, title, category, status, effective_date, created_at`,
        [body.title, body.description, body.category, body.effectiveDate,
         body.requirements ? JSON.stringify(body.requirements) : null, user.userId]
      );
      return reply.code(201).send({ directive: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });
}
