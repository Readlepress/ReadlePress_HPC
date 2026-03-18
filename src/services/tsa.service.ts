/**
 * eMudhra RFC 3161 TSA Client (Gap #7)
 * Timestamp Authority client for requesting RFC 3161 timestamps.
 */

import * as https from 'https';
import * as http from 'http';

// SHA-256 OID: 2.16.840.1.101.3.4.2.1
const SHA256_OID = Buffer.from([0x06, 0x09, 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01]);

export interface TimestampResult {
  timestampToken: Buffer;
  anchorRef: string;
  timestamp: Date;
}

function getConfig() {
  const tsaUrl = process.env.EMUDHRA_TSA_URL;
  const username = process.env.EMUDHRA_TSA_USERNAME;
  const password = process.env.EMUDHRA_TSA_PASSWORD;
  const credentials = process.env.EMUDHRA_TSA_CREDENTIALS; // "username:password" format
  return { tsaUrl, username, password, credentials };
}

function isConfigured(): boolean {
  return !!process.env.EMUDHRA_TSA_URL;
}

/**
 * Builds a minimal RFC 3161 TimeStampReq DER-encoded request.
 * TimeStampReq ::= SEQUENCE { version INTEGER, messageImprint MessageImprint }
 * MessageImprint ::= SEQUENCE { hashAlgorithm AlgorithmIdentifier, hashedMessage OCTET STRING }
 */
function buildTimeStampReq(hashBytes: Buffer): Buffer {
  if (hashBytes.length !== 32) {
    throw new Error('TSA expects SHA-256 hash (32 bytes)');
  }

  // hashAlgorithm: SEQUENCE { algorithm OID, parameters NULL }
  const hashAlgorithm = Buffer.concat([
    Buffer.from([0x30, 0x0d]), // SEQUENCE, 13 bytes
    SHA256_OID,
    Buffer.from([0x05, 0x00]), // NULL
  ]);

  // hashedMessage: OCTET STRING (32 bytes)
  const hashedMessage = Buffer.concat([
    Buffer.from([0x04, 0x20]), // OCTET STRING, 32 bytes
    hashBytes,
  ]);

  // messageImprint: SEQUENCE { hashAlgorithm, hashedMessage }
  const messageImprint = Buffer.concat([
    Buffer.from([0x30, 0x31]), // SEQUENCE, 49 bytes
    hashAlgorithm,
    hashedMessage,
  ]);

  // version: INTEGER 1
  const version = Buffer.from([0x02, 0x01, 0x01]);

  // TimeStampReq: SEQUENCE { version, messageImprint }
  return Buffer.concat([
    Buffer.from([0x30]), // SEQUENCE
    Buffer.from([0x36]), // 54 bytes total
    version,
    messageImprint,
  ]);
}

/**
 * Converts dataHash (hex string) to raw bytes. Supports both hex and base64.
 */
function hashToBytes(dataHash: string): Buffer {
  const trimmed = dataHash.replace(/\s/g, '');
  if (/^[0-9a-fA-F]+$/.test(trimmed) && trimmed.length === 64) {
    return Buffer.from(trimmed, 'hex');
  }
  try {
    return Buffer.from(trimmed, 'base64');
  } catch {
    throw new Error('dataHash must be 64-char hex or base64-encoded 32 bytes');
  }
}

/**
 * Requests an RFC 3161 timestamp from the TSA.
 * @param dataHash - SHA-256 hash as hex string (64 chars) or base64
 */
export async function requestTimestamp(dataHash: string): Promise<TimestampResult> {
  const { tsaUrl, username, password, credentials } = getConfig();

  if (!tsaUrl) {
    if (process.env.NODE_ENV === 'development') {
      console.log('[TSA] requestTimestamp (dev fallback):', { dataHash: dataHash.slice(0, 16) + '...' });
      const mockToken = Buffer.from('mock-timestamp-token');
      return {
        timestampToken: mockToken,
        anchorRef: 'MOCK_DEV_ANCHOR',
        timestamp: new Date(),
      };
    }
    throw new Error('EMUDHRA_TSA_URL not configured');
  }

  const hashBytes = hashToBytes(dataHash);
  const requestBody = buildTimeStampReq(hashBytes);

  const url = new URL(tsaUrl);
  const isHttps = url.protocol === 'https:';
  const lib = isHttps ? https : http;

  const auth =
    credentials || (username && password ? `${username}:${password}` : null);
  const authHeader = auth ? `Basic ${Buffer.from(auth).toString('base64')}` : null;

  return new Promise((resolve, reject) => {
    const req = lib.request(
      {
        hostname: url.hostname,
        port: url.port || (isHttps ? 443 : 80),
        path: url.pathname || '/',
        method: 'POST',
        headers: {
          'Content-Type': 'application/timestamp-query',
          'Content-Length': requestBody.length,
          ...(authHeader ? { Authorization: authHeader } : {}),
        },
      },
      (res) => {
        const chunks: Buffer[] = [];
        res.on('data', (chunk: Buffer) => chunks.push(chunk));
        res.on('end', () => {
          const body = Buffer.concat(chunks);
          if (res.statusCode && res.statusCode >= 400) {
            reject(new Error(`TSA request failed: ${res.statusCode} ${body.toString('utf8').slice(0, 200)}`));
            return;
          }
          // TimeStampResp: SEQUENCE { status PKIStatusInfo, timeStampToken [0] IMPLICIT ... }
          // For simplicity, we return the full response as the token and derive anchorRef from it
          const token = body;
          const anchorRef = `TSA:${token.toString('base64').slice(0, 32)}`;
          const timestamp = new Date();
          resolve({
            timestampToken: token,
            anchorRef,
            timestamp,
          });
        });
      }
    );
    req.on('error', reject);
    req.write(requestBody);
    req.end();
  });
}

export const tsaService = {
  requestTimestamp,
  isConfigured,
};
