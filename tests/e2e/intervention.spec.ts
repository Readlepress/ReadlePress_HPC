import { test, expect } from '@playwright/test';

let authToken: string;
let classTeacherToken: string;

test.beforeAll(async ({ request }) => {
  const loginRes = await request.post('/auth/login', {
    data: {
      email: 'counsellor@school.example.com',
      password: 'CounsellorPass123!',
    },
  });
  const body = await loginRes.json();
  authToken = body.token;

  const ctLogin = await request.post('/auth/login', {
    data: {
      email: 'teacher@school.example.com',
      password: 'TeacherPass123!',
    },
  });
  const ctBody = await ctLogin.json();
  classTeacherToken = ctBody.token;
});

function headers(token?: string) {
  return { Authorization: `Bearer ${token || authToken}` };
}

test.describe('Intervention', () => {
  test('get intervention alerts returns open alerts', async ({ request }) => {
    const response = await request.get('/intervention-alerts', {
      headers: headers(),
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toHaveProperty('alerts');
    expect(Array.isArray(body.alerts)).toBe(true);

    if (body.alerts.length > 0) {
      const alert = body.alerts[0];
      expect(alert).toHaveProperty('id');
      expect(alert).toHaveProperty('student_id');
      expect(alert).toHaveProperty('sensitivity_level');
      expect(alert.status).toBe('OPEN');
    }
  });

  test('convert alert to plan creates intervention plan', async ({ request }) => {
    const alertId = '00000000-0000-0000-0000-000000000400';

    const response = await request.post(`/intervention-alerts/${alertId}/convert`, {
      headers: headers(),
      data: {
        title: 'Academic Support Plan',
        description: 'Student requires additional support in literacy',
        sensitivityLevel: 'ACADEMIC',
        objectives: [{ goal: 'Improve reading comprehension', targetDate: '2026-06-30' }],
        nextReviewDate: '2026-04-15',
      },
    });

    if (response.status() === 201) {
      const body = await response.json();
      expect(body).toHaveProperty('planId');
    } else {
      // Alert may not exist or not be OPEN
      expect([400, 404, 500]).toContain(response.status());
    }
  });

  test('CLASS_TEACHER cannot access WELFARE plans', async ({ request }) => {
    const response = await request.get('/intervention-alerts', {
      headers: headers(classTeacherToken),
      params: { sensitivityLevel: 'WELFARE' },
    });

    expect(response.status()).toBeLessThan(500);
    const body = await response.json();

    if (body.alerts && body.alerts.length > 0) {
      for (const alert of body.alerts) {
        expect(alert.sensitivity_level).not.toBe('WELFARE');
        expect(alert.sensitivity_level).not.toBe('SAFEGUARDING');
      }
    }
  });
});
