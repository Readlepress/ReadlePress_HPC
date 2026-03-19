import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  registerPartner,
  logEngagementSession,
  listPartners,
  getEngagementAggregates,
} from '../services/community.service';

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
}
