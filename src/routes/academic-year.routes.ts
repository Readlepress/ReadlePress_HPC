import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { listAcademicYears, initiateYearClose } from '../services/academic-year.service';

export default async function academicYearRoutes(app: FastifyInstance) {
  app.get('/academic-years', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { schoolId } = request.query as { schoolId?: string };
    const years = await listAcademicYears(user.tenantId, user.userId, user.role, schoolId);
    return { academicYears: years };
  });

  app.post('/academic-years/:id/close', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);

    try {
      const result = await initiateYearClose(user.tenantId, id, user.userId, user.role);
      if (result.status === 'BLOCKED') {
        return reply.code(409).send({
          error: 'YEAR_CLOSE_BLOCKED',
          ...result,
        });
      }
      return result;
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      if (message === 'YEAR_NOT_IN_REVIEW') {
        return reply.code(400).send({
          error: 'INVALID_STATE',
          message: 'Academic year must be in REVIEW status to close',
        });
      }
      throw err;
    }
  });
}
