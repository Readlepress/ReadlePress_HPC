import { query } from '../config/database';

interface TriggerConditions {
  metric: string;
  operator: string;
  threshold: number;
  window_days?: number;
}

export async function evaluateTriggerRules(tenantId: string, ruleId: string): Promise<void> {
  const ruleResult = await query(
    `SELECT * FROM intervention_trigger_rules WHERE id = $1 AND tenant_id = $2 AND is_active = TRUE`,
    [ruleId, tenantId]
  );

  if (ruleResult.rows.length === 0) return;
  const rule = ruleResult.rows[0];
  const conditions: TriggerConditions = rule.conditions;

  const runResult = await query(
    `INSERT INTO intervention_trigger_runs (tenant_id, rule_id, students_evaluated, alerts_generated, alerts_suppressed, stale_aggregates_skipped)
     VALUES ($1, $2, 0, 0, 0, 0) RETURNING id`,
    [tenantId, ruleId]
  );
  const runId = runResult.rows[0].id;

  let studentsEvaluated = 0;
  let alertsGenerated = 0;
  let alertsSuppressed = 0;
  let staleSkipped = 0;

  const startTime = Date.now();

  // Get students to evaluate based on rule type
  let studentQuery: string;
  const queryParams: unknown[] = [tenantId];

  if (rule.rule_type === 'MASTERY_DECLINE') {
    studentQuery = `
      SELECT DISTINCT ma.student_id, ma.current_ewm, ma.trend_direction,
             ma.last_aggregated_at, se.class_id
      FROM mastery_aggregates ma
      JOIN student_enrolments se ON se.student_id = ma.student_id AND se.status = 'ACTIVE'
      WHERE ma.tenant_id = $1
        AND ma.trend_direction = 'DECLINING'
        AND ma.current_ewm < $2
    `;
    queryParams.push(conditions.threshold);
  } else if (rule.rule_type === 'ENGAGEMENT_LOW') {
    studentQuery = `
      SELECT DISTINCT ma.student_id, ma.current_ewm, ma.event_count,
             ma.last_aggregated_at, se.class_id
      FROM mastery_aggregates ma
      JOIN student_enrolments se ON se.student_id = ma.student_id AND se.status = 'ACTIVE'
      WHERE ma.tenant_id = $1
        AND ma.event_count < $2
    `;
    queryParams.push(conditions.threshold);
  } else {
    // CUSTOM and ATTENDANCE_DROP: general query on aggregates below threshold
    studentQuery = `
      SELECT DISTINCT ma.student_id, ma.current_ewm,
             ma.last_aggregated_at, se.class_id
      FROM mastery_aggregates ma
      JOIN student_enrolments se ON se.student_id = ma.student_id AND se.status = 'ACTIVE'
      WHERE ma.tenant_id = $1
        AND ma.confidence_score >= 0.3
        AND ma.current_ewm < $2
    `;
    queryParams.push(conditions.threshold);
  }

  const students = await query(studentQuery, queryParams);

  for (const student of students.rows) {
    studentsEvaluated++;

    // Stale aggregate check
    if (student.last_aggregated_at) {
      const hoursAgo = (Date.now() - new Date(student.last_aggregated_at).getTime()) / (1000 * 60 * 60);
      if (hoursAgo > rule.stale_threshold_hours) {
        staleSkipped++;
        continue;
      }
    }

    // Suppress if open intervention already exists for this student + sensitivity level
    if (rule.suppress_if_open) {
      const existing = await query(
        `SELECT 1 FROM intervention_alerts ia
         WHERE ia.tenant_id = $1 AND ia.student_id = $2
           AND ia.sensitivity_level = $3 AND ia.status IN ('OPEN', 'ACKNOWLEDGED')
         UNION ALL
         SELECT 1 FROM intervention_plans ip
         WHERE ip.tenant_id = $1 AND ip.student_id = $2
           AND ip.sensitivity_level = $3 AND ip.status IN ('ACTIVE', 'DRAFT')
         LIMIT 1`,
        [tenantId, student.student_id, rule.sensitivity_level]
      );

      if (existing.rows.length > 0) {
        alertsSuppressed++;
        continue;
      }
    }

    // Generate alert
    await query(
      `INSERT INTO intervention_alerts
         (tenant_id, trigger_rule_id, trigger_run_id, student_id, class_id,
          sensitivity_level, alert_data)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [
        tenantId, ruleId, runId, student.student_id, student.class_id,
        rule.sensitivity_level,
        JSON.stringify({
          ruleType: rule.rule_type,
          currentEwm: student.current_ewm,
          threshold: conditions.threshold,
          trendDirection: student.trend_direction,
        }),
      ]
    );

    alertsGenerated++;
  }

  const executionTimeMs = Date.now() - startTime;

  await query(
    `UPDATE intervention_trigger_runs
     SET students_evaluated = $2, alerts_generated = $3, alerts_suppressed = $4,
         stale_aggregates_skipped = $5, execution_time_ms = $6,
         details = $7::jsonb
     WHERE id = $1`,
    [
      runId, studentsEvaluated, alertsGenerated, alertsSuppressed,
      staleSkipped, executionTimeMs,
      JSON.stringify({ ruleType: rule.rule_type, conditions }),
    ]
  );
}
