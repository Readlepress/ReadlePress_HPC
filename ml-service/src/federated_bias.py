"""
Federated Bias Detection Module

Implements privacy-preserving bias detection across schools using federated
gradient-like summaries (counts + sums, never raw data).
"""

import os
import json
import math
from datetime import datetime, timezone
from typing import Any

import psycopg2

WARNING_THRESHOLD = 0.15
CRITICAL_THRESHOLD = 0.30


def _get_db_connection():
    return psycopg2.connect(
        os.environ.get(
            "DATABASE_URL",
            "postgresql://app_rw:app_rw_dev_password@localhost:5432/readlepress",
        )
    )


def _safe_div(numerator: float, denominator: float) -> float:
    return numerator / denominator if denominator else 0.0


def compute_local_bias_metrics(tenant_id: str) -> dict[str, Any]:
    """Compute bias metrics for one school's data.

    Returns gradient-like summaries (counts and sums) that are safe to share
    across the federation without exposing individual student data.
    """
    conn = _get_db_connection()
    try:
        cur = conn.cursor()

        # Acceptance rate by mastery decile (10 buckets)
        cur.execute(
            """
            SELECT
                NTILE(10) OVER (ORDER BY me.numeric_value) AS decile,
                COUNT(*) AS total,
                SUM(CASE WHEN ad.status = 'ACCEPTED' THEN 1 ELSE 0 END) AS accepted
            FROM mastery_events me
            LEFT JOIN ai_drafts ad ON ad.student_id = me.student_id
            WHERE me.tenant_id = %s
            GROUP BY decile
            ORDER BY decile
            """,
            (tenant_id,),
        )
        rows = cur.fetchall()
        acceptance_by_decile: dict[int, dict[str, float]] = {}
        for row in rows:
            decile, total, accepted = row
            acceptance_by_decile[decile] = {
                "total": total,
                "accepted": accepted,
                "rate": _safe_div(accepted, total),
            }

        # Sentiment variance between high and low mastery groups
        cur.execute(
            """
            SELECT
                CASE WHEN me.numeric_value >= 0.5 THEN 'high' ELSE 'low' END AS mastery_group,
                AVG(ad.sentiment_score) AS avg_sentiment,
                COUNT(*) AS cnt
            FROM mastery_events me
            JOIN ai_drafts ad ON ad.student_id = me.student_id
            WHERE me.tenant_id = %s AND ad.sentiment_score IS NOT NULL
            GROUP BY mastery_group
            """,
            (tenant_id,),
        )
        sentiment_rows = cur.fetchall()
        sentiment_by_group: dict[str, dict[str, float]] = {}
        for row in sentiment_rows:
            group, avg_sent, cnt = row
            sentiment_by_group[group] = {
                "avg_sentiment": float(avg_sent) if avg_sent else 0.0,
                "count": cnt,
            }
        high_sent = sentiment_by_group.get("high", {}).get("avg_sentiment", 0.0)
        low_sent = sentiment_by_group.get("low", {}).get("avg_sentiment", 0.0)
        sentiment_variance = abs(high_sent - low_sent)

        # Edit distance by mastery group
        cur.execute(
            """
            SELECT
                CASE WHEN me.numeric_value >= 0.5 THEN 'high' ELSE 'low' END AS mastery_group,
                AVG(ad.edit_distance) AS avg_edit_distance,
                COUNT(*) AS cnt
            FROM mastery_events me
            JOIN ai_drafts ad ON ad.student_id = me.student_id
            WHERE me.tenant_id = %s AND ad.edit_distance IS NOT NULL
            GROUP BY mastery_group
            """,
            (tenant_id,),
        )
        edit_rows = cur.fetchall()
        edit_distance_by_mastery: dict[str, dict[str, float]] = {}
        for row in edit_rows:
            group, avg_ed, cnt = row
            edit_distance_by_mastery[group] = {
                "avg_edit_distance": float(avg_ed) if avg_ed else 0.0,
                "count": cnt,
            }

        # Acceptance by social category
        cur.execute(
            """
            SELECT
                sp.social_category,
                COUNT(*) AS total,
                SUM(CASE WHEN ad.status = 'ACCEPTED' THEN 1 ELSE 0 END) AS accepted
            FROM student_profiles sp
            JOIN ai_drafts ad ON ad.student_id = sp.id
            WHERE sp.tenant_id = %s AND sp.social_category IS NOT NULL
            GROUP BY sp.social_category
            """,
            (tenant_id,),
        )
        social_rows = cur.fetchall()
        acceptance_by_social: dict[str, dict[str, float]] = {}
        for row in social_rows:
            cat, total, accepted = row
            acceptance_by_social[cat] = {
                "total": total,
                "accepted": accepted,
                "rate": _safe_div(accepted, total),
            }

        return {
            "tenant_id": tenant_id,
            "computed_at": datetime.now(timezone.utc).isoformat(),
            "acceptance_rate_by_mastery_decile": acceptance_by_decile,
            "sentiment_variance": sentiment_variance,
            "sentiment_by_group": sentiment_by_group,
            "edit_distance_by_mastery": edit_distance_by_mastery,
            "acceptance_by_social_category": acceptance_by_social,
        }
    finally:
        conn.close()


def aggregate_federated_metrics(
    local_metrics_list: list[dict[str, Any]],
) -> dict[str, Any]:
    """Aggregate metrics from multiple schools using weighted averages.

    Detects threshold breaches and computes an equity index.
    """
    if not local_metrics_list:
        return {
            "aggregated_metrics": {},
            "threshold_breaches": [],
            "equity_index": 1.0,
            "recommendations": [],
        }

    # Weighted-average acceptance by decile
    decile_totals: dict[int, dict[str, float]] = {}
    for metrics in local_metrics_list:
        for decile_str, vals in metrics.get("acceptance_rate_by_mastery_decile", {}).items():
            d = int(decile_str)
            if d not in decile_totals:
                decile_totals[d] = {"total": 0, "accepted": 0}
            decile_totals[d]["total"] += vals["total"]
            decile_totals[d]["accepted"] += vals["accepted"]

    agg_acceptance_by_decile = {}
    for d, vals in sorted(decile_totals.items()):
        agg_acceptance_by_decile[d] = {
            "total": vals["total"],
            "accepted": vals["accepted"],
            "rate": _safe_div(vals["accepted"], vals["total"]),
        }

    # Weighted sentiment variance
    total_weight = 0.0
    weighted_variance = 0.0
    for metrics in local_metrics_list:
        sv = metrics.get("sentiment_variance", 0.0)
        groups = metrics.get("sentiment_by_group", {})
        w = sum(g.get("count", 0) for g in groups.values())
        weighted_variance += sv * w
        total_weight += w
    agg_sentiment_variance = _safe_div(weighted_variance, total_weight)

    # Weighted edit distance
    agg_edit_distance: dict[str, dict[str, float]] = {}
    for metrics in local_metrics_list:
        for group, vals in metrics.get("edit_distance_by_mastery", {}).items():
            if group not in agg_edit_distance:
                agg_edit_distance[group] = {"sum_ed": 0.0, "count": 0}
            agg_edit_distance[group]["sum_ed"] += vals["avg_edit_distance"] * vals["count"]
            agg_edit_distance[group]["count"] += vals["count"]
    for group in agg_edit_distance:
        c = agg_edit_distance[group]["count"]
        agg_edit_distance[group]["avg_edit_distance"] = _safe_div(
            agg_edit_distance[group]["sum_ed"], c
        )

    # Weighted social category acceptance
    social_totals: dict[str, dict[str, float]] = {}
    for metrics in local_metrics_list:
        for cat, vals in metrics.get("acceptance_by_social_category", {}).items():
            if cat not in social_totals:
                social_totals[cat] = {"total": 0, "accepted": 0}
            social_totals[cat]["total"] += vals["total"]
            social_totals[cat]["accepted"] += vals["accepted"]
    agg_social = {}
    for cat, vals in social_totals.items():
        agg_social[cat] = {
            "total": vals["total"],
            "accepted": vals["accepted"],
            "rate": _safe_div(vals["accepted"], vals["total"]),
        }

    aggregated = {
        "acceptance_rate_by_mastery_decile": agg_acceptance_by_decile,
        "sentiment_variance": agg_sentiment_variance,
        "edit_distance_by_mastery": agg_edit_distance,
        "acceptance_by_social_category": agg_social,
        "school_count": len(local_metrics_list),
        "aggregated_at": datetime.now(timezone.utc).isoformat(),
    }

    # Threshold detection
    breaches: list[dict[str, Any]] = []

    if agg_sentiment_variance >= CRITICAL_THRESHOLD:
        breaches.append(
            {"metric": "sentiment_variance", "value": agg_sentiment_variance, "severity": "CRITICAL"}
        )
    elif agg_sentiment_variance >= WARNING_THRESHOLD:
        breaches.append(
            {"metric": "sentiment_variance", "value": agg_sentiment_variance, "severity": "WARNING"}
        )

    decile_rates = [v["rate"] for v in agg_acceptance_by_decile.values() if v["total"] > 0]
    if len(decile_rates) >= 2:
        rate_spread = max(decile_rates) - min(decile_rates)
        if rate_spread >= CRITICAL_THRESHOLD:
            breaches.append(
                {"metric": "acceptance_rate_spread", "value": rate_spread, "severity": "CRITICAL"}
            )
        elif rate_spread >= WARNING_THRESHOLD:
            breaches.append(
                {"metric": "acceptance_rate_spread", "value": rate_spread, "severity": "WARNING"}
            )

    social_rates = [v["rate"] for v in agg_social.values() if v["total"] > 0]
    if len(social_rates) >= 2:
        social_spread = max(social_rates) - min(social_rates)
        if social_spread >= CRITICAL_THRESHOLD:
            breaches.append(
                {"metric": "social_category_spread", "value": social_spread, "severity": "CRITICAL"}
            )
        elif social_spread >= WARNING_THRESHOLD:
            breaches.append(
                {"metric": "social_category_spread", "value": social_spread, "severity": "WARNING"}
            )

    # Equity index: 1.0 = perfectly equitable, 0.0 = maximally biased
    penalty = 0.0
    for b in breaches:
        penalty += 0.3 if b["severity"] == "CRITICAL" else 0.1
    equity_index = max(0.0, min(1.0, 1.0 - penalty))

    recommendations: list[str] = []
    for b in breaches:
        if b["metric"] == "sentiment_variance":
            recommendations.append(
                f"Sentiment variance ({b['value']:.3f}) exceeds {b['severity']} threshold. "
                "Review AI prompt templates for differential tone by mastery level."
            )
        elif b["metric"] == "acceptance_rate_spread":
            recommendations.append(
                f"Acceptance rate spread ({b['value']:.3f}) exceeds {b['severity']} threshold. "
                "Investigate whether AI drafts for lower mastery students are systematically lower quality."
            )
        elif b["metric"] == "social_category_spread":
            recommendations.append(
                f"Social category acceptance spread ({b['value']:.3f}) exceeds {b['severity']} threshold. "
                "Audit AI outputs for potential demographic bias."
            )

    return {
        "aggregated_metrics": aggregated,
        "threshold_breaches": breaches,
        "equity_index": equity_index,
        "recommendations": recommendations,
    }


def generate_bias_report(aggregated: dict[str, Any]) -> str:
    """Generate a human-readable bias report from aggregated metrics."""
    lines: list[str] = []
    lines.append("=" * 60)
    lines.append("FEDERATED BIAS DETECTION REPORT")
    lines.append("=" * 60)

    metrics = aggregated.get("aggregated_metrics", {})
    lines.append(f"\nSchools included: {metrics.get('school_count', 'N/A')}")
    lines.append(f"Aggregated at: {metrics.get('aggregated_at', 'N/A')}")
    lines.append(f"Equity Index: {aggregated.get('equity_index', 'N/A')}")

    lines.append("\n--- Acceptance Rate by Mastery Decile ---")
    for decile, vals in sorted(metrics.get("acceptance_rate_by_mastery_decile", {}).items(), key=lambda x: int(x[0])):
        lines.append(
            f"  Decile {decile}: {vals['rate']:.1%} "
            f"({int(vals['accepted'])}/{int(vals['total'])})"
        )

    lines.append(f"\nSentiment Variance: {metrics.get('sentiment_variance', 0):.4f}")

    ed = metrics.get("edit_distance_by_mastery", {})
    if ed:
        lines.append("\n--- Edit Distance by Mastery Group ---")
        for group, vals in ed.items():
            lines.append(f"  {group}: avg={vals.get('avg_edit_distance', 0):.2f} (n={int(vals.get('count', 0))})")

    social = metrics.get("acceptance_by_social_category", {})
    if social:
        lines.append("\n--- Acceptance by Social Category ---")
        for cat, vals in social.items():
            lines.append(
                f"  {cat}: {vals['rate']:.1%} "
                f"({int(vals['accepted'])}/{int(vals['total'])})"
            )

    breaches = aggregated.get("threshold_breaches", [])
    if breaches:
        lines.append(f"\n*** THRESHOLD BREACHES ({len(breaches)}) ***")
        for b in breaches:
            lines.append(f"  [{b['severity']}] {b['metric']}: {b['value']:.4f}")

    recs = aggregated.get("recommendations", [])
    if recs:
        lines.append("\n--- Recommendations ---")
        for i, r in enumerate(recs, 1):
            lines.append(f"  {i}. {r}")

    lines.append("\n" + "=" * 60)
    return "\n".join(lines)
