import { query, withTransaction } from '../config/database';
import { insertAuditLog } from './audit.service';
import { requestTimestamp } from './tsa.service';
import { anchorMerkleRoot } from './blockchain.service';

export async function listAcademicYears(tenantId: string, userId: string, userRole: string, schoolId?: string) {
  return withTransaction(async (client) => {
    const result = schoolId
      ? await client.query(
          `SELECT id, label, start_date, end_date, status, locked_at
           FROM academic_years WHERE school_id = $1 ORDER BY start_date DESC`,
          [schoolId]
        )
      : await client.query(
          `SELECT id, label, start_date, end_date, status, locked_at
           FROM academic_years ORDER BY start_date DESC`
        );
    return result.rows;
  }, tenantId, userId, userRole);
}

export async function initiateYearClose(
  tenantId: string,
  academicYearId: string,
  performedBy: string,
  userRole: string
) {
  return withTransaction(async (client) => {
    const yearResult = await client.query(
      'SELECT id, status, school_id FROM academic_years WHERE id = $1',
      [academicYearId]
    );

    if (yearResult.rows.length === 0) {
      throw new Error('YEAR_NOT_FOUND');
    }

    const year = yearResult.rows[0];
    if (year.status !== 'REVIEW') {
      throw new Error('YEAR_NOT_IN_REVIEW');
    }

    const checks = await client.query(
      'SELECT * FROM check_year_close_readiness($1, $2)',
      [academicYearId, tenantId]
    );

    const failedChecks = checks.rows.filter((c: { check_result: string; blocking: boolean }) =>
      c.check_result === 'FAIL' && c.blocking
    );

    if (failedChecks.length > 0) {
      for (const check of checks.rows) {
        await client.query(
          `INSERT INTO year_close_completeness_checks
             (tenant_id, academic_year_id, check_type, check_result, blocking, details, checked_by)
           VALUES ($1, $2, $3, $4, $5, $6, $7)`,
          [tenantId, academicYearId, check.check_type, check.check_result, check.blocking, check.details, performedBy]
        );
      }

      return {
        status: 'BLOCKED',
        failedChecks: failedChecks.map((c: { check_type: string; details: unknown }) => ({
          type: c.check_type,
          details: c.details,
        })),
        allChecks: checks.rows,
      };
    }

    const merkle = await client.query(
      'SELECT * FROM compute_merkle_root($1, $2)',
      [academicYearId, tenantId]
    );

    const merkleResult = merkle.rows[0];

    const schoolResult = await client.query(
      `SELECT s.name, s.udise_code FROM schools s WHERE s.id = $1`,
      [year.school_id]
    );

    const snapshotResult = await client.query(
      `INSERT INTO year_snapshots
         (tenant_id, academic_year_id, merkle_root_hash, total_leaf_count, tree_depth,
          snapshot_hash, taxonomy_snapshot, school_identity_snapshot)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id`,
      [
        tenantId, academicYearId,
        merkleResult.root_hash, merkleResult.leaf_count, merkleResult.tree_depth,
        merkleResult.root_hash,
        JSON.stringify({ computed_at: new Date().toISOString() }),
        JSON.stringify(schoolResult.rows[0] || {}),
      ]
    );

    let externalAnchorRef: string | null = null;
    let externalAnchorTimestamp: Date | null = null;
    try {
      const tsaResult = await requestTimestamp(merkleResult.root_hash);
      externalAnchorRef = tsaResult.anchorRef;
      externalAnchorTimestamp = tsaResult.timestamp;
      await client.query(
        `UPDATE year_snapshots SET external_anchor_ref = $1, external_anchor_timestamp = $2, tsa_response = $3 WHERE id = $4`,
        [externalAnchorRef, externalAnchorTimestamp, tsaResult.timestampToken, snapshotResult.rows[0].id]
      );
    } catch (err) {
      console.warn('[AcademicYear] TSA request failed, storing TSA_UNAVAILABLE:', err);
      externalAnchorRef = 'TSA_UNAVAILABLE';
      await client.query(
        `UPDATE year_snapshots SET external_anchor_ref = $1 WHERE id = $2`,
        [externalAnchorRef, snapshotResult.rows[0].id]
      );
    }

    try {
      const blockchainResult = await anchorMerkleRoot(tenantId, snapshotResult.rows[0].id, merkleResult.root_hash);
      await client.query(
        `UPDATE year_snapshots SET blockchain_tx_hash = $1, blockchain_block_number = $2, blockchain_chain = $3 WHERE id = $4`,
        [blockchainResult.transactionHash, blockchainResult.blockNumber, blockchainResult.chainName, snapshotResult.rows[0].id]
      );
    } catch (err) {
      console.warn('Blockchain anchoring failed (non-fatal):', err);
    }

    await client.query(
      `UPDATE academic_years SET status = 'LOCKED', year_snapshot_id = $1, locked_by = $2 WHERE id = $3`,
      [snapshotResult.rows[0].id, performedBy, academicYearId]
    );

    await insertAuditLog({
      tenantId,
      eventType: 'ACADEMIC_YEAR.LOCKED',
      entityType: 'ACADEMIC_YEARS',
      entityId: academicYearId,
      performedBy,
      afterState: {
        merkleRoot: merkleResult.root_hash,
        leafCount: merkleResult.leaf_count,
        snapshotId: snapshotResult.rows[0].id,
      },
    }, client);

    return {
      status: 'LOCKED',
      snapshotId: snapshotResult.rows[0].id,
      merkleRoot: merkleResult.root_hash,
      leafCount: merkleResult.leaf_count,
    };
  }, tenantId, performedBy, userRole);
}
