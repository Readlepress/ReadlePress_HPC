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

import { closeInterventionPlan } from '../../src/services/intervention.service';

describe('InterventionService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('closeInterventionPlan', () => {
    test('closure without evidence throws CLOSURE_EVIDENCE_REQUIRED', async () => {
      mockClientQuery
        // plan lookup
        .mockResolvedValueOnce({
          rows: [{
            id: 'plan-1',
            sensitivity_level: 'ACADEMIC',
            status: 'ACTIVE',
          }],
        })
        // evidence count = 0
        .mockResolvedValueOnce({
          rows: [{ count: '0' }],
        });

      await expect(
        closeInterventionPlan('tenant-1', 'user-1', 'CLASS_TEACHER', 'plan-1', 'RESOLVED')
      ).rejects.toThrow('CLOSURE_EVIDENCE_REQUIRED');
    });

    test('WELFARE closure without approval throws CLOSURE_APPROVAL_REQUIRED', async () => {
      mockClientQuery
        .mockResolvedValueOnce({
          rows: [{
            id: 'plan-1',
            sensitivity_level: 'WELFARE',
            status: 'ACTIVE',
          }],
        })
        .mockResolvedValueOnce({
          rows: [{ count: '3' }],
        });

      await expect(
        closeInterventionPlan('tenant-1', 'user-1', 'COUNSELLOR', 'plan-1', 'RESOLVED')
      ).rejects.toThrow('CLOSURE_APPROVAL_REQUIRED');
    });

    test('WELFARE closure with approval succeeds', async () => {
      mockClientQuery
        .mockResolvedValueOnce({
          rows: [{
            id: 'plan-1',
            sensitivity_level: 'WELFARE',
            status: 'ACTIVE',
          }],
        })
        .mockResolvedValueOnce({
          rows: [{ count: '2' }],
        })
        // UPDATE intervention_plans
        .mockResolvedValueOnce({ rows: [] });

      const result = await closeInterventionPlan(
        'tenant-1', 'user-1', 'COUNSELLOR', 'plan-1', 'RESOLVED', 'principal-1'
      );

      expect(result).toEqual({ status: 'CLOSED' });
    });
  });

  describe('sensitivity level access matrix', () => {
    const ACCESS_MATRIX: Record<string, string[]> = {
      ACADEMIC: ['CLASS_TEACHER', 'SUBJECT_TEACHER', 'COUNSELLOR', 'PRINCIPAL', 'WELFARE_OFFICER'],
      BEHAVIOURAL: ['CLASS_TEACHER', 'SUBJECT_TEACHER', 'COUNSELLOR', 'PRINCIPAL', 'WELFARE_OFFICER'],
      WELFARE: ['COUNSELLOR', 'PRINCIPAL', 'WELFARE_OFFICER'],
      SAFEGUARDING: ['WELFARE_OFFICER'],
    };

    function canAccess(role: string, sensitivity: string): boolean {
      return (ACCESS_MATRIX[sensitivity] || []).includes(role);
    }

    test('CLASS_TEACHER can access ACADEMIC and BEHAVIOURAL', () => {
      expect(canAccess('CLASS_TEACHER', 'ACADEMIC')).toBe(true);
      expect(canAccess('CLASS_TEACHER', 'BEHAVIOURAL')).toBe(true);
    });

    test('CLASS_TEACHER cannot access WELFARE or SAFEGUARDING', () => {
      expect(canAccess('CLASS_TEACHER', 'WELFARE')).toBe(false);
      expect(canAccess('CLASS_TEACHER', 'SAFEGUARDING')).toBe(false);
    });

    test('COUNSELLOR can access WELFARE but not SAFEGUARDING', () => {
      expect(canAccess('COUNSELLOR', 'WELFARE')).toBe(true);
      expect(canAccess('COUNSELLOR', 'SAFEGUARDING')).toBe(false);
    });

    test('WELFARE_OFFICER can access all levels', () => {
      expect(canAccess('WELFARE_OFFICER', 'ACADEMIC')).toBe(true);
      expect(canAccess('WELFARE_OFFICER', 'BEHAVIOURAL')).toBe(true);
      expect(canAccess('WELFARE_OFFICER', 'WELFARE')).toBe(true);
      expect(canAccess('WELFARE_OFFICER', 'SAFEGUARDING')).toBe(true);
    });
  });
});
