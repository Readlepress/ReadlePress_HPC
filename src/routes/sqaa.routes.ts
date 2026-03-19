import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  getSqaaScores,
  triggerSqaaComputation,
  listIndicatorDefinitions,
} from '../services/sqaa.service';

export default async function sqaaRoutes(app: FastifyInstance) {
  app.get('/schools/:id/sqaa-scores', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return getSqaaScores(user.tenantId, user.userId, user.role, id);
  });

  app.post('/sqaa-computation/trigger', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const { schoolId, academicYearId } = request.body as {
      schoolId: string;
      academicYearId: string;
    };
    const result = await triggerSqaaComputation(
      user.tenantId, user.userId, user.role, schoolId, academicYearId
    );
    return reply.code(202).send(result);
  });

  app.get('/sqaa-indicators', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const indicators = await listIndicatorDefinitions(user.tenantId, user.userId, user.role);
    return { indicators };
  });
}
