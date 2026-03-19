import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  createOverrideRequest,
  approveOverrideRequest,
  listGovernanceAlerts,
  requestComplianceReconstruction,
} from '../services/governance.service';

export default async function governanceRoutes(app: FastifyInstance) {
  app.post('/override-requests', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof createOverrideRequest>[3];
    const result = await createOverrideRequest(user.tenantId, user.userId, user.role, body);
    return reply.code(201).send(result);
  });

  app.post('/override-requests/:id/approve', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as { decision: 'APPROVED' | 'REJECTED'; notes?: string };
    return approveOverrideRequest(user.tenantId, user.userId, user.role, id, body);
  });

  app.get('/governance-alerts', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const alerts = await listGovernanceAlerts(user.tenantId, user.userId, user.role);
    return { alerts };
  });

  app.post('/compliance-reconstruction', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as { entityType: string; entityId: string; reason: string };
    const result = await requestComplianceReconstruction(
      user.tenantId, user.userId, user.role, body
    );
    return reply.code(202).send(result);
  });
}
