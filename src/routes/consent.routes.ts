import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { initiateConsent, verifyConsent } from '../services/consent.service';

export default async function consentRoutes(app: FastifyInstance) {
  app.post('/consent/initiate', { preHandler: [authenticate] }, async (request, reply) => {
    const { phone, purpose } = request.body as { phone: string; purpose: string };
    const user = getUser(request);

    try {
      const result = await initiateConsent(user.tenantId, phone, purpose, user.userId);
      return result;
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      if (message === 'OTP_COOLDOWN_ACTIVE') {
        return reply.code(429).send({ error: 'OTP_COOLDOWN', message: 'Please wait before requesting another OTP' });
      }
      throw err;
    }
  });

  app.post('/consent/verify', { preHandler: [authenticate] }, async (request, reply) => {
    const { phone, otp, purposes, studentId, policyVersionId } = request.body as {
      phone: string;
      otp: string;
      purposes: string[];
      studentId: string;
      policyVersionId?: string;
    };
    const user = getUser(request);

    try {
      const result = await verifyConsent(
        user.tenantId, phone, otp, purposes, studentId, user.userId, policyVersionId
      );
      return result;
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      if (message === 'INVALID_OTP') {
        return reply.code(400).send({ error: 'INVALID_OTP', message: 'Invalid OTP' });
      }
      if (message === 'MAX_OTP_ATTEMPTS_EXCEEDED') {
        return reply.code(429).send({ error: 'MAX_ATTEMPTS', message: 'Maximum OTP attempts exceeded' });
      }
      throw err;
    }
  });
}
