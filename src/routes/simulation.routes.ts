import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import {
  simulatePolicyChange,
  getSimulationById,
  listSimulationHistory,
} from '../services/policy-simulation.service';

export default async function simulationRoutes(app: FastifyInstance) {
  app.post('/simulations/policy', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      policyType: string;
      currentValue: number;
      proposedValue: number;
      affectedMetric: string;
      academicYearId?: string;
    };

    if (!body.policyType || body.currentValue === undefined || body.proposedValue === undefined) {
      throw new Error('MISSING_REQUIRED_FIELDS');
    }

    const result = await simulatePolicyChange(
      user.tenantId,
      user.userId,
      user.role,
      {
        policyType: body.policyType as Parameters<typeof simulatePolicyChange>[3]['policyType'],
        currentValue: body.currentValue,
        proposedValue: body.proposedValue,
        affectedMetric: body.affectedMetric,
        academicYearId: body.academicYearId,
      }
    );

    return reply.code(201).send(result);
  });

  app.get('/simulations/:id', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return getSimulationById(user.tenantId, user.userId, user.role, id);
  });

  app.get('/simulations/history', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { limit, offset } = request.query as { limit?: string; offset?: string };
    return listSimulationHistory(
      user.tenantId,
      user.userId,
      user.role,
      limit ? parseInt(limit, 10) : 50,
      offset ? parseInt(offset, 10) : 0
    );
  });
}
