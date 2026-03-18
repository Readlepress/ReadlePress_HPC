import { withTransaction } from '../config/database';

export async function listCompetencies(
  tenantId: string,
  userId: string,
  userRole: string,
  stageId?: string
) {
  return withTransaction(async (client) => {
    const params: unknown[] = [];
    let whereClause = "c.status = 'ACTIVE'";

    if (stageId) {
      params.push(stageId);
      whereClause += ` AND c.stage_id = $${params.length}`;
    }

    const activationsFilter = `
      AND NOT EXISTS (
        SELECT 1 FROM competency_activations ca
        WHERE ca.competency_id = c.id AND ca.is_suppressed = TRUE
      )
    `;

    const result = await client.query(
      `SELECT c.id, c.uid, c.name, c.name_local, c.description,
              c.grade, c.subdomain, c.sequence_number,
              td.domain_code, td.name AS domain_name,
              ast.stage_code, ast.name AS stage_name
       FROM competencies c
       JOIN taxonomy_domains td ON td.id = c.domain_id
       JOIN academic_stages ast ON ast.id = c.stage_id
       WHERE ${whereClause} ${activationsFilter}
       ORDER BY ast.grade_range_start, td.display_order, c.sequence_number`,
      params
    );
    return result.rows;
  }, tenantId, userId, userRole);
}

export async function getCompetencyLineage(tenantId: string, userId: string, userRole: string, competencyId: string) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT cl.id, cl.lineage_type, cl.weight, cl.effective_from,
              cs.uid AS source_uid, cs.name AS source_name,
              ct.uid AS target_uid, ct.name AS target_name
       FROM competency_lineage cl
       JOIN competencies cs ON cs.id = cl.source_competency_id
       JOIN competencies ct ON ct.id = cl.target_competency_id
       WHERE cl.source_competency_id = $1 OR cl.target_competency_id = $1
       ORDER BY cl.effective_from DESC`,
      [competencyId]
    );
    return result.rows;
  }, tenantId, userId, userRole);
}
