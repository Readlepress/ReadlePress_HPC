import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  generatePortabilityPackage,
  importPortabilityPackage,
  getCrl,
  verifyPackageSignature,
} from '../services/portability.service';

export default async function portabilityRoutes(app: FastifyInstance) {
  app.post('/portability/generate', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const { studentId } = request.body as { studentId: string };
    const result = await generatePortabilityPackage(
      user.tenantId, user.userId, user.role, studentId
    );
    return reply.code(202).send(result);
  });

  app.post('/portability/import', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as { packageData: string; sourceSchoolId?: string };
    const result = await importPortabilityPackage(user.tenantId, user.userId, user.role, body);
    return reply.code(202).send(result);
  });

  // Public CRL endpoint — no auth required
  app.get('/portability/crl', async () => {
    const entries = await getCrl();
    return { entries };
  });

  app.post('/portability/verify', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const body = request.body as { packageHash: string; signature: string };
    return verifyPackageSignature(user.tenantId, user.userId, user.role, body);
  });
}
