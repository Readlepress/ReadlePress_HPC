import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { getMasterySummary, verifyMasteryEvent } from '../services/mastery.service';
import { withTransaction } from '../config/database';

export default async function masteryRoutes(app: FastifyInstance) {
  app.get('/students/:id/mastery-summary', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const summary = await getMasterySummary(user.tenantId, user.userId, user.role, id);
    return { aggregates: summary };
  });

  app.post('/mastery-events/:id/verify', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return verifyMasteryEvent(user.tenantId, user.userId, user.role, id);
  });

  app.get('/students/:id/growth-curve', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { competencyUid, startDate, endDate } = request.query as {
      competencyUid?: string;
      startDate?: string;
      endDate?: string;
    };
    return withTransaction(async (client) => {
      const conditions = ['me.student_id = $1'];
      const params: unknown[] = [id];
      if (competencyUid) { conditions.push(`c.uid = $${params.length + 1}`); params.push(competencyUid); }
      if (startDate) { conditions.push(`me.observed_at >= $${params.length + 1}`); params.push(startDate); }
      if (endDate) { conditions.push(`me.observed_at <= $${params.length + 1}`); params.push(endDate); }
      const where = conditions.join(' AND ');
      const result = await client.query(
        `SELECT me.event_id, c.uid AS competency_uid, c.label AS competency_label,
                me.numeric_value, me.observed_at, me.source_type
         FROM mastery_events me
         JOIN competencies c ON c.competency_id = me.competency_id
         WHERE ${where}
         ORDER BY me.observed_at ASC`,
        params
      );
      return { studentId: id, dataPoints: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/students/:id/stage-readiness', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { targetStageCode } = request.query as { targetStageCode?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT c.uid AS competency_uid, c.label,
                COALESCE(ma.aggregate_value, 0) AS current_value,
                c.mastery_threshold,
                CASE WHEN COALESCE(ma.aggregate_value, 0) >= c.mastery_threshold
                     THEN true ELSE false END AS met
         FROM competencies c
         LEFT JOIN mastery_aggregates ma ON ma.competency_id = c.competency_id AND ma.student_id = $1
         WHERE c.stage_code = COALESCE($2,
           (SELECT stage_code FROM student_enrolments se
            JOIN classes cl ON cl.class_id = se.class_id
            WHERE se.student_id = $1 AND se.is_current = true LIMIT 1))
         ORDER BY c.sort_order`,
        [id, targetStageCode || null]
      );
      const total = result.rows.length;
      const met = result.rows.filter((r: Record<string, unknown>) => r.met).length;
      return {
        studentId: id,
        competencies: result.rows,
        totalCompetencies: total,
        metCount: met,
        readinessPercent: total > 0 ? Math.round((met / total) * 100) : 0,
        ready: total > 0 && met === total,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/classes/:id/mastery-dashboard', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const students = await client.query(
        `SELECT s.student_id, s.full_name,
                COUNT(DISTINCT ma.competency_id) AS assessed_competencies,
                AVG(ma.aggregate_value) AS avg_mastery
         FROM student_enrolments se
         JOIN students s ON s.student_id = se.student_id
         LEFT JOIN mastery_aggregates ma ON ma.student_id = s.student_id
         WHERE se.class_id = $1 AND se.is_current = true
         GROUP BY s.student_id, s.full_name
         ORDER BY s.full_name`,
        [id]
      );
      const classAvg = await client.query(
        `SELECT AVG(ma.aggregate_value) AS class_average
         FROM student_enrolments se
         JOIN mastery_aggregates ma ON ma.student_id = se.student_id
         WHERE se.class_id = $1 AND se.is_current = true`,
        [id]
      );
      return {
        classId: id,
        classAverage: classAvg.rows[0]?.class_average || 0,
        students: students.rows,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/mastery/trigger-aggregation', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const { studentId, competencyId } = request.body as {
      studentId?: string;
      competencyId?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO aggregation_jobs (student_id, competency_id, status, triggered_by)
         VALUES ($1, $2, 'QUEUED', $3)
         RETURNING job_id, student_id, competency_id, status, created_at`,
        [studentId || null, competencyId || null, user.userId]
      );
      return reply.code(202).send({ job: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/mastery-events/:id/amend', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      reason: string;
      amendedValue?: number;
      amendedNote?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO mastery_event_amendments (event_id, reason, amended_value, amended_note,
                                               status, submitted_by)
         VALUES ($1, $2, $3, $4, 'PENDING', $5)
         RETURNING amendment_id, event_id, reason, status, created_at`,
        [id, body.reason, body.amendedValue || null, body.amendedNote || null, user.userId]
      );
      return reply.code(201).send({ amendment: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/mastery-aggregation-jobs/:id/status', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT job_id, student_id, competency_id, status, progress_percent,
                error_message, created_at, completed_at
         FROM aggregation_jobs WHERE job_id = $1`,
        [id]
      );
      if (result.rows.length === 0) throw new Error('JOB_NOT_FOUND');
      return { job: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });
}
