import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { getLocalizedStrings } from '../services/localization.service';

export default async function localizationRoutes(app: FastifyInstance) {
  app.get('/localization/strings', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { language, prefix } = request.query as { language: string; prefix?: string };
    const strings = await getLocalizedStrings(user.tenantId, user.userId, user.role, language, prefix);
    return { strings };
  });
}
