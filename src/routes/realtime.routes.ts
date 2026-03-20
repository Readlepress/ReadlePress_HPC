import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  createSession,
  getSession,
  broadcastAssessment,
  getDivergenceReport,
  finalizeSession,
  subscribe,
} from '../services/realtime.service';

export default async function realtimeRoutes(app: FastifyInstance) {
  app.post('/realtime/sessions', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      templateId: string;
      studentId: string;
      assessorIds: string[];
    };

    const result = createSession(body.templateId, body.studentId, body.assessorIds);
    return reply.code(201).send(result);
  });

  app.get('/realtime/sessions/:id', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const session = getSession(id);
    if (!session) throw new Error('SESSION_NOT_FOUND');
    return { session };
  });

  app.post('/realtime/sessions/:id/assess', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      dimensionId: string;
      selectedLevel: string;
      note?: string;
    };

    broadcastAssessment(id, user.userId, body.dimensionId, body.selectedLevel, body.note ?? null);
    return { status: 'broadcast_sent' };
  });

  app.post('/realtime/sessions/:id/finalize', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      consensusDecisions: Array<{
        dimensionId: string;
        descriptorLevelId: string;
        numericValue: number;
        assessorNote?: string;
      }>;
    };

    return finalizeSession(id, body.consensusDecisions, user.tenantId, user.userId, user.role);
  });

  app.get('/realtime/sessions/:id/divergence', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const report = getDivergenceReport(id);
    return { dimensions: report };
  });

  app.get('/realtime/sessions/:id/ws', { websocket: true }, (socket: import('ws').WebSocket, request) => {
    const url = request.url || '';
    const idMatch = url.match(/\/realtime\/sessions\/([^/]+)\/ws/);
    const sessionId = idMatch ? idMatch[1] : '';

    let unsubscribe: (() => void) | null = null;
    try {
      unsubscribe = subscribe(sessionId, (data) => {
        if (socket.readyState === socket.OPEN) {
          socket.send(JSON.stringify(data));
        }
      });

      socket.send(JSON.stringify({ type: 'CONNECTED', sessionId }));
    } catch (err) {
      socket.send(JSON.stringify({ type: 'ERROR', message: 'Session not found' }));
      socket.close();
      return;
    }

    socket.on('message', (raw: Buffer | string) => {
      try {
        const msg = JSON.parse(raw.toString());
        if (msg.type === 'ASSESS' && msg.assessorId && msg.dimensionId && msg.selectedLevel) {
          broadcastAssessment(sessionId, msg.assessorId, msg.dimensionId, msg.selectedLevel, msg.note ?? null);
        }
      } catch {
        // ignore malformed messages
      }
    });

    socket.on('close', () => {
      if (unsubscribe) unsubscribe();
    });
  });
}
