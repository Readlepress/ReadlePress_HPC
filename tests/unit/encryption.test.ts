import { encrypt, decrypt, isEncrypted } from '../../src/utils/encryption';

describe('Encryption Utility', () => {
  test('encrypts and decrypts a string correctly', () => {
    const plaintext = 'UDID-12345-ABCDE';
    const encrypted = encrypt(plaintext);
    const decrypted = decrypt(encrypted);
    expect(decrypted).toBe(plaintext);
  });

  test('encrypted value differs from plaintext', () => {
    const plaintext = 'sensitive-data';
    const encrypted = encrypt(plaintext);
    expect(encrypted).not.toBe(plaintext);
  });

  test('two encryptions of same value produce different ciphertexts (random IV)', () => {
    const plaintext = 'test-value';
    const enc1 = encrypt(plaintext);
    const enc2 = encrypt(plaintext);
    expect(enc1).not.toBe(enc2);
  });

  test('both decrypt to the same value', () => {
    const plaintext = 'test-value';
    const enc1 = encrypt(plaintext);
    const enc2 = encrypt(plaintext);
    expect(decrypt(enc1)).toBe(plaintext);
    expect(decrypt(enc2)).toBe(plaintext);
  });

  test('isEncrypted detects encrypted format', () => {
    const encrypted = encrypt('test');
    expect(isEncrypted(encrypted)).toBe(true);
  });

  test('isEncrypted returns false for plaintext', () => {
    expect(isEncrypted('just-plain-text')).toBe(false);
    expect(isEncrypted('')).toBe(false);
  });

  test('decrypt throws on invalid format', () => {
    expect(() => decrypt('not-encrypted')).toThrow('INVALID_ENCRYPTED_FORMAT');
  });

  test('handles empty string', () => {
    const encrypted = encrypt('');
    expect(decrypt(encrypted)).toBe('');
  });

  test('handles unicode / Devanagari text', () => {
    const plaintext = 'हिन्दी नाम';
    const encrypted = encrypt(plaintext);
    expect(decrypt(encrypted)).toBe(plaintext);
  });

  test('handles long UDID numbers', () => {
    const plaintext = 'MH-2024-UDID-0000123456789-CAT-VISUAL-PCT-40';
    const encrypted = encrypt(plaintext);
    expect(decrypt(encrypted)).toBe(plaintext);
  });
});
