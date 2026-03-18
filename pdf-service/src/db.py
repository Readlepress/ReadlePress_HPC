"""
Database connection for PDF service.
Reads from year_snapshots for locked year data.
"""
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager


def get_connection_string() -> str:
    """Get database URL from environment."""
    url = os.getenv("DATABASE_URL")
    if not url:
        raise ValueError("DATABASE_URL environment variable is required")
    return url


@contextmanager
def get_connection():
    """Context manager for database connections."""
    conn = psycopg2.connect(get_connection_string(), cursor_factory=RealDictCursor)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def fetch_year_snapshot(academic_year_id: str, tenant_id: str) -> dict | None:
    """
    Fetch year_snapshot for a locked academic year.
    Returns taxonomy_snapshot, school_identity_snapshot, merkle data.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, merkle_root_hash, total_leaf_count, tree_depth,
                       taxonomy_snapshot, school_identity_snapshot,
                       external_anchor_ref, external_anchor_timestamp, created_at
                FROM year_snapshots
                WHERE academic_year_id = %s AND tenant_id = %s
                """,
                (academic_year_id, tenant_id),
            )
            row = cur.fetchone()
            return dict(row) if row else None


def fetch_mastery_aggregates(
    student_id: str, academic_year_id: str, tenant_id: str
) -> list[dict]:
    """Fetch mastery aggregates for a student in the given academic year."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT competency_id, current_ewm, event_count, trend_direction,
                       confidence_score
                FROM mastery_aggregates
                WHERE student_id = %s AND academic_year_id = %s AND tenant_id = %s
                  AND current_ewm IS NOT NULL
                ORDER BY competency_id
                """,
                (student_id, academic_year_id, tenant_id),
            )
            return [dict(r) for r in cur.fetchall()]


def fetch_student_info(student_id: str, tenant_id: str) -> dict | None:
    """Fetch student profile (no disability data)."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT sp.id, sp.first_name, sp.last_name, sp.first_name_local,
                       sp.last_name_local, sp.date_of_birth, sp.gender
                FROM student_profiles sp
                WHERE sp.id = %s AND sp.tenant_id = %s
                """,
                (student_id, tenant_id),
            )
            row = cur.fetchone()
            return dict(row) if row else None


def fetch_enrolment_info(
    student_id: str, academic_year_id: str, tenant_id: str
) -> dict | None:
    """Fetch student enrolment for the academic year (class, grade, roll number, stage_code)."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT se.roll_number, se.academic_year_label, c.grade, c.section,
                       c.stage_id, ast.stage_code, ay.label as year_label
                FROM student_enrolments se
                JOIN classes c ON c.id = se.class_id AND c.tenant_id = se.tenant_id
                JOIN academic_stages ast ON ast.id = c.stage_id
                JOIN academic_years ay ON ay.school_id = c.school_id
                    AND ay.tenant_id = c.tenant_id
                    AND ay.label = se.academic_year_label
                WHERE se.student_id = %s AND ay.id = %s AND se.tenant_id = %s
                  AND se.status = 'ACTIVE'
                LIMIT 1
                """,
                (student_id, academic_year_id, tenant_id),
            )
            row = cur.fetchone()
            return dict(row) if row else None


def fetch_academic_year_info(academic_year_id: str, tenant_id: str) -> dict | None:
    """Fetch academic year label and dates."""
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT id, label, start_date, end_date, status
                FROM academic_years
                WHERE id = %s AND tenant_id = %s
                """,
                (academic_year_id, tenant_id),
            )
            row = cur.fetchone()
            return dict(row) if row else None


def student_has_disability_profile(student_id: str, tenant_id: str) -> bool:
    """
    Check if student has an active disability profile.
    Used to ensure no disability data appears in standard HPC exports.
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT 1 FROM student_disability_profiles
                WHERE student_id = %s AND tenant_id = %s AND is_active = TRUE
                LIMIT 1
                """,
                (student_id, tenant_id),
            )
            return cur.fetchone() is not None


def fetch_localization_string(
    key_code: str, language_code: str, tenant_id: str | None
) -> str | None:
    """
    Fetch localized string. Only VERIFIED or OFFICIAL_LOCKED status.
    DRAFT strings are NEVER used.
    Prefer tenant-specific, fallback to platform (tenant_id IS NULL).
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            # Try tenant-specific first
            if tenant_id:
                cur.execute(
                    """
                    SELECT ls.value
                    FROM localization_strings ls
                    JOIN localization_keys lk ON lk.id = ls.key_id
                    WHERE lk.key_code = %s AND ls.language_code = %s
                      AND ls.status IN ('VERIFIED', 'OFFICIAL_LOCKED')
                      AND ls.tenant_id = %s
                    ORDER BY ls.version DESC
                    LIMIT 1
                    """,
                    (key_code, language_code, tenant_id),
                )
                row = cur.fetchone()
                if row:
                    return row["value"]
            # Fallback to platform
            cur.execute(
                """
                SELECT ls.value
                FROM localization_strings ls
                JOIN localization_keys lk ON lk.id = ls.key_id
                WHERE lk.key_code = %s AND ls.language_code = %s
                  AND ls.status IN ('VERIFIED', 'OFFICIAL_LOCKED')
                  AND ls.tenant_id IS NULL
                ORDER BY ls.version DESC
                LIMIT 1
                """,
                (key_code, language_code),
            )
            row = cur.fetchone()
            return row["value"] if row else None
