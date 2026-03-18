import { withTransaction, query } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function getMasterySummary(
  tenantId: string,
  userId: string,
  userRole: string,
  studentId: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT ma.id, ma.competency_id, ma.current_ewm, ma.event_count,
              ma.last_event_at, ma.trend_direction, ma.trend_slope,
              ma.confidence_score, ma.pending_draft_count,
              c.uid AS competency_uid, c.name AS competency_name,
              td.domain_code, td.name AS domain_name
       FROM mastery_aggregates ma
       JOIN competencies c ON c.id = ma.competency_id
       JOIN taxonomy_domains td ON td.id = c.domain_id
       WHERE ma.student_id = $1
       ORDER BY td.display_order, c.sequence_number`,
      [studentId]
    );
    return result.rows;
  }, tenantId, userId, userRole);
}

export async function verifyMasteryEvent(
  tenantId: string,
  userId: string,
  userRole: string,
  masteryEventId: string
) {
  return withTransaction(async (client) => {
    const eventResult = await client.query(
      'SELECT * FROM mastery_events WHERE id = $1 AND event_status = $2',
      [masteryEventId, 'DRAFT']
    );

    if (eventResult.rows.length === 0) {
      throw new Error('EVENT_NOT_FOUND_OR_NOT_DRAFT');
    }

    await client.query(
      "UPDATE mastery_events SET event_status = 'ACTIVE' WHERE id = $1",
      [masteryEventId]
    );

    const event = eventResult.rows[0];

    // Queue aggregation job
    const idempotencyKey = Buffer.from(
      `MASTERY_AGG${event.student_id}${event.competency_id}${event.academic_year_id || ''}`
    ).toString('hex');

    await client.query(
      `INSERT INTO mastery_aggregation_jobs
         (tenant_id, student_id, competency_id, academic_year_id, idempotency_key, status)
       VALUES ($1, $2, $3, $4, $5, 'PENDING')
       ON CONFLICT (idempotency_key) DO NOTHING`,
      [tenantId, event.student_id, event.competency_id, event.academic_year_id, idempotencyKey]
    );

    await insertAuditLog({
      tenantId,
      eventType: 'MASTERY_EVENT.VERIFIED',
      entityType: 'MASTERY_EVENTS',
      entityId: masteryEventId,
      performedBy: userId,
    }, client);

    return { status: 'ACTIVE' };
  }, tenantId, userId, userRole);
}

export async function runAggregation(
  tenantId: string,
  studentId: string,
  competencyId: string,
  academicYearId?: string
) {
  const ewmResult = await query(
    'SELECT compute_ewm($1, $2, $3, $4) AS ewm',
    [tenantId, studentId, competencyId, academicYearId || null]
  );

  const ewm = ewmResult.rows[0].ewm;

  const eventCount = await query(
    `SELECT COUNT(*) as count, MAX(observed_at) as last_event_at
     FROM mastery_events
     WHERE tenant_id = $1 AND student_id = $2 AND competency_id = $3
       AND event_status = 'ACTIVE'
       AND ($4::uuid IS NULL OR academic_year_id = $4)`,
    [tenantId, studentId, competencyId, academicYearId || null]
  );

  const count = parseInt(eventCount.rows[0].count);

  let trendDirection = 'INSUFFICIENT_DATA';
  if (count >= 3) {
    const recentEvents = await query(
      `SELECT numeric_value, observed_at
       FROM mastery_events
       WHERE tenant_id = $1 AND student_id = $2 AND competency_id = $3
         AND event_status = 'ACTIVE'
       ORDER BY observed_at DESC LIMIT 5`,
      [tenantId, studentId, competencyId]
    );

    const values = recentEvents.rows.map((r: { numeric_value: string }) => parseFloat(r.numeric_value));
    const avgRecent = values.slice(0, 2).reduce((a: number, b: number) => a + b, 0) / Math.min(2, values.length);
    const avgOlder = values.slice(2).reduce((a: number, b: number) => a + b, 0) / Math.max(1, values.length - 2);

    if (avgRecent > avgOlder + 0.05) trendDirection = 'IMPROVING';
    else if (avgRecent < avgOlder - 0.05) trendDirection = 'DECLINING';
    else trendDirection = 'STABLE';
  }

  const confidence = Math.min(1.0, count / 10);

  await query(
    `INSERT INTO mastery_aggregates
       (tenant_id, student_id, competency_id, academic_year_id, current_ewm,
        event_count, last_event_at, trend_direction, confidence_score, last_aggregated_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, now())
     ON CONFLICT (tenant_id, student_id, competency_id, academic_year_id)
     DO UPDATE SET
       current_ewm = EXCLUDED.current_ewm,
       event_count = EXCLUDED.event_count,
       last_event_at = EXCLUDED.last_event_at,
       trend_direction = EXCLUDED.trend_direction,
       confidence_score = EXCLUDED.confidence_score,
       last_aggregated_at = now(),
       updated_at = now()`,
    [tenantId, studentId, competencyId, academicYearId || null, ewm, count,
     eventCount.rows[0].last_event_at, trendDirection, confidence]
  );

  return { ewm, eventCount: count, trendDirection, confidence };
}
