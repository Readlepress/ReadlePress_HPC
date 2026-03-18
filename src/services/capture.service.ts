import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

interface SyncDraft {
  localId: string;
  studentId: string;
  competencyId: string;
  observedAt: string;
  recordedAt: string;
  timestampSource: string;
  timestampConfidence: string;
  numericValue: number;
  descriptorLevelId?: string;
  observationNote?: string;
  evidenceLocalIds?: string[];
  sourceType?: string;
  deviceId?: string;
}

export async function syncOfflineCapture(
  tenantId: string,
  teacherId: string,
  userId: string,
  userRole: string,
  drafts: SyncDraft[]
) {
  return withTransaction(async (client) => {
    const results = [];
    const conflicts = [];

    for (const draft of drafts) {
      // Idempotency: skip if already synced
      const existing = await client.query(
        `SELECT id, sync_status FROM mastery_event_drafts
         WHERE tenant_id = $1 AND local_id = $2`,
        [tenantId, draft.localId]
      );

      if (existing.rows.length > 0) {
        results.push({
          localId: draft.localId,
          status: 'ALREADY_SYNCED',
          draftId: existing.rows[0].id,
        });
        continue;
      }

      // Validate observed_at: not in the future, not more than 90 days old
      const observedAt = new Date(draft.observedAt);
      const now = new Date();
      const ninetyDaysAgo = new Date(now.getTime() - 90 * 24 * 60 * 60 * 1000);

      if (observedAt > now) {
        results.push({ localId: draft.localId, status: 'REJECTED', reason: 'FUTURE_TIMESTAMP' });
        continue;
      }
      if (observedAt < ninetyDaysAgo) {
        results.push({ localId: draft.localId, status: 'REJECTED', reason: 'STALE_TIMESTAMP' });
        continue;
      }

      // Check for conflicts
      const conflictCheck = await client.query(
        `SELECT id FROM mastery_event_drafts
         WHERE tenant_id = $1 AND student_id = $2 AND competency_id = $3
           AND ABS(EXTRACT(EPOCH FROM (observed_at - $4::timestamptz))) < 300
           AND sync_status = 'SYNCED'`,
        [tenantId, draft.studentId, draft.competencyId, draft.observedAt]
      );

      const teacherProfileResult = await client.query(
        `SELECT id FROM teacher_profiles WHERE user_id = $1 AND tenant_id = $2`,
        [userId, tenantId]
      );
      const tpId = teacherProfileResult.rows[0]?.id || teacherId;

      const insertResult = await client.query(
        `INSERT INTO mastery_event_drafts
           (tenant_id, local_id, teacher_id, student_id, competency_id,
            observed_at, recorded_at, synced_at, timestamp_source,
            timestamp_confidence, numeric_value, descriptor_level_id,
            observation_note, evidence_local_ids, source_type, sync_status, device_id)
         VALUES ($1, $2, $3, $4, $5, $6, $7, now(), $8, $9, $10, $11, $12, $13, $14,
                 CASE WHEN $15 THEN 'CONFLICT' ELSE 'SYNCED' END, $16)
         RETURNING id`,
        [
          tenantId, draft.localId, tpId, draft.studentId, draft.competencyId,
          draft.observedAt, draft.recordedAt, draft.timestampSource,
          draft.timestampConfidence, draft.numericValue, draft.descriptorLevelId || null,
          draft.observationNote || null, draft.evidenceLocalIds || [],
          draft.sourceType || 'DIRECT_OBSERVATION',
          conflictCheck.rows.length > 0,
          draft.deviceId || null,
        ]
      );

      if (conflictCheck.rows.length > 0) {
        await client.query(
          `INSERT INTO sync_conflicts
             (tenant_id, draft_id, existing_event_id, conflict_type, device_version)
           VALUES ($1, $2, $3, 'DIVERGENT', $4)`,
          [tenantId, insertResult.rows[0].id, conflictCheck.rows[0].id, JSON.stringify(draft)]
        );
        conflicts.push({ localId: draft.localId, draftId: insertResult.rows[0].id });
      }

      results.push({
        localId: draft.localId,
        status: conflictCheck.rows.length > 0 ? 'CONFLICT' : 'SYNCED',
        draftId: insertResult.rows[0].id,
      });
    }

    return { results, conflicts };
  }, tenantId, userId, userRole);
}
