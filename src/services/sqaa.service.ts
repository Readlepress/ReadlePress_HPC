import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function getSqaaScores(
  tenantId: string,
  userId: string,
  userRole: string,
  schoolId: string
) {
  return withTransaction(async (client) => {
    const compositeResult = await client.query(
      `SELECT sc.id, sc.academic_year_id, sc.composite_score, sc.tier, sc.created_at
       FROM sqaa_composite_scores sc
       WHERE sc.school_id = $1
       ORDER BY sc.created_at DESC`,
      [schoolId]
    );

    const domainResult = await client.query(
      `SELECT sd.id, sd.academic_year_id, sd.domain_name, sd.weighted_score,
              sd.indicator_count, sd.created_at
       FROM sqaa_domain_scores sd
       WHERE sd.school_id = $1
       ORDER BY sd.domain_name`,
      [schoolId]
    );

    const indicatorResult = await client.query(
      `SELECT siv.id, siv.indicator_id, siv.academic_year_id,
              siv.numeric_value, siv.performance_level, siv.is_stale,
              sid.indicator_code, sid.name AS indicator_name
       FROM sqaa_indicator_values siv
       JOIN sqaa_indicator_definitions sid ON sid.id = siv.indicator_id
       WHERE siv.school_id = $1
       ORDER BY sid.indicator_code`,
      [schoolId]
    );

    return {
      composite: compositeResult.rows,
      domains: domainResult.rows,
      indicators: indicatorResult.rows,
    };
  }, tenantId, userId, userRole);
}

export async function triggerSqaaComputation(
  tenantId: string,
  userId: string,
  userRole: string,
  schoolId: string,
  academicYearId: string
) {
  return withTransaction(async (client) => {
    const idempotencyKey = Buffer.from(
      `SQAA_COMP${schoolId}${academicYearId}`
    ).toString('hex');

    const result = await client.query(
      `INSERT INTO sqaa_computation_jobs
         (tenant_id, school_id, academic_year_id, idempotency_key, status)
       VALUES ($1, $2, $3, $4, 'PENDING')
       ON CONFLICT (idempotency_key) DO NOTHING
       RETURNING id`,
      [tenantId, schoolId, academicYearId, idempotencyKey]
    );

    const jobId = result.rows[0]?.id;

    await insertAuditLog({
      tenantId,
      eventType: 'SQAA_COMPUTATION.TRIGGERED',
      entityType: 'SQAA_COMPUTATION_JOBS',
      entityId: jobId || 'DUPLICATE',
      performedBy: userId,
      afterState: { schoolId, academicYearId },
    }, client);

    return { jobId, status: jobId ? 'PENDING' : 'ALREADY_QUEUED' };
  }, tenantId, userId, userRole);
}

export async function listIndicatorDefinitions(
  tenantId: string,
  userId: string,
  userRole: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT sid.id, sid.framework_id, sid.indicator_code, sid.name,
              sid.computation_type, sid.data_source_layer, sid.weight,
              sid.performance_levels, sid.max_staleness_days,
              sf.name AS framework_name
       FROM sqaa_indicator_definitions sid
       JOIN sqaa_frameworks sf ON sf.id = sid.framework_id
       ORDER BY sid.indicator_code`
    );
    return result.rows;
  }, tenantId, userId, userRole);
}
