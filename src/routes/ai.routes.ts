import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  generateAiDraft,
  promoteAiDraft,
  listPendingAiDrafts,
} from '../services/ai.service';

export default async function aiRoutes(app: FastifyInstance) {
  app.post('/ai/generate', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof generateAiDraft>[3];
    const result = await generateAiDraft(user.tenantId, user.userId, user.role, body);
    return reply.code(202).send(result);
  });

  app.post('/ai/drafts/:id/promote', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return promoteAiDraft(user.tenantId, user.userId, user.role, id);
  });

  app.get('/ai/drafts', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const drafts = await listPendingAiDrafts(user.tenantId, user.userId, user.role);
    return { drafts };
  });
}
