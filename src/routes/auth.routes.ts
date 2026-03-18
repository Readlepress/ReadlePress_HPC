import { FastifyInstance } from 'fastify';
import { authenticateUser } from '../services/auth.service';

export default async function authRoutes(app: FastifyInstance) {
  app.post('/auth/login', async (request, reply) => {
    const { email, phone, password } = request.body as {
      email?: string;
      phone?: string;
      password: string;
    };

    if (!email && !phone) {
      return reply.code(400).send({ error: 'VALIDATION_ERROR', message: 'Email or phone required' });
    }

    try {
      const user = await authenticateUser(email, phone, password);
      const token = app.jwt.sign({
        userId: user.userId,
        tenantId: user.tenantId,
        role: user.role,
        email,
        phone,
      });

      return { token, user };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      if (message === 'INVALID_CREDENTIALS') {
        return reply.code(401).send({ error: 'INVALID_CREDENTIALS', message: 'Invalid email/phone or password' });
      }
      if (message === 'ACCOUNT_LOCKED') {
        return reply.code(423).send({ error: 'ACCOUNT_LOCKED', message: 'Account temporarily locked due to failed attempts' });
      }
      if (message === 'ACCOUNT_INACTIVE') {
        return reply.code(403).send({ error: 'ACCOUNT_INACTIVE', message: 'Account is not active' });
      }
      throw err;
    }
  });
}
