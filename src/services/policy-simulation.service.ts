import { withTransaction } from '../config/database';
import { PoolClient } from 'pg';

type PolicyType =
  | 'MASTERY_THRESHOLD'
  | 'CREDIT_HOURS_PER_CREDIT'
  | 'DOMAIN_CAP'
  | 'CPD_HOURS_TARGET'
  | 'K_ANONYMITY_THRESHOLD';

type RiskLevel = 'LOW' | 'MEDIUM' | 'HIGH';

interface SimulationInput {
  policyType: PolicyType;
  currentValue: number;
  proposedValue: number;
  affectedMetric: string;
  academicYearId?: string;
}

interface StageBreakdown {
  [stage: string]: { affected: number; total: number };
}

interface SimulationImpact {
  studentsAffected: number;
  percentageChange: number;
  byStage: StageBreakdown;
  byDomain: Record<string, number>;
  byDistrict: Record<string, number>;
}

interface SimulationResult {
  id: string;
  currentPolicy: { type: PolicyType; value: number };
  proposedPolicy: { type: PolicyType; value: number };
  impact: SimulationImpact;
  riskAssessment: RiskLevel;
  recommendations: string[];
}

function assessRisk(percentageChange: number): RiskLevel {
  const abs = Math.abs(percentageChange);
  if (abs < 5) return 'LOW';
  if (abs < 20) return 'MEDIUM';
  return 'HIGH';
}

function generateRecommendations(policyType: PolicyType, impact: SimulationImpact, risk: RiskLevel): string[] {
  const recs: string[] = [];

  if (risk === 'HIGH') {
    recs.push('Consider a phased rollout to minimize disruption.');
    recs.push('Engage stakeholders (teachers, parents, district officers) before implementation.');
  }
  if (risk === 'MEDIUM') {
    recs.push('Monitor affected cohorts closely during the first term after implementation.');
  }

  switch (policyType) {
    case 'MASTERY_THRESHOLD':
      if (impact.percentageChange < 0) {
        recs.push('Lowering the threshold may reduce rigor. Ensure standards alignment.');
      } else {
        recs.push('Raising the threshold will increase the bar. Provide additional support for at-risk students.');
      }
      break;
    case 'CREDIT_HOURS_PER_CREDIT':
      recs.push('Recompute credit totals and notify affected students and teachers.');
      break;
    case 'DOMAIN_CAP':
      recs.push('Review domain distribution to ensure balanced learning across subjects.');
      break;
    case 'CPD_HOURS_TARGET':
      recs.push('Update CPD tracking dashboards and communicate new targets to all teachers.');
      break;
    case 'K_ANONYMITY_THRESHOLD':
      recs.push('Run a privacy impact assessment after changing anonymity thresholds.');
      break;
  }

  if (recs.length === 0) {
    recs.push('No specific recommendations. Monitor standard metrics post-implementation.');
  }

  return recs;
}

async function simulateMasteryThreshold(
  client: PoolClient,
  currentValue: number,
  proposedValue: number,
  academicYearId?: string
): Promise<SimulationImpact> {
  const yearFilter = academicYearId
    ? `AND ma.academic_year_id = '${academicYearId}'`
    : '';

  const currentPassResult = await client.query(
    `SELECT COUNT(*) AS count FROM mastery_aggregates ma
     WHERE ma.aggregate_score >= $1 ${yearFilter}`,
    [currentValue]
  );

  const proposedPassResult = await client.query(
    `SELECT COUNT(*) AS count FROM mastery_aggregates ma
     WHERE ma.aggregate_score >= $1 ${yearFilter}`,
    [proposedValue]
  );

  const totalResult = await client.query(
    `SELECT COUNT(*) AS count FROM mastery_aggregates ma WHERE 1=1 ${yearFilter}`
  );

  const currentPass = parseInt(currentPassResult.rows[0]?.count || '0', 10);
  const proposedPass = parseInt(proposedPassResult.rows[0]?.count || '0', 10);
  const total = parseInt(totalResult.rows[0]?.count || '0', 10);

  const affected = Math.abs(currentPass - proposedPass);
  const percentageChange = total > 0 ? ((proposedPass - currentPass) / total) * 100 : 0;

  const stageResult = await client.query(
    `SELECT ma.stage, COUNT(*) FILTER (WHERE ma.aggregate_score >= $1) AS current_pass,
            COUNT(*) FILTER (WHERE ma.aggregate_score >= $2) AS proposed_pass,
            COUNT(*) AS total
     FROM mastery_aggregates ma
     WHERE 1=1 ${yearFilter}
     GROUP BY ma.stage`,
    [currentValue, proposedValue]
  );

  const byStage: StageBreakdown = {};
  for (const row of stageResult.rows) {
    byStage[row.stage || 'UNKNOWN'] = {
      affected: Math.abs(parseInt(row.current_pass, 10) - parseInt(row.proposed_pass, 10)),
      total: parseInt(row.total, 10),
    };
  }

  return { studentsAffected: affected, percentageChange, byStage, byDomain: {}, byDistrict: {} };
}

async function simulateCreditHoursPerCredit(
  client: PoolClient,
  currentValue: number,
  proposedValue: number,
  academicYearId?: string
): Promise<SimulationImpact> {
  const yearFilter = academicYearId
    ? `AND hle.academic_year_id = '${academicYearId}'`
    : '';

  const result = await client.query(
    `SELECT COUNT(DISTINCT hle.student_id) AS affected_students,
            SUM(hle.hours) AS total_hours
     FROM hour_ledger_entries hle
     WHERE 1=1 ${yearFilter}`,
  );

  const totalHours = parseFloat(result.rows[0]?.total_hours || '0');
  const currentCredits = currentValue > 0 ? totalHours / currentValue : 0;
  const proposedCredits = proposedValue > 0 ? totalHours / proposedValue : 0;
  const affectedStudents = parseInt(result.rows[0]?.affected_students || '0', 10);
  const percentageChange = currentCredits > 0
    ? ((proposedCredits - currentCredits) / currentCredits) * 100
    : 0;

  return {
    studentsAffected: affectedStudents,
    percentageChange,
    byStage: {},
    byDomain: {},
    byDistrict: {},
  };
}

async function simulateDomainCap(
  client: PoolClient,
  currentValue: number,
  proposedValue: number,
  academicYearId?: string
): Promise<SimulationImpact> {
  const yearFilter = academicYearId
    ? `AND cle.academic_year_id = '${academicYearId}'`
    : '';

  const result = await client.query(
    `SELECT cle.domain, SUM(cle.credits) AS total_credits, COUNT(DISTINCT cle.student_id) AS student_count
     FROM credit_ledger_entries cle
     WHERE 1=1 ${yearFilter}
     GROUP BY cle.domain`,
  );

  const byDomain: Record<string, number> = {};
  let totalAffected = 0;

  for (const row of result.rows) {
    const credits = parseFloat(row.total_credits || '0');
    const overflowCurrent = Math.max(0, credits - currentValue);
    const overflowProposed = Math.max(0, credits - proposedValue);

    if (overflowCurrent !== overflowProposed) {
      byDomain[row.domain || 'UNKNOWN'] = overflowProposed - overflowCurrent;
      totalAffected += parseInt(row.student_count || '0', 10);
    }
  }

  const currentOverflow = Object.values(byDomain).filter(v => v < 0).length;
  const proposedOverflow = Object.values(byDomain).filter(v => v > 0).length;
  const percentageChange = currentOverflow + proposedOverflow > 0
    ? ((proposedOverflow - currentOverflow) / (currentOverflow + proposedOverflow + 1)) * 100
    : 0;

  return {
    studentsAffected: totalAffected,
    percentageChange,
    byStage: {},
    byDomain,
    byDistrict: {},
  };
}

async function simulateGenericPolicy(
  _client: PoolClient,
  currentValue: number,
  proposedValue: number
): Promise<SimulationImpact> {
  const percentageChange = currentValue > 0
    ? ((proposedValue - currentValue) / currentValue) * 100
    : 0;

  return {
    studentsAffected: 0,
    percentageChange,
    byStage: {},
    byDomain: {},
    byDistrict: {},
  };
}

export async function simulatePolicyChange(
  tenantId: string,
  userId: string,
  userRole: string,
  simulation: SimulationInput
): Promise<SimulationResult> {
  return withTransaction(async (client) => {
    let impact: SimulationImpact;

    switch (simulation.policyType) {
      case 'MASTERY_THRESHOLD':
        impact = await simulateMasteryThreshold(
          client, simulation.currentValue, simulation.proposedValue, simulation.academicYearId
        );
        break;
      case 'CREDIT_HOURS_PER_CREDIT':
        impact = await simulateCreditHoursPerCredit(
          client, simulation.currentValue, simulation.proposedValue, simulation.academicYearId
        );
        break;
      case 'DOMAIN_CAP':
        impact = await simulateDomainCap(
          client, simulation.currentValue, simulation.proposedValue, simulation.academicYearId
        );
        break;
      case 'CPD_HOURS_TARGET':
      case 'K_ANONYMITY_THRESHOLD':
        impact = await simulateGenericPolicy(
          client, simulation.currentValue, simulation.proposedValue
        );
        break;
      default:
        impact = await simulateGenericPolicy(
          client, simulation.currentValue, simulation.proposedValue
        );
    }

    const riskAssessment = assessRisk(impact.percentageChange);
    const recommendations = generateRecommendations(simulation.policyType, impact, riskAssessment);

    const insertResult = await client.query(
      `INSERT INTO policy_simulation_runs
         (tenant_id, simulation_type, parameters, results, impact_summary, risk_level, simulated_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id`,
      [
        tenantId,
        simulation.policyType,
        JSON.stringify(simulation),
        JSON.stringify({ impact, recommendations }),
        JSON.stringify(impact),
        riskAssessment,
        userId,
      ]
    );

    return {
      id: insertResult.rows[0].id,
      currentPolicy: { type: simulation.policyType, value: simulation.currentValue },
      proposedPolicy: { type: simulation.policyType, value: simulation.proposedValue },
      impact,
      riskAssessment,
      recommendations,
    };
  }, tenantId, userId, userRole);
}

export async function getSimulationById(
  tenantId: string,
  userId: string,
  userRole: string,
  simulationId: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT id, simulation_type, parameters, results, impact_summary, risk_level,
              simulated_by, simulated_at, created_at
       FROM policy_simulation_runs
       WHERE id = $1`,
      [simulationId]
    );

    if (result.rows.length === 0) throw new Error('SIMULATION_NOT_FOUND');
    return result.rows[0];
  }, tenantId, userId, userRole);
}

export async function listSimulationHistory(
  tenantId: string,
  userId: string,
  userRole: string,
  limit = 50,
  offset = 0
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT id, simulation_type, parameters, impact_summary, risk_level,
              simulated_by, simulated_at, created_at
       FROM policy_simulation_runs
       ORDER BY simulated_at DESC
       LIMIT $1 OFFSET $2`,
      [limit, offset]
    );

    return { simulations: result.rows, limit, offset };
  }, tenantId, userId, userRole);
}
