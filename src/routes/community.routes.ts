import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  registerPartner,
  logEngagementSession,
  listPartners,
  getEngagementAggregates,
} from '../services/community.service';
import { withTransaction } from '../config/database';

export default async function communityRoutes(app: FastifyInstance) {
  app.post('/community/partners', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof registerPartner>[3];
    const result = await registerPartner(user.tenantId, user.userId, user.role, body);
    return reply.code(201).send(result);
  });

  app.post('/community/sessions', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof logEngagementSession>[3];
    const result = await logEngagementSession(user.tenantId, user.userId, user.role, body);
    return reply.code(201).send(result);
  });

  app.get('/community/partners', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const partners = await listPartners(user.tenantId, user.userId, user.role);
    return { partners };
  });

  app.get('/community/aggregates', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const aggregates = await getEngagementAggregates(user.tenantId, user.userId, user.role);
    return { aggregates };
  });

  app.post('/community/partners/:id/vet', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      decision: 'APPROVED' | 'REJECTED' | 'REQUIRES_MORE_INFO';
      notes?: string;
      verificationDocRef?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO partner_vetting_actions (partner_id, decision, notes,
                                               verification_doc_ref, vetted_by)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING action_id, partner_id, decision, created_at`,
        [id, body.decision, body.notes || null, body.verificationDocRef || null, user.userId]
      );
      await client.query(
        `UPDATE community_partners SET vetting_status = $1, updated_at = NOW()
         WHERE partner_id = $2`,
        [body.decision, id]
      );
      return reply.code(201).send({ vettingAction: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/community/partners/:id/vetting-log', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT pva.action_id, pva.decision, pva.notes, pva.verification_doc_ref,
                pva.vetted_by, pva.created_at
         FROM partner_vetting_actions pva
         WHERE pva.partner_id = $1
         ORDER BY pva.created_at DESC`,
        [id]
      );
      return { partnerId: id, vettingLog: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/community/sessions/:id/verify', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { verified, notes } = request.body as { verified: boolean; notes?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE community_sessions SET verification_status = $1, verified_by = $2,
                verified_at = NOW(), verification_notes = $3, updated_at = NOW()
         WHERE session_id = $4
         RETURNING session_id, verification_status, verified_by, verified_at`,
        [verified ? 'VERIFIED' : 'REJECTED', user.userId, notes || null, id]
      );
      if (result.rows.length === 0) throw new Error('SESSION_NOT_FOUND');
      return { session: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/community/sessions/:schoolId', { preHandler: [authenticate] }, async (request) => {
    const { schoolId } = request.params as { schoolId: string };
    const user = getUser(request);
    const { limit, offset } = request.query as { limit?: string; offset?: string };
    return withTransaction(async (client) => {
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      const result = await client.query(
        `SELECT cs.session_id, cs.partner_id, cs.school_id, cs.session_date,
                cs.session_type, cs.description, cs.students_involved,
                cs.verification_status, cs.created_at
         FROM community_sessions cs
         WHERE cs.school_id = $1
         ORDER BY cs.session_date DESC
         LIMIT $2 OFFSET $3`,
        [schoolId, lim, off]
      );
      return { schoolId, sessions: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/community/safeguarding-incidents', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      schoolId: string;
      partnerId?: string;
      sessionId?: string;
      incidentType: string;
      severity: string;
      description: string;
      reportedDate: string;
      involvedStudentIds?: string[];
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO safeguarding_incidents (school_id, partner_id, session_id,
                                              incident_type, severity, description,
                                              reported_date, involved_student_ids,
                                              status, reported_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'REPORTED', $9)
         RETURNING incident_id, school_id, incident_type, severity, status, created_at`,
        [body.schoolId, body.partnerId || null, body.sessionId || null,
         body.incidentType, body.severity, body.description, body.reportedDate,
         body.involvedStudentIds ? JSON.stringify(body.involvedStudentIds) : null,
         user.userId]
      );
      return reply.code(201).send({ incident: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/alumni', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { schoolId, graduationYear, limit, offset } = request.query as {
      schoolId?: string;
      graduationYear?: string;
      limit?: string;
      offset?: string;
    };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (schoolId) { conditions.push(`a.school_id = $${params.length + 1}`); params.push(schoolId); }
      if (graduationYear) { conditions.push(`a.graduation_year = $${params.length + 1}`); params.push(parseInt(graduationYear, 10)); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      params.push(lim, off);

      const result = await client.query(
        `SELECT a.alumni_id, a.full_name, a.school_id, a.graduation_year,
                a.contact_email, a.status, a.created_at
         FROM alumni a
         ${where}
         ORDER BY a.graduation_year DESC, a.full_name
         LIMIT $${params.length - 1} OFFSET $${params.length}`,
        params
      );
      return { alumni: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/alumni/register', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      fullName: string;
      schoolId: string;
      graduationYear: number;
      contactEmail?: string;
      contactPhone?: string;
      currentOccupation?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO alumni (full_name, school_id, graduation_year, contact_email,
                              contact_phone, current_occupation, status, registered_by)
         VALUES ($1, $2, $3, $4, $5, $6, 'ACTIVE', $7)
         RETURNING alumni_id, full_name, school_id, graduation_year, status, created_at`,
        [body.fullName, body.schoolId, body.graduationYear, body.contactEmail || null,
         body.contactPhone || null, body.currentOccupation || null, user.userId]
      );
      return reply.code(201).send({ alumni: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/alumni/:id/engagements', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT ae.engagement_id, ae.alumni_id, ae.engagement_type, ae.description,
                ae.session_id, ae.school_id, ae.engagement_date, ae.created_at
         FROM alumni_engagements ae
         WHERE ae.alumni_id = $1
         ORDER BY ae.engagement_date DESC`,
        [id]
      );
      return { alumniId: id, engagements: result.rows };
    }, user.tenantId, user.userId, user.role);
  });
}
