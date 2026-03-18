-- ============================================================================
-- Layer 5 — Localization
-- 22 Indian language support with governed translation lifecycle
-- ============================================================================

-- 1. supported_languages — Registry of all target languages
CREATE TABLE supported_languages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    language_code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_native TEXT NOT NULL,
    script TEXT NOT NULL,
    text_direction TEXT NOT NULL DEFAULT 'LTR'
        CHECK (text_direction IN ('LTR', 'RTL')),
    font_family TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed the 22 scheduled languages of India
INSERT INTO supported_languages (language_code, name, name_native, script, text_direction, font_family) VALUES
    ('en', 'English', 'English', 'Latin', 'LTR', 'NotoSans-Regular'),
    ('hi', 'Hindi', 'हिन्दी', 'Devanagari', 'LTR', 'NotoSansDevanagari-Regular'),
    ('bn', 'Bengali', 'বাংলা', 'Bengali', 'LTR', 'NotoSansBengali-Regular'),
    ('te', 'Telugu', 'తెలుగు', 'Telugu', 'LTR', 'NotoSansTelugu-Regular'),
    ('mr', 'Marathi', 'मराठी', 'Devanagari', 'LTR', 'NotoSansDevanagari-Regular'),
    ('ta', 'Tamil', 'தமிழ்', 'Tamil', 'LTR', 'NotoSansTamil-Regular'),
    ('gu', 'Gujarati', 'ગુજરાતી', 'Gujarati', 'LTR', 'NotoSansGujarati-Regular'),
    ('kn', 'Kannada', 'ಕನ್ನಡ', 'Kannada', 'LTR', 'NotoSansKannada-Regular'),
    ('ml', 'Malayalam', 'മലയാളം', 'Malayalam', 'LTR', 'NotoSansMalayalam-Regular'),
    ('or', 'Odia', 'ଓଡ଼ିଆ', 'Odia', 'LTR', 'NotoSansOdia-Regular'),
    ('pa', 'Punjabi', 'ਪੰਜਾਬੀ', 'Gurmukhi', 'LTR', 'NotoSansGurmukhi-Regular'),
    ('as', 'Assamese', 'অসমীয়া', 'Bengali', 'LTR', 'NotoSansBengali-Regular'),
    ('mai', 'Maithili', 'मैथिली', 'Devanagari', 'LTR', 'NotoSansDevanagari-Regular'),
    ('sa', 'Sanskrit', 'संस्कृतम्', 'Devanagari', 'LTR', 'NotoSansDevanagari-Regular'),
    ('ne', 'Nepali', 'नेपाली', 'Devanagari', 'LTR', 'NotoSansDevanagari-Regular'),
    ('kok', 'Konkani', 'कोंकणी', 'Devanagari', 'LTR', 'NotoSansDevanagari-Regular'),
    ('doi', 'Dogri', 'डोगरी', 'Devanagari', 'LTR', 'NotoSansDevanagari-Regular'),
    ('mni', 'Manipuri', 'মৈতৈলোন্', 'Bengali', 'LTR', 'NotoSansBengali-Regular'),
    ('sd', 'Sindhi', 'سنڌي', 'Devanagari', 'LTR', 'NotoSansDevanagari-Regular'),
    ('sat', 'Santali', 'ᱥᱟᱱᱛᱟᱲᱤ', 'Ol Chiki', 'LTR', 'NotoSans-Regular'),
    ('ur', 'Urdu', 'اردو', 'Nastaliq', 'RTL', 'NotoNastaliqUrdu-Regular'),
    ('ks', 'Kashmiri', 'کٲشُر', 'Nastaliq', 'RTL', 'NotoNastaliqUrdu-Regular'),
    ('bo', 'Bodo', 'बड़ो', 'Devanagari', 'LTR', 'NotoSansDevanagari-Regular');

-- 2. localization_keys — Stable identifier for each string
CREATE TABLE localization_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key_code TEXT NOT NULL UNIQUE,
    context TEXT,
    max_length INTEGER,
    is_legal_document BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. localization_strings — Actual translations, one per key per language per status
CREATE TABLE localization_strings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE RESTRICT,
    key_id UUID NOT NULL REFERENCES localization_keys(id),
    language_code TEXT NOT NULL REFERENCES supported_languages(language_code),
    value TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'VERIFIED', 'OFFICIAL_LOCKED')),
    translated_by UUID REFERENCES users(id),
    reviewed_by UUID REFERENCES users(id),
    locked_at TIMESTAMPTZ,
    locked_by UUID REFERENCES users(id),
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_localization_active ON localization_strings(key_id, language_code, status)
    WHERE tenant_id IS NULL;
CREATE UNIQUE INDEX idx_localization_tenant ON localization_strings(tenant_id, key_id, language_code, status)
    WHERE tenant_id IS NOT NULL;

-- Trigger: OFFICIAL_LOCKED strings cannot be modified — must supersede
CREATE OR REPLACE FUNCTION protect_official_locked_strings()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'OFFICIAL_LOCKED' THEN
        RAISE EXCEPTION 'OFFICIAL_LOCKED localization strings cannot be modified. Create a new version instead.'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_official_locked
    BEFORE UPDATE ON localization_strings
    FOR EACH ROW
    EXECUTE FUNCTION protect_official_locked_strings();

-- 4. locale_format_rules — Number/date formatting per language
CREATE TABLE locale_format_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    language_code TEXT NOT NULL REFERENCES supported_languages(language_code),
    number_system TEXT NOT NULL DEFAULT 'latn',
    decimal_separator TEXT NOT NULL DEFAULT '.',
    thousands_separator TEXT NOT NULL DEFAULT ',',
    date_format TEXT NOT NULL DEFAULT 'DD/MM/YYYY',
    academic_year_format TEXT NOT NULL DEFAULT 'YYYY-YY',
    digit_mapping JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_locale_rules UNIQUE (language_code)
);

-- 5. sms_notification_templates — DLT-registered templates with localized content
CREATE TABLE sms_notification_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE RESTRICT,
    template_code TEXT NOT NULL,
    dlt_template_id TEXT,
    language_code TEXT NOT NULL REFERENCES supported_languages(language_code),
    template_text TEXT NOT NULL,
    variables TEXT[] NOT NULL DEFAULT '{}',
    is_dlt_registered BOOLEAN NOT NULL DEFAULT FALSE,
    dlt_registered_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PENDING_DLT', 'REGISTERED', 'REJECTED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_sms_template UNIQUE (template_code, language_code)
);

INSERT INTO schema_migrations (version, description) VALUES ('V005', 'Layer 5 — Localization');
