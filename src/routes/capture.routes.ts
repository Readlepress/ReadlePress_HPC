import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { syncOfflineCapture } from '../services/capture.service';
import { withTransaction } from '../config/database';

export default async function captureRoutes(app: FastifyInstance) {
  app.post('/capture/sync', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { teacherId, drafts } = request.body as {
      teacherId: string;
      drafts: Array<{
        localId: string;
        studentId: string;
        competencyId: string;
        observedAt: string;
        recordedAt: string;
        timestampSource: string;
        timestampConfidence: string;
        numericValue: number;
        descriptorLevelId?: string;
        observationNote?: string;
        evidenceLocalIds?: string[];
        sourceType?: string;
        deviceId?: string;
      }>;
    };

    const result = await syncOfflineCapture(user.tenantId, teacherId, user.userId, user.role, drafts);
    return result;
  });

  app.post('/capture-sessions', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      teacherId: string;
      classId: string;
      deviceId?: string;
      startedAt?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO capture_sessions (teacher_id, class_id, device_id, started_at, status, created_by)
         VALUES ($1, $2, $3, COALESCE($4, NOW()), 'ACTIVE', $5)
         RETURNING session_id, teacher_id, class_id, device_id, started_at, status, created_at`,
        [body.teacherId, body.classId, body.deviceId || null, body.startedAt || null, user.userId]
      );
      return reply.code(201).send({ session: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/conflicts/:id/resolve', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { resolution, winnerDraftId } = request.body as {
      resolution: 'SERVER_WINS' | 'CLIENT_WINS' | 'MERGE';
      winnerDraftId?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE sync_conflicts SET resolution = $1, winner_draft_id = $2,
                resolved_by = $3, resolved_at = NOW(), status = 'RESOLVED'
         WHERE conflict_id = $4
         RETURNING conflict_id, resolution, status, resolved_at`,
        [resolution, winnerDraftId || null, user.userId, id]
      );
      if (result.rows.length === 0) throw new Error('CONFLICT_NOT_FOUND');
      return { conflict: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/drafts/:id/promote', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const draft = await client.query(
        `SELECT * FROM capture_drafts WHERE draft_id = $1 AND status = 'SYNCED'`, [id]
      );
      if (draft.rows.length === 0) throw new Error('DRAFT_NOT_FOUND_OR_NOT_SYNCED');
      const d = draft.rows[0] as Record<string, unknown>;

      const event = await client.query(
        `INSERT INTO mastery_events (student_id, competency_id, observed_at, numeric_value,
                                     descriptor_level_id, observation_note, source_type,
                                     teacher_id, created_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING event_id, student_id, competency_id, created_at`,
        [d.student_id, d.competency_id, d.observed_at, d.numeric_value,
         d.descriptor_level_id, d.observation_note, d.source_type || 'DIRECT_OBSERVATION',
         d.teacher_id, user.userId]
      );

      await client.query(
        `UPDATE capture_drafts SET status = 'PROMOTED', promoted_event_id = $1, updated_at = NOW()
         WHERE draft_id = $2`,
        [event.rows[0].event_id, id]
      );
      return { masteryEvent: event.rows[0], draftId: id };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/capture-dashboard', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { classId, teacherId } = request.query as { classId?: string; teacherId?: string };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (classId) { conditions.push(`cs.class_id = $${params.length + 1}`); params.push(classId); }
      if (teacherId) { conditions.push(`cs.teacher_id = $${params.length + 1}`); params.push(teacherId); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      const sessions = await client.query(
        `SELECT COUNT(*) AS total_sessions,
                COUNT(*) FILTER (WHERE cs.status = 'ACTIVE') AS active_sessions
         FROM capture_sessions cs ${where}`,
        params
      );
      const drafts = await client.query(
        `SELECT COUNT(*) AS total_drafts,
                COUNT(*) FILTER (WHERE cd.status = 'PENDING') AS pending_drafts,
                COUNT(*) FILTER (WHERE cd.status = 'SYNCED') AS synced_drafts,
                COUNT(*) FILTER (WHERE cd.status = 'PROMOTED') AS promoted_drafts
         FROM capture_drafts cd`
      );
      const conflicts = await client.query(
        `SELECT COUNT(*) AS total_conflicts,
                COUNT(*) FILTER (WHERE sc.status = 'PENDING') AS unresolved_conflicts
         FROM sync_conflicts sc`
      );
      return {
        sessions: sessions.rows[0],
        drafts: drafts.rows[0],
        conflicts: conflicts.rows[0],
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/conflicts', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { status, sessionId, limit, offset } = request.query as {
      status?: string;
      sessionId?: string;
      limit?: string;
      offset?: string;
    };
    return withTransaction(async (client) => {
      const conditions: string[] = [];
      const params: unknown[] = [];
      if (status) { conditions.push(`sc.status = $${params.length + 1}`); params.push(status); }
      if (sessionId) { conditions.push(`sc.session_id = $${params.length + 1}`); params.push(sessionId); }
      const where = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
      const lim = Math.min(parseInt(limit || '50', 10), 200);
      const off = parseInt(offset || '0', 10);
      params.push(lim, off);

      const result = await client.query(
        `SELECT sc.conflict_id, sc.session_id, sc.draft_id, sc.conflict_type,
                sc.server_value, sc.client_value, sc.status, sc.resolution,
                sc.created_at
         FROM sync_conflicts sc
         ${where}
         ORDER BY sc.created_at DESC
         LIMIT $${params.length - 1} OFFSET $${params.length}`,
        params
      );
      return { conflicts: result.rows, limit: lim, offset: off };
    }, user.tenantId, user.userId, user.role);
  });
}
