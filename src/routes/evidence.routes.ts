import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { uploadEvidence, getEvidence } from '../services/evidence.service';

export default async function evidenceRoutes(app: FastifyInstance) {
  app.post('/evidence', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      storageProviderId: string;
      contentRef: string;
      contentType: string;
      mimeType: string;
      fileSizeBytes: number;
      originalFilename: string;
      contentHash: string;
      trustLevel: string;
      classification?: string;
    };

    const result = await uploadEvidence(user.tenantId, user.userId, user.role, body as Parameters<typeof uploadEvidence>[3]);
    return reply.code(201).send(result);
  });

  app.get('/evidence/:id', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);

    try {
      const evidence = await getEvidence(user.tenantId, user.userId, user.role, id);
      return evidence;
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      if (message === 'EVIDENCE_READ_RESTRICTED_REQUIRED') {
        return reply.code(403).send({
          error: 'FORBIDDEN',
          message: 'EVIDENCE:READ_RESTRICTED permission required',
        });
      }
      throw err;
    }
  });
}
