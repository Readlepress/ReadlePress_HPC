import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  generateExport,
  getExportJobStatus,
  getExportDocument,
  verifyExportDocument,
} from '../services/export.service';

export default async function exportRoutes(app: FastifyInstance) {
  app.post('/exports/generate', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof generateExport>[3];
    const result = await generateExport(user.tenantId, user.userId, user.role, body);
    return reply.code(202).send(result);
  });

  app.get('/exports/:id', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return getExportJobStatus(user.tenantId, user.userId, user.role, id);
  });

  app.get('/exports/:id/document', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return getExportDocument(user.tenantId, user.userId, user.role, id);
  });

  app.post('/exports/:id/verify', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as { documentHash: string; signature: string };
    return verifyExportDocument(user.tenantId, user.userId, user.role, id, body);
  });
}
