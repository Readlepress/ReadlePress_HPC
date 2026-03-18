import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function createOverlay(
  tenantId: string,
  userId: string,
  userRole: string,
  studentId: string,
  data: {
    disabilityProfileId: string;
    overlayTemplateId?: string;
    competencyIds: string[];
    modifications: Record<string, unknown>;
    modifiedMasteryThreshold?: number;
    effectiveFrom: string;
    effectiveUntil: string;
  }
) {
  return withTransaction(async (client) => {
    // Verify disability data consent
    const consentCheck = await client.query(
      `SELECT id FROM data_consent_records
       WHERE tenant_id = $1 AND student_id = $2
         AND consent_purpose_code = 'DISABILITY_DATA'
         AND consent_status = 'ACTIVE'`,
      [tenantId, studentId]
    );

    if (consentCheck.rows.length === 0) {
      throw new Error('DISABILITY_DATA_CONSENT_REQUIRED');
    }

    const result = await client.query(
      `INSERT INTO rubric_overlays
         (tenant_id, student_id, disability_profile_id, overlay_template_id,
          competency_ids, modifications, modified_mastery_threshold,
          submitted_by, submitted_at, effective_from, effective_until, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now(), $9, $10, 'PENDING_APPROVAL')
       RETURNING id`,
      [
        tenantId, studentId, data.disabilityProfileId, data.overlayTemplateId || null,
        data.competencyIds, JSON.stringify(data.modifications),
        data.modifiedMasteryThreshold || null, userId,
        data.effectiveFrom, data.effectiveUntil,
      ]
    );

    const overlayId = result.rows[0].id;

    await client.query(
      `INSERT INTO overlay_approval_log
         (tenant_id, overlay_id, action, performed_by, details)
       VALUES ($1, $2, 'SUBMITTED', $3, $4)`,
      [tenantId, overlayId, userId, JSON.stringify({ submittedBy: userId })]
    );

    await insertAuditLog({
      tenantId,
      eventType: 'OVERLAY.SUBMITTED',
      entityType: 'RUBRIC_OVERLAYS',
      entityId: overlayId,
      performedBy: userId,
      afterState: { studentId, competencyIds: data.competencyIds },
    }, client);

    return { overlayId };
  }, tenantId, userId, userRole);
}

export async function approveOverlay(
  tenantId: string,
  userId: string,
  userRole: string,
  overlayId: string,
  action: 'APPROVED' | 'REJECTED',
  rejectionReason?: string
) {
  return withTransaction(async (client) => {
    const overlayResult = await client.query(
      'SELECT * FROM rubric_overlays WHERE id = $1',
      [overlayId]
    );

    if (overlayResult.rows.length === 0) {
      throw new Error('OVERLAY_NOT_FOUND');
    }

    const overlay = overlayResult.rows[0];

    if (overlay.status !== 'PENDING_APPROVAL') {
      throw new Error('OVERLAY_NOT_PENDING');
    }

    // Self-approval prevention (also enforced at DB level)
    if (overlay.submitted_by === userId) {
      throw new Error('SELF_APPROVAL_NOT_ALLOWED');
    }

    if (action === 'APPROVED') {
      await client.query(
        `UPDATE rubric_overlays
         SET status = 'ACTIVE', approved_by = $1, approved_at = now()
         WHERE id = $2`,
        [userId, overlayId]
      );

      // Auto-create credit_overlay_links if modified_mastery_threshold is set
      if (overlay.modified_mastery_threshold) {
        for (const compId of overlay.competency_ids) {
          await client.query(
            `INSERT INTO credit_overlay_links
               (tenant_id, overlay_id, student_id, competency_id,
                standard_threshold, modified_threshold)
             VALUES ($1, $2, $3, $4, 0.50, $5)
             ON CONFLICT (overlay_id, competency_id) DO NOTHING`,
            [tenantId, overlayId, overlay.student_id, compId, overlay.modified_mastery_threshold]
          );
        }
      }
    } else {
      await client.query(
        `UPDATE rubric_overlays
         SET status = 'REJECTED', rejected_by = $1, rejected_at = now(), rejection_reason = $2
         WHERE id = $3`,
        [userId, rejectionReason || null, overlayId]
      );
    }

    await client.query(
      `INSERT INTO overlay_approval_log
         (tenant_id, overlay_id, action, performed_by, details)
       VALUES ($1, $2, $3, $4, $5)`,
      [tenantId, overlayId, action, userId, JSON.stringify({ reason: rejectionReason })]
    );

    return { status: action === 'APPROVED' ? 'ACTIVE' : 'REJECTED' };
  }, tenantId, userId, userRole);
}

export async function getActiveOverlays(
  tenantId: string,
  userId: string,
  userRole: string,
  studentId: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT ro.id, ro.competency_ids, ro.modifications,
              ro.modified_mastery_threshold, ro.effective_from, ro.effective_until,
              ro.status, ot.name AS template_name
       FROM rubric_overlays ro
       LEFT JOIN overlay_templates ot ON ot.id = ro.overlay_template_id
       WHERE ro.student_id = $1
         AND ro.status = 'ACTIVE'
         AND ro.effective_from <= CURRENT_DATE
         AND ro.effective_until >= CURRENT_DATE
       ORDER BY ro.effective_from`,
      [studentId]
    );
    return result.rows;
  }, tenantId, userId, userRole);
}
