import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { query, withTransaction } from '../config/database';

export default async function uiSchemaRoutes(app: FastifyInstance) {
  app.get('/ui-schema', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);

    const stages = await withTransaction(async (client) => {
      const result = await client.query(
        `SELECT stage_code, name, grade_range_start, grade_range_end,
                display_mode, show_numbers, descriptor_style, ui_schema
         FROM academic_stages
         ORDER BY grade_range_start`
      );
      return result.rows;
    }, user.tenantId, user.userId, user.role);

    return {
      stages: stages.map((s: Record<string, unknown>) => ({
        code: s.stage_code,
        name: s.name,
        gradeRange: { start: s.grade_range_start, end: s.grade_range_end },
        display: {
          mode: s.display_mode,
          showNumbers: s.show_numbers,
          descriptorStyle: s.descriptor_style,
        },
        uiSchema: s.ui_schema,
      })),
    };
  });
}
