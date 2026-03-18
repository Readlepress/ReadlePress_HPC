import { FastifyRequest, FastifyReply } from 'fastify';
import { JwtPayload } from '../types';

export async function authenticate(request: FastifyRequest, reply: FastifyReply): Promise<void> {
  try {
    const token = request.headers.authorization?.replace('Bearer ', '');
    if (!token) {
      reply.code(401).send({ error: 'UNAUTHORIZED', message: 'Missing authorization token' });
      return;
    }
    await request.jwtVerify();
  } catch (err) {
    reply.code(401).send({ error: 'UNAUTHORIZED', message: 'Invalid or expired token' });
  }
}

export function getUser(request: FastifyRequest): JwtPayload {
  return request.user as unknown as JwtPayload;
}

export function requireRole(...roles: string[]) {
  return async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    const user = getUser(request);
    if (!user) {
      reply.code(401).send({ error: 'UNAUTHORIZED', message: 'Not authenticated' });
      return;
    }
    if (!roles.includes(user.role)) {
      reply.code(403).send({
        error: 'FORBIDDEN',
        message: `Role ${user.role} does not have access. Required: ${roles.join(', ')}`,
      });
    }
  };
}
