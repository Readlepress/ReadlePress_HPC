import { withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';

export async function registerPartner(
  tenantId: string,
  userId: string,
  userRole: string,
  data: {
    name: string;
    organizationType: string;
    contactEmail: string;
    contactPhone?: string;
    description?: string;
  }
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO community_partners
         (tenant_id, name, organization_type, contact_email, contact_phone,
          description, vetting_status, is_active, registered_by)
       VALUES ($1, $2, $3, $4, $5, $6, 'PENDING', TRUE, $7)
       RETURNING id`,
      [
        tenantId, data.name, data.organizationType, data.contactEmail,
        data.contactPhone || null, data.description || null, userId,
      ]
    );

    const partnerId = result.rows[0].id;

    await insertAuditLog({
      tenantId,
      eventType: 'COMMUNITY_PARTNER.REGISTERED',
      entityType: 'COMMUNITY_PARTNERS',
      entityId: partnerId,
      performedBy: userId,
      afterState: { name: data.name },
    }, client);

    return { partnerId, status: 'PENDING' };
  }, tenantId, userId, userRole);
}

export async function logEngagementSession(
  tenantId: string,
  userId: string,
  userRole: string,
  data: {
    partnerId: string;
    schoolId: string;
    sessionDate: string;
    durationMinutes: number;
    participantCount: number;
    description: string;
  }
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `INSERT INTO engagement_sessions
         (tenant_id, partner_id, school_id, session_date, duration_minutes,
          participant_count, description, recorded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id`,
      [
        tenantId, data.partnerId, data.schoolId, data.sessionDate,
        data.durationMinutes, data.participantCount, data.description, userId,
      ]
    );

    const sessionId = result.rows[0].id;

    await insertAuditLog({
      tenantId,
      eventType: 'ENGAGEMENT_SESSION.LOGGED',
      entityType: 'ENGAGEMENT_SESSIONS',
      entityId: sessionId,
      performedBy: userId,
    }, client);

    return { sessionId };
  }, tenantId, userId, userRole);
}

export async function listPartners(
  tenantId: string,
  userId: string,
  userRole: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT id, name, organization_type, contact_email, contact_phone,
              vetting_status, is_active, created_at
       FROM community_partners
       WHERE is_active = TRUE
       ORDER BY name`
    );
    return result.rows;
  }, tenantId, userId, userRole);
}

export async function getEngagementAggregates(
  tenantId: string,
  userId: string,
  userRole: string
) {
  return withTransaction(async (client) => {
    const result = await client.query(
      `SELECT cp.id AS partner_id, cp.name AS partner_name,
              COUNT(es.id) AS session_count,
              SUM(es.duration_minutes) AS total_minutes,
              SUM(es.participant_count) AS total_participants
       FROM community_partners cp
       LEFT JOIN engagement_sessions es ON es.partner_id = cp.id
       WHERE cp.is_active = TRUE
       GROUP BY cp.id, cp.name
       ORDER BY cp.name`
    );
    return result.rows;
  }, tenantId, userId, userRole);
}
