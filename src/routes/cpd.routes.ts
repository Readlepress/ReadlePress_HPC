import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  logCpdActivity,
  getCpdSummary,
  logPeerObservation,
} from '../services/cpd.service';
import { withTransaction } from '../config/database';

export default async function cpdRoutes(app: FastifyInstance) {
  app.post('/cpd/activities', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof logCpdActivity>[3];
    const result = await logCpdActivity(user.tenantId, user.userId, user.role, body);
    return reply.code(201).send(result);
  });

  app.get('/teachers/:id/cpd-summary', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return getCpdSummary(user.tenantId, user.userId, user.role, id);
  });

  app.post('/peer-observations', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof logPeerObservation>[3];
    const result = await logPeerObservation(user.tenantId, user.userId, user.role, body);
    return reply.code(201).send(result);
  });

  app.post('/cpd/activities/:id/verify', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { verified, notes } = request.body as { verified: boolean; notes?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE cpd_activities SET verification_status = $1, verified_by = $2,
                verified_at = NOW(), verification_notes = $3, updated_at = NOW()
         WHERE activity_id = $4
         RETURNING activity_id, verification_status, verified_by, verified_at`,
        [verified ? 'VERIFIED' : 'REJECTED', user.userId, notes || null, id]
      );
      if (result.rows.length === 0) throw new Error('ACTIVITY_NOT_FOUND');
      return { activity: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/teachers/:id/npst-assessment', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT na.assessment_id, na.teacher_id, na.npst_level, na.domain_scores,
                na.overall_score, na.assessment_date, na.status, na.assessor_id, na.created_at
         FROM npst_assessments na
         WHERE na.teacher_id = $1
         ORDER BY na.assessment_date DESC`,
        [id]
      );
      return { teacherId: id, assessments: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/npst-assessments', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      teacherId: string;
      npstLevel: string;
      domainScores: Record<string, unknown>;
      overallScore: number;
      assessmentDate: string;
      notes?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO npst_assessments (teacher_id, npst_level, domain_scores, overall_score,
                                        assessment_date, notes, status, assessor_id)
         VALUES ($1, $2, $3, $4, $5, $6, 'COMPLETED', $7)
         RETURNING assessment_id, teacher_id, npst_level, overall_score, status, created_at`,
        [body.teacherId, body.npstLevel, JSON.stringify(body.domainScores),
         body.overallScore, body.assessmentDate, body.notes || null, user.userId]
      );
      return reply.code(201).send({ assessment: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/peer-observation-cycles', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { schoolId, status } = request.query as { schoolId?: string; status?: string };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (schoolId) { conditions.push(`poc.school_id = $${params.length + 1}`); params.push(schoolId); }
      if (status) { conditions.push(`poc.status = $${params.length + 1}`); params.push(status); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const result = await client.query(
        `SELECT poc.cycle_id, poc.school_id, poc.title, poc.start_date, poc.end_date,
                poc.status, poc.created_by, poc.created_at
         FROM peer_observation_cycles poc
         ${where}
         ORDER BY poc.start_date DESC`,
        params
      );
      return { cycles: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/peer-observation-cycles', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      schoolId: string;
      title: string;
      startDate: string;
      endDate: string;
      pairings?: Array<{ observerId: string; observeeId: string }>;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO peer_observation_cycles (school_id, title, start_date, end_date,
                                               pairings, status, created_by)
         VALUES ($1, $2, $3, $4, $5, 'ACTIVE', $6)
         RETURNING cycle_id, school_id, title, status, start_date, created_at`,
        [body.schoolId, body.title, body.startDate, body.endDate,
         body.pairings ? JSON.stringify(body.pairings) : null, user.userId]
      );
      return reply.code(201).send({ cycle: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/teachers/:id/professional-growth', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const cpd = await client.query(
        `SELECT COUNT(*) AS total_activities,
                SUM(hours) AS total_hours,
                COUNT(*) FILTER (WHERE verification_status = 'VERIFIED') AS verified_activities
         FROM cpd_activities WHERE teacher_id = $1`,
        [id]
      );
      const npst = await client.query(
        `SELECT npst_level, overall_score, assessment_date
         FROM npst_assessments WHERE teacher_id = $1
         ORDER BY assessment_date DESC LIMIT 1`,
        [id]
      );
      const observations = await client.query(
        `SELECT COUNT(*) AS total_observations,
                AVG(overall_rating) AS avg_rating
         FROM peer_observations WHERE observee_id = $1`,
        [id]
      );
      const interventions = await client.query(
        `SELECT intervention_id, type, status, created_at
         FROM professional_growth_interventions WHERE teacher_id = $1
         ORDER BY created_at DESC`,
        [id]
      );
      return {
        teacherId: id,
        cpdSummary: cpd.rows[0],
        latestNpst: npst.rows[0] || null,
        observationSummary: observations.rows[0],
        interventions: interventions.rows,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/professional-growth-interventions', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      teacherId: string;
      type: string;
      description: string;
      targetAreas?: string[];
      startDate?: string;
      endDate?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO professional_growth_interventions (teacher_id, type, description,
                                                         target_areas, start_date, end_date,
                                                         status, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, 'ACTIVE', $7)
         RETURNING intervention_id, teacher_id, type, status, created_at`,
        [body.teacherId, body.type, body.description,
         body.targetAreas ? JSON.stringify(body.targetAreas) : null,
         body.startDate || null, body.endDate || null, user.userId]
      );
      return reply.code(201).send({ intervention: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });
}
