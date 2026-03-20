import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { listAcademicYears, initiateYearClose } from '../services/academic-year.service';
import { withTransaction } from '../config/database';

export default async function academicYearRoutes(app: FastifyInstance) {
  app.get('/academic-years', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { schoolId } = request.query as { schoolId?: string };
    const years = await listAcademicYears(user.tenantId, user.userId, user.role, schoolId);
    return { academicYears: years };
  });

  app.post('/academic-years', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      label: string;
      startDate: string;
      endDate: string;
      schoolId: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO academic_years (label, start_date, end_date, school_id, status, created_by)
         VALUES ($1, $2, $3, $4, 'PLANNING', $5)
         RETURNING year_id, label, start_date, end_date, school_id, status, created_at`,
        [body.label, body.startDate, body.endDate, body.schoolId, user.userId]
      );
      return reply.code(201).send({ academicYear: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/academic-years/:id/advance-status', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { targetStatus } = request.body as { targetStatus: string };
    return withTransaction(async (client) => {
      const current = await client.query(
        `SELECT status FROM academic_years WHERE year_id = $1`, [id]
      );
      if (current.rows.length === 0) throw new Error('YEAR_NOT_FOUND');

      const transitions: Record<string, string[]> = {
        PLANNING: ['ACTIVE'],
        ACTIVE: ['REVIEW'],
        REVIEW: ['LOCKED'],
      };
      const allowed = transitions[current.rows[0].status as string] || [];
      if (!allowed.includes(targetStatus)) {
        throw new Error(`Cannot transition from ${current.rows[0].status} to ${targetStatus}`);
      }

      const result = await client.query(
        `UPDATE academic_years SET status = $1, updated_at = NOW(), updated_by = $2
         WHERE year_id = $3
         RETURNING year_id, label, status, updated_at`,
        [targetStatus, user.userId, id]
      );
      return { academicYear: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/academic-years/:id/completeness-check', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const enrolments = await client.query(
        `SELECT COUNT(*) AS total FROM student_enrolments WHERE academic_year_id = $1`, [id]
      );
      const withMastery = await client.query(
        `SELECT COUNT(DISTINCT se.student_id) AS total
         FROM student_enrolments se
         JOIN mastery_events me ON me.student_id = se.student_id
         WHERE se.academic_year_id = $1`, [id]
      );
      const total = parseInt(enrolments.rows[0].total, 10);
      const covered = parseInt(withMastery.rows[0].total, 10);
      return {
        yearId: id,
        totalEnrolments: total,
        studentsWithMastery: covered,
        completenessPercent: total > 0 ? Math.round((covered / total) * 100) : 0,
        ready: total > 0 && covered === total,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/terms', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      academicYearId: string;
      label: string;
      startDate: string;
      endDate: string;
      sequence: number;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO terms (academic_year_id, label, start_date, end_date, sequence, status, created_by)
         VALUES ($1, $2, $3, $4, $5, 'OPEN', $6)
         RETURNING term_id, academic_year_id, label, start_date, end_date, sequence, status, created_at`,
        [body.academicYearId, body.label, body.startDate, body.endDate, body.sequence, user.userId]
      );
      return reply.code(201).send({ term: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/terms/:id/lock', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE terms SET status = 'LOCKED', locked_at = NOW(), locked_by = $1, updated_at = NOW()
         WHERE term_id = $2 AND status = 'OPEN'
         RETURNING term_id, label, status, locked_at`,
        [user.userId, id]
      );
      if (result.rows.length === 0) throw new Error('TERM_NOT_FOUND_OR_ALREADY_LOCKED');
      return { term: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/academic-years/:id/rollover/dry-run', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const enrolments = await client.query(
        `SELECT se.student_id, s.full_name, se.class_id, c.grade_level
         FROM student_enrolments se
         JOIN students s ON s.student_id = se.student_id
         JOIN classes c ON c.class_id = se.class_id
         WHERE se.academic_year_id = $1 AND se.is_current = true`,
        [id]
      );
      const preview = enrolments.rows.map((r: Record<string, unknown>) => ({
        studentId: r.student_id,
        fullName: r.full_name,
        currentClassId: r.class_id,
        currentGrade: r.grade_level,
        proposedGrade: (r.grade_level as number) + 1,
      }));
      return { dryRun: true, yearId: id, students: preview, totalAffected: preview.length };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/academic-years/:id/rollover/execute', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { targetYearId } = request.body as { targetYearId: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO rollover_jobs (source_year_id, target_year_id, status, initiated_by)
         VALUES ($1, $2, 'RUNNING', $3)
         RETURNING job_id, source_year_id, target_year_id, status, created_at`,
        [id, targetYearId, user.userId]
      );
      return reply.code(202).send({ rolloverJob: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/academic-years/:id/snapshot', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const year = await client.query(
        `SELECT * FROM academic_years WHERE year_id = $1`, [id]
      );
      const terms = await client.query(
        `SELECT * FROM terms WHERE academic_year_id = $1 ORDER BY sequence`, [id]
      );
      const enrolmentCount = await client.query(
        `SELECT COUNT(*) AS total FROM student_enrolments WHERE academic_year_id = $1`, [id]
      );
      return {
        academicYear: year.rows[0] || null,
        terms: terms.rows,
        enrolmentCount: parseInt(enrolmentCount.rows[0].total, 10),
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/academic-years/:id/close', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);

    try {
      const result = await initiateYearClose(user.tenantId, id, user.userId, user.role);
      if (result.status === 'BLOCKED') {
        return reply.code(409).send({
          error: 'YEAR_CLOSE_BLOCKED',
          ...result,
        });
      }
      return result;
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      if (message === 'YEAR_NOT_IN_REVIEW') {
        return reply.code(400).send({
          error: 'INVALID_STATE',
          message: 'Academic year must be in REVIEW status to close',
        });
      }
      throw err;
    }
  });
}
