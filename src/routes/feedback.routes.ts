import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { dispatchFeedbackRequests, submitFeedbackResponse, getModerationQueue } from '../services/feedback.service';

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
}
