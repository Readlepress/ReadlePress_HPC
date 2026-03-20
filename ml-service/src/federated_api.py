"""
Flask API for Federated Bias Detection.
"""

import json
import os
from datetime import datetime, timezone

from flask import Flask, request, jsonify

from .federated_bias import (
    compute_local_bias_metrics,
    aggregate_federated_metrics,
    generate_bias_report,
)

app = Flask(__name__)

_latest_report: dict | None = None
_latest_aggregated: dict | None = None


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "service": "federated-bias", "timestamp": datetime.now(timezone.utc).isoformat()})


@app.route("/federated/compute-local", methods=["POST"])
def compute_local():
    """Compute local bias metrics for a single tenant."""
    body = request.get_json(force=True)
    tenant_id = body.get("tenant_id")
    if not tenant_id:
        return jsonify({"error": "tenant_id is required"}), 400

    try:
        metrics = compute_local_bias_metrics(tenant_id)
        return jsonify(metrics)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/federated/aggregate", methods=["POST"])
def aggregate():
    """Aggregate local metric sets from multiple schools."""
    global _latest_report, _latest_aggregated

    body = request.get_json(force=True)
    local_metrics_list = body.get("local_metrics", [])
    if not local_metrics_list:
        return jsonify({"error": "local_metrics array is required"}), 400

    try:
        aggregated = aggregate_federated_metrics(local_metrics_list)
        report_text = generate_bias_report(aggregated)
        _latest_aggregated = aggregated
        _latest_report = {
            "report_text": report_text,
            "aggregated": aggregated,
            "generated_at": datetime.now(timezone.utc).isoformat(),
        }
        return jsonify(aggregated)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/federated/latest-report", methods=["GET"])
def latest_report():
    """Return the latest aggregated bias report."""
    if _latest_report is None:
        return jsonify({"error": "No report available yet. Run /federated/aggregate first."}), 404
    return jsonify(_latest_report)


if __name__ == "__main__":
    port = int(os.environ.get("ML_SERVICE_PORT", "5050"))
    app.run(host="0.0.0.0", port=port, debug=os.environ.get("FLASK_DEBUG", "0") == "1")
