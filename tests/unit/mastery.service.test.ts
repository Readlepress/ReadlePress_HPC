const mockQuery = jest.fn();
const mockWithTransaction = jest.fn();

jest.mock('../../src/config/database', () => ({
  query: (...args: unknown[]) => mockQuery(...args),
  withTransaction: (...args: unknown[]) => mockWithTransaction(...args),
}));

jest.mock('../../src/services/audit.service', () => ({
  insertAuditLog: jest.fn().mockResolvedValue('audit-id'),
}));

import { runAggregation } from '../../src/services/mastery.service';

describe('MasteryService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('runAggregation', () => {
    test('computes EWM correctly', async () => {
      const ewmValue = 0.72;

      mockQuery
        // compute_ewm call
        .mockResolvedValueOnce({ rows: [{ ewm: ewmValue }] })
        // event count
        .mockResolvedValueOnce({
          rows: [{ count: '8', last_event_at: '2026-03-01T10:00:00Z' }],
        })
        // recent events for trend (count >= 3)
        .mockResolvedValueOnce({
          rows: [
            { numeric_value: '0.80', observed_at: '2026-03-01' },
            { numeric_value: '0.75', observed_at: '2026-02-15' },
            { numeric_value: '0.60', observed_at: '2026-02-01' },
            { numeric_value: '0.55', observed_at: '2026-01-15' },
            { numeric_value: '0.50', observed_at: '2026-01-01' },
          ],
        })
        // upsert mastery_aggregates
        .mockResolvedValueOnce({ rows: [] });

      const result = await runAggregation('tenant-1', 'student-1', 'comp-1', 'year-1');

      expect(result.ewm).toBe(ewmValue);
      expect(result.eventCount).toBe(8);
      expect(typeof result.confidence).toBe('number');
    });

    test('trend detection: IMPROVING when recent avg exceeds older avg by > 0.05', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ ewm: 0.8 }] })
        .mockResolvedValueOnce({
          rows: [{ count: '5', last_event_at: '2026-03-01' }],
        })
        .mockResolvedValueOnce({
          rows: [
            { numeric_value: '0.90', observed_at: '2026-03-01' },
            { numeric_value: '0.85', observed_at: '2026-02-15' },
            { numeric_value: '0.60', observed_at: '2026-02-01' },
            { numeric_value: '0.55', observed_at: '2026-01-15' },
            { numeric_value: '0.50', observed_at: '2026-01-01' },
          ],
        })
        .mockResolvedValueOnce({ rows: [] });

      const result = await runAggregation('tenant-1', 'student-1', 'comp-1');

      // avgRecent = (0.90 + 0.85) / 2 = 0.875
      // avgOlder = (0.60 + 0.55 + 0.50) / 3 = 0.55
      // 0.875 > 0.55 + 0.05 → IMPROVING
      expect(result.trendDirection).toBe('IMPROVING');
    });

    test('trend detection: STABLE when difference is within 0.05', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ ewm: 0.7 }] })
        .mockResolvedValueOnce({
          rows: [{ count: '5', last_event_at: '2026-03-01' }],
        })
        .mockResolvedValueOnce({
          rows: [
            { numeric_value: '0.72', observed_at: '2026-03-01' },
            { numeric_value: '0.70', observed_at: '2026-02-15' },
            { numeric_value: '0.71', observed_at: '2026-02-01' },
            { numeric_value: '0.69', observed_at: '2026-01-15' },
            { numeric_value: '0.70', observed_at: '2026-01-01' },
          ],
        })
        .mockResolvedValueOnce({ rows: [] });

      const result = await runAggregation('tenant-1', 'student-1', 'comp-1');

      // avgRecent = (0.72 + 0.70) / 2 = 0.71
      // avgOlder = (0.71 + 0.69 + 0.70) / 3 = 0.70
      // 0.71 is NOT > 0.70 + 0.05 AND NOT < 0.70 - 0.05 → STABLE
      expect(result.trendDirection).toBe('STABLE');
    });

    test('trend detection: DECLINING when recent avg is below older avg by > 0.05', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ ewm: 0.5 }] })
        .mockResolvedValueOnce({
          rows: [{ count: '5', last_event_at: '2026-03-01' }],
        })
        .mockResolvedValueOnce({
          rows: [
            { numeric_value: '0.40', observed_at: '2026-03-01' },
            { numeric_value: '0.45', observed_at: '2026-02-15' },
            { numeric_value: '0.70', observed_at: '2026-02-01' },
            { numeric_value: '0.75', observed_at: '2026-01-15' },
            { numeric_value: '0.80', observed_at: '2026-01-01' },
          ],
        })
        .mockResolvedValueOnce({ rows: [] });

      const result = await runAggregation('tenant-1', 'student-1', 'comp-1');

      // avgRecent = (0.40 + 0.45) / 2 = 0.425
      // avgOlder = (0.70 + 0.75 + 0.80) / 3 = 0.75
      // 0.425 < 0.75 - 0.05 → DECLINING
      expect(result.trendDirection).toBe('DECLINING');
    });

    test('trend detection: INSUFFICIENT_DATA when count < 3', async () => {
      mockQuery
        .mockResolvedValueOnce({ rows: [{ ewm: 0.6 }] })
        .mockResolvedValueOnce({
          rows: [{ count: '2', last_event_at: '2026-03-01' }],
        })
        // No recent events query because count < 3
        .mockResolvedValueOnce({ rows: [] });

      const result = await runAggregation('tenant-1', 'student-1', 'comp-1');

      expect(result.trendDirection).toBe('INSUFFICIENT_DATA');
    });

    test('confidence score calculation: count/10 capped at 1.0', async () => {
      // Test with count = 5 → confidence = 0.5
      mockQuery
        .mockResolvedValueOnce({ rows: [{ ewm: 0.7 }] })
        .mockResolvedValueOnce({
          rows: [{ count: '5', last_event_at: '2026-03-01' }],
        })
        .mockResolvedValueOnce({
          rows: [
            { numeric_value: '0.70', observed_at: '2026-03-01' },
            { numeric_value: '0.70', observed_at: '2026-02-15' },
            { numeric_value: '0.70', observed_at: '2026-02-01' },
          ],
        })
        .mockResolvedValueOnce({ rows: [] });

      const result5 = await runAggregation('tenant-1', 'student-1', 'comp-1');
      expect(result5.confidence).toBe(0.5);

      jest.clearAllMocks();

      // Test with count = 15 → confidence = 1.0 (capped)
      mockQuery
        .mockResolvedValueOnce({ rows: [{ ewm: 0.8 }] })
        .mockResolvedValueOnce({
          rows: [{ count: '15', last_event_at: '2026-03-01' }],
        })
        .mockResolvedValueOnce({
          rows: [
            { numeric_value: '0.80', observed_at: '2026-03-01' },
            { numeric_value: '0.80', observed_at: '2026-02-15' },
            { numeric_value: '0.80', observed_at: '2026-02-01' },
          ],
        })
        .mockResolvedValueOnce({ rows: [] });

      const result15 = await runAggregation('tenant-1', 'student-1', 'comp-1');
      expect(result15.confidence).toBe(1.0);
    });

    test('idempotent aggregation: same result on rerun', async () => {
      const setupMocks = () => {
        mockQuery
          .mockResolvedValueOnce({ rows: [{ ewm: 0.75 }] })
          .mockResolvedValueOnce({
            rows: [{ count: '6', last_event_at: '2026-03-01' }],
          })
          .mockResolvedValueOnce({
            rows: [
              { numeric_value: '0.80', observed_at: '2026-03-01' },
              { numeric_value: '0.75', observed_at: '2026-02-15' },
              { numeric_value: '0.70', observed_at: '2026-02-01' },
              { numeric_value: '0.65', observed_at: '2026-01-15' },
              { numeric_value: '0.60', observed_at: '2026-01-01' },
            ],
          })
          .mockResolvedValueOnce({ rows: [] });
      };

      setupMocks();
      const result1 = await runAggregation('tenant-1', 'student-1', 'comp-1');

      jest.clearAllMocks();
      setupMocks();
      const result2 = await runAggregation('tenant-1', 'student-1', 'comp-1');

      expect(result1.ewm).toBe(result2.ewm);
      expect(result1.eventCount).toBe(result2.eventCount);
      expect(result1.trendDirection).toBe(result2.trendDirection);
      expect(result1.confidence).toBe(result2.confidence);
    });
  });
});
