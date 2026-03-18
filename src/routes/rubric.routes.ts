import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { submitRubricCompletion, getAssessmentContext } from '../services/rubric.service';

export default async function rubricRoutes(app: FastifyInstance) {
  app.get('/students/:id/assessment-context', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return getAssessmentContext(user.tenantId, user.userId, user.role, id);
  });

  app.post('/rubric-completions', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof submitRubricCompletion>[3];
    const result = await submitRubricCompletion(user.tenantId, user.userId, user.role, body);
    return reply.code(201).send(result);
  });
}
