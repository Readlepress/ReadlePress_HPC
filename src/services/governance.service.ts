import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function createOverrideRequest(
  tenantId: string,
  userId: string,
  userRole: string,
  data: {
    entityType: string;
    entityId: string;
    reason: string;
    requestedChange: Record<string, unknown>;
  }
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO override_requests
         (tenant_id, entity_type, entity_id, reason, requested_change,
          requested_by, status)
       VALUES ($1, $2, $3, $4, $5, $6, 'PENDING')
       RETURNING id`,
      [
        tenantId, data.entityType, data.entityId, data.reason,
        JSON.stringify(data.requestedChange), userId,
      ]
    );

    const requestId = result.rows[0].id;

    await insertAuditLog({
      tenantId,
      eventType: 'OVERRIDE_REQUEST.CREATED',
      entityType: 'OVERRIDE_REQUESTS',
      entityId: requestId,
      performedBy: userId,
      afterState: { entityType: data.entityType, entityId: data.entityId },
    }, client);

    return { requestId, status: 'PENDING' };
  }, tenantId, userId, userRole);
}

export async function approveOverrideRequest(
  tenantId: string,
  userId: string,
  userRole: string,
  requestId: string,
  data: { decision: 'APPROVED' | 'REJECTED'; notes?: string }
) {
  return withTransaction(async (client) => {
    const existing = await client.query(
      'SELECT * FROM override_requests WHERE id = $1 AND status = $2',
      [requestId, 'PENDING']
    );

    if (existing.rows.length === 0) {
      throw new Error('OVERRIDE_REQUEST_NOT_FOUND_OR_NOT_PENDING');
    }

    const req = existing.rows[0];

    if (req.requested_by === userId) {
      throw new Error('SELF_APPROVAL_NOT_ALLOWED');
    }

    await client.query(
      `UPDATE override_requests
       SET status = $1, decided_by = $2, decided_at = now(), decision_notes = $3
       WHERE id = $4`,
      [data.decision, userId, data.notes || null, requestId]
    );

    await insertAuditLog({
      tenantId,
      eventType: `OVERRIDE_REQUEST.${data.decision}`,
      entityType: 'OVERRIDE_REQUESTS',
      entityId: requestId,
      performedBy: userId,
      afterState: { decision: data.decision },
    }, client);

    return { status: data.decision };
  }, tenantId, userId, userRole);
}

export async function listGovernanceAlerts(
  tenantId: string,
  userId: string,
  userRole: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT id, alert_type, severity, entity_type, entity_id,
              message, is_resolved, created_at
       FROM governance_alerts
       ORDER BY created_at DESC
       LIMIT 100`
    );
    return result.rows;
  }, tenantId, userId, userRole);
}

export async function requestComplianceReconstruction(
  tenantId: string,
  userId: string,
  userRole: string,
  data: { entityType: string; entityId: string; reason: string }
) {
  return withTransaction(async (client) => {
    await insertAuditLog({
      tenantId,
      eventType: 'COMPLIANCE_RECONSTRUCTION.REQUESTED',
      entityType: data.entityType,
      entityId: data.entityId,
      performedBy: userId,
      afterState: { reason: data.reason },
    }, client);

    return { status: 'RECONSTRUCTION_QUEUED' };
  }, tenantId, userId, userRole);
}
