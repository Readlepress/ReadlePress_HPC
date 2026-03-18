import { query } from '../config/database';
import { runAggregation } from '../services/mastery.service';
import { analyzeEvidenceExif } from './exif-analysis.job';
import { evaluateTriggerRules } from './intervention-trigger.job';

const DATABASE_URL = process.env.DATABASE_URL || 'postgresql://app_rw:app_rw_dev_password@localhost:5432/readlepress';

let bossInstance: any = null;

export async function startWorker(): Promise<any> {
  const pgBoss = await import('pg-boss');
  const PgBoss = pgBoss.PgBoss;
  const boss = new PgBoss(DATABASE_URL);

  boss.on('error', (error: Error) => console.error('pg-boss error:', error));

  await boss.start();
  bossInstance = boss;
  console.log('pg-boss worker started');

  // ── Job: Mastery Aggregation ──
  await boss.work('mastery-aggregation', async (job: any) => {
    const { tenantId, studentId, competencyId, academicYearId, jobId } = job.data;

    await query(`UPDATE mastery_aggregation_jobs SET status = 'PROCESSING', started_at = now() WHERE id = $1`, [jobId]);

    try {
      await runAggregation(tenantId, studentId, competencyId, academicYearId);
      await query(`UPDATE mastery_aggregation_jobs SET status = 'COMPLETED', completed_at = now() WHERE id = $1`, [jobId]);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      await query(
        `UPDATE mastery_aggregation_jobs SET status = 'FAILED', error_message = $2, retry_count = retry_count + 1 WHERE id = $1`,
        [jobId, message]
      );
      throw err;
    }
  });

  // ── Job: EXIF Analysis ──
  await boss.work('exif-analysis', async (job: any) => {
    const { evidenceId, fileBuffer, schoolLat, schoolLon } = job.data;
    const buffer = Buffer.from(fileBuffer, 'base64');
    await analyzeEvidenceExif(evidenceId, buffer, schoolLat, schoolLon);
  });

  // ── Job: Intervention Trigger Evaluation ──
  await boss.work('intervention-trigger-evaluation', async (job: any) => {
    const { tenantId, ruleId } = job.data;
    await evaluateTriggerRules(tenantId, ruleId);
  });

  // ── Scheduled: Moderation SLA Check (every hour) ──
  await boss.schedule('moderation-sla-check', '0 * * * *', {});
  await boss.work('moderation-sla-check', async () => {
    const result = await query(
      `UPDATE feedback_requests
       SET moderation_overdue = TRUE
       WHERE moderation_status = 'PENDING'
         AND status = 'COMPLETED'
         AND moderation_overdue = FALSE
         AND completed_at + (moderation_sla_hours || ' hours')::interval < now()
       RETURNING id`
    );
    if (result.rowCount && result.rowCount > 0) {
      console.log(`Moderation SLA: flagged ${result.rowCount} overdue requests`);
    }
  });

  // ── Scheduled: Overlay Expiry Notifications (daily at 6 AM) ──
  await boss.schedule('overlay-expiry-check', '0 6 * * *', {});
  await boss.work('overlay-expiry-check', async () => {
    const notifications = [
      { type: '14_DAY', days: 14 },
      { type: '7_DAY', days: 7 },
      { type: '1_DAY', days: 1 },
    ];

    for (const n of notifications) {
      await query(
        `INSERT INTO overlay_expiry_notifications (tenant_id, overlay_id, notification_type, sent_to)
         SELECT ro.tenant_id, ro.id, $1, ro.submitted_by
         FROM rubric_overlays ro
         WHERE ro.status = 'ACTIVE'
           AND ro.effective_until = CURRENT_DATE + $2
           AND NOT EXISTS (
             SELECT 1 FROM overlay_expiry_notifications oen
             WHERE oen.overlay_id = ro.id AND oen.notification_type = $1
           )`,
        [n.type, n.days]
      );
    }

    // Mark expired overlays
    const expired = await query(
      `UPDATE rubric_overlays SET status = 'EXPIRED'
       WHERE status = 'ACTIVE' AND effective_until < CURRENT_DATE
       RETURNING id, tenant_id, submitted_by`
    );

    for (const row of (expired.rows || [])) {
      await query(
        `INSERT INTO overlay_expiry_notifications (tenant_id, overlay_id, notification_type, sent_to)
         VALUES ($1, $2, 'EXPIRED', $3)
         ON CONFLICT DO NOTHING`,
        [row.tenant_id, row.id, row.submitted_by]
      ).catch(() => {});
    }
  });

  // ── Scheduled: Consent Witness Confirmation Deadline (daily at 8 AM) ──
  await boss.schedule('consent-witness-deadline', '0 8 * * *', {});
  await boss.work('consent-witness-deadline', async () => {
    const overdue = await query(
      `SELECT wcr.id, wcr.consent_record_id, wcr.tenant_id, wcr.witness_user_id
       FROM witnessed_consent_records wcr
       WHERE wcr.principal_confirmed = FALSE
         AND wcr.confirmation_deadline < now()`
    );

    for (const row of overdue.rows) {
      await query(
        `INSERT INTO audit_log (tenant_id, event_type, entity_type, entity_id, performed_by, metadata)
         VALUES ($1, 'CONSENT.WITNESS_CONFIRMATION_OVERDUE', 'WITNESSED_CONSENT_RECORDS', $2, $3, $4::jsonb)`,
        [
          row.tenant_id, row.id, row.witness_user_id,
          JSON.stringify({ consentRecordId: row.consent_record_id, action: 'ESCALATION_REQUIRED' }),
        ]
      );
    }

    if (overdue.rows.length > 0) {
      console.log(`Consent witness deadline: ${overdue.rows.length} overdue confirmations escalated`);
    }
  });

  // ── Scheduled: Intervention Trigger Evaluation (every 4 hours) ──
  await boss.schedule('intervention-trigger-scan', '0 */4 * * *', {});
  await boss.work('intervention-trigger-scan', async () => {
    const rules = await query(
      `SELECT DISTINCT itr.id, itr.tenant_id
       FROM intervention_trigger_rules itr
       WHERE itr.is_active = TRUE`
    );

    for (const rule of rules.rows) {
      await boss.send('intervention-trigger-evaluation', {
        tenantId: rule.tenant_id,
        ruleId: rule.id,
      });
    }
  });

  return boss;
}

export async function enqueueAggregationJob(
  tenantId: string,
  studentId: string,
  competencyId: string,
  academicYearId: string | undefined,
  jobId: string
): Promise<void> {
  if (bossInstance) {
    await bossInstance.send('mastery-aggregation', {
      tenantId, studentId, competencyId, academicYearId, jobId,
    });
  }
}

export async function enqueueExifAnalysis(
  evidenceId: string,
  fileBuffer: Buffer,
  schoolLat?: number,
  schoolLon?: number
): Promise<void> {
  if (bossInstance) {
    await bossInstance.send('exif-analysis', {
      evidenceId,
      fileBuffer: fileBuffer.toString('base64'),
      schoolLat,
      schoolLon,
    });
  }
}
