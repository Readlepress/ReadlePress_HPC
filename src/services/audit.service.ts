import { PoolClient } from 'pg';
import { query, withTransaction } from '../config/database';

export interface AuditLogEntry {
  tenantId: string;
  eventType: string;
  entityType: string;
  entityId: string;
  performedBy: string;
  beforeState?: Record<string, unknown>;
  afterState?: Record<string, unknown>;
  metadata?: Record<string, unknown>;
  ipAddress?: string;
}

export async function insertAuditLog(entry: AuditLogEntry, client?: PoolClient): Promise<string> {
  const sql = `SELECT insert_audit_log($1, $2, $3, $4::uuid, $5::uuid, $6, $7, $8, $9) AS id`;
  const params = [
    entry.tenantId,
    entry.eventType,
    entry.entityType,
    entry.entityId,
    entry.performedBy,
    entry.beforeState ? JSON.stringify(entry.beforeState) : null,
    entry.afterState ? JSON.stringify(entry.afterState) : null,
    entry.metadata ? JSON.stringify(entry.metadata) : null,
    entry.ipAddress || null,
  ];

  const result = client ? await client.query(sql, params) : await query(sql, params);
  return result.rows[0].id;
}

export async function verifyAuditChain(tenantId: string): Promise<{
  totalRecords: number;
  brokenChains: number;
  firstBrokenId: string | null;
}> {
  const result = await query('SELECT * FROM verify_audit_chain($1)', [tenantId]);
  const row = result.rows[0];
  return {
    totalRecords: Number(row.total_records),
    brokenChains: Number(row.broken_chains),
    firstBrokenId: row.first_broken_id,
  };
}
