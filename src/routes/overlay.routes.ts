import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { createOverlay, approveOverlay, getActiveOverlays } from '../services/overlay.service';

export default async function overlayRoutes(app: FastifyInstance) {
  app.post('/students/:id/overlays', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as Parameters<typeof createOverlay>[4];
    const result = await createOverlay(user.tenantId, user.userId, user.role, id, body);
    return reply.code(201).send(result);
  });

  app.post('/overlays/:id/approve', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { action, rejectionReason } = request.body as {
      action: 'APPROVED' | 'REJECTED';
      rejectionReason?: string;
    };
    return approveOverlay(user.tenantId, user.userId, user.role, id, action, rejectionReason);
  });

  app.get('/students/:id/overlays/active', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return { overlays: await getActiveOverlays(user.tenantId, user.userId, user.role, id) };
  });
}
