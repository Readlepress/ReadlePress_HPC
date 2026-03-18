import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';
import { encrypt, decrypt } from '../utils/encryption';

export async function createDisabilityProfile(
  tenantId: string,
  userId: string,
  userRole: string,
  studentId: string,
  data: {
    udidNumber?: string;
    udidDisabilityCategory?: string;
    disabilityCategory: string;
    disabilityTier: string;
    supportNeeds?: string[];
    consentRecordId?: string;
  }
) {
  return withTransaction(async (client) => {
    // Verify DISABILITY_DATA consent
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

    // Encrypt UDID fields at application layer
    const encryptedUdidNumber = data.udidNumber ? encrypt(data.udidNumber) : null;
    const encryptedUdidCategory = data.udidDisabilityCategory ? encrypt(data.udidDisabilityCategory) : null;

    const result = await client.query(
      `INSERT INTO student_disability_profiles
         (tenant_id, student_id, udid_number_encrypted, udid_disability_category_encrypted,
          disability_category, disability_tier, support_needs, consent_record_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (tenant_id, student_id) DO UPDATE SET
         udid_number_encrypted = EXCLUDED.udid_number_encrypted,
         udid_disability_category_encrypted = EXCLUDED.udid_disability_category_encrypted,
         disability_category = EXCLUDED.disability_category,
         disability_tier = EXCLUDED.disability_tier,
         support_needs = EXCLUDED.support_needs,
         updated_at = now()
       RETURNING id`,
      [
        tenantId, studentId, encryptedUdidNumber, encryptedUdidCategory,
        data.disabilityCategory, data.disabilityTier,
        data.supportNeeds || [], data.consentRecordId || null,
      ]
    );

    await insertAuditLog({
      tenantId,
      eventType: 'DISABILITY_DATA.CREATED',
      entityType: 'STUDENT_DISABILITY_PROFILES',
      entityId: result.rows[0].id,
      performedBy: userId,
      afterState: { studentId, disabilityCategory: data.disabilityCategory },
    }, client);

    return { id: result.rows[0].id };
  }, tenantId, userId, userRole);
}

export async function getDisabilityProfile(
  tenantId: string,
  userId: string,
  userRole: string,
  studentId: string
) {
  return withTransaction(async (client) => {
    // Check STUDENT:READ_SENSITIVE permission
    const permCheck = await client.query(
      `SELECT 1 FROM role_permissions rp
       JOIN permissions p ON p.id = rp.permission_id
       JOIN role_assignments ra ON ra.role_code = rp.role_code
       WHERE ra.user_id = $1 AND p.code = 'STUDENT:READ_SENSITIVE' AND ra.is_active = TRUE`,
      [userId]
    );

    if (permCheck.rows.length === 0) {
      throw new Error('STUDENT_READ_SENSITIVE_REQUIRED');
    }

    const result = await client.query(
      `SELECT * FROM student_disability_profiles WHERE student_id = $1`,
      [studentId]
    );

    if (result.rows.length === 0) {
      throw new Error('PROFILE_NOT_FOUND');
    }

    const profile = result.rows[0];

    // Log access
    await insertAuditLog({
      tenantId,
      eventType: 'DISABILITY_DATA.ACCESSED',
      entityType: 'STUDENT_DISABILITY_PROFILES',
      entityId: profile.id,
      performedBy: userId,
    }, client);

    // Decrypt UDID fields only for INCLUSION_COORDINATOR or PRINCIPAL
    const canSeeUdid = ['INCLUSION_COORDINATOR', 'PRINCIPAL', 'PLATFORM_ADMIN'].includes(userRole);

    return {
      ...profile,
      udid_number: canSeeUdid && profile.udid_number_encrypted
        ? decrypt(profile.udid_number_encrypted)
        : undefined,
      udid_disability_category: canSeeUdid && profile.udid_disability_category_encrypted
        ? decrypt(profile.udid_disability_category_encrypted)
        : undefined,
      udid_number_encrypted: undefined,
      udid_disability_category_encrypted: undefined,
    };
  }, tenantId, userId, userRole);
}
