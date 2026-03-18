"""
Flask API for ReadlePress PDF generation service.
"""
import logging
from dotenv import load_dotenv

load_dotenv()

from flask import Flask, request, jsonify, send_file
from io import BytesIO

from . import generator

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)


@app.route("/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({"status": "ok", "service": "readlepress-pdf-service"})


@app.route("/generate/hpc", methods=["POST"])
def generate_hpc():
    """
    Generate HPC PDF for a student.
    JSON body: { student_id, academic_year_id, tenant_id, language_code, secondary_language_code? }
    """
    try:
        data = request.get_json(force=True, silent=True) or {}
        student_id = data.get("student_id")
        academic_year_id = data.get("academic_year_id")
        tenant_id = data.get("tenant_id")
        language_code = data.get("language_code", "en")
        secondary_language_code = data.get("secondary_language_code")

        if not all([student_id, academic_year_id, tenant_id]):
            return (
                jsonify({
                    "error": "Missing required fields: student_id, academic_year_id, tenant_id",
                }),
                400,
            )

        pdf_bytes = generator.generate_hpc(
            student_id=str(student_id),
            academic_year_id=str(academic_year_id),
            tenant_id=str(tenant_id),
            primary_lang=str(language_code),
            secondary_lang=str(secondary_language_code) if secondary_language_code else None,
        )
        return send_file(
            BytesIO(pdf_bytes),
            mimetype="application/pdf",
            as_attachment=True,
            download_name="hpc_report.pdf",
        )
    except ValueError as e:
        logger.warning("HPC generation validation error: %s", e)
        return jsonify({"error": str(e)}), 404
    except Exception as e:
        logger.exception("HPC generation failed")
        return jsonify({"error": "Internal server error", "detail": str(e)}), 500


@app.route("/generate/merkle-certificate", methods=["POST"])
def generate_merkle_certificate():
    """
    Generate Merkle root certificate PDF.
    JSON body: { academic_year_id, tenant_id }
    """
    try:
        data = request.get_json(force=True, silent=True) or {}
        academic_year_id = data.get("academic_year_id")
        tenant_id = data.get("tenant_id")

        if not all([academic_year_id, tenant_id]):
            return (
                jsonify({
                    "error": "Missing required fields: academic_year_id, tenant_id",
                }),
                400,
            )

        pdf_bytes = generator.generate_merkle_certificate(
            academic_year_id=str(academic_year_id),
            tenant_id=str(tenant_id),
        )
        return send_file(
            BytesIO(pdf_bytes),
            mimetype="application/pdf",
            as_attachment=True,
            download_name="merkle_certificate.pdf",
        )
    except ValueError as e:
        logger.warning("Merkle certificate generation validation error: %s", e)
        return jsonify({"error": str(e)}), 404
    except Exception as e:
        logger.exception("Merkle certificate generation failed")
        return jsonify({"error": "Internal server error", "detail": str(e)}), 500


def create_app():
    """Application factory."""
    return app


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
