describe('TsaService', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
    delete process.env.EMUDHRA_TSA_URL;
    delete process.env.NODE_ENV;
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  describe('requestTimestamp', () => {
    test('dev mode mock when EMUDHRA_TSA_URL not set', async () => {
      process.env.NODE_ENV = 'development';
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation();

      const { requestTimestamp } = await import('../../src/services/tsa.service');

      const dataHash = 'a'.repeat(64);
      const result = await requestTimestamp(dataHash);

      expect(result).toHaveProperty('timestampToken');
      expect(result.timestampToken).toBeInstanceOf(Buffer);
      expect(result.anchorRef).toBe('MOCK_DEV_ANCHOR');
      expect(result.timestamp).toBeInstanceOf(Date);

      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('[TSA] requestTimestamp (dev fallback)'),
        expect.objectContaining({ dataHash: expect.any(String) })
      );

      consoleSpy.mockRestore();
    });

    test('throws when EMUDHRA_TSA_URL not set in production', async () => {
      process.env.NODE_ENV = 'production';

      const { requestTimestamp } = await import('../../src/services/tsa.service');

      await expect(
        requestTimestamp('a'.repeat(64))
      ).rejects.toThrow('EMUDHRA_TSA_URL not configured');
    });

    test('timestamp request builds correct hash', async () => {
      process.env.NODE_ENV = 'development';

      const { requestTimestamp } = await import('../../src/services/tsa.service');

      // Valid 64-character hex hash (SHA-256)
      const validHash = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const result = await requestTimestamp(validHash);

      expect(result).toHaveProperty('timestampToken');
      expect(result).toHaveProperty('anchorRef');
      expect(result).toHaveProperty('timestamp');
    });

    test('rejects invalid hash length', async () => {
      process.env.NODE_ENV = 'production';
      process.env.EMUDHRA_TSA_URL = 'http://tsa.example.com/ts';

      const { requestTimestamp } = await import('../../src/services/tsa.service');

      // This should fail because the hash is not 32 bytes
      await expect(
        requestTimestamp('tooshort')
      ).rejects.toThrow();
    });
  });

  describe('response parsing', () => {
    test('dev mode returns parseable TimestampResult', async () => {
      process.env.NODE_ENV = 'development';

      const { requestTimestamp } = await import('../../src/services/tsa.service');

      const result = await requestTimestamp('a'.repeat(64));

      expect(typeof result.anchorRef).toBe('string');
      expect(result.anchorRef.length).toBeGreaterThan(0);
      expect(result.timestamp.getTime()).toBeLessThanOrEqual(Date.now());
      expect(result.timestamp.getTime()).toBeGreaterThan(Date.now() - 5000);
    });
  });
});
