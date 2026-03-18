import { FastifyRequest, FastifyReply } from 'fastify';
import { getClient, setTenantContext } from '../config/database';
import { getUser } from './auth';

export async function setTenantMiddleware(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  const user = getUser(request);
  if (!user) {
    return;
  }

  const { tenantId, userId, role } = user;
  if (!tenantId || !userId || !role) {
    reply.code(400).send({
      error: 'INVALID_CONTEXT',
      message: 'Missing tenant context in token',
    });
  }
}
