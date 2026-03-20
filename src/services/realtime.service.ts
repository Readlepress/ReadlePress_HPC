import { v4 as uuidv4 } from 'uuid';
import { query, withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export interface CollaborationSession {
  sessionId: string;
  templateId: string;
  studentId: string;
  assessorIds: string[];
  status: 'ACTIVE' | 'FINALIZED' | 'EXPIRED';
  expiresAt: Date;
  createdAt: Date;
}

export interface DimensionDivergence {
  dimensionId: string;
  assessments: Array<{ assessorId: string; level: string; note: string | null }>;
  divergence: number;
  isConverged: boolean;
}

interface SessionStore {
  session: CollaborationSession;
  assessments: Map<string, Map<string, { level: string; note: string | null }>>;
  subscribers: Set<(data: unknown) => void>;
}

const CONVERGENCE_THRESHOLD = 0;
const SESSION_TTL_HOURS = 4;

const sessions = new Map<string, SessionStore>();

export function createSession(
  templateId: string,
  studentId: string,
  assessorIds: string[]
): { sessionId: string; joinUrl: string; expiresAt: Date } {
  const sessionId = uuidv4();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_TTL_HOURS * 60 * 60 * 1000);

  const session: CollaborationSession = {
    sessionId,
    templateId,
    studentId,
    assessorIds,
    status: 'ACTIVE',
    expiresAt,
    createdAt: now,
  };

  sessions.set(sessionId, {
    session,
    assessments: new Map(),
    subscribers: new Set(),
  });

  const joinUrl = `/api/v1/realtime/sessions/${sessionId}/ws`;

  return { sessionId, joinUrl, expiresAt };
}

export function getSession(sessionId: string): CollaborationSession | null {
  const store = sessions.get(sessionId);
  return store?.session ?? null;
}

export function broadcastAssessment(
  sessionId: string,
  assessorId: string,
  dimensionId: string,
  selectedLevel: string,
  note: string | null
): void {
  const store = sessions.get(sessionId);
  if (!store) throw new Error('SESSION_NOT_FOUND');
  if (store.session.status !== 'ACTIVE') throw new Error('SESSION_NOT_ACTIVE');
  if (!store.session.assessorIds.includes(assessorId)) throw new Error('ASSESSOR_NOT_IN_SESSION');

  if (!store.assessments.has(dimensionId)) {
    store.assessments.set(dimensionId, new Map());
  }
  store.assessments.get(dimensionId)!.set(assessorId, { level: selectedLevel, note });

  const payload = {
    type: 'ASSESSMENT_UPDATE',
    sessionId,
    assessorId,
    dimensionId,
    selectedLevel,
    note,
    timestamp: new Date().toISOString(),
  };

  for (const send of store.subscribers) {
    try {
      send(payload);
    } catch {
      // subscriber disconnected
    }
  }
}

export function subscribe(sessionId: string, callback: (data: unknown) => void): () => void {
  const store = sessions.get(sessionId);
  if (!store) throw new Error('SESSION_NOT_FOUND');
  store.subscribers.add(callback);
  return () => { store.subscribers.delete(callback); };
}

export function getDivergenceReport(sessionId: string): DimensionDivergence[] {
  const store = sessions.get(sessionId);
  if (!store) throw new Error('SESSION_NOT_FOUND');

  const report: DimensionDivergence[] = [];
  for (const [dimensionId, assessorMap] of store.assessments) {
    const assessments: DimensionDivergence['assessments'] = [];
    for (const [assessorId, data] of assessorMap) {
      assessments.push({ assessorId, level: data.level, note: data.note });
    }

    const uniqueLevels = new Set(assessments.map((a) => a.level));
    const divergence = uniqueLevels.size - 1;
    const isConverged =
      divergence <= CONVERGENCE_THRESHOLD &&
      assessments.length === store.session.assessorIds.length;

    report.push({ dimensionId, assessments, divergence, isConverged });
  }

  return report;
}

export async function finalizeSession(
  sessionId: string,
  consensusDecisions: Array<{
    dimensionId: string;
    descriptorLevelId: string;
    numericValue: number;
    assessorNote?: string;
  }>,
  tenantId: string,
  userId: string,
  userRole: string
): Promise<{ completionId: string }> {
  const store = sessions.get(sessionId);
  if (!store) throw new Error('SESSION_NOT_FOUND');
  if (store.session.status !== 'ACTIVE') throw new Error('SESSION_NOT_ACTIVE');

  const result = await withTransaction(async (client) => {
    const overallValue =
      consensusDecisions.reduce((s, d) => s + d.numericValue, 0) / consensusDecisions.length;

    const completionResult = await client.query(
      `INSERT INTO rubric_completion_records
         (tenant_id, template_id, student_id, assessor_id, class_id,
          overall_numeric_value, status, is_group_assessment,
          observation_note, completed_at)
       VALUES ($1, $2, $3, $4, NULL, $5, 'SUBMITTED', false, $6, NOW())
       RETURNING id`,
      [
        tenantId,
        store.session.templateId,
        store.session.studentId,
        userId,
        overallValue,
        `Multi-assessor session ${sessionId}`,
      ]
    );

    const completionId = completionResult.rows[0].id;

    for (const cd of consensusDecisions) {
      await client.query(
        `INSERT INTO rubric_dimension_assessments
           (tenant_id, completion_id, dimension_id, descriptor_level_id, numeric_value, assessor_note)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [tenantId, completionId, cd.dimensionId, cd.descriptorLevelId, cd.numericValue, cd.assessorNote || null]
      );
    }

    await insertAuditLog(
      {
        tenantId,
        eventType: 'RUBRIC.MULTI_ASSESSOR_FINALIZED',
        entityType: 'RUBRIC_COMPLETION_RECORDS',
        entityId: completionId,
        performedBy: userId,
        afterState: {
          sessionId,
          assessorIds: store.session.assessorIds,
          dimensionCount: consensusDecisions.length,
        },
      },
      client
    );

    return { completionId };
  }, tenantId, userId, userRole);

  store.session.status = 'FINALIZED';

  const payload = { type: 'SESSION_FINALIZED', sessionId, timestamp: new Date().toISOString() };
  for (const send of store.subscribers) {
    try { send(payload); } catch { /* disconnected */ }
  }

  return result;
}
