import { withTransaction } from '../config/database';
import { PoolClient } from 'pg';

type PerformanceLevel = 'EXCELLENT' | 'GOOD' | 'SATISFACTORY' | 'NEEDS_IMPROVEMENT' | 'CRITICAL';

interface IndicatorResult {
  indicatorCode: string;
  computedValue: number;
  performanceLevel: PerformanceLevel;
  dataTimestamp: string;
  staleness: number;
}

function classifyPerformance(value: number): PerformanceLevel {
  if (value >= 0.9) return 'EXCELLENT';
  if (value >= 0.75) return 'GOOD';
  if (value >= 0.5) return 'SATISFACTORY';
  if (value >= 0.25) return 'NEEDS_IMPROVEMENT';
  return 'CRITICAL';
}

function computeStaleness(timestamp: Date): number {
  return Math.floor((Date.now() - timestamp.getTime()) / (1000 * 60 * 60));
}

async function computeAssessmentCoverage(
  client: PoolClient, schoolId: string, academicYearId: string
): Promise<IndicatorResult> {
  const result = await client.query(
    `SELECT
       COUNT(DISTINCT CASE WHEN me.event_count >= 3 THEN me.student_id END) AS covered,
       COUNT(DISTINCT sp.id) AS total
     FROM student_profiles sp
     LEFT JOIN (
       SELECT student_id, COUNT(*) AS event_count
       FROM mastery_events
       WHERE school_id = $1 AND academic_year_id = $2 AND status = 'ACTIVE'
       GROUP BY student_id
     ) me ON me.student_id = sp.id
     WHERE sp.school_id = $1`,
    [schoolId, academicYearId]
  );

  const covered = parseInt(result.rows[0]?.covered || '0', 10);
  const total = parseInt(result.rows[0]?.total || '0', 10);
  const value = total > 0 ? covered / total : 0;

  return {
    indicatorCode: 'ASSESSMENT_COVERAGE',
    computedValue: Math.round(value * 10000) / 10000,
    performanceLevel: classifyPerformance(value),
    dataTimestamp: new Date().toISOString(),
    staleness: 0,
  };
}

async function computeEvidenceDensity(
  client: PoolClient, schoolId: string, academicYearId: string
): Promise<IndicatorResult> {
  const result = await client.query(
    `SELECT AVG(ev_count) AS avg_density FROM (
       SELECT me.id, COUNT(er.id) AS ev_count
       FROM mastery_events me
       LEFT JOIN evidence_records er ON er.id = ANY(
         SELECT unnest(evidence_ids) FROM mastery_event_evidence WHERE mastery_event_id = me.id
       )
       WHERE me.school_id = $1 AND me.academic_year_id = $2
       GROUP BY me.id
     ) sub`,
    [schoolId, academicYearId]
  );

  const avgDensity = parseFloat(result.rows[0]?.avg_density || '0');
  const normalized = Math.min(1, avgDensity / 5);

  return {
    indicatorCode: 'EVIDENCE_DENSITY',
    computedValue: Math.round(avgDensity * 100) / 100,
    performanceLevel: classifyPerformance(normalized),
    dataTimestamp: new Date().toISOString(),
    staleness: 0,
  };
}

async function computeInterventionClosureRate(
  client: PoolClient, schoolId: string, academicYearId: string
): Promise<IndicatorResult> {
  const result = await client.query(
    `SELECT
       COUNT(*) FILTER (WHERE ip.status = 'CLOSED' AND ip.outcome_evidence_id IS NOT NULL) AS closed_with_evidence,
       COUNT(*) AS total
     FROM intervention_plans ip
     WHERE ip.school_id = $1 AND ip.academic_year_id = $2`,
    [schoolId, academicYearId]
  );

  const closed = parseInt(result.rows[0]?.closed_with_evidence || '0', 10);
  const total = parseInt(result.rows[0]?.total || '0', 10);
  const value = total > 0 ? closed / total : 0;

  return {
    indicatorCode: 'INTERVENTION_CLOSURE_RATE',
    computedValue: Math.round(value * 10000) / 10000,
    performanceLevel: classifyPerformance(value),
    dataTimestamp: new Date().toISOString(),
    staleness: 0,
  };
}

async function computeCpdCompliance(
  client: PoolClient, schoolId: string, _academicYearId: string
): Promise<IndicatorResult> {
  const result = await client.query(
    `SELECT
       COUNT(*) FILTER (WHERE total_hours >= 50) AS compliant,
       COUNT(*) AS total
     FROM (
       SELECT cl.teacher_id, SUM(cl.hours) AS total_hours
       FROM cpd_log cl
       JOIN users u ON u.id = cl.teacher_id
       WHERE u.school_id = $1
       GROUP BY cl.teacher_id
     ) sub`,
    [schoolId]
  );

  const compliant = parseInt(result.rows[0]?.compliant || '0', 10);
  const total = parseInt(result.rows[0]?.total || '0', 10);
  const value = total > 0 ? compliant / total : 0;

  return {
    indicatorCode: 'CPD_COMPLIANCE',
    computedValue: Math.round(value * 10000) / 10000,
    performanceLevel: classifyPerformance(value),
    dataTimestamp: new Date().toISOString(),
    staleness: 0,
  };
}

async function computePeerAssessmentResponseRate(
  client: PoolClient, schoolId: string, academicYearId: string
): Promise<IndicatorResult> {
  const result = await client.query(
    `SELECT
       COUNT(*) FILTER (WHERE fr.status = 'COMPLETED') AS completed,
       COUNT(*) AS total
     FROM feedback_requests fr
     WHERE fr.feedback_type = 'PEER_ASSESSMENT'
       AND fr.school_id = $1 AND fr.academic_year_id = $2`,
    [schoolId, academicYearId]
  );

  const completed = parseInt(result.rows[0]?.completed || '0', 10);
  const total = parseInt(result.rows[0]?.total || '0', 10);
  const value = total > 0 ? completed / total : 0;

  return {
    indicatorCode: 'PEER_ASSESSMENT_RESPONSE_RATE',
    computedValue: Math.round(value * 10000) / 10000,
    performanceLevel: classifyPerformance(value),
    dataTimestamp: new Date().toISOString(),
    staleness: 0,
  };
}

async function computeHpcExportCompletion(
  client: PoolClient, schoolId: string, academicYearId: string
): Promise<IndicatorResult> {
  const result = await client.query(
    `SELECT
       COUNT(DISTINCT edr.student_id) AS exported,
       (SELECT COUNT(*) FROM student_profiles sp WHERE sp.school_id = $1) AS total
     FROM export_document_records edr
     WHERE edr.school_id = $1 AND edr.academic_year_id = $2`,
    [schoolId, academicYearId]
  );

  const exported = parseInt(result.rows[0]?.exported || '0', 10);
  const total = parseInt(result.rows[0]?.total || '0', 10);
  const value = total > 0 ? exported / total : 0;

  return {
    indicatorCode: 'HPC_EXPORT_COMPLETION_RATE',
    computedValue: Math.round(value * 10000) / 10000,
    performanceLevel: classifyPerformance(value),
    dataTimestamp: new Date().toISOString(),
    staleness: 0,
  };
}

async function computeGovernanceOverrideRate(
  client: PoolClient, schoolId: string, academicYearId: string
): Promise<IndicatorResult> {
  const result = await client.query(
    `SELECT
       (SELECT COUNT(*) FROM override_requests orq
        WHERE orq.school_id = $1 AND orq.academic_year_id = $2) AS overrides,
       (SELECT COUNT(*) FROM mastery_events me
        WHERE me.school_id = $1 AND me.academic_year_id = $2 AND me.verified = TRUE) AS verified
    `,
    [schoolId, academicYearId]
  );

  const overrides = parseInt(result.rows[0]?.overrides || '0', 10);
  const verified = parseInt(result.rows[0]?.verified || '0', 10);
  const denominator = Math.max(1, verified / 100);
  const rate = overrides / denominator;
  const normalized = Math.max(0, 1 - Math.min(1, rate / 10));

  return {
    indicatorCode: 'GOVERNANCE_OVERRIDE_RATE',
    computedValue: Math.round(rate * 100) / 100,
    performanceLevel: classifyPerformance(normalized),
    dataTimestamp: new Date().toISOString(),
    staleness: 0,
  };
}

async function computeAiAcceptanceQuality(
  client: PoolClient, schoolId: string, _academicYearId: string
): Promise<IndicatorResult> {
  const result = await client.query(
    `SELECT AVG(agl.edit_distance) AS avg_edit_distance
     FROM ai_generation_log agl
     WHERE agl.human_decision = 'EDITED_THEN_PROMOTED'
       AND agl.school_id = $1`,
    [schoolId]
  );

  const avgEditDistance = parseFloat(result.rows[0]?.avg_edit_distance || '0');
  const normalized = Math.max(0, 1 - Math.min(1, avgEditDistance / 100));

  return {
    indicatorCode: 'AI_ACCEPTANCE_QUALITY',
    computedValue: Math.round(avgEditDistance * 100) / 100,
    performanceLevel: classifyPerformance(normalized),
    dataTimestamp: new Date().toISOString(),
    staleness: 0,
  };
}

async function computeInclusionOverlayTimeliness(
  client: PoolClient, schoolId: string, _academicYearId: string
): Promise<IndicatorResult> {
  const result = await client.query(
    `SELECT
       COUNT(*) FILTER (WHERE io.approved_at IS NOT NULL
         AND io.approved_at <= io.created_at + INTERVAL '14 days') AS timely,
       COUNT(*) AS total
     FROM inclusion_overlays io
     WHERE io.school_id = $1`,
    [schoolId]
  );

  const timely = parseInt(result.rows[0]?.timely || '0', 10);
  const total = parseInt(result.rows[0]?.total || '0', 10);
  const value = total > 0 ? timely / total : 0;

  return {
    indicatorCode: 'INCLUSION_OVERLAY_TIMELINESS',
    computedValue: Math.round(value * 10000) / 10000,
    performanceLevel: classifyPerformance(value),
    dataTimestamp: new Date().toISOString(),
    staleness: 0,
  };
}

export async function computeAutoIndicators(
  tenantId: string,
  userId: string,
  userRole: string,
  schoolId: string,
  academicYearId: string
): Promise<IndicatorResult[]> {
  return withTransaction(async (client) => {
    const computeFunctions = [
      computeAssessmentCoverage,
      computeEvidenceDensity,
      computeInterventionClosureRate,
      computeCpdCompliance,
      computePeerAssessmentResponseRate,
      computeHpcExportCompletion,
      computeGovernanceOverrideRate,
      computeAiAcceptanceQuality,
      computeInclusionOverlayTimeliness,
    ];

    const results: IndicatorResult[] = [];

    for (const fn of computeFunctions) {
      try {
        const result = await fn(client, schoolId, academicYearId);
        results.push(result);
      } catch {
        results.push({
          indicatorCode: fn.name.replace('compute', '').replace(/([A-Z])/g, '_$1').toUpperCase().replace(/^_/, ''),
          computedValue: 0,
          performanceLevel: 'CRITICAL',
          dataTimestamp: new Date().toISOString(),
          staleness: -1,
        });
      }
    }

    return results;
  }, tenantId, userId, userRole);
}

export async function getLatestAutoIndicators(
  tenantId: string,
  userId: string,
  userRole: string,
  schoolId: string
): Promise<IndicatorResult[]> {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT siv.id, sid.indicator_code, siv.numeric_value, siv.performance_level,
              siv.computed_at, siv.is_stale
       FROM sqaa_indicator_values siv
       JOIN sqaa_indicator_definitions sid ON sid.id = siv.indicator_id
       WHERE siv.school_id = $1
         AND sid.computation_type = 'AUTO'
       ORDER BY sid.indicator_code`,
      [schoolId]
    );

    return result.rows.map((row: Record<string, unknown>) => ({
      indicatorCode: row.indicator_code as string,
      computedValue: parseFloat(String(row.numeric_value || '0')),
      performanceLevel: (row.performance_level as PerformanceLevel) || 'CRITICAL',
      dataTimestamp: row.computed_at ? new Date(row.computed_at as string).toISOString() : new Date().toISOString(),
      staleness: row.computed_at ? computeStaleness(new Date(row.computed_at as string)) : -1,
    }));
  }, tenantId, userId, userRole);
}
