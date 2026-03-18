import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { getMasterySummary, verifyMasteryEvent } from '../services/mastery.service';

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
}
