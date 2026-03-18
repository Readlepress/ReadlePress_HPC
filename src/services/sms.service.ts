/**
 * MSG91 SMS Integration (Gap #6)
 * HTTP client for MSG91 API (https://control.msg91.com/api/v5/)
 * Supports OTP, verification, and transactional SMS with DLT template IDs (TRAI compliance).
 */

const MSG91_BASE = 'https://control.msg91.com/api/v5';

function getConfig() {
  const apiKey = process.env.MSG91_API_KEY;
  const senderId = process.env.MSG91_SENDER_ID || 'SMSIND';
  const route = process.env.MSG91_ROUTE || '4'; // 4 = transactional
  return { apiKey, senderId, route };
}

export function isConfigured(): boolean {
  return !!process.env.MSG91_API_KEY;
}

/**
 * Sends OTP via MSG91 Send OTP API.
 * @param phone - Phone number with country code (e.g. 919876543210)
 * @param templateId - DLT template ID (TRAI compliance)
 * @param otp - OTP value to send
 * @param variables - Optional template variables (e.g. { "var1": "value1" })
 */
export async function sendOtp(
  phone: string,
  templateId: string,
  otp: string,
  variables?: Record<string, string>
): Promise<{ success: boolean; messageId?: string }> {
  const { apiKey, senderId } = getConfig();

  if (!apiKey) {
    if (process.env.NODE_ENV === 'development') {
      console.log('[SMS] sendOtp (dev fallback):', { phone, templateId, otp, variables });
      return { success: true };
    }
    throw new Error('MSG91_API_KEY not configured');
  }

  const body: Record<string, unknown> = {
    template_id: templateId,
    mobile: phone.replace(/\D/g, '').replace(/^0/, '91'),
    otp,
    sender: senderId,
    ...variables,
  };

  const res = await fetch(`${MSG91_BASE}/otp`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'authkey': apiKey,
    },
    body: JSON.stringify(body),
  });

  const data = (await res.json()) as { type?: string; message?: string; request_id?: string };
  if (!res.ok) {
    throw new Error(`MSG91 sendOtp failed: ${data.message || res.statusText}`);
  }
  return {
    success: data.type === 'success',
    messageId: data.request_id,
  };
}

/**
 * Verifies OTP via MSG91 Verify OTP API.
 */
export async function verifyOtp(phone: string, otp: string): Promise<{ valid: boolean }> {
  const { apiKey } = getConfig();

  if (!apiKey) {
    if (process.env.NODE_ENV === 'development') {
      console.log('[SMS] verifyOtp (dev fallback):', { phone, otp });
      return { valid: true };
    }
    throw new Error('MSG91_API_KEY not configured');
  }

  const mobile = phone.replace(/\D/g, '').replace(/^0/, '91');
  const res = await fetch(`${MSG91_BASE}/otp/verify`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'authkey': apiKey,
    },
    body: JSON.stringify({ mobile, otp }),
  });

  const data = (await res.json()) as { type?: string };
  return { valid: data.type === 'success' };
}

/**
 * Sends transactional SMS (consent confirmations, HPC ready notifications).
 * @param phone - Phone number with country code
 * @param templateId - DLT template ID
 * @param variables - Template variables
 */
export async function sendTransactional(
  phone: string,
  templateId: string,
  variables: Record<string, string>
): Promise<{ success: boolean; messageId?: string }> {
  const { apiKey, senderId, route } = getConfig();

  if (!apiKey) {
    if (process.env.NODE_ENV === 'development') {
      console.log('[SMS] sendTransactional (dev fallback):', { phone, templateId, variables });
      return { success: true };
    }
    throw new Error('MSG91_API_KEY not configured');
  }

  const mobile = phone.replace(/\D/g, '').replace(/^0/, '91');
  const body = {
    flow_id: templateId,
    sender: senderId,
    short_url: '0',
    recipients: [{ mobiles: `91${mobile}`, ...variables }],
  };

  const res = await fetch(`${MSG91_BASE}/flow`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'authkey': apiKey,
    },
    body: JSON.stringify(body),
  });

  const data = (await res.json()) as { type?: string; request_id?: string; message?: string };
  if (!res.ok) {
    throw new Error(`MSG91 sendTransactional failed: ${data.message || res.statusText}`);
  }
  return {
    success: res.ok && (data.type === 'success' || !data.type),
    messageId: data.request_id,
  };
}

export const smsService = {
  sendOtp,
  verifyOtp,
  sendTransactional,
  isConfigured,
} as const;
