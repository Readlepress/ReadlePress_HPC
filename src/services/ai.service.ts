import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function generateAiDraft(
  tenantId: string,
  userId: string,
  userRole: string,
  data: {
    entityType: string;
    entityId: string;
    promptContext: Record<string, unknown>;
  }
) {
  return withTransaction(async (client) => {
    // Step 1: Log the generation request
    const logResult = await client.query(
      `INSERT INTO ai_generation_log
         (tenant_id, entity_type, entity_id, prompt_context, requested_by,
          pipeline_stage, status)
       VALUES ($1, $2, $3, $4, $5, 'INITIATED', 'PROCESSING')
       RETURNING id`,
      [tenantId, data.entityType, data.entityId, JSON.stringify(data.promptContext), userId]
    );

    const logId = logResult.rows[0].id;

    // Step 2: Create the AI draft record
    const draftResult = await client.query(
      `INSERT INTO ai_drafts
         (tenant_id, generation_log_id, entity_type, entity_id,
          draft_content, status, created_by)
       VALUES ($1, $2, $3, $4, $5, 'PENDING_REVIEW', $6)
       RETURNING id`,
      [tenantId, logId, data.entityType, data.entityId, '{}', userId]
    );

    const draftId = draftResult.rows[0].id;

    // Step 3: Update generation log with draft reference
    await client.query(
      `UPDATE ai_generation_log
       SET pipeline_stage = 'DRAFT_CREATED', status = 'COMPLETED', draft_id = $1
       WHERE id = $2`,
      [draftId, logId]
    );

    await insertAuditLog({
      tenantId,
      eventType: 'AI_DRAFT.GENERATED',
      entityType: 'AI_DRAFTS',
      entityId: draftId,
      performedBy: userId,
      afterState: { entityType: data.entityType, generationLogId: logId },
    }, client);

    return { draftId, generationLogId: logId, status: 'PENDING_REVIEW' };
  }, tenantId, userId, userRole);
}

export async function promoteAiDraft(
  tenantId: string,
  userId: string,
  userRole: string,
  draftId: string
) {
  return withTransaction(async (client) => {
    const existing = await client.query(
      'SELECT * FROM ai_drafts WHERE id = $1 AND status = $2',
      [draftId, 'PENDING_REVIEW']
    );

    if (existing.rows.length === 0) {
      throw new Error('AI_DRAFT_NOT_FOUND_OR_NOT_PENDING');
    }

    await client.query(
      `UPDATE ai_drafts
       SET status = 'PROMOTED', promoted_by = $1, promoted_at = now()
       WHERE id = $2`,
      [userId, draftId]
    );

    await insertAuditLog({
      tenantId,
      eventType: 'AI_DRAFT.PROMOTED',
      entityType: 'AI_DRAFTS',
      entityId: draftId,
      performedBy: userId,
    }, client);

    return { status: 'PROMOTED' };
  }, tenantId, userId, userRole);
}

export async function listPendingAiDrafts(
  tenantId: string,
  userId: string,
  userRole: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT id, entity_type, entity_id, draft_content, status,
              created_by, created_at
       FROM ai_drafts
       WHERE status = 'PENDING_REVIEW'
       ORDER BY created_at DESC
       LIMIT 100`
    );
    return result.rows;
  }, tenantId, userId, userRole);
}
