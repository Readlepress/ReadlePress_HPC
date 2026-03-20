import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { getAssessmentRecommendations } from '../services/recommendation.service';

export default async function recommendationRoutes(app: FastifyInstance) {
  app.get('/recommendations/assessments', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { classId } = request.query as { classId?: string };

    const recommendations = await getAssessmentRecommendations(
      user.tenantId,
      user.userId,
      user.userId,
      user.role,
      classId
    );

    return { recommendations };
  });
}
