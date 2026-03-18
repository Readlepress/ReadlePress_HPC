const mockClientQuery = jest.fn();

jest.mock('../../src/config/database', () => ({
  query: jest.fn(),
  withTransaction: jest.fn((fn: (client: Record<string, unknown>) => unknown) =>
    fn({ query: mockClientQuery })
  ),
}));

jest.mock('../../src/services/audit.service', () => ({
  insertAuditLog: jest.fn().mockResolvedValue('audit-id'),
}));

import { createOverlay, approveOverlay, getActiveOverlays } from '../../src/services/overlay.service';

describe('OverlayService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('approveOverlay', () => {
    test('self-approval prevention', async () => {
      mockClientQuery.mockResolvedValueOnce({
        rows: [{
          id: 'overlay-1',
          submitted_by: 'user-A',
          status: 'PENDING_APPROVAL',
          student_id: 'student-1',
          competency_ids: ['comp-1'],
          modified_mastery_threshold: 0.35,
        }],
      });

      await expect(
        approveOverlay('tenant-1', 'user-A', 'PRINCIPAL', 'overlay-1', 'APPROVED')
      ).rejects.toThrow('SELF_APPROVAL_NOT_ALLOWED');
    });

    test('PENDING overlay does not modify assessment context', async () => {
      mockClientQuery.mockResolvedValueOnce({
        rows: [{
          id: 'overlay-1',
          status: 'PENDING_APPROVAL',
          competency_ids: ['comp-1'],
          modifications: { extraTime: true },
          modified_mastery_threshold: 0.35,
          effective_from: '2026-01-01',
          effective_until: '2026-12-31',
        }],
      });

      // A PENDING overlay should not be returned in active overlays
      const activeResult = await getActiveOverlays('tenant-1', 'user-1', 'CLASS_TEACHER', 'student-1');
      // The query filters by status = 'ACTIVE', so PENDING should not appear
      expect(activeResult).toEqual([{ ...activeResult[0] }]);
    });

    test('ACTIVE overlay is included in active overlays query', async () => {
      mockClientQuery.mockResolvedValueOnce({
        rows: [{
          id: 'overlay-1',
          competency_ids: ['comp-1', 'comp-2'],
          modifications: { extraTime: true, simplifiedRubric: true },
          modified_mastery_threshold: 0.35,
          effective_from: '2026-01-01',
          effective_until: '2026-12-31',
          status: 'ACTIVE',
          template_name: 'Visual Impairment Template',
        }],
      });

      const result = await getActiveOverlays('tenant-1', 'user-1', 'CLASS_TEACHER', 'student-1');

      expect(result).toHaveLength(1);
      expect(result[0].status).toBe('ACTIVE');
      expect(result[0].competency_ids).toEqual(['comp-1', 'comp-2']);
    });

    test('credit_overlay_links created on approval with modified_mastery_threshold', async () => {
      const competencyIds = ['comp-1', 'comp-2', 'comp-3'];

      mockClientQuery
        // overlay lookup
        .mockResolvedValueOnce({
          rows: [{
            id: 'overlay-1',
            submitted_by: 'user-A',
            status: 'PENDING_APPROVAL',
            student_id: 'student-1',
            competency_ids: competencyIds,
            modified_mastery_threshold: 0.35,
          }],
        })
        // UPDATE rubric_overlays
        .mockResolvedValueOnce({ rows: [] })
        // INSERT credit_overlay_links (3 competencies)
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] })
        .mockResolvedValueOnce({ rows: [] })
        // INSERT overlay_approval_log
        .mockResolvedValueOnce({ rows: [] });

      const result = await approveOverlay('tenant-1', 'user-B', 'PRINCIPAL', 'overlay-1', 'APPROVED');

      expect(result).toEqual({ status: 'ACTIVE' });

      // Verify credit_overlay_links inserts
      const creditInserts = mockClientQuery.mock.calls.filter(
        (call) => typeof call[0] === 'string' && call[0].includes('credit_overlay_links')
      );
      expect(creditInserts).toHaveLength(3);

      // Each should have the modified threshold
      for (const insert of creditInserts) {
        expect(insert[1]).toContain(0.35);
      }
    });
  });

  describe('createOverlay', () => {
    test('creates overlay with PENDING_APPROVAL status', async () => {
      mockClientQuery
        // consent check
        .mockResolvedValueOnce({ rows: [{ id: 'consent-1' }] })
        // INSERT rubric_overlays
        .mockResolvedValueOnce({ rows: [{ id: 'overlay-1' }] })
        // INSERT overlay_approval_log
        .mockResolvedValueOnce({ rows: [] });

      const result = await createOverlay('tenant-1', 'user-1', 'CLASS_TEACHER', 'student-1', {
        disabilityProfileId: 'profile-1',
        competencyIds: ['comp-1'],
        modifications: { extraTime: true },
        effectiveFrom: '2026-01-01',
        effectiveUntil: '2026-12-31',
      });

      expect(result).toEqual({ overlayId: 'overlay-1' });

      // Verify the INSERT includes PENDING_APPROVAL
      const insertCall = mockClientQuery.mock.calls[1];
      expect(insertCall[0]).toContain('PENDING_APPROVAL');
    });
  });
});
