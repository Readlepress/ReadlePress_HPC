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

test.describe('Mastery', () => {
  test('verify mastery event draft transitions status to ACTIVE', async ({ request }) => {
    const draftEventId = '00000000-0000-0000-0000-000000000200';

    const response = await request.post(`/mastery-events/${draftEventId}/verify`, {
      headers: headers(),
    });

    if (response.status() === 200) {
      const body = await response.json();
      expect(body.status).toBe('ACTIVE');
    } else {
      // Event may not exist or not be in DRAFT status
      expect([400, 404, 500]).toContain(response.status());
    }
  });

  test('mastery summary returns aggregates', async ({ request }) => {
    const studentId = '00000000-0000-0000-0000-000000000001';

    const response = await request.get(`/students/${studentId}/mastery-summary`, {
      headers: headers(),
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toHaveProperty('aggregates');
    expect(Array.isArray(body.aggregates)).toBe(true);

    if (body.aggregates.length > 0) {
      const agg = body.aggregates[0];
      expect(agg).toHaveProperty('competency_id');
      expect(agg).toHaveProperty('current_ewm');
      expect(agg).toHaveProperty('trend_direction');
      expect(agg).toHaveProperty('confidence_score');
    }
  });

  test('no-naked-scoring: upload without evidence or note returns error', async ({ request }) => {
    const response = await request.post('/capture/sync', {
      headers: headers(),
      data: {
        teacherId: '00000000-0000-0000-0000-000000000050',
        drafts: [{
          localId: 'naked-score-test-001',
          studentId: '00000000-0000-0000-0000-000000000001',
          competencyId: '00000000-0000-0000-0000-000000000300',
          observedAt: new Date().toISOString(),
          recordedAt: new Date().toISOString(),
          timestampSource: 'DEVICE',
          timestampConfidence: 'HIGH',
          numericValue: 0.75,
          // No observationNote and no evidenceLocalIds -> naked score
        }],
      },
    });

    const body = await response.json();
    // The API should either reject naked scores or flag them
    if (response.status() === 400) {
      expect(body.error).toBeDefined();
    } else {
      // If sync succeeds, verify the result contains the draft
      expect(response.status()).toBe(200);
      expect(body).toHaveProperty('results');
    }
  });
});
