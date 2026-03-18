describe('SmsService', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    jest.resetModules();
    process.env = { ...originalEnv };
    delete process.env.MSG91_API_KEY;
    delete process.env.NODE_ENV;
  });

  afterAll(() => {
    process.env = originalEnv;
  });

  describe('sendOtp', () => {
    test('dev mode fallback when MSG91_API_KEY not set', async () => {
      process.env.NODE_ENV = 'development';
      const consoleSpy = jest.spyOn(console, 'log').mockImplementation();

      const { sendOtp } = await import('../../src/services/sms.service');

      const result = await sendOtp('919876543210', 'template-1', '123456');

      expect(result).toEqual({ success: true });
      expect(consoleSpy).toHaveBeenCalledWith(
        expect.stringContaining('[SMS] sendOtp (dev fallback)'),
        expect.objectContaining({ phone: '919876543210', otp: '123456' })
      );

      consoleSpy.mockRestore();
    });

    test('throws when MSG91_API_KEY not set in production', async () => {
      process.env.NODE_ENV = 'production';

      const { sendOtp } = await import('../../src/services/sms.service');

      await expect(
        sendOtp('919876543210', 'template-1', '123456')
      ).rejects.toThrow('MSG91_API_KEY not configured');
    });

    test('builds correct MSG91 request', async () => {
      process.env.MSG91_API_KEY = 'test-api-key';
      process.env.MSG91_SENDER_ID = 'RDLPRS';

      const mockResponse = {
        ok: true,
        json: async () => ({ type: 'success', request_id: 'msg-123' }),
      };
      global.fetch = jest.fn().mockResolvedValue(mockResponse) as jest.Mock;

      const { sendOtp } = await import('../../src/services/sms.service');

      const result = await sendOtp('919876543210', 'tpl-otp-001', '654321', { purpose: 'EDUCATIONAL_RECORD' });

      expect(global.fetch).toHaveBeenCalledWith(
        'https://control.msg91.com/api/v5/otp',
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({
            'Content-Type': 'application/json',
            authkey: 'test-api-key',
          }),
        })
      );

      const fetchCall = (global.fetch as jest.Mock).mock.calls[0];
      const body = JSON.parse(fetchCall[1].body);
      expect(body.template_id).toBe('tpl-otp-001');
      expect(body.otp).toBe('654321');
      expect(body.sender).toBe('RDLPRS');
      expect(body.purpose).toBe('EDUCATIONAL_RECORD');

      expect(result).toEqual({ success: true, messageId: 'msg-123' });

      (global.fetch as jest.Mock).mockRestore?.();
    });
  });

  describe('sendTransactional', () => {
    test('sends with DLT template', async () => {
      process.env.MSG91_API_KEY = 'test-api-key';
      process.env.MSG91_SENDER_ID = 'RDLPRS';

      const mockResponse = {
        ok: true,
        json: async () => ({ type: 'success', request_id: 'txn-456' }),
      };
      global.fetch = jest.fn().mockResolvedValue(mockResponse) as jest.Mock;

      const { sendTransactional } = await import('../../src/services/sms.service');

      const result = await sendTransactional(
        '919876543210',
        'dlt-template-consent',
        { name: 'Parent Name', school: 'Test School' }
      );

      expect(global.fetch).toHaveBeenCalledWith(
        'https://control.msg91.com/api/v5/flow',
        expect.objectContaining({ method: 'POST' })
      );

      const fetchCall = (global.fetch as jest.Mock).mock.calls[0];
      const body = JSON.parse(fetchCall[1].body);
      expect(body.flow_id).toBe('dlt-template-consent');
      expect(body.sender).toBe('RDLPRS');
      expect(body.recipients).toHaveLength(1);
      expect(body.recipients[0].name).toBe('Parent Name');

      expect(result).toEqual({ success: true, messageId: 'txn-456' });

      (global.fetch as jest.Mock).mockRestore?.();
    });
  });
});
