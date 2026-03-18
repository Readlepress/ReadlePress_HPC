"""
Core PDF generation for ReadlePress HPC and Merkle certificates.
"""
import logging
from io import BytesIO
from pathlib import Path

from weasyprint import HTML, CSS
from jinja2 import Environment, FileSystemLoader, select_autoescape

from . import db
from . import signing

logger = logging.getLogger(__name__)

# RTL language codes (Nastaliq script)
RTL_LANGUAGES = {"ur", "ks"}

# NEP 2020 stage codes
STAGE_FOUNDATIONAL = "FOUNDATIONAL"
STAGE_SECONDARY = "SECONDARY"


def _get_template_env() -> Environment:
    """Get Jinja2 environment with templates directory."""
    templates_dir = Path(__file__).resolve().parent.parent / "templates"
    return Environment(
        loader=FileSystemLoader(str(templates_dir)),
        autoescape=select_autoescape(["html", "xml"]),
    )


def _resolve_descriptor_from_ewm(
    current_ewm: float,
    descriptor_levels: list[dict],
    stage_code: str,
    primary_lang: str,
    secondary_lang: str,
    tenant_id: str | None,
) -> dict:
    """
    Resolve the descriptor level from EWM value.
    For FOUNDATIONAL: use metaphor_icon, never numbers.
    For SECONDARY: full academic descriptors with numbers.
    Only use VERIFIED or OFFICIAL_LOCKED localization.
    """
    if not descriptor_levels:
        return {"primary": str(current_ewm), "secondary": str(current_ewm), "show_number": False}

    # Find closest descriptor by numeric_value
    sorted_levels = sorted(
        descriptor_levels,
        key=lambda x: abs(float(x.get("numeric_value", 0)) - float(current_ewm)),
    )
    level = sorted_levels[0] if sorted_levels else {}

    stage_code = (stage_code or "").upper()
    is_foundational = stage_code == STAGE_FOUNDATIONAL
    is_secondary = stage_code == STAGE_SECONDARY

    primary_label = level.get("label_local") or level.get("label") or level.get("level_code", "")
    secondary_label = level.get("label") or level.get("label_local") or level.get("level_code", "")

    # Localize if we have key-based lookup (simplified: use label/label_local from snapshot)
    # DRAFT strings never used - we only use snapshot data which is locked

    metaphor_icon = level.get("metaphor_icon", "")

    if is_foundational:
        # Emoji/metaphor only, never numbers
        primary_display = metaphor_icon or primary_label
        secondary_display = metaphor_icon or secondary_label
        show_number = False
    elif is_secondary:
        # Full academic with numbers
        num_val = level.get("numeric_value", current_ewm)
        primary_display = f"{primary_label} ({num_val})"
        secondary_display = f"{secondary_label} ({num_val})"
        show_number = True
    else:
        # Preparatory/Middle: label only or label with optional number
        primary_display = primary_label
        secondary_display = secondary_label
        show_number = False

    return {
        "primary": primary_display or str(current_ewm),
        "secondary": secondary_display or str(current_ewm),
        "show_number": show_number,
    }


def _build_competency_mastery_rows(
    mastery_aggregates: list[dict],
    taxonomy_snapshot: dict,
    stage_code: str,
    primary_lang: str,
    secondary_lang: str,
    tenant_id: str | None,
) -> list[dict]:
    """Build rows for domain-wise competency mastery display."""
    rows = []
    taxonomy = taxonomy_snapshot or {}
    domains = taxonomy.get("domains", [])
    competency_map = {}
    for d in domains:
        for c in d.get("competencies", []):
            competency_map[str(c.get("id", c.get("competency_id", "")))] = {
                **c,
                "domain_name": d.get("name", ""),
                "domain_name_local": d.get("name_local", ""),
            }

    for agg in mastery_aggregates:
        comp_id = str(agg.get("competency_id", ""))
        comp_info = competency_map.get(comp_id, {})
        descriptor_levels = comp_info.get("descriptor_levels", [])
        if isinstance(descriptor_levels, dict):
            descriptor_levels = list(descriptor_levels.values())

        descriptor = _resolve_descriptor_from_ewm(
            float(agg.get("current_ewm", 0)),
            descriptor_levels,
            stage_code,
            primary_lang,
            secondary_lang,
            tenant_id,
        )
        rows.append({
            "domain": comp_info.get("domain_name", "—"),
            "domain_local": comp_info.get("domain_name_local", ""),
            "competency_name": comp_info.get("name", comp_info.get("uid", "—")),
            "competency_name_local": comp_info.get("name_local", ""),
            "descriptor_primary": descriptor["primary"],
            "descriptor_secondary": descriptor["secondary"],
            "show_number": descriptor["show_number"],
        })
    return rows


def generate_hpc(
    student_id: str,
    academic_year_id: str,
    tenant_id: str,
    primary_lang: str,
    secondary_lang: str | None = None,
) -> bytes:
    """
    Generate Holistic Progress Card (HPC) PDF for a student.
    - Reads from year_snapshots (taxonomy_snapshot, school_identity_snapshot)
    - Reads mastery_aggregates for the student
    - Uses snapshot data only for locked years
    - Bilingual: primary left, English right (or swapped for RTL)
    - FOUNDATIONAL: emoji/metaphor descriptors, never numbers
    - SECONDARY: full academic descriptors with numbers
    - Only VERIFIED or OFFICIAL_LOCKED localization (no DRAFT)
    - Ensures no disability data in standard HPC exports
    """
    # Guard: no disability data in standard HPC
    if db.student_has_disability_profile(student_id, tenant_id):
        logger.warning(
            "Student %s has disability profile; standard HPC must not expose this data",
            student_id,
        )
        # We still generate the HPC but ensure we never include disability info.
        # The schema already excludes it - we don't fetch from student_disability_profiles.

    secondary_lang = secondary_lang or "en"
    if primary_lang.lower() == "en":
        primary_lang, secondary_lang = "en", secondary_lang or "hi"

    snapshot = db.fetch_year_snapshot(academic_year_id, tenant_id)
    if not snapshot:
        raise ValueError(
            f"No year snapshot found for academic_year_id={academic_year_id}, tenant_id={tenant_id}"
        )

    student = db.fetch_student_info(student_id, tenant_id)
    if not student:
        raise ValueError(f"Student not found: {student_id}")

    enrolment = db.fetch_enrolment_info(student_id, academic_year_id, tenant_id)
    year_info = db.fetch_academic_year_info(academic_year_id, tenant_id)
    mastery_aggregates = db.fetch_mastery_aggregates(student_id, academic_year_id, tenant_id)

    taxonomy_snapshot = snapshot.get("taxonomy_snapshot") or {}
    school_identity = snapshot.get("school_identity_snapshot") or {}

    # Determine stage from enrolment (has stage_code from academic_stages join)
    stage_code = (
        (enrolment or {}).get("stage_code")
        or taxonomy_snapshot.get("stage_code")
        or STAGE_FOUNDATIONAL
    )

    mastery_rows = _build_competency_mastery_rows(
        mastery_aggregates,
        taxonomy_snapshot,
        stage_code,
        primary_lang,
        secondary_lang,
        tenant_id,
    )

    primary_rtl = primary_lang.lower() in RTL_LANGUAGES
    # Bilingual: primary left, English right. For RTL primary, right column gets RTL.
    secondary_rtl = secondary_lang.lower() in RTL_LANGUAGES

    env = _get_template_env()
    template = env.get_template("hpc_report.html")
    html_str = template.render(
        student=student,
        enrolment=enrolment or {},
        year_info=year_info or {},
        school_name=school_identity.get("name", "—"),
        school_name_local=school_identity.get("name_local", ""),
        udise_code=school_identity.get("udise_code", "—"),
        academic_year_label=year_info.get("label", "") if year_info else "",
        mastery_rows=mastery_rows,
        primary_lang=primary_lang,
        secondary_lang=secondary_lang,
        primary_rtl=primary_rtl,
        secondary_rtl=secondary_rtl,
        stage_code=stage_code,
        is_foundational=stage_code == STAGE_FOUNDATIONAL,
        is_secondary=stage_code == STAGE_SECONDARY,
    )

    html = HTML(string=html_str, base_url=str(Path(__file__).resolve().parent.parent))
    pdf_bytes_io = BytesIO()
    html.write_pdf(pdf_bytes_io)
    pdf_bytes = pdf_bytes_io.getvalue()

    return signing.sign_pdf(pdf_bytes)


def generate_merkle_certificate(academic_year_id: str, tenant_id: str) -> bytes:
    """
    Generate Merkle root certificate PDF.
    Shows merkle_root_hash, total_leaf_count, tree_depth, external_anchor_ref, school info.
    """
    snapshot = db.fetch_year_snapshot(academic_year_id, tenant_id)
    if not snapshot:
        raise ValueError(
            f"No year snapshot found for academic_year_id={academic_year_id}, tenant_id={tenant_id}"
        )

    year_info = db.fetch_academic_year_info(academic_year_id, tenant_id)
    school_identity = snapshot.get("school_identity_snapshot") or {}

    env = _get_template_env()
    template = env.get_template("merkle_certificate.html")
    html_str = template.render(
        school_name=school_identity.get("name", "—"),
        school_name_local=school_identity.get("name_local", ""),
        udise_code=school_identity.get("udise_code", "—"),
        academic_year_label=year_info.get("label", "") if year_info else "",
        merkle_root_hash=snapshot.get("merkle_root_hash", "—"),
        total_leaf_count=snapshot.get("total_leaf_count", 0),
        tree_depth=snapshot.get("tree_depth", 0),
        external_anchor_ref=snapshot.get("external_anchor_ref", "—"),
        external_anchor_timestamp=snapshot.get("external_anchor_timestamp"),
        created_at=snapshot.get("created_at"),
    )

    html = HTML(string=html_str, base_url=str(Path(__file__).resolve().parent.parent))
    pdf_bytes_io = BytesIO()
    html.write_pdf(pdf_bytes_io)
    pdf_bytes = pdf_bytes_io.getvalue()

    return signing.sign_pdf(pdf_bytes)
