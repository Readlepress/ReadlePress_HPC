import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function dispatchFeedbackRequests(
  tenantId: string,
  userId: string,
  userRole: string,
  data: {
    promptSetId: string;
    studentIds: string[];
    feedbackType: string;
    classId: string;
    termId?: string;
    academicYearId?: string;
    respondentUserIds: string[];
    dueAt: string;
  }
) {
  return withTransaction(async (client) => {
    const requestIds = [];

    for (const studentId of data.studentIds) {
      for (const respondentId of data.respondentUserIds) {
        const result = await client.query(
          `INSERT INTO feedback_requests
             (tenant_id, prompt_set_id, subject_student_id, respondent_user_id,
              feedback_type, class_id, term_id, academic_year_id, due_at)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
           RETURNING id`,
          [
            tenantId, data.promptSetId, studentId, respondentId,
            data.feedbackType, data.classId, data.termId || null,
            data.academicYearId || null, data.dueAt,
          ]
        );
        requestIds.push(result.rows[0].id);
      }
    }

    return { requestIds, totalDispatched: requestIds.length };
  }, tenantId, userId, userRole);
}

export async function submitFeedbackResponse(
  tenantId: string,
  userId: string,
  userRole: string,
  requestId: string,
  items: Array<{
    promptId: string;
    scaleValue?: number;
    textValue?: string;
    selectedOptions?: unknown;
  }>
) {
  return withTransaction(async (client) => {
    const requestResult = await client.query(
      `SELECT id, respondent_user_id, status, feedback_type
       FROM feedback_requests WHERE id = $1`,
      [requestId]
    );

    if (requestResult.rows.length === 0) {
      throw new Error('REQUEST_NOT_FOUND');
    }

    const req = requestResult.rows[0];
    if (req.status !== 'PENDING') {
      throw new Error('REQUEST_NOT_PENDING');
    }

    const responseResult = await client.query(
      `INSERT INTO feedback_responses (tenant_id, request_id, is_complete)
       VALUES ($1, $2, TRUE)
       RETURNING id`,
      [tenantId, requestId]
    );

    const responseId = responseResult.rows[0].id;

    for (const item of items) {
      await client.query(
        `INSERT INTO feedback_response_items
           (tenant_id, response_id, prompt_id, scale_value, text_value, selected_options)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [tenantId, responseId, item.promptId, item.scaleValue || null,
         item.textValue || null, item.selectedOptions ? JSON.stringify(item.selectedOptions) : null]
      );
    }

    await client.query(
      `UPDATE feedback_requests SET status = 'COMPLETED', completed_at = now() WHERE id = $1`,
      [requestId]
    );

    return { responseId };
  }, tenantId, userId, userRole);
}

export async function getModerationQueue(
  tenantId: string,
  userId: string,
  userRole: string,
  classId?: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT fr.id, fr.feedback_type, fr.subject_student_id,
              fr.moderation_status, fr.moderation_overdue, fr.dispatched_at,
              fr.due_at, fr.completed_at,
              sp.first_name, sp.last_name
       FROM feedback_requests fr
       JOIN student_profiles sp ON sp.id = fr.subject_student_id
       WHERE fr.status = 'COMPLETED'
         AND fr.moderation_status = 'PENDING'
         ${classId ? 'AND fr.class_id = $1' : ''}
       ORDER BY fr.moderation_overdue DESC, fr.completed_at ASC`,
      classId ? [classId] : []
    );

    return result.rows.map((row: Record<string, unknown>) => ({
      ...row,
      respondent_user_id: undefined,
    }));
  }, tenantId, userId, userRole);
}
