import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { listCompetencies } from '../services/competency.service';
import { withTransaction } from '../config/database';

export default async function competencyRoutes(app: FastifyInstance) {
  app.get('/competencies', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { stageId } = request.query as { stageId?: string };
    const competencies = await listCompetencies(user.tenantId, user.userId, user.role, stageId);
    return { competencies };
  });

  app.get('/taxonomy/bridge-readiness', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { stageCode } = request.query as { stageCode?: string };
    return withTransaction(async (client) => {
      const params: unknown[] = [];
      let where = '';
      if (stageCode) {
        where = 'WHERE ast.stage_code = $1';
        params.push(stageCode);
      }
      const result = await client.query(
        `SELECT ast.stage_code, ast.name AS stage_name,
                COUNT(c.competency_id) AS total_competencies,
                COUNT(c.competency_id) FILTER (WHERE c.bridge_ready = true) AS bridge_ready_count
         FROM academic_stages ast
         LEFT JOIN competencies c ON c.stage_code = ast.stage_code
         ${where}
         GROUP BY ast.stage_code, ast.name
         ORDER BY ast.grade_range_start`,
        params
      );
      return { stages: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/taxonomy/competencies/:uid/lineage', { preHandler: [authenticate] }, async (request) => {
    const { uid } = request.params as { uid: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const result = await client.query(
        `WITH RECURSIVE lineage AS (
           SELECT competency_id, uid, parent_uid, label, level, 0 AS depth
           FROM competencies WHERE uid = $1
           UNION ALL
           SELECT c.competency_id, c.uid, c.parent_uid, c.label, c.level, l.depth + 1
           FROM competencies c
           JOIN lineage l ON c.uid = l.parent_uid
         )
         SELECT * FROM lineage ORDER BY depth DESC`,
        [uid]
      );
      return { lineage: result.rows };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/taxonomy/versions', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      versionLabel: string;
      description?: string;
      basedOnVersionId?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO taxonomy_versions (version_label, description, based_on_version_id, status, created_by)
         VALUES ($1, $2, $3, 'DRAFT', $4)
         RETURNING version_id, version_label, description, status, created_at`,
        [body.versionLabel, body.description || null, body.basedOnVersionId || null, user.userId]
      );
      return reply.code(201).send({ version: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/taxonomy/proposals', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      versionId: string;
      changeType: string;
      competencyUid?: string;
      proposedData: Record<string, unknown>;
      justification: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO taxonomy_change_proposals (version_id, change_type, competency_uid,
                                                proposed_data, justification, status, proposed_by)
         VALUES ($1, $2, $3, $4, $5, 'PENDING', $6)
         RETURNING proposal_id, version_id, change_type, status, created_at`,
        [body.versionId, body.changeType, body.competencyUid || null,
         JSON.stringify(body.proposedData), body.justification, user.userId]
      );
      return reply.code(201).send({ proposal: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });
}
