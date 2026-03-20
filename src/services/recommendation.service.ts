import { withTransaction } from '../config/database';

interface RecommendationResult {
  studentId: string;
  studentName: string;
  competencyUid: string;
  competencyName: string;
  currentMastery: number;
  suggestedDescriptorLevel: string;
  reason: string;
  priorityScore: number;
}

interface StudentCompetencyPair {
  studentId: string;
  studentName: string;
  competencyId: string;
  competencyUid: string;
  competencyName: string;
  subdomain: string | null;
  stageId: string;
  currentEwm: number;
  eventCount: number;
  lastEventAt: string | null;
  trendSlope: number | null;
  descriptorLevels: DescriptorLevelInfo[];
  isBridgeCompetency: boolean;
  bridgeMinimumLevel: number | null;
  classAvgEwm: number;
}

interface DescriptorLevelInfo {
  levelCode: string;
  numericValue: number;
}

export async function getAssessmentRecommendations(
  tenantId: string,
  teacherId: string,
  userId: string,
  userRole: string,
  classId?: string
): Promise<RecommendationResult[]> {
  return withTransaction(async (client) => {
    const classCondition = classId
      ? 'AND ta.class_id = $2'
      : '';
    const classParams: unknown[] = classId
      ? [teacherId, classId]
      : [teacherId];

    const classesResult = await client.query(
      `SELECT DISTINCT ta.class_id, c.stage_id
       FROM teacher_assignments ta
       JOIN classes c ON c.id = ta.class_id
       WHERE ta.teacher_id = $1 AND ta.status = 'ACTIVE'
         ${classCondition}`,
      classParams
    );

    if (classesResult.rows.length === 0) {
      return [];
    }

    const classIds = classesResult.rows.map((r: Record<string, unknown>) => r.class_id as string);
    const stageIds = [...new Set(classesResult.rows.map((r: Record<string, unknown>) => r.stage_id as string))];

    const studentsResult = await client.query(
      `SELECT DISTINCT se.student_id, sp.first_name, sp.last_name, se.class_id
       FROM student_enrolments se
       JOIN student_profiles sp ON sp.id = se.student_id
       WHERE se.class_id = ANY($1) AND se.status = 'ACTIVE'
         AND sp.dedup_status NOT IN ('CONFIRMED_DUPLICATE')`,
      [classIds]
    );

    if (studentsResult.rows.length === 0) {
      return [];
    }

    const competenciesResult = await client.query(
      `SELECT c.id, c.uid, c.name, c.subdomain, c.stage_id
       FROM competencies c
       LEFT JOIN competency_activations ca ON ca.competency_id = c.id AND ca.tenant_id = $1
       WHERE c.stage_id = ANY($2) AND c.status = 'ACTIVE'
         AND (ca.id IS NULL OR ca.is_suppressed = false)`,
      [tenantId, stageIds]
    );

    if (competenciesResult.rows.length === 0) {
      return [];
    }

    const competencyIds = competenciesResult.rows.map((r: Record<string, unknown>) => r.id as string);
    const studentIds = studentsResult.rows.map((r: Record<string, unknown>) => r.student_id as string);

    const descriptorsResult = await client.query(
      `SELECT competency_id, level_code, numeric_value
       FROM descriptor_levels
       WHERE competency_id = ANY($1)
       ORDER BY competency_id, display_order`,
      [competencyIds]
    );

    const descriptorMap = new Map<string, DescriptorLevelInfo[]>();
    for (const row of descriptorsResult.rows) {
      const key = row.competency_id as string;
      if (!descriptorMap.has(key)) descriptorMap.set(key, []);
      descriptorMap.get(key)!.push({
        levelCode: row.level_code as string,
        numericValue: parseFloat(row.numeric_value as string),
      });
    }

    const aggregatesResult = await client.query(
      `SELECT student_id, competency_id, current_ewm, event_count, last_event_at, trend_slope
       FROM mastery_aggregates
       WHERE student_id = ANY($1) AND competency_id = ANY($2)`,
      [studentIds, competencyIds]
    );

    const aggregateMap = new Map<string, Record<string, unknown>>();
    for (const row of aggregatesResult.rows) {
      const key = `${row.student_id}:${row.competency_id}`;
      aggregateMap.set(key, row);
    }

    const bridgeResult = await client.query(
      `SELECT competency_id, minimum_mastery_level
       FROM stage_bridge_mappings
       WHERE competency_id = ANY($1)`,
      [competencyIds]
    );

    const bridgeMap = new Map<string, number>();
    for (const row of bridgeResult.rows) {
      bridgeMap.set(row.competency_id as string, parseFloat(row.minimum_mastery_level as string));
    }

    const classAvgResult = await client.query(
      `SELECT ma.competency_id, AVG(ma.current_ewm) AS avg_ewm
       FROM mastery_aggregates ma
       JOIN student_enrolments se ON se.student_id = ma.student_id AND se.status = 'ACTIVE'
       WHERE se.class_id = ANY($1) AND ma.competency_id = ANY($2)
       GROUP BY ma.competency_id`,
      [classIds, competencyIds]
    );

    const classAvgMap = new Map<string, number>();
    for (const row of classAvgResult.rows) {
      classAvgMap.set(row.competency_id as string, parseFloat(row.avg_ewm as string) || 0);
    }

    const pairs: StudentCompetencyPair[] = [];
    for (const student of studentsResult.rows) {
      for (const comp of competenciesResult.rows) {
        const aggKey = `${student.student_id}:${comp.id}`;
        const agg = aggregateMap.get(aggKey);

        pairs.push({
          studentId: student.student_id,
          studentName: `${student.first_name} ${student.last_name || ''}`.trim(),
          competencyId: comp.id,
          competencyUid: comp.uid,
          competencyName: comp.name,
          subdomain: comp.subdomain,
          stageId: comp.stage_id,
          currentEwm: agg ? parseFloat(agg.current_ewm as string) || 0 : 0,
          eventCount: agg ? parseInt(agg.event_count as string) || 0 : 0,
          lastEventAt: agg ? (agg.last_event_at as string | null) : null,
          trendSlope: agg && agg.trend_slope != null ? parseFloat(agg.trend_slope as string) : null,
          descriptorLevels: descriptorMap.get(comp.id) || [],
          isBridgeCompetency: bridgeMap.has(comp.id),
          bridgeMinimumLevel: bridgeMap.get(comp.id) ?? null,
          classAvgEwm: classAvgMap.get(comp.id) || 0,
        });
      }
    }

    const scored = pairs.map((pair) => ({
      pair,
      score: computePriorityScore(pair),
    }));

    scored.sort((a, b) => b.score - a.score);

    const top = scored.slice(0, 10);

    return top.map(({ pair, score }) => {
      const suggested = suggestNextDescriptorLevel(pair.currentEwm, pair.descriptorLevels);
      return {
        studentId: pair.studentId,
        studentName: pair.studentName,
        competencyUid: pair.competencyUid,
        competencyName: pair.competencyName,
        currentMastery: pair.currentEwm,
        suggestedDescriptorLevel: suggested,
        reason: buildReason(pair, score),
        priorityScore: Math.round(score * 1000) / 1000,
      };
    });
  }, tenantId, userId, userRole);
}

function computePriorityScore(pair: StudentCompetencyPair): number {
  const now = Date.now();

  // assessment_gap: highest priority if zero events
  const assessmentGap = pair.eventCount === 0 ? 10.0 : 0;

  // days_since_last_observation
  let daysSinceLastObs = 0;
  if (pair.lastEventAt) {
    const lastMs = new Date(pair.lastEventAt).getTime();
    daysSinceLastObs = Math.max(0, (now - lastMs) / (1000 * 60 * 60 * 24));
  } else {
    daysSinceLastObs = 90; // default high urgency if no event
  }
  const recencyScore = Math.min(daysSinceLastObs / 30, 3.0);

  // frontier_score: how close to next descriptor boundary (0.4-0.6 = high)
  let frontierScore = 0;
  if (pair.descriptorLevels.length > 0) {
    const boundaries = pair.descriptorLevels
      .map((d) => d.numericValue)
      .sort((a, b) => a - b);

    let minDist = 1.0;
    for (const boundary of boundaries) {
      const dist = Math.abs(pair.currentEwm - boundary);
      if (dist < minDist) minDist = dist;
    }
    // Closer to boundary = higher frontier score; peak when within 0.1 of boundary
    frontierScore = Math.max(0, 1.0 - minDist * 5);
  }

  // bridge_readiness_factor
  let bridgeFactor = 0;
  if (pair.isBridgeCompetency && pair.bridgeMinimumLevel != null) {
    const gap = pair.bridgeMinimumLevel - pair.currentEwm;
    if (gap > 0 && gap < 0.3) {
      bridgeFactor = 2.0; // near stage transition threshold
    } else if (gap > 0) {
      bridgeFactor = 1.0;
    }
  }

  // evidence_density: penalize if 5+ events (diminishing returns)
  let densityPenalty = 0;
  if (pair.eventCount >= 5) {
    densityPenalty = Math.min((pair.eventCount - 4) * 0.3, 2.0);
  }

  return assessmentGap + recencyScore * 2.0 + frontierScore * 1.5 + bridgeFactor - densityPenalty;
}

function suggestNextDescriptorLevel(
  currentEwm: number,
  descriptorLevels: DescriptorLevelInfo[]
): string {
  if (descriptorLevels.length === 0) return 'DEVELOPING';

  const sorted = [...descriptorLevels].sort((a, b) => a.numericValue - b.numericValue);

  for (const dl of sorted) {
    if (dl.numericValue > currentEwm) {
      return dl.levelCode;
    }
  }
  return sorted[sorted.length - 1].levelCode;
}

function buildReason(pair: StudentCompetencyPair, score: number): string {
  const parts: string[] = [];

  if (pair.eventCount === 0) {
    parts.push('No observations recorded yet for this competency');
  } else {
    if (pair.lastEventAt) {
      const days = Math.round(
        (Date.now() - new Date(pair.lastEventAt).getTime()) / (1000 * 60 * 60 * 24)
      );
      if (days > 14) {
        parts.push(`${days} days since last observation`);
      }
    }

    if (pair.currentEwm > 0) {
      const boundaries = pair.descriptorLevels
        .map((d) => d.numericValue)
        .sort((a, b) => a - b);
      for (const b of boundaries) {
        if (Math.abs(pair.currentEwm - b) < 0.1) {
          parts.push('Near descriptor level boundary — assessment can confirm transition');
          break;
        }
      }
    }
  }

  if (pair.isBridgeCompetency && pair.bridgeMinimumLevel != null) {
    const gap = pair.bridgeMinimumLevel - pair.currentEwm;
    if (gap > 0) {
      parts.push('Bridge competency required for stage transition');
    }
  }

  if (pair.eventCount >= 5) {
    parts.push('Multiple observations exist — focus on under-assessed areas first');
  }

  if (parts.length === 0) {
    parts.push('Recommended for balanced assessment coverage');
  }

  return parts.join('. ') + '.';
}
