import { FastifyInstance } from 'fastify';
import { authenticate } from '../middleware/auth';
import {
  classifyEvidence,
  detectHandwriting,
  compareProgressionPhotos,
  assessClassroomEnvironment,
} from '../services/vision.service';

export default async function visionRoutes(app: FastifyInstance) {
  app.post('/vision/classify', { preHandler: [authenticate] }, async (request) => {
    const body = request.body as { imageBase64?: string };
    const buffer = body.imageBase64 ? Buffer.from(body.imageBase64, 'base64') : Buffer.alloc(0);
    return classifyEvidence(buffer);
  });

  app.post('/vision/detect-handwriting', { preHandler: [authenticate] }, async (request) => {
    const body = request.body as { imageBase64?: string };
    const buffer = body.imageBase64 ? Buffer.from(body.imageBase64, 'base64') : Buffer.alloc(0);
    return detectHandwriting(buffer);
  });

  app.post('/vision/compare-progression', { preHandler: [authenticate] }, async (request) => {
    const body = request.body as { imageBase64_1?: string; imageBase64_2?: string };
    const buffer1 = body.imageBase64_1 ? Buffer.from(body.imageBase64_1, 'base64') : Buffer.alloc(0);
    const buffer2 = body.imageBase64_2 ? Buffer.from(body.imageBase64_2, 'base64') : Buffer.alloc(0);
    return compareProgressionPhotos(buffer1, buffer2);
  });

  app.post('/vision/assess-classroom', { preHandler: [authenticate] }, async (request) => {
    const body = request.body as { imageBase64?: string };
    const buffer = body.imageBase64 ? Buffer.from(body.imageBase64, 'base64') : Buffer.alloc(0);
    return assessClassroomEnvironment(buffer);
  });
}
