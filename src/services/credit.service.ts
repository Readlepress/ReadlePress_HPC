import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function triggerCreditComputation(
  tenantId: string,
  userId: string,
  userRole: string,
  studentId: string,
  academicYearId: string
) {
  return withTransaction(async (client) => {
    const idempotencyKey = Buffer.from(
      `CREDIT_COMP${studentId}${academicYearId}`
    ).toString('hex');

    const result = await client.query(
      `INSERT INTO credit_computation_jobs
         (tenant_id, student_id, academic_year_id, idempotency_key, status)
       VALUES ($1, $2, $3, $4, 'PENDING')
       ON CONFLICT (idempotency_key) DO NOTHING
       RETURNING id`,
      [tenantId, studentId, academicYearId, idempotencyKey]
    );

    const jobId = result.rows[0]?.id;

    await insertAuditLog({
      tenantId,
      eventType: 'CREDIT_COMPUTATION.TRIGGERED',
      entityType: 'CREDIT_COMPUTATION_JOBS',
      entityId: jobId || 'DUPLICATE',
      performedBy: userId,
      afterState: { studentId, academicYearId },
    }, client);

    return { jobId, status: jobId ? 'PENDING' : 'ALREADY_QUEUED' };
  }, tenantId, userId, userRole);
}

export async function getCreditSummary(
  tenantId: string,
  userId: string,
  userRole: string,
  studentId: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT cle.id, cle.competency_id, cle.academic_year_id,
              cle.credits_earned, cle.credits_possible,
              cle.mastery_score, cle.created_at
       FROM credit_ledger_entries cle
       WHERE cle.student_id = $1
       ORDER BY cle.created_at DESC`,
      [studentId]
    );
    return result.rows;
  }, tenantId, userId, userRole);
}

export async function submitExternalCreditClaim(
  tenantId: string,
  userId: string,
  userRole: string,
  data: {
    studentId: string;
    competencyId: string;
    externalProvider: string;
    creditsRequested: number;
    evidenceRef?: string;
  }
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO external_credit_claims
         (tenant_id, student_id, competency_id, external_provider,
          credits_requested, evidence_ref, submitted_by, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'PENDING')
       RETURNING id`,
      [
        tenantId, data.studentId, data.competencyId,
        data.externalProvider, data.creditsRequested,
        data.evidenceRef || null, userId,
      ]
    );

    const claimId = result.rows[0].id;

    await insertAuditLog({
      tenantId,
      eventType: 'EXTERNAL_CREDIT_CLAIM.SUBMITTED',
      entityType: 'EXTERNAL_CREDIT_CLAIMS',
      entityId: claimId,
      performedBy: userId,
      afterState: { studentId: data.studentId, competencyId: data.competencyId },
    }, client);

    return { claimId, status: 'PENDING' };
  }, tenantId, userId, userRole);
}
