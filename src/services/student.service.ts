import { PoolClient } from 'pg';
import { query, withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function listStudentsByClass(tenantId: string, userId: string, userRole: string) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT sp.id, sp.apaar_id, sp.first_name, sp.last_name,
              sp.date_of_birth, sp.gender, sp.dedup_status,
              se.class_id, se.roll_number, se.status as enrolment_status,
              c.grade, c.section
       FROM student_profiles sp
       JOIN student_enrolments se ON se.student_id = sp.id AND se.status = 'ACTIVE'
       JOIN classes c ON c.id = se.class_id
       WHERE sp.dedup_status NOT IN ('CONFIRMED_DUPLICATE')
       ORDER BY se.roll_number, sp.first_name`,
    );
    return result.rows;
  }, tenantId, userId, userRole);
}

export async function enrolStudent(
  tenantId: string,
  studentId: string,
  classId: string,
  academicYearLabel: string,
  rollNumber: string | null,
  performedBy: string,
  userRole: string
) {
  return withTransaction(async (client) => {
    const consentCheck = await client.query(
      `SELECT id FROM data_consent_records
       WHERE tenant_id = $1 AND student_id = $2
         AND consent_purpose_code = 'EDUCATIONAL_RECORD'
         AND consent_status = 'ACTIVE'`,
      [tenantId, studentId]
    );

    if (consentCheck.rows.length === 0) {
      throw new Error('CONSENT_REQUIRED');
    }

    const result = await client.query(
      `INSERT INTO student_enrolments (tenant_id, student_id, class_id, academic_year_label, roll_number)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [tenantId, studentId, classId, academicYearLabel, rollNumber]
    );

    await insertAuditLog({
      tenantId,
      eventType: 'STUDENT.ENROLLED',
      entityType: 'STUDENT_ENROLMENTS',
      entityId: result.rows[0].id,
      performedBy,
      afterState: { studentId, classId, academicYearLabel },
    }, client);

    return result.rows[0];
  }, tenantId, performedBy, userRole);
}
