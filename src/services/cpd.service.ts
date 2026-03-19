import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function logCpdActivity(
  tenantId: string,
  userId: string,
  userRole: string,
  data: {
    teacherId: string;
    activityType: string;
    hours: number;
    description: string;
    evidenceRef?: string;
  }
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO cpd_hours_ledger
         (tenant_id, teacher_id, activity_type, hours, description,
          evidence_ref, recorded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id`,
      [
        tenantId, data.teacherId, data.activityType, data.hours,
        data.description, data.evidenceRef || null, userId,
      ]
    );

    const entryId = result.rows[0].id;

    await insertAuditLog({
      tenantId,
      eventType: 'CPD_ACTIVITY.LOGGED',
      entityType: 'CPD_HOURS_LEDGER',
      entityId: entryId,
      performedBy: userId,
      afterState: { teacherId: data.teacherId, hours: data.hours },
    }, client);

    return { entryId };
  }, tenantId, userId, userRole);
}

export async function getCpdSummary(
  tenantId: string,
  userId: string,
  userRole: string,
  teacherId: string
) {
  return withTransaction(async (client) => {
    const hoursResult = await client.query(
      `SELECT activity_type, SUM(hours) AS total_hours, COUNT(*) AS activity_count
       FROM cpd_hours_ledger
       WHERE teacher_id = $1
       GROUP BY activity_type
       ORDER BY activity_type`,
      [teacherId]
    );

    const totalResult = await client.query(
      `SELECT SUM(hours) AS total_hours, COUNT(*) AS total_activities
       FROM cpd_hours_ledger
       WHERE teacher_id = $1`,
      [teacherId]
    );

    return {
      byType: hoursResult.rows,
      total: totalResult.rows[0],
    };
  }, tenantId, userId, userRole);
}

export async function logPeerObservation(
  tenantId: string,
  userId: string,
  userRole: string,
  data: {
    observerId: string;
    observedTeacherId: string;
    classId: string;
    notes: string;
    competencyFocus?: string;
  }
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO peer_observation_records
         (tenant_id, observer_id, observed_teacher_id, class_id,
          notes, competency_focus, recorded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id`,
      [
        tenantId, data.observerId, data.observedTeacherId, data.classId,
        data.notes, data.competencyFocus || null, userId,
      ]
    );

    const recordId = result.rows[0].id;

    await insertAuditLog({
      tenantId,
      eventType: 'PEER_OBSERVATION.LOGGED',
      entityType: 'PEER_OBSERVATION_RECORDS',
      entityId: recordId,
      performedBy: userId,
    }, client);

    return { recordId };
  }, tenantId, userId, userRole);
}
