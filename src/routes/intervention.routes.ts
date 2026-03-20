import { FastifyInstance } from 'fastify';
import { authenticate, getUser } from '../middleware/auth';
import { getInterventionAlerts, convertAlertToPlan } from '../services/intervention.service';
import { withTransaction } from '../config/database';

export default async function interventionRoutes(app: FastifyInstance) {
  app.get('/intervention-alerts', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { classId } = request.query as { classId?: string };
    const alerts = await getInterventionAlerts(user.tenantId, user.userId, user.role, classId);
    return { alerts };
  });

  app.post('/intervention-alerts/:id/convert', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      title: string;
      description?: string;
      sensitivityLevel: string;
      objectives?: unknown[];
      nextReviewDate?: string;
    };
    const result = await convertAlertToPlan(user.tenantId, user.userId, user.role, id, body);
    return reply.code(201).send(result);
  });

  app.post('/intervention-alerts/:id/acknowledge', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { notes } = request.body as { notes?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE intervention_alerts SET status = 'ACKNOWLEDGED', acknowledged_by = $1,
                acknowledged_at = NOW(), acknowledgement_notes = $2, updated_at = NOW()
         WHERE alert_id = $3
         RETURNING alert_id, status, acknowledged_by, acknowledged_at`,
        [user.userId, notes || null, id]
      );
      if (result.rows.length === 0) throw new Error('ALERT_NOT_FOUND');
      return { alert: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/intervention-plans/:id/actions', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      actionType: string;
      description: string;
      scheduledDate?: string;
      assignedTo?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO intervention_plan_actions (plan_id, action_type, description,
                                                scheduled_date, assigned_to, status, created_by)
         VALUES ($1, $2, $3, $4, $5, 'PENDING', $6)
         RETURNING action_id, plan_id, action_type, status, created_at`,
        [id, body.actionType, body.description, body.scheduledDate || null,
         body.assignedTo || null, user.userId]
      );
      return reply.code(201).send({ action: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/intervention-plans/:id/outcome-evidence', { preHandler: [authenticate] }, async (request, reply) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const body = request.body as {
      evidenceType: string;
      description: string;
      evidenceId?: string;
      outcome: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO intervention_outcome_evidence (plan_id, evidence_type, description,
                                                     evidence_id, outcome, submitted_by)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING outcome_evidence_id, plan_id, evidence_type, outcome, created_at`,
        [id, body.evidenceType, body.description, body.evidenceId || null,
         body.outcome, user.userId]
      );
      return reply.code(201).send({ outcomeEvidence: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/intervention-plans/:id/close', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    const { outcome, closureNotes } = request.body as { outcome: string; closureNotes?: string };
    return withTransaction(async (client) => {
      const result = await client.query(
        `UPDATE intervention_plans SET status = 'CLOSED', outcome = $1,
                closure_notes = $2, closed_by = $3, closed_at = NOW(), updated_at = NOW()
         WHERE plan_id = $4
         RETURNING plan_id, status, outcome, closed_at`,
        [outcome, closureNotes || null, user.userId, id]
      );
      if (result.rows.length === 0) throw new Error('PLAN_NOT_FOUND');
      return { plan: result.rows[0] };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/intervention-plans/:id', { preHandler: [authenticate] }, async (request) => {
    const { id } = request.params as { id: string };
    const user = getUser(request);
    return withTransaction(async (client) => {
      const plan = await client.query(
        `SELECT * FROM intervention_plans WHERE plan_id = $1`, [id]
      );
      if (plan.rows.length === 0) throw new Error('PLAN_NOT_FOUND');
      const actions = await client.query(
        `SELECT * FROM intervention_plan_actions WHERE plan_id = $1 ORDER BY created_at`, [id]
      );
      const evidence = await client.query(
        `SELECT * FROM intervention_outcome_evidence WHERE plan_id = $1 ORDER BY created_at`, [id]
      );
      return {
        plan: plan.rows[0],
        actions: actions.rows,
        outcomeEvidence: evidence.rows,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.get('/principal/intervention-overview', { preHandler: [authenticate] }, async (request) => {
    const user = getUser(request);
    const { schoolId } = request.query as { schoolId?: string };
    return withTransaction(async (client) => {
      const params: unknown[] = [];
      let schoolFilter = '';
      if (schoolId) {
        schoolFilter = 'WHERE ia.school_id = $1';
        params.push(schoolId);
      }
      const alerts = await client.query(
        `SELECT ia.status, COUNT(*) AS count
         FROM intervention_alerts ia ${schoolFilter}
         GROUP BY ia.status`,
        params
      );
      const plans = await client.query(
        `SELECT ip.status, COUNT(*) AS count,
                ip.sensitivity_level
         FROM intervention_plans ip
         ${schoolFilter ? 'WHERE ip.school_id = $1' : ''}
         GROUP BY ip.status, ip.sensitivity_level`,
        params
      );
      return {
        alertsByStatus: alerts.rows,
        plansByStatus: plans.rows,
      };
    }, user.tenantId, user.userId, user.role);
  });

  app.post('/intervention-alerts/manual', { preHandler: [authenticate] }, async (request, reply) => {
    const user = getUser(request);
    const body = request.body as {
      studentId: string;
      alertType: string;
      severity: string;
      description: string;
      competencyUid?: string;
    };
    return withTransaction(async (client) => {
      const result = await client.query(
        `INSERT INTO intervention_alerts (student_id, alert_type, severity, description,
                                          competency_uid, source, status, created_by)
         VALUES ($1, $2, $3, $4, $5, 'MANUAL', 'NEW', $6)
         RETURNING alert_id, student_id, alert_type, severity, status, created_at`,
        [body.studentId, body.alertType, body.severity, body.description,
         body.competencyUid || null, user.userId]
      );
      return reply.code(201).send({ alert: result.rows[0] });
    }, user.tenantId, user.userId, user.role);
  });
}
