import bcrypt from 'bcrypt';

const mockQuery = jest.fn();
const mockWithTransaction = jest.fn();

jest.mock('../../src/config/database', () => ({
  query: (...args: unknown[]) => mockQuery(...args),
  withTransaction: (...args: unknown[]) => mockWithTransaction(...args),
}));

jest.mock('../../src/config/redis', () => ({
  __esModule: true,
  default: {
    exists: jest.fn(),
    setex: jest.fn(),
    get: jest.fn(),
    incr: jest.fn(),
  },
}));

import { authenticateUser, hashPassword } from '../../src/services/auth.service';

describe('AuthService', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('authenticateUser', () => {
    test('returns user data with valid credentials', async () => {
      const passwordHash = await bcrypt.hash('CorrectPassword123!', 10);

      mockQuery
        .mockResolvedValueOnce({
          rows: [{
            id: 'user-1',
            tenant_id: 'tenant-1',
            password_hash: passwordHash,
            status: 'ACTIVE',
            failed_login_attempts: 0,
            locked_until: null,
            role_code: 'CLASS_TEACHER',
          }],
        })
        .mockResolvedValueOnce({ rows: [] });

      const result = await authenticateUser('teacher@example.com', undefined, 'CorrectPassword123!');

      expect(result).toEqual({
        userId: 'user-1',
        tenantId: 'tenant-1',
        role: 'CLASS_TEACHER',
      });

      expect(mockQuery).toHaveBeenCalledTimes(2);
      // Second call resets failed_login_attempts
      expect(mockQuery.mock.calls[1][0]).toContain('failed_login_attempts = 0');
    });

    test('wrong password increments failed_attempts', async () => {
      const passwordHash = await bcrypt.hash('CorrectPassword123!', 10);

      mockQuery
        .mockResolvedValueOnce({
          rows: [{
            id: 'user-1',
            tenant_id: 'tenant-1',
            password_hash: passwordHash,
            status: 'ACTIVE',
            failed_login_attempts: 2,
            locked_until: null,
            role_code: 'CLASS_TEACHER',
          }],
        })
        .mockResolvedValueOnce({ rows: [] });

      await expect(
        authenticateUser('teacher@example.com', undefined, 'WrongPassword')
      ).rejects.toThrow('INVALID_CREDENTIALS');

      expect(mockQuery).toHaveBeenCalledTimes(2);
      // Should update with incremented attempts (2 + 1 = 3)
      expect(mockQuery.mock.calls[1][1]?.[0]).toBe(3);
    });

    test('account lockout after MAX_LOGIN_ATTEMPTS', async () => {
      const passwordHash = await bcrypt.hash('CorrectPassword123!', 10);

      mockQuery
        .mockResolvedValueOnce({
          rows: [{
            id: 'user-1',
            tenant_id: 'tenant-1',
            password_hash: passwordHash,
            status: 'ACTIVE',
            failed_login_attempts: 4,
            locked_until: null,
            role_code: 'CLASS_TEACHER',
          }],
        })
        .mockResolvedValueOnce({ rows: [] });

      await expect(
        authenticateUser('teacher@example.com', undefined, 'WrongPassword')
      ).rejects.toThrow('INVALID_CREDENTIALS');

      // 4 + 1 = 5 >= MAX_LOGIN_ATTEMPTS (5), so locked_until should be set
      const updateCall = mockQuery.mock.calls[1];
      expect(updateCall[1]?.[0]).toBe(5);
      expect(updateCall[1]?.[1]).not.toBeNull(); // locked_until should be a Date
    });

    test('locked account returns ACCOUNT_LOCKED', async () => {
      const passwordHash = await bcrypt.hash('CorrectPassword123!', 10);
      const futureDate = new Date(Date.now() + 30 * 60 * 1000);

      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: 'user-1',
          tenant_id: 'tenant-1',
          password_hash: passwordHash,
          status: 'ACTIVE',
          failed_login_attempts: 5,
          locked_until: futureDate.toISOString(),
          role_code: 'CLASS_TEACHER',
        }],
      });

      await expect(
        authenticateUser('teacher@example.com', undefined, 'CorrectPassword123!')
      ).rejects.toThrow('ACCOUNT_LOCKED');

      expect(mockQuery).toHaveBeenCalledTimes(1);
    });

    test('inactive account returns ACCOUNT_INACTIVE', async () => {
      mockQuery.mockResolvedValueOnce({
        rows: [{
          id: 'user-1',
          tenant_id: 'tenant-1',
          password_hash: 'hash',
          status: 'INACTIVE',
          failed_login_attempts: 0,
          locked_until: null,
          role_code: 'CLASS_TEACHER',
        }],
      });

      await expect(
        authenticateUser('teacher@example.com', undefined, 'AnyPassword')
      ).rejects.toThrow('ACCOUNT_INACTIVE');

      expect(mockQuery).toHaveBeenCalledTimes(1);
    });
  });

  describe('hashPassword', () => {
    test('produces valid bcrypt hash', async () => {
      const password = 'SecurePassword123!';
      const hash = await hashPassword(password);

      expect(hash).toBeDefined();
      expect(hash).toMatch(/^\$2[aby]?\$\d+\$/);
      expect(await bcrypt.compare(password, hash)).toBe(true);
      expect(await bcrypt.compare('WrongPassword', hash)).toBe(false);
    });
  });
});
