import { FastifyInstance } from 'fastify';
import { authenticate, getUser, requireRole } from '../middleware/auth';
import { listStudentsByClass, enrolStudent } from '../services/student.service';
import { withTransaction } from '../config/database';

export default async function studentRoutes(app: FastifyInstance) {
  app.get('/students', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const students = await listStudentsByClass(user.tenantId, user.userId, user.role);
    return { students };
  });

  app.post('/students', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      fullName: string;
      dateOfBirth: string;
      gender: string;
      guardianName?: string;
      guardianPhone?: string;
      aadhaarLastFour?: string;
      motherTongue?: string;
      address?: Record<string, unknown>;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO students (full_name, date_of_birth, gender, guardian_name, guardian_phone,
                               aadhaar_last_four, mother_tongue, address, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING student_id, full_name, date_of_birth, gender, created_at`,
        [body.fullName, body.dateOfBirth, body.gender, body.guardianName || null,
         body.guardianPhone || null, body.aadhaarLastFour || null,
         body.motherTongue || null, body.address ? JSON.stringify(body.address) : null,
         user.userId]
      );
      return reply.code(201).send({ student: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/students/:id/enrolments', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const { classId, academicYearLabel, rollNumber } = request.body as {
      classId: string;
      academicYearLabel: string;
      rollNumber?: string;
    };
    const user = getUser(request);

    try {
      const result = await enrolStudent(
        user.tenantId, id, classId, academicYearLabel, rollNumber || null, user.userId, user.role
      );
      return reply.code(201).send(result);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      if (message === 'CONSENT_REQUIRED') {
        return reply.code(400).send({
          error: 'CONSENT_REQUIRED',
          message: 'Active EDUCATIONAL_RECORD consent required for enrolment',
        });
      }
      throw err;
    }
  });

  app.get('/students/:id/hpc-identity', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT student_id, full_name, date_of_birth, gender, guardian_name,
                aadhaar_last_four, apaar_id, apaar_verified, mother_tongue
         FROM students WHERE student_id = $1`,
        [id]
      );
      if (result.rows.length === 0) {
        throw new Error('STUDENT_NOT_FOUND');
      }
      return { identity: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.patch('/students/:id/apaar-status', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { apaarId, verified } = request.body as { apaarId?: string; verified: boolean };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE students SET apaar_id = COALESCE($1, apaar_id), apaar_verified = $2,
                apaar_verified_at = CASE WHEN $2 THEN NOW() ELSE apaar_verified_at END,
                updated_at = NOW(), updated_by = $3
         WHERE student_id = $4
         RETURNING student_id, apaar_id, apaar_verified, apaar_verified_at`,
        [apaarId || null, verified, user.userId, id]
      );
      return { student: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/students/:id/transfers', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      targetSchoolId: string;
      reason: string;
      effectiveDate?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO student_transfers (student_id, source_school_id, target_school_id, reason,
                                        effective_date, status, initiated_by)
         VALUES ($1,
                 (SELECT school_id FROM student_enrolments WHERE student_id = $1 AND is_current = true LIMIT 1),
                 $2, $3, COALESCE($4, CURRENT_DATE), 'PENDING', $5)
         RETURNING transfer_id, student_id, source_school_id, target_school_id, status, created_at`,
        [id, body.targetSchoolId, body.reason, body.effectiveDate || null, user.userId]
      );
      return reply.code(201).send({ transfer: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/admin/deduplication/scan', { preHandler: [authenticate, requireRole('ADMIN', 'PLATFORM_ADMIN')] }, async (request, reply) => {
    const user = getUser(request);
    const { scope } = request.body as { scope?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO deduplication_scans (scope, status, triggered_by)
         VALUES ($1, 'RUNNING', $2)
         RETURNING scan_id, scope, status, created_at`,
        [scope || 'FULL', user.userId]
      );
      return reply.code(202).send({ scan: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/admin/deduplication/candidates', { preHandler: [authenticate, requireRole('ADMIN', 'PLATFORM_ADMIN')] }, async (request) => {
    const user = getUser(request);
    const { status, limit, offset } = request.query as { status?: string; limit?: string; offset?: string };
    return withTransaction(async (client) => {
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      const params: unknown[] = [lim, off];
      let where = '';
      if (status) {
        where = 'WHERE dc.status = $3';
        params.push(status);
      }
      const result = await client.query(
        `SELECT dc.candidate_id, dc.student_id_a, dc.student_id_b, dc.match_score,
                dc.status, dc.resolved_by, dc.resolved_at, dc.created_at
         FROM deduplication_candidates dc ${where}
         ORDER BY dc.match_score DESC
         LIMIT $1 OFFSET $2`,
        params
      );
      return { candidates: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/students/:id', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT s.student_id, s.full_name, s.date_of_birth, s.gender,
                s.guardian_name, s.guardian_phone, s.aadhaar_last_four,
                s.apaar_id, s.apaar_verified, s.mother_tongue, s.address,
                s.status, s.created_at, s.updated_at
         FROM students s WHERE s.student_id = $1`,
        [id]
      );
      if (result.rows.length === 0) throw new Error('STUDENT_NOT_FOUND');
      const enrolments = await client.query(
        `SELECT se.enrolment_id, se.class_id, se.academic_year_id, se.roll_number,
                se.is_current, se.enrolled_at
         FROM student_enrolments se WHERE se.student_id = $1
         ORDER BY se.enrolled_at DESC`,
        [id]
      );
      return { student: result.rows[0], enrolments: enrolments.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/admin/deduplication/suspects', { preHandler: [authenticate, requireRole('ADMIN', 'PLATFORM_ADMIN')] }, async (request) => {
    const user = getUser(request);
    const { minScore, limit, offset } = request.query as { minScore?: string; limit?: string; offset?: string };
    return withTransaction(async (client) => {
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      const threshold = parseFloat(minScore || '0.7');
      const result = await client.query(
        `SELECT dc.candidate_id, dc.student_id_a, dc.student_id_b, dc.match_score,
                dc.status, dc.created_at,
                sa.full_name AS student_a_name, sb.full_name AS student_b_name
         FROM deduplication_candidates dc
         JOIN students sa ON sa.student_id = dc.student_id_a
         JOIN students sb ON sb.student_id = dc.student_id_b
         WHERE dc.status = 'SUSPECT' AND dc.match_score >= $1
         ORDER BY dc.match_score DESC
         LIMIT $2 OFFSET $3`,
        [threshold, lim, off]
      );
      return { suspects: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/admin/deduplication/:id/resolve', { preHandler: [authenticate, requireRole('ADMIN', 'PLATFORM_ADMIN')] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { resolution, mergeIntoStudentId, notes } = request.body as {
      resolution: 'MERGED' | 'NOT_DUPLICATE' | 'DEFERRED';
      mergeIntoStudentId?: string;
      notes?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE deduplication_candidates SET status = $1, resolved_by = $2,
                resolved_at = NOW(), resolution_notes = $3, merge_into_student_id = $4
         WHERE candidate_id = $5
         RETURNING candidate_id, status, resolved_by, resolved_at`,
        [resolution, user.userId, notes || null, mergeIntoStudentId || null, id]
      );
      if (result.rows.length === 0) throw new Error('CANDIDATE_NOT_FOUND');
      return { candidate: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });
}
