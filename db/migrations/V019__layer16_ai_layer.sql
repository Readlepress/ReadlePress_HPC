-- ============================================================================
-- Layer 16 — AI Layer
-- Provider registry, prompt governance, bias monitoring, consent checks
-- ============================================================================

-- 1. ai_provider_registry — Global AI provider configuration
CREATE TABLE ai_provider_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    adapter_type TEXT NOT NULL,
    api_endpoint TEXT,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    dpa_signed_at TIMESTAMPTZ,
    config JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. prompt_templates — Governed prompt definitions with PII exclusion
CREATE TABLE prompt_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    template_code TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    prompt_text TEXT NOT NULL,
    pii_exclusion_fields TEXT[] NOT NULL DEFAULT ARRAY['student_name', 'apaar_id', 'aadhaar', 'disability_category', 'social_category'],
    max_output_words INTEGER NOT NULL DEFAULT 500,
    max_free_text_chars INTEGER NOT NULL DEFAULT 2000,
    output_format_schema JSONB,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUSPENDED', 'ARCHIVED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. ai_generation_log — Hash-chained immutable log of AI generations
CREATE TABLE ai_generation_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    provider_id UUID NOT NULL REFERENCES ai_provider_registry(id),
    template_id UUID NOT NULL REFERENCES prompt_templates(id),
    prompt_hash TEXT NOT NULL,
    input_data_hash TEXT NOT NULL,
    raw_output_hash TEXT,
    output_word_count INTEGER,
    generation_time_ms INTEGER,
    human_decision TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (human_decision IN ('PENDING', 'PROMOTED', 'EDITED_THEN_PROMOTED', 'REJECTED', 'EXPIRED')),
    edit_distance INTEGER,
    ai_assisted_flag_set BOOLEAN NOT NULL DEFAULT FALSE,
    prev_log_hash TEXT,
    log_hash TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger: compute hash chain for ai_generation_log
CREATE OR REPLACE FUNCTION compute_ai_generation_log_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.log_hash := encode(sha256(
        (NEW.id::text || NEW.prompt_hash || NEW.input_data_hash
         || extract(epoch from NEW.created_at)::text
         || COALESCE(NEW.prev_log_hash, ''))::bytea
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ai_generation_log_hash
    BEFORE INSERT ON ai_generation_log
    FOR EACH ROW
    EXECUTE FUNCTION compute_ai_generation_log_hash();

-- Append-only enforcement for ai_generation_log
CREATE RULE no_ai_gen_log_update AS ON UPDATE TO ai_generation_log DO INSTEAD NOTHING;
CREATE RULE no_ai_gen_log_delete AS ON DELETE TO ai_generation_log DO INSTEAD NOTHING;

-- 4. ai_generation_subject_links — Maps anonymised IDs back to real entities
CREATE TABLE ai_generation_subject_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    generation_id UUID NOT NULL REFERENCES ai_generation_log(id),
    anonymised_id TEXT NOT NULL,
    real_entity_type TEXT NOT NULL,
    real_entity_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. ai_draft_contents — Draft text produced by AI, awaiting human review
CREATE TABLE ai_draft_contents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    generation_id UUID NOT NULL REFERENCES ai_generation_log(id),
    draft_text TEXT NOT NULL,
    target_entity_type TEXT,
    target_entity_id UUID,
    promotion_status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (promotion_status IN ('DRAFT', 'PROMOTED', 'REJECTED', 'EXPIRED')),
    promoted_at TIMESTAMPTZ,
    promoted_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. bias_monitoring_runs — Periodic bias metric computation results
CREATE TABLE bias_monitoring_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    run_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    metrics_computed JSONB NOT NULL,
    thresholds_breached TEXT[],
    severity TEXT NOT NULL DEFAULT 'NONE'
        CHECK (severity IN ('NONE', 'WARNING', 'CRITICAL')),
    template_id UUID REFERENCES prompt_templates(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. bias_monitoring_policy — Threshold configuration for bias detection
CREATE TABLE bias_monitoring_policy (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    metric_code TEXT NOT NULL,
    threshold_value DECIMAL NOT NULL,
    severity_level TEXT NOT NULL DEFAULT 'WARNING'
        CHECK (severity_level IN ('WARNING', 'CRITICAL')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. ai_consent_checks — Append-only record of AI consent verification
CREATE TABLE ai_consent_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    consent_status TEXT NOT NULL,
    checked_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only enforcement for ai_consent_checks
CREATE RULE no_ai_consent_update AS ON UPDATE TO ai_consent_checks DO INSTEAD NOTHING;
CREATE RULE no_ai_consent_delete AS ON DELETE TO ai_consent_checks DO INSTEAD NOTHING;

INSERT INTO schema_migrations (version, description) VALUES ('V019', 'Layer 16 — AI Layer');
