import { test, expect } from '@playwright/test';

const VALID_USER = {
  email: 'teacher@school.example.com',
  password: 'TeacherPass123!',
};

test.describe('Authentication', () => {
  test('login with valid credentials returns JWT token', async ({ request }) => {
    const response = await request.post('/auth/login', {
      data: {
        email: VALID_USER.email,
        password: VALID_USER.password,
      },
    });

    expect(response.status()).toBe(200);
    const body = await response.json();
    expect(body).toHaveProperty('token');
    expect(typeof body.token).toBe('string');
    expect(body.token.split('.')).toHaveLength(3); // JWT has 3 parts
    expect(body).toHaveProperty('user');
    expect(body.user).toHaveProperty('userId');
    expect(body.user).toHaveProperty('tenantId');
    expect(body.user).toHaveProperty('role');
  });

  test('login with wrong password returns 401', async ({ request }) => {
    const response = await request.post('/auth/login', {
      data: {
        email: VALID_USER.email,
        password: 'WrongPassword999!',
      },
    });

    expect(response.status()).toBe(401);
    const body = await response.json();
    expect(body.error).toBe('INVALID_CREDENTIALS');
  });

  test('login with locked account returns 423', async ({ request }) => {
    const lockedEmail = 'locked@school.example.com';

    // Exhaust login attempts to lock the account
    for (let i = 0; i < 6; i++) {
      await request.post('/auth/login', {
        data: { email: lockedEmail, password: 'Wrong' },
      });
    }

    const response = await request.post('/auth/login', {
      data: {
        email: lockedEmail,
        password: 'AnyPassword123!',
      },
    });

    expect(response.status()).toBe(423);
    const body = await response.json();
    expect(body.error).toBe('ACCOUNT_LOCKED');
  });
});
