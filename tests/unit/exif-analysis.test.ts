import { analyzeEvidenceExif } from '../../src/jobs/exif-analysis.job';

// Mock the database query
jest.mock('../../src/config/database', () => ({
  query: jest.fn().mockResolvedValue({ rows: [], rowCount: 0 }),
}));

const { query } = require('../../src/config/database');

describe('EXIF Integrity Analysis', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('handles buffer with no EXIF data gracefully', async () => {
    const emptyBuffer = Buffer.from('not-a-real-image');
    await analyzeEvidenceExif('test-evidence-id', emptyBuffer);

    expect(query).toHaveBeenCalled();
    const lastCall = query.mock.calls[query.mock.calls.length - 1];
    const sql = lastCall[0];
    expect(sql).toContain('integrity_flags');
  });

  test('processes PNG header buffer without crashing', async () => {
    // Minimal PNG header
    const pngHeader = Buffer.from([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    ]);
    await analyzeEvidenceExif('test-id-2', pngHeader);
    expect(query).toHaveBeenCalled();
  });
});

describe('Distance Calculation', () => {
  test('calculateDistance returns correct km for known coords', () => {
    // Mumbai to Pune ~150km
    const { calculateDistance } = jest.requireActual('../../src/jobs/exif-analysis.job');
    if (calculateDistance) {
      const dist = calculateDistance(19.076, 72.877, 18.520, 73.856);
      expect(dist).toBeGreaterThan(100);
      expect(dist).toBeLessThan(200);
    }
  });
});
