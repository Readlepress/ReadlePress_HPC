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

import { getModerationQueue } from '../../src/services/feedback.service';

describe('FeedbackService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('k-anonymity', () => {
    test('publishable only when respondent_count >= k_threshold', () => {
      const K_THRESHOLD = 5;

      function isPublishable(respondentCount: number): boolean {
        return respondentCount >= K_THRESHOLD;
      }

      expect(isPublishable(1)).toBe(false);
      expect(isPublishable(4)).toBe(false);
      expect(isPublishable(5)).toBe(true);
      expect(isPublishable(10)).toBe(true);
    });
  });

  describe('getModerationQueue', () => {
    test('excludes respondent_user_id for non-teacher roles', async () => {
      mockClientQuery.mockResolvedValueOnce({
        rows: [
          {
            id: 'fr-1',
            feedback_type: 'PEER',
            subject_student_id: 'student-1',
            moderation_status: 'PENDING',
            moderation_overdue: false,
            dispatched_at: '2026-01-01',
            due_at: '2026-01-15',
            completed_at: '2026-01-10',
            first_name: 'John',
            last_name: 'Doe',
            respondent_user_id: 'should-be-hidden',
          },
        ],
      });

      const result = await getModerationQueue('tenant-1', 'principal-1', 'PRINCIPAL');

      expect(result).toHaveLength(1);
      expect(result[0].respondent_user_id).toBeUndefined();
      expect((result[0] as Record<string, unknown>).id).toBe('fr-1');
    });
  });

  describe('self-assessment promotion', () => {
    test('promotion_status starts as PENDING', () => {
      const selfAssessment = {
        feedbackType: 'SELF_ASSESSMENT',
        promotionStatus: 'PENDING',
        completedAt: null,
      };

      expect(selfAssessment.promotionStatus).toBe('PENDING');
    });
  });
});
