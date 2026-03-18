export interface JwtPayload {
  userId: string;
  tenantId: string;
  role: string;
  email?: string;
  phone?: string;
  iat?: number;
  exp?: number;
}

export interface TenantContext {
  tenantId: string;
  userId: string;
  userRole: string;
}

export type AcademicYearStatus = 'PLANNING' | 'ACTIVE' | 'REVIEW' | 'LOCKED';
export type ConsentPurpose = 'EDUCATIONAL_RECORD' | 'ASSESSMENT_DATA' | 'EVIDENCE_CAPTURE' | 'PARENT_COMMUNICATION' | 'DISABILITY_DATA' | 'AI_PROCESSING' | 'PORTABILITY_EXPORT' | 'DIGILOCKER_DELIVERY' | 'RESEARCH_ANONYMIZED';
export type VerificationMethod = 'OTP' | 'WITNESSED_PAPER' | 'GUARDIAN_PORTAL' | 'SYSTEM';
export type TrustLevel = 'INSTITUTIONAL' | 'TEACHER_DIRECT' | 'PARTNER_SUBMITTED' | 'EXTERNAL_CERTIFICATE' | 'PARENT_UPLOADED';
export type SensitivityLevel = 'ACADEMIC' | 'BEHAVIOURAL' | 'WELFARE' | 'SAFEGUARDING';
export type SourceType = 'DIRECT_OBSERVATION' | 'SELF_ASSESSMENT' | 'PEER_ASSESSMENT' | 'HISTORICAL_ENTRY';
export type OverlayStatus = 'DRAFT' | 'PENDING_APPROVAL' | 'ACTIVE' | 'EXPIRED' | 'REJECTED' | 'REVOKED';

export interface ApiError {
  statusCode: number;
  error: string;
  message: string;
}
