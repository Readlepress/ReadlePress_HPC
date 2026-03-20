import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  computeAutoIndicators,
  getLatestAutoIndicators,
} from '../services/auto-sqaa.service';

export default async function autoSqaaRoutes(app: FastifyInstance) {
  app.post('/sqaa/auto-compute/:schoolId', { preHandler: [authenticate] }, async (request, reply) => {
    const { schoolId } = request.params as { schoolId: string };
    const user = getUser(request);
    const { academicYearId } = request.body as { academicYearId: string };

    if (!academicYearId) throw new Error('MISSING_ACADEMIC_YEAR_ID');

    const indicators = await computeAutoIndicators(
      user.tenantId, user.userId, user.role, schoolId, academicYearId
    );
    return reply.code(200).send({ schoolId, academicYearId, indicators });
  });

  app.get('/sqaa/auto-indicators/:schoolId', { preHandler: [authenticate] }, async (request) => {
    const { schoolId } = request.params as { schoolId: string };
    const user = getUser(request);
    const indicators = await getLatestAutoIndicators(
      user.tenantId, user.userId, user.role, schoolId
    );
    return { schoolId, indicators };
  });
}
