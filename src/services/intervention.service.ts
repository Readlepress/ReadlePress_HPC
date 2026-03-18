import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function getInterventionAlerts(
  tenantId: string,
  userId: string,
  userRole: string,
  classId?: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT ia.id, ia.student_id, ia.sensitivity_level, ia.alert_data,
              ia.status, ia.created_at,
              sp.first_name, sp.last_name,
              itr.name AS trigger_name
       FROM intervention_alerts ia
       JOIN student_profiles sp ON sp.id = ia.student_id
       JOIN intervention_trigger_rules itr ON itr.id = ia.trigger_rule_id
       WHERE ia.status = 'OPEN'
         ${classId ? 'AND ia.class_id = $1' : ''}
       ORDER BY ia.created_at DESC`,
      classId ? [classId] : []
    );
    return result.rows;
  }, tenantId, userId, userRole);
}

export async function convertAlertToPlan(
  tenantId: string,
  userId: string,
  userRole: string,
  alertId: string,
  data: {
    title: string;
    description?: string;
    sensitivityLevel: string;
    objectives?: unknown[];
    nextReviewDate?: string;
  }
) {
  return withTransaction(async (client) => {
    const alertResult = await client.query(
      'SELECT * FROM intervention_alerts WHERE id = $1 AND status = $2',
      [alertId, 'OPEN']
    );

    if (alertResult.rows.length === 0) {
      throw new Error('ALERT_NOT_FOUND_OR_NOT_OPEN');
    }

    const alert = alertResult.rows[0];

    const planResult = await client.query(
      `INSERT INTO intervention_plans
         (tenant_id, alert_id, student_id, class_id, sensitivity_level,
          title, description, objectives, created_by, next_review_date)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING id`,
      [
        tenantId, alertId, alert.student_id, alert.class_id,
        data.sensitivityLevel, data.title, data.description || null,
        JSON.stringify(data.objectives || []), userId, data.nextReviewDate || null,
      ]
    );

    await client.query(
      `UPDATE intervention_alerts SET status = 'CONVERTED', acknowledged_by = $1, acknowledged_at = now()
       WHERE id = $2`,
      [userId, alertId]
    );

    if (data.sensitivityLevel === 'WELFARE' || data.sensitivityLevel === 'SAFEGUARDING') {
      await client.query(
        `INSERT INTO welfare_case_access_log
           (tenant_id, plan_id, accessed_by, access_role, access_type)
         VALUES ($1, $2, $3, $4, 'EDIT')`,
        [tenantId, planResult.rows[0].id, userId, userRole]
      );
    }

    await insertAuditLog({
      tenantId,
      eventType: 'INTERVENTION.PLAN_CREATED',
      entityType: 'INTERVENTION_PLANS',
      entityId: planResult.rows[0].id,
      performedBy: userId,
      afterState: {
        alertId,
        sensitivityLevel: data.sensitivityLevel,
        studentId: alert.student_id,
      },
    }, client);

    return { planId: planResult.rows[0].id };
  }, tenantId, userId, userRole);
}

export async function closeInterventionPlan(
  tenantId: string,
  userId: string,
  userRole: string,
  planId: string,
  closureType: string,
  approvalUserId?: string
) {
  return withTransaction(async (client) => {
    const planResult = await client.query(
      'SELECT * FROM intervention_plans WHERE id = $1',
      [planId]
    );

    if (planResult.rows.length === 0) {
      throw new Error('PLAN_NOT_FOUND');
    }

    const plan = planResult.rows[0];

    // Check for outcome evidence
    const evidenceResult = await client.query(
      'SELECT COUNT(*) as count FROM intervention_outcome_evidence WHERE plan_id = $1',
      [planId]
    );

    if (parseInt(evidenceResult.rows[0].count) === 0) {
      throw new Error('CLOSURE_EVIDENCE_REQUIRED');
    }

    // WELFARE closure requires principal approval
    if (plan.sensitivity_level === 'WELFARE' && !approvalUserId) {
      throw new Error('CLOSURE_APPROVAL_REQUIRED');
    }

    await client.query(
      `UPDATE intervention_plans
       SET status = 'CLOSED', closed_at = now(), closed_by = $1,
           closure_type = $2, closure_approved_by = $3, closure_approved_at = $4
       WHERE id = $5`,
      [userId, closureType, approvalUserId || null, approvalUserId ? new Date() : null, planId]
    );

    return { status: 'CLOSED' };
  }, tenantId, userId, userRole);
}
