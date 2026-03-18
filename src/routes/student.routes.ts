import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { listStudentsByClass, enrolStudent } from '../services/student.service';

export default async function studentRoutes(app: FastifyInstance) {
  app.get('/students', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const students = await listStudentsByClass(user.tenantId, user.userId, user.role);
    return { students };
  });

  app.post('/students/:id/enrolments', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const { classId, academicYearLabel, rollNumber } = request.body as {
      classId: string;
      academicYearLabel: string;
      rollNumber?: string;
    };
    const user = getUser(request);

    try {
      const result = await enrolStudent(
        user.tenantId, id, classId, academicYearLabel, rollNumber || null, user.userId, user.role
      );
      return reply.code(201).send(result);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      if (message === 'CONSENT_REQUIRED') {
        return reply.code(400).send({
          error: 'CONSENT_REQUIRED',
          message: 'Active EDUCATIONAL_RECORD consent required for enrolment',
        });
      }
      throw err;
    }
  });
}
