import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { syncOfflineCapture } from '../services/capture.service';

export default async function captureRoutes(app: FastifyInstance) {
  app.post('/capture/sync', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { teacherId, drafts } = request.body as {
      teacherId: string;
      drafts: Array<{
        localId: string;
        studentId: string;
        competencyId: string;
        observedAt: string;
        recordedAt: string;
        timestampSource: string;
        timestampConfidence: string;
        numericValue: number;
        descriptorLevelId?: string;
        observationNote?: string;
        evidenceLocalIds?: string[];
        sourceType?: string;
        deviceId?: string;
      }>;
    };

    const result = await syncOfflineCapture(user.tenantId, teacherId, user.userId, user.role, drafts);
    return result;
  });
}
