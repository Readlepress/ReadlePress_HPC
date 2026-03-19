import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  triggerCreditComputation,
  getCreditSummary,
  submitExternalCreditClaim,
} from '../services/credit.service';

export default async function creditRoutes(app: FastifyInstance) {
  app.post('/credit-computation/trigger', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const { studentId, academicYearId } = request.body as {
      studentId: string;
      academicYearId: string;
    };
    const result = await triggerCreditComputation(
      user.tenantId, user.userId, user.role, studentId, academicYearId
    );
    return reply.code(202).send(result);
  });

  app.get('/students/:id/credit-summary', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const entries = await getCreditSummary(user.tenantId, user.userId, user.role, id);
    return { entries };
  });

  app.post('/external-credit-claims', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as Parameters<typeof submitExternalCreditClaim>[3];
    const result = await submitExternalCreditClaim(
      user.tenantId, user.userId, user.role, body
    );
    return reply.code(201).send(result);
  });
}
