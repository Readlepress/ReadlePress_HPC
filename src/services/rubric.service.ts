import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function submitRubricCompletion(
  tenantId: string,
  userId: string,
  userRole: string,
  data: {
    templateId: string;
    studentId: string;
    classId: string;
    termId?: string;
    academicYearId?: string;
    dimensionAssessments: Array<{
      dimensionId: string;
      descriptorLevelId: string;
      numericValue: number;
      assessorNote?: string;
    }>;
    evidenceRecordIds?: string[];
    observationNote?: string;
    isGroupAssessment?: boolean;
    groupStudentIds?: string[];
  }
) {
  return withTransaction(async (client) => {
    const studentIds = data.isGroupAssessment && data.groupStudentIds
      ? data.groupStudentIds
      : [data.studentId];

    const completionIds = [];

    for (const studentId of studentIds) {
      const overallValue = data.dimensionAssessments.reduce(
        (sum, da) => sum + da.numericValue, 0
      ) / data.dimensionAssessments.length;

      const completionResult = await client.query(
        `INSERT INTO rubric_completion_records
           (tenant_id, template_id, student_id, assessor_id, class_id, term_id,
            academic_year_id, overall_numeric_value, status, is_group_assessment,
            evidence_record_ids, observation_note, completed_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'SUBMITTED', $9, $10, $11, now())
         RETURNING id`,
        [
          tenantId, data.templateId, studentId, userId, data.classId,
          data.termId || null, data.academicYearId || null,
          overallValue, data.isGroupAssessment || false,
          data.evidenceRecordIds || [], data.observationNote || null,
        ]
      );

      const completionId = completionResult.rows[0].id;

      for (const da of data.dimensionAssessments) {
        await client.query(
          `INSERT INTO rubric_dimension_assessments
             (tenant_id, completion_id, dimension_id, descriptor_level_id, numeric_value, assessor_note)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [tenantId, completionId, da.dimensionId, da.descriptorLevelId, da.numericValue, da.assessorNote || null]
        );
      }

      completionIds.push(completionId);

      await insertAuditLog({
        tenantId,
        eventType: 'RUBRIC.COMPLETED',
        entityType: 'RUBRIC_COMPLETION_RECORDS',
        entityId: completionId,
        performedBy: userId,
        afterState: { studentId, templateId: data.templateId, overallValue },
      }, client);
    }

    return { completionIds };
  }, tenantId, userId, userRole);
}

export async function getAssessmentContext(
  tenantId: string,
  userId: string,
  userRole: string,
  studentId: string
) {
  return withTransaction(async (client) => {
    const activeOverlays = await client.query(
      `SELECT ro.id, ro.competency_ids, ro.modifications, ro.modified_mastery_threshold,
              ro.effective_from, ro.effective_until
       FROM rubric_overlays ro
       WHERE ro.student_id = $1 AND ro.status = 'ACTIVE'
         AND ro.effective_from <= CURRENT_DATE AND ro.effective_until >= CURRENT_DATE`,
      [studentId]
    );

    const studentResult = await client.query(
      `SELECT sp.id, sp.first_name, sp.last_name, se.class_id, c.stage_id,
              ast.stage_code, ast.display_mode, ast.show_numbers, ast.descriptor_style
       FROM student_profiles sp
       JOIN student_enrolments se ON se.student_id = sp.id AND se.status = 'ACTIVE'
       JOIN classes c ON c.id = se.class_id
       JOIN academic_stages ast ON ast.id = c.stage_id
       WHERE sp.id = $1`,
      [studentId]
    );

    if (studentResult.rows.length === 0) {
      throw new Error('STUDENT_NOT_FOUND');
    }

    return {
      student: studentResult.rows[0],
      activeOverlays: activeOverlays.rows,
      stageDisplay: {
        displayMode: studentResult.rows[0].display_mode,
        showNumbers: studentResult.rows[0].show_numbers,
        descriptorStyle: studentResult.rows[0].descriptor_style,
      },
    };
  }, tenantId, userId, userRole);
}
