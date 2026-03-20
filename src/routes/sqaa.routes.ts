import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  getSqaaScores,
  triggerSqaaComputation,
  listIndicatorDefinitions,
} from '../services/sqaa.service';
import { withTransaction } from '../config/database';

export default async function sqaaRoutes(app: FastifyInstance) {
  app.get('/schools/:id/sqaa-scores', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return getSqaaScores(user.tenantId, user.userId, user.role, id);
  });

  app.post('/sqaa-computation/trigger', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const { schoolId, academicYearId } = request.body as {
      schoolId: string;
      academicYearId: string;
    };
    const result = await triggerSqaaComputation(
      user.tenantId, user.userId, user.role, schoolId, academicYearId
    );
    return reply.code(202).send(result);
  });

  app.get('/sqaa-indicators', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const indicators = await listIndicatorDefinitions(user.tenantId, user.userId, user.role);
    return { indicators };
  });

  app.get('/sqaa/:schoolId/dashboard', { preHandler: [authenticate] }, async (request) => {
    const { schoolId } = request.params as { schoolId: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const scores = await client.query(
        `SELECT si.indicator_id, si.indicator_name, si.category,
                ss.score, ss.evidence_count, ss.computed_at
         FROM sqaa_indicators si
         LEFT JOIN sqaa_scores ss ON ss.indicator_id = si.indicator_id AND ss.school_id = $1
         ORDER BY si.category, si.indicator_name`,
        [schoolId]
      );
      const overall = await client.query(
        `SELECT AVG(ss.score) AS average_score, COUNT(ss.score_id) AS assessed_indicators
         FROM sqaa_scores ss WHERE ss.school_id = $1`,
        [schoolId]
      );
      return {
        schoolId,
        indicators: scores.rows,
        summary: overall.rows[0] || { average_score: 0, assessed_indicators: 0 },
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/sqaa/:schoolId/indicators', { preHandler: [authenticate] }, async (request) => {
    const { schoolId } = request.params as { schoolId: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT si.indicator_id, si.indicator_name, si.category, si.description,
                si.weight, si.measurement_type,
                ss.score, ss.evidence_count, ss.computed_at
         FROM sqaa_indicators si
         LEFT JOIN sqaa_scores ss ON ss.indicator_id = si.indicator_id AND ss.school_id = $1
         ORDER BY si.category, si.sort_order`,
        [schoolId]
      );
      return { schoolId, indicators: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/sqaa/district/:districtId/summary', { preHandler: [authenticate] }, async (request) => {
    const { districtId } = request.params as { districtId: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT gn.node_id AS school_id, gn.name AS school_name,
                AVG(ss.score) AS average_score,
                COUNT(DISTINCT ss.indicator_id) AS assessed_indicators
         FROM governance_nodes gn
         LEFT JOIN sqaa_scores ss ON ss.school_id = gn.node_id
         WHERE gn.parent_node_id = $1 AND gn.level = 'SCHOOL'
         GROUP BY gn.node_id, gn.name
         ORDER BY gn.name`,
        [districtId]
      );
      return { districtId, schools: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/sqaa/submissions', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      schoolId: string;
      indicatorId: string;
      value: number;
      evidenceDescription?: string;
      evidenceIds?: string[];
      period?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO sqaa_submissions (school_id, indicator_id, value, evidence_description,
                                        evidence_ids, period, status, submitted_by)
         VALUES ($1, $2, $3, $4, $5, $6, 'SUBMITTED', $7)
         RETURNING submission_id, school_id, indicator_id, value, status, created_at`,
        [body.schoolId, body.indicatorId, body.value, body.evidenceDescription || null,
         body.evidenceIds ? JSON.stringify(body.evidenceIds) : null,
         body.period || null, user.userId]
      );
      return reply.code(201).send({ submission: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/sqaa/improvement-plans', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      schoolId: string;
      title: string;
      description?: string;
      targetIndicators?: string[];
      startDate: string;
      endDate?: string;
      objectives?: Record<string, unknown>[];
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO sqaa_improvement_plans (school_id, title, description, target_indicators,
                                              start_date, end_date, objectives, status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, 'ACTIVE', $8)
         RETURNING plan_id, school_id, title, status, start_date, created_at`,
        [body.schoolId, body.title, body.description || null,
         body.targetIndicators ? JSON.stringify(body.targetIndicators) : null,
         body.startDate, body.endDate || null,
         body.objectives ? JSON.stringify(body.objectives) : null, user.userId]
      );
      return reply.code(201).send({ plan: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/sqaa/improvement-plans/:id', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const plan = await client.query(
        `SELECT plan_id, school_id, title, description, target_indicators,
                start_date, end_date, objectives, status, created_by, created_at
         FROM sqaa_improvement_plans WHERE plan_id = $1`,
        [id]
      );
      if (plan.rows.length === 0) throw new Error('PLAN_NOT_FOUND');
      const actions = await client.query(
        `SELECT action_id, description, status, assigned_to, due_date, completed_at
         FROM sqaa_improvement_actions WHERE plan_id = $1
         ORDER BY due_date`,
        [id]
      );
      return { plan: plan.rows[0], actions: actions.rows };
    }, user.tenantId, user.userId, user.role);
  });
}
