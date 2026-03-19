import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  logCpdActivity,
  getCpdSummary,
  logPeerObservation,
} from '../services/cpd.service';

export default async function cpdRoutes(app: FastifyInstance) {
  app.post('/cpd/activities', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof logCpdActivity>[3];
    const result = await logCpdActivity(user.tenantId, user.userId, user.role, body);
    return reply.code(201).send(result);
  });

  app.get('/teachers/:id/cpd-summary', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return getCpdSummary(user.tenantId, user.userId, user.role, id);
  });

  app.post('/peer-observations', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof logPeerObservation>[3];
    const result = await logPeerObservation(user.tenantId, user.userId, user.role, body);
    return reply.code(201).send(result);
  });
}
