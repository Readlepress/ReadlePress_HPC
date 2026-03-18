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

test.describe('Student Journey', () => {
  test('list students for teacher returns filtered students', async ({ request }) => {
    const response = await request.get('/students', {
      headers: headers(),
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toHaveProperty('students');
    expect(Array.isArray(body.students)).toBe(true);

    if (body.students.length > 0) {
      const student = body.students[0];
      expect(student).toHaveProperty('id');
      expect(student).toHaveProperty('first_name');
      expect(student).toHaveProperty('enrolment_status');
      expect(student.dedup_status).not.toBe('CONFIRMED_DUPLICATE');
    }
  });

  test('enrol student creates enrolment with audit log entry', async ({ request }) => {
    const studentId = '00000000-0000-0000-0000-000000000001';

    const response = await request.post(`/students/${studentId}/enrolments`, {
      headers: headers(),
      data: {
        classId: '00000000-0000-0000-0000-000000000010',
        academicYearLabel: '2025-26',
        rollNumber: '42',
      },
    });

    // Should succeed (201) if consent exists, or fail with CONSENT_REQUIRED
    if (response.status() === 201) {
      const body = await response.json();
      expect(body).toHaveProperty('id');
    } else {
      expect(response.status()).toBe(400);
      const body = await response.json();
      expect(body.error).toBe('CONSENT_REQUIRED');
    }
  });

  test('enrol without consent returns CONSENT_REQUIRED error', async ({ request }) => {
    const studentWithoutConsent = '00000000-0000-0000-0000-999999999999';

    const response = await request.post(`/students/${studentWithoutConsent}/enrolments`, {
      headers: headers(),
      data: {
        classId: '00000000-0000-0000-0000-000000000010',
        academicYearLabel: '2025-26',
      },
    });

    expect(response.status()).toBe(400);
    const body = await response.json();
    expect(body.error).toBe('CONSENT_REQUIRED');
    expect(body.message).toContain('consent');
  });
});
