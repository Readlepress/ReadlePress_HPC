import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { listCompetencies } from '../services/competency.service';

export default async function competencyRoutes(app: FastifyInstance) {
  app.get('/competencies', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { stageId } = request.query as { stageId?: string };
    const competencies = await listCompetencies(user.tenantId, user.userId, user.role, stageId);
    return { competencies };
  });
}
