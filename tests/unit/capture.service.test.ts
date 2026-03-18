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

import { syncOfflineCapture } from '../../src/services/capture.service';

function makeDraft(overrides: Record<string, unknown> = {}) {
  const now = new Date();
  return {
    localId: `local-${Math.random().toString(36).slice(2)}`,
    studentId: 'student-1',
    competencyId: 'comp-1',
    observedAt: new Date(now.getTime() - 60 * 60 * 1000).toISOString(),
    recordedAt: now.toISOString(),
    timestampSource: 'DEVICE',
    timestampConfidence: 'HIGH',
    numericValue: 0.75,
    observationNote: 'Good progress shown',
    sourceType: 'DIRECT_OBSERVATION',
    ...overrides,
  };
}

describe('CaptureService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('syncOfflineCapture', () => {
    test('idempotent sync: same local_id not duplicated', async () => {
      const draft = makeDraft({ localId: 'duplicate-test-001' });

      // First call: not found → insert
      mockClientQuery
        // existing check → already synced
        .mockResolvedValueOnce({
          rows: [{ id: 'draft-existing', sync_status: 'SYNCED' }],
        });

      const result = await syncOfflineCapture('tenant-1', 'teacher-1', 'user-1', 'CLASS_TEACHER', [draft]);

      expect(result.results).toHaveLength(1);
      expect(result.results[0].status).toBe('ALREADY_SYNCED');
      expect(result.results[0].localId).toBe('duplicate-test-001');
      expect(result.results[0].draftId).toBe('draft-existing');
    });

    test('future timestamp rejection', async () => {
      const futureDate = new Date(Date.now() + 24 * 60 * 60 * 1000);
      const draft = makeDraft({ observedAt: futureDate.toISOString() });

      mockClientQuery
        // existing check → not found
        .mockResolvedValueOnce({ rows: [] });

      const result = await syncOfflineCapture('tenant-1', 'teacher-1', 'user-1', 'CLASS_TEACHER', [draft]);

      expect(result.results).toHaveLength(1);
      expect(result.results[0].status).toBe('REJECTED');
      expect(result.results[0].reason).toBe('FUTURE_TIMESTAMP');
    });

    test('stale timestamp (>90 days) rejection', async () => {
      const staleDate = new Date(Date.now() - 100 * 24 * 60 * 60 * 1000);
      const draft = makeDraft({ observedAt: staleDate.toISOString() });

      mockClientQuery
        .mockResolvedValueOnce({ rows: [] });

      const result = await syncOfflineCapture('tenant-1', 'teacher-1', 'user-1', 'CLASS_TEACHER', [draft]);

      expect(result.results).toHaveLength(1);
      expect(result.results[0].status).toBe('REJECTED');
      expect(result.results[0].reason).toBe('STALE_TIMESTAMP');
    });

    test('observed_at preserved exactly from device', async () => {
      const exactTimestamp = '2026-03-10T14:30:00.123Z';
      const draft = makeDraft({ observedAt: exactTimestamp });

      mockClientQuery
        // existing check
        .mockResolvedValueOnce({ rows: [] })
        // conflict check
        .mockResolvedValueOnce({ rows: [] })
        // teacher profile lookup
        .mockResolvedValueOnce({ rows: [{ id: 'tp-1' }] })
        // insert
        .mockResolvedValueOnce({ rows: [{ id: 'new-draft-1' }] });

      const result = await syncOfflineCapture('tenant-1', 'teacher-1', 'user-1', 'CLASS_TEACHER', [draft]);

      expect(result.results).toHaveLength(1);
      expect(result.results[0].status).toBe('SYNCED');

      // Verify the INSERT statement was called with the exact timestamp
      const insertCall = mockClientQuery.mock.calls[3];
      expect(insertCall[1]).toContain(exactTimestamp);
    });

    test('successful sync with valid draft', async () => {
      const draft = makeDraft();

      mockClientQuery
        // existing check
        .mockResolvedValueOnce({ rows: [] })
        // conflict check
        .mockResolvedValueOnce({ rows: [] })
        // teacher profile
        .mockResolvedValueOnce({ rows: [{ id: 'tp-1' }] })
        // insert
        .mockResolvedValueOnce({ rows: [{ id: 'new-draft-1' }] });

      const result = await syncOfflineCapture('tenant-1', 'teacher-1', 'user-1', 'CLASS_TEACHER', [draft]);

      expect(result.results).toHaveLength(1);
      expect(result.results[0].status).toBe('SYNCED');
      expect(result.results[0].draftId).toBe('new-draft-1');
      expect(result.conflicts).toHaveLength(0);
    });
  });
});
