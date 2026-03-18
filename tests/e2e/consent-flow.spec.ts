import { test, expect } from '@playwright/test';

let authToken: string;

test.beforeAll(async ({ request }) => {
  const loginRes = await request.post('/auth/login', {
    data: {
      email: 'teacher@school.example.com',
      password: 'TeacherPass123!',
    },
  });
  const loginBody = await loginRes.json();
  authToken = loginBody.token;
});

function headers() {
  return { Authorization: `Bearer ${authToken}` };
}

test.describe('Consent Flow', () => {
  const phone = '919876543210';
  const purpose = 'EDUCATIONAL_RECORD';

  test('OTP initiation returns success with expiresAt', async ({ request }) => {
    const response = await request.post('/consent/initiate', {
      headers: headers(),
      data: { phone, purpose },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toHaveProperty('expiresAt');
    expect(body.message).toBe('OTP sent successfully');
    expect(new Date(body.expiresAt).getTime()).toBeGreaterThan(Date.now());
  });

  test('OTP verification creates consent records for all purposes', async ({ request }) => {
    // Initiate OTP first (dev mode returns OTP in response)
    const initRes = await request.post('/consent/initiate', {
      headers: headers(),
      data: { phone: '919876543211', purpose: 'EDUCATIONAL_RECORD' },
    });
    const initBody = await initRes.json();
    const otp = initBody.otp; // available in dev mode

    test.skip(!otp, 'OTP only available in dev mode without MSG91');

    const response = await request.post('/consent/verify', {
      headers: headers(),
      data: {
        phone: '919876543211',
        otp,
        purposes: ['EDUCATIONAL_RECORD', 'ASSESSMENT_DATA'],
        studentId: '00000000-0000-0000-0000-000000000001',
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toHaveProperty('consentRecords');
    expect(body.consentRecords.length).toBe(2);
    for (const record of body.consentRecords) {
      expect(record).toHaveProperty('id');
      expect(record).toHaveProperty('purpose');
    }
  });

  test('OTP cooldown returns 429 on rapid re-request', async ({ request }) => {
    const cooldownPhone = '919876543299';

    // First request should succeed
    const first = await request.post('/consent/initiate', {
      headers: headers(),
      data: { phone: cooldownPhone, purpose },
    });
    expect(first.status()).toBe(200);

    // Immediate second request should be rate-limited
    const second = await request.post('/consent/initiate', {
      headers: headers(),
      data: { phone: cooldownPhone, purpose },
    });

    expect(second.status()).toBe(429);
    const body = await second.json();
    expect(body.error).toBe('OTP_COOLDOWN');
  });
});
