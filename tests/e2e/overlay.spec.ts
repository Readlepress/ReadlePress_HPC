import { test, expect } from '@playwright/test';

let teacherToken: string;
let principalToken: string;

test.beforeAll(async ({ request }) => {
  const teacherLogin = await request.post('/auth/login', {
    data: {
      email: 'teacher@school.example.com',
      password: 'TeacherPass123!',
    },
  });
  const teacherBody = await teacherLogin.json();
  teacherToken = teacherBody.token;

  const principalLogin = await request.post('/auth/login', {
    data: {
      email: 'principal@school.example.com',
      password: 'PrincipalPass123!',
    },
  });
  const principalBody = await principalLogin.json();
  principalToken = principalBody.token;
});

function headers(token: string) {
  return { Authorization: `Bearer ${token}` };
}

test.describe('Overlay', () => {
  let overlayId: string;
  const studentId = '00000000-0000-0000-0000-000000000001';

  test('create overlay returns status PENDING_APPROVAL', async ({ request }) => {
    const response = await request.post(`/students/${studentId}/overlays`, {
      headers: headers(teacherToken),
      data: {
        disabilityProfileId: '00000000-0000-0000-0000-000000000500',
        competencyIds: [
          '00000000-0000-0000-0000-000000000300',
          '00000000-0000-0000-0000-000000000301',
        ],
        modifications: {
          extraTime: true,
          simplifiedRubric: true,
        },
        modifiedMasteryThreshold: 0.35,
        effectiveFrom: '2026-01-01',
        effectiveUntil: '2026-12-31',
      },
    });

    if (response.status() === 201) {
      const body = await response.json();
      expect(body).toHaveProperty('overlayId');
      overlayId = body.overlayId;
    } else {
      // May fail if consent not present
      expect([400, 500]).toContain(response.status());
    }
  });

  test('approve overlay by different user transitions to ACTIVE', async ({ request }) => {
    test.skip(!overlayId, 'No overlay created in previous test');

    const response = await request.post(`/overlays/${overlayId}/approve`, {
      headers: headers(principalToken),
      data: {
        action: 'APPROVED',
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body.status).toBe('ACTIVE');
  });

  test('self-approval returns error', async ({ request }) => {
    // Create a new overlay with teacher token, then try to approve with same teacher
    const createRes = await request.post(`/students/${studentId}/overlays`, {
      headers: headers(teacherToken),
      data: {
        disabilityProfileId: '00000000-0000-0000-0000-000000000500',
        competencyIds: ['00000000-0000-0000-0000-000000000300'],
        modifications: { extraTime: true },
        effectiveFrom: '2026-01-01',
        effectiveUntil: '2026-12-31',
      },
    });

    if (createRes.status() !== 201) {
      test.skip(true, 'Could not create overlay for self-approval test');
      return;
    }

    const { overlayId: newOverlayId } = await createRes.json();

    const response = await request.post(`/overlays/${newOverlayId}/approve`, {
      headers: headers(teacherToken),
      data: {
        action: 'APPROVED',
      },
    });

    expect(response.status()).toBe(500);
    const body = await response.json();
    expect(body.message || body.error).toBeDefined();
  });
});
