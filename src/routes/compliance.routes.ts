import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { withTransaction } from '../config/database';

export default async function complianceRoutes(app: FastifyInstance) {
  app.get('/policy-directives', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { status, category, limit, offset } = request.query as {
      status?: string;
      category?: string;
      limit?: string;
      offset?: string;
    };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (status) { conditions.push(`pd.status = $${params.length + 1}`); params.push(status); }
      if (category) { conditions.push(`pd.category = $${params.length + 1}`); params.push(category); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      params.push(lim, off);

      const result = await client.query(
        `SELECT pd.directive_id, pd.title, pd.description, pd.category,
                pd.effective_date, pd.expiry_date, pd.status, pd.issued_by, pd.created_at
         FROM policy_directives pd
         ${where}
         ORDER BY pd.effective_date DESC
         LIMIT $${params.length - 1} OFFSET $${params.length}`,
        params
      );
      return { directives: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/policy-directives', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      title: string;
      description: string;
      category: string;
      effectiveDate: string;
      expiryDate?: string;
      requirements?: Record<string, unknown>;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO policy_directives (title, description, category, effective_date,
                                         expiry_date, requirements, status, issued_by)
         VALUES ($1, $2, $3, $4, $5, $6, 'ACTIVE', $7)
         RETURNING directive_id, title, category, status, effective_date, created_at`,
        [body.title, body.description, body.category, body.effectiveDate,
         body.expiryDate || null,
         body.requirements ? JSON.stringify(body.requirements) : null, user.userId]
      );
      return reply.code(201).send({ directive: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/policy-directives/:id', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT directive_id, title, description, category, effective_date,
                expiry_date, requirements, status, issued_by, created_at, updated_at
         FROM policy_directives WHERE directive_id = $1`,
        [id]
      );
      if (result.rows.length === 0) throw new Error('DIRECTIVE_NOT_FOUND');
      return { directive: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/compliance-checklists/:schoolId', { preHandler: [authenticate] }, async (request) => {
    const { schoolId } = request.params as { schoolId: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT cc.checklist_id, cc.directive_id, cc.school_id, cc.status,
                cc.due_date, cc.completed_at, cc.evidence_count,
                pd.title AS directive_title, pd.category
         FROM compliance_checklists cc
         LEFT JOIN policy_directives pd ON pd.directive_id = cc.directive_id
         WHERE cc.school_id = $1
         ORDER BY cc.due_date`,
        [schoolId]
      );
      return { schoolId, checklists: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/compliance-checklists/:id/submit-evidence', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      evidenceType: string;
      description: string;
      evidenceId?: string;
      attachmentRef?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO compliance_evidence_submissions (checklist_id, evidence_type, description,
                                                       evidence_id, attachment_ref, submitted_by)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING submission_id, checklist_id, evidence_type, created_at`,
        [id, body.evidenceType, body.description, body.evidenceId || null,
         body.attachmentRef || null, user.userId]
      );
      await client.query(
        `UPDATE compliance_checklists SET evidence_count = evidence_count + 1, updated_at = NOW()
         WHERE checklist_id = $1`,
        [id]
      );
      return reply.code(201).send({ submission: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/compliance-risk-radar/:schoolId', { preHandler: [authenticate] }, async (request) => {
    const { schoolId } = request.params as { schoolId: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const risks = await client.query(
        `SELECT ri.risk_id, ri.category, ri.risk_level, ri.description,
                ri.mitigation_status, ri.last_assessed_at
         FROM compliance_risk_items ri
         WHERE ri.school_id = $1
         ORDER BY ri.risk_level DESC, ri.category`,
        [schoolId]
      );
      const summary = await client.query(
        `SELECT risk_level, COUNT(*) AS count
         FROM compliance_risk_items
         WHERE school_id = $1
         GROUP BY risk_level`,
        [schoolId]
      );
      return { schoolId, risks: risks.rows, summary: summary.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/outbound-submissions', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      submissionType: string;
      targetAuthority: string;
      schoolId: string;
      payload: Record<string, unknown>;
      dueDate?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO outbound_submissions (submission_type, target_authority, school_id,
                                            payload, due_date, status, submitted_by)
         VALUES ($1, $2, $3, $4, $5, 'PENDING', $6)
         RETURNING submission_id, submission_type, target_authority, status, created_at`,
        [body.submissionType, body.targetAuthority, body.schoolId,
         JSON.stringify(body.payload), body.dueDate || null, user.userId]
      );
      return reply.code(201).send({ submission: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/outbound-submissions/:id/status', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT submission_id, submission_type, target_authority, school_id,
                status, acknowledgement_ref, submitted_at, acknowledged_at, created_at
         FROM outbound_submissions WHERE submission_id = $1`,
        [id]
      );
      if (result.rows.length === 0) throw new Error('SUBMISSION_NOT_FOUND');
      return { submission: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });
}
