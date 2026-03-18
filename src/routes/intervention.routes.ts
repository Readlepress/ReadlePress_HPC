import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { getInterventionAlerts, convertAlertToPlan } from '../services/intervention.service';

export default async function interventionRoutes(app: FastifyInstance) {
  app.get('/intervention-alerts', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { classId } = request.query as { classId?: string };
    const alerts = await getInterventionAlerts(user.tenantId, user.userId, user.role, classId);
    return { alerts };
  });

  app.post('/intervention-alerts/:id/convert', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      title: string;
      description?: string;
      sensitivityLevel: string;
      objectives?: unknown[];
      nextReviewDate?: string;
    };
    const result = await convertAlertToPlan(user.tenantId, user.userId, user.role, id, body);
    return reply.code(201).send(result);
  });
}
