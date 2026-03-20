import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  triggerCreditComputation,
  getCreditSummary,
  submitExternalCreditClaim,
} from '../services/credit.service';
import { withTransaction } from '../config/database';

export default async function creditRoutes(app: FastifyInstance) {
  app.post('/credit-computation/trigger', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const { studentId, academicYearId } = request.body as {
      studentId: string;
      academicYearId: string;
    };
    const result = await triggerCreditComputation(
      user.tenantId, user.userId, user.role, studentId, academicYearId
    );
    return reply.code(202).send(result);
  });

  app.get('/students/:id/credit-summary', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const entries = await getCreditSummary(user.tenantId, user.userId, user.role, id);
    return { entries };
  });

  app.post('/external-credit-claims', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof submitExternalCreditClaim>[3];
    const result = await submitExternalCreditClaim(
      user.tenantId, user.userId, user.role, body
    );
    return reply.code(201).send(result);
  });

  app.post('/activity-records', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      studentId: string;
      activityType: string;
      title: string;
      description?: string;
      hoursSpent?: number;
      competencyUids?: string[];
      evidenceIds?: string[];
      activityDate: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO activity_records (student_id, activity_type, title, description,
                                       hours_spent, competency_uids, evidence_ids,
                                       activity_date, status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'DRAFT', $9)
         RETURNING record_id, student_id, activity_type, title, status, created_at`,
        [body.studentId, body.activityType, body.title, body.description || null,
         body.hoursSpent || null,
         body.competencyUids ? JSON.stringify(body.competencyUids) : null,
         body.evidenceIds ? JSON.stringify(body.evidenceIds) : null,
         body.activityDate, user.userId]
      );
      return reply.code(201).send({ record: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/activity-records/:id/submit', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE activity_records SET status = 'SUBMITTED', submitted_at = NOW(),
                submitted_by = $1, updated_at = NOW()
         WHERE record_id = $2 AND status = 'DRAFT'
         RETURNING record_id, status, submitted_at`,
        [user.userId, id]
      );
      if (result.rows.length === 0) throw new Error('RECORD_NOT_FOUND_OR_NOT_DRAFT');
      return { record: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/activity-records/:id/verify', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { decision, notes } = request.body as { decision: 'VERIFIED' | 'REJECTED'; notes?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE activity_records SET status = $1, verified_by = $2, verified_at = NOW(),
                verification_notes = $3, updated_at = NOW()
         WHERE record_id = $4 AND status = 'SUBMITTED'
         RETURNING record_id, status, verified_by, verified_at`,
        [decision, user.userId, notes || null, id]
      );
      if (result.rows.length === 0) throw new Error('RECORD_NOT_FOUND_OR_NOT_SUBMITTED');
      return { record: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/external-credit-claims/:id/approve', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { decision, notes, creditValue } = request.body as {
      decision: 'APPROVED' | 'REJECTED';
      notes?: string;
      creditValue?: number;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE external_credit_claims SET status = $1, reviewed_by = $2, reviewed_at = NOW(),
                review_notes = $3, approved_credit_value = $4, updated_at = NOW()
         WHERE claim_id = $5
         RETURNING claim_id, status, reviewed_by, reviewed_at, approved_credit_value`,
        [decision, user.userId, notes || null, creditValue || null, id]
      );
      if (result.rows.length === 0) throw new Error('CLAIM_NOT_FOUND');
      return { claim: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/credit/trigger-computation', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const { studentId, academicYearId } = request.body as {
      studentId: string;
      academicYearId: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO credit_computation_jobs (student_id, academic_year_id, status, triggered_by)
         VALUES ($1, $2, 'QUEUED', $3)
         RETURNING job_id, student_id, academic_year_id, status, created_at`,
        [studentId, academicYearId, user.userId]
      );
      return reply.code(202).send({ job: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/students/:id/credit-ledger', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { academicYearId, limit, offset } = request.query as {
      academicYearId?: string;
      limit?: string;
      offset?: string;
    };
    return withTransaction(async (client) => {
      const conditions = ['cl.student_id = $1'];
      const params: unknown[] = [id];
      if (academicYearId) { conditions.push(`cl.academic_year_id = $${params.length + 1}`); params.push(academicYearId); }
      const where = conditions.join(' AND ');
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      params.push(lim, off);

      const result = await client.query(
        `SELECT cl.ledger_entry_id, cl.student_id, cl.academic_year_id, cl.credit_type,
                cl.credit_value, cl.source_record_id, cl.source_type, cl.description,
                cl.created_at
         FROM credit_ledger cl
         WHERE ${where}
         ORDER BY cl.created_at DESC
         LIMIT $${params.length - 1} OFFSET $${params.length}`,
        params
      );
      return { ledger: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/external-credit-claims/:id/review', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { decision, notes, creditValue } = request.body as {
      decision: 'APPROVED' | 'REJECTED';
      notes?: string;
      creditValue?: number;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE external_credit_claims SET status = $1, reviewed_by = $2, reviewed_at = NOW(),
                review_notes = $3, approved_credit_value = $4, updated_at = NOW()
         WHERE claim_id = $5
         RETURNING claim_id, status, reviewed_by, reviewed_at, approved_credit_value`,
        [decision, user.userId, notes || null, creditValue || null, id]
      );
      if (result.rows.length === 0) throw new Error('CLAIM_NOT_FOUND');
      return { claim: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/credit-computation-jobs/:id/status', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT job_id, student_id, academic_year_id, status, progress_percent,
                error_message, created_at, completed_at
         FROM credit_computation_jobs WHERE job_id = $1`,
        [id]
      );
      if (result.rows.length === 0) throw new Error('JOB_NOT_FOUND');
      return { job: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });
}
