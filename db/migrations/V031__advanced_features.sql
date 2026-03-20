-- ============================================================================
-- V031 — Advanced Features: Policy Simulation, Assessment Recommendations,
--        Prediction Runs, NLP Analysis, Vision Analysis, Blockchain Anchors
-- ============================================================================

-- 1. policy_simulation_runs
CREATE TABLE IF NOT EXISTS policy_simulation_runs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id),
    simulation_type TEXT NOT NULL,
    parameters      JSONB NOT NULL,
    results         JSONB,
    impact_summary  JSONB,
    risk_level      TEXT CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH')),
    simulated_by    UUID REFERENCES users(id),
    simulated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    directive_id    UUID,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. assessment_recommendations
CREATE TABLE IF NOT EXISTS assessment_recommendations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    teacher_id          UUID REFERENCES users(id),
    student_id          UUID REFERENCES student_profiles(id),
    competency_id       UUID REFERENCES competencies(id),
    priority_score      DECIMAL,
    reason              TEXT,
    recommendation_type TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at          TIMESTAMPTZ
);

-- 3. prediction_runs
CREATE TABLE IF NOT EXISTS prediction_runs (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             UUID NOT NULL REFERENCES tenants(id),
    model_version         TEXT,
    student_id            UUID REFERENCES student_profiles(id),
    competency_id         UUID REFERENCES competencies(id),
    risk_score            DECIMAL,
    risk_level            TEXT CHECK (risk_level IN ('LOW', 'MEDIUM', 'HIGH')),
    contributing_factors  JSONB,
    predicted_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. nlp_analysis_results
CREATE TABLE IF NOT EXISTS nlp_analysis_results (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id),
    source_type       TEXT,
    source_id         UUID,
    sentiment         TEXT,
    confidence        DECIMAL,
    themes            JSONB,
    language_detected TEXT,
    analyzed_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. vision_analysis_results
CREATE TABLE IF NOT EXISTS vision_analysis_results (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id             UUID NOT NULL REFERENCES tenants(id),
    evidence_id           UUID REFERENCES evidence_records(id),
    category              TEXT,
    confidence            DECIMAL,
    tags                  TEXT[],
    handwriting_detected  BOOLEAN,
    extracted_text        TEXT,
    analyzed_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. blockchain_anchors
CREATE TABLE IF NOT EXISTS blockchain_anchors (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id),
    year_snapshot_id    UUID REFERENCES year_snapshots(id),
    chain_name          TEXT NOT NULL DEFAULT 'POLYGON',
    transaction_hash    TEXT,
    block_number        BIGINT,
    anchor_data_hash    TEXT,
    anchored_at         TIMESTAMPTZ,
    verification_url    TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_policy_sim_tenant ON policy_simulation_runs(tenant_id);
CREATE INDEX IF NOT EXISTS idx_policy_sim_type ON policy_simulation_runs(simulation_type);
CREATE INDEX IF NOT EXISTS idx_assessment_rec_student ON assessment_recommendations(student_id);
CREATE INDEX IF NOT EXISTS idx_assessment_rec_teacher ON assessment_recommendations(teacher_id);
CREATE INDEX IF NOT EXISTS idx_prediction_runs_student ON prediction_runs(student_id);
CREATE INDEX IF NOT EXISTS idx_prediction_runs_risk ON prediction_runs(risk_level);
CREATE INDEX IF NOT EXISTS idx_nlp_results_source ON nlp_analysis_results(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_vision_results_evidence ON vision_analysis_results(evidence_id);
CREATE INDEX IF NOT EXISTS idx_blockchain_anchors_snapshot ON blockchain_anchors(year_snapshot_id);

INSERT INTO schema_migrations (version, description)
VALUES ('V031', 'Advanced Features — Policy Simulation, NLP, Vision, Predictions, Blockchain');
