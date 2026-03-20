import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { dispatchFeedbackRequests, submitFeedbackResponse, getModerationQueue } from '../services/feedback.service';
import { withTransaction } from '../config/database';

export default async function feedbackRoutes(app: FastifyInstance) {
  app.post('/feedback-requests/batch', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof dispatchFeedbackRequests>[3];
    const result = await dispatchFeedbackRequests(user.tenantId, user.userId, user.role, body);
    return reply.code(201).send(result);
  });

  app.post('/feedback-requests/:id/response', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { items } = request.body as {
      items: Array<{
        promptId: string;
        scaleValue?: number;
        textValue?: string;
        selectedOptions?: unknown;
      }>;
    };
    return submitFeedbackResponse(user.tenantId, user.userId, user.role, id, items);
  });

  app.get('/moderation-queue', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { classId } = request.query as { classId?: string };
    const queue = await getModerationQueue(user.tenantId, user.userId, user.role, classId);
    return { queue };
  });

  app.post('/moderation-queue/:id/moderate', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { decision, reason } = request.body as {
      decision: 'APPROVED' | 'REJECTED' | 'FLAGGED';
      reason?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE feedback_responses SET moderation_status = $1, moderation_reason = $2,
                moderated_by = $3, moderated_at = NOW(), updated_at = NOW()
         WHERE response_id = $4
         RETURNING response_id, moderation_status, moderated_by, moderated_at`,
        [decision, reason || null, user.userId, id]
      );
      if (result.rows.length === 0) throw new Error('RESPONSE_NOT_FOUND');
      return { response: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/students/:id/peer-summary', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT fr.request_id, fr.feedback_type, fr.competency_uid,
                fre.response_id, fre.moderation_status,
                AVG(fri.scale_value) AS avg_scale,
                COUNT(fri.item_id) AS item_count
         FROM feedback_requests fr
         JOIN feedback_responses fre ON fre.request_id = fr.request_id
         LEFT JOIN feedback_response_items fri ON fri.response_id = fre.response_id
         WHERE fr.target_student_id = $1
           AND fr.feedback_type = 'PEER'
           AND fre.moderation_status = 'APPROVED'
         GROUP BY fr.request_id, fr.feedback_type, fr.competency_uid,
                  fre.response_id, fre.moderation_status`,
        [id]
      );
      return { studentId: id, peerAssessments: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/students/:id/self-assessment-summary', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT sal.link_id, sal.competency_uid, sal.status, sal.promoted,
                sal.self_rating, sal.reflection_text, sal.created_at
         FROM self_assessment_links sal
         WHERE sal.student_id = $1
         ORDER BY sal.created_at DESC`,
        [id]
      );
      return { studentId: id, selfAssessments: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/self-assessment-links/:id/promote', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const link = await client.query(
        `SELECT * FROM self_assessment_links WHERE link_id = $1 AND promoted = false`, [id]
      );
      if (link.rows.length === 0) throw new Error('LINK_NOT_FOUND_OR_ALREADY_PROMOTED');
      const l = link.rows[0] as Record<string, unknown>;

      const event = await client.query(
        `INSERT INTO mastery_events (student_id, competency_id, observed_at, numeric_value,
                                     source_type, observation_note, created_by)
         VALUES ($1,
                 (SELECT competency_id FROM competencies WHERE uid = $2 LIMIT 1),
                 NOW(), $3, 'SELF_ASSESSMENT', $4, $5)
         RETURNING event_id`,
        [l.student_id, l.competency_uid, l.self_rating, l.reflection_text, user.userId]
      );

      await client.query(
        `UPDATE self_assessment_links SET promoted = true, promoted_event_id = $1,
                promoted_at = NOW(), promoted_by = $2
         WHERE link_id = $3`,
        [event.rows[0].event_id, user.userId, id]
      );
      return { linkId: id, eventId: event.rows[0].event_id, promoted: true };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/classes/:id/response-rates', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `SELECT fr.feedback_type,
                COUNT(fr.request_id) AS total_requests,
                COUNT(fre.response_id) AS total_responses,
                CASE WHEN COUNT(fr.request_id) > 0
                     THEN ROUND(COUNT(fre.response_id)::numeric / COUNT(fr.request_id) * 100, 1)
                     ELSE 0 END AS response_rate_percent
         FROM feedback_requests fr
         LEFT JOIN feedback_responses fre ON fre.request_id = fr.request_id
         WHERE fr.class_id = $1
         GROUP BY fr.feedback_type`,
        [id]
      );
      return { classId: id, responseRates: result.rows };
    }, user.tenantId, user.userId, user.role);
  });
}
