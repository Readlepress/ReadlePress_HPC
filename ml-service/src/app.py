"""
Flask API for the mastery decline prediction service.

Endpoints:
  POST /predict/decline-risk   — single student×competency prediction
  POST /predict/batch          — batch predictions for all students in a class
  GET  /health                 — health check
"""

import os
from datetime import datetime, timezone

import numpy as np
import pandas as pd
import psycopg2
from dotenv import load_dotenv
from flask import Flask, jsonify, request

from predict import predict_decline_risk

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))

app = Flask(__name__)

DATABASE_URL = os.getenv(
    'DATABASE_URL',
    'postgresql://app_rw:app_rw_dev_password@localhost:5432/readlepress',
)


def get_connection():
    return psycopg2.connect(DATABASE_URL)


def fetch_student_features(conn, student_id: str, competency_id: str, tenant_id: str) -> dict:
    """Fetch current features from the database for a student×competency pair."""
    cur = conn.cursor()

    cur.execute(
        """SELECT current_ewm, event_count, trend_slope, last_event_at
           FROM mastery_aggregates
           WHERE student_id = %s AND competency_id = %s AND tenant_id = %s
           LIMIT 1""",
        (student_id, competency_id, tenant_id),
    )
    agg_row = cur.fetchone()

    now = datetime.now(timezone.utc)

    if agg_row is None:
        return {
            'current_ewm': 0.0,
            'event_count': 0,
            'trend_slope': 0.0,
            'days_since_last_event': 90,
            'observation_frequency': 0.0,
            'descriptor_level_variance': 0.0,
            'term_position': 0.5,
            'peer_comparison': 0.0,
        }

    current_ewm = float(agg_row[0]) if agg_row[0] else 0.0
    event_count = int(agg_row[1]) if agg_row[1] else 0
    trend_slope = float(agg_row[2]) if agg_row[2] else 0.0
    last_event_at = agg_row[3]

    days_since = 90
    if last_event_at:
        if last_event_at.tzinfo is None:
            from datetime import timezone as tz
            last_event_at = last_event_at.replace(tzinfo=tz.utc)
        days_since = max(0, (now - last_event_at).days)

    # observation_frequency: events in last 30 days / 4 weeks
    thirty_days_ago = now - pd.Timedelta(days=30)
    cur.execute(
        """SELECT COUNT(*) FROM mastery_events
           WHERE student_id = %s AND competency_id = %s AND tenant_id = %s
             AND event_status = 'ACTIVE' AND observed_at >= %s""",
        (student_id, competency_id, tenant_id, thirty_days_ago),
    )
    recent_count = cur.fetchone()[0]
    obs_frequency = recent_count / 4.0

    # descriptor_level_variance
    cur.execute(
        """SELECT numeric_value FROM mastery_events
           WHERE student_id = %s AND competency_id = %s AND tenant_id = %s
             AND event_status = 'ACTIVE'
           ORDER BY observed_at""",
        (student_id, competency_id, tenant_id),
    )
    values = [float(r[0]) for r in cur.fetchall()]
    descriptor_variance = float(np.var(values)) if len(values) > 1 else 0.0

    # term_position
    term_position = 0.5
    cur.execute(
        """SELECT t.start_date, t.end_date
           FROM terms t WHERE t.is_active = true
           LIMIT 1""",
    )
    term_row = cur.fetchone()
    if term_row:
        term_start = pd.Timestamp(term_row[0], tz='UTC')
        term_end = pd.Timestamp(term_row[1], tz='UTC')
        duration = (term_end - term_start).days
        if duration > 0:
            term_position = min(1.0, max(0.0, (now - term_start.to_pydatetime()).days / duration))

    # peer_comparison
    cur.execute(
        """SELECT AVG(ma.current_ewm) FROM mastery_aggregates ma
           JOIN student_enrolments se ON se.student_id = ma.student_id AND se.status = 'ACTIVE'
           WHERE ma.competency_id = %s AND se.class_id IN (
               SELECT se2.class_id FROM student_enrolments se2
               WHERE se2.student_id = %s AND se2.status = 'ACTIVE'
           )""",
        (competency_id, student_id),
    )
    avg_row = cur.fetchone()
    class_avg = float(avg_row[0]) if avg_row and avg_row[0] else current_ewm
    peer_comparison = current_ewm - class_avg

    cur.close()

    return {
        'current_ewm': current_ewm,
        'event_count': event_count,
        'trend_slope': trend_slope,
        'days_since_last_event': days_since,
        'observation_frequency': obs_frequency,
        'descriptor_level_variance': descriptor_variance,
        'term_position': term_position,
        'peer_comparison': peer_comparison,
    }


@app.route('/health', methods=['GET'])
def health():
    return jsonify({
        'status': 'ok',
        'service': 'ml-prediction',
        'timestamp': datetime.now(timezone.utc).isoformat(),
    })


@app.route('/predict/decline-risk', methods=['POST'])
def decline_risk():
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    student_id = data.get('student_id')
    competency_id = data.get('competency_id')
    tenant_id = data.get('tenant_id')

    if not all([student_id, competency_id, tenant_id]):
        return jsonify({'error': 'student_id, competency_id, and tenant_id are required'}), 400

    try:
        conn = get_connection()
        features = fetch_student_features(conn, student_id, competency_id, tenant_id)
        conn.close()

        prediction = predict_decline_risk(features)
        prediction['student_id'] = student_id
        prediction['competency_id'] = competency_id

        return jsonify(prediction)
    except FileNotFoundError as e:
        return jsonify({'error': str(e)}), 503
    except Exception as e:
        return jsonify({'error': f'Prediction failed: {str(e)}'}), 500


@app.route('/predict/batch', methods=['POST'])
def batch_predict():
    data = request.get_json()
    if not data:
        return jsonify({'error': 'Request body required'}), 400

    class_id = data.get('class_id')
    tenant_id = data.get('tenant_id')

    if not all([class_id, tenant_id]):
        return jsonify({'error': 'class_id and tenant_id are required'}), 400

    try:
        conn = get_connection()
        cur = conn.cursor()

        cur.execute(
            """SELECT DISTINCT se.student_id, ma.competency_id
               FROM student_enrolments se
               JOIN mastery_aggregates ma ON ma.student_id = se.student_id
               WHERE se.class_id = %s AND se.status = 'ACTIVE'""",
            (class_id,),
        )
        pairs = cur.fetchall()
        cur.close()

        predictions = []
        for student_id, competency_id in pairs:
            features = fetch_student_features(conn, str(student_id), str(competency_id), tenant_id)
            prediction = predict_decline_risk(features)
            prediction['student_id'] = str(student_id)
            prediction['competency_id'] = str(competency_id)
            predictions.append(prediction)

        conn.close()

        predictions.sort(key=lambda p: p['risk_score'], reverse=True)

        return jsonify({
            'class_id': class_id,
            'total_predictions': len(predictions),
            'high_risk_count': sum(1 for p in predictions if p['risk_level'] == 'HIGH'),
            'medium_risk_count': sum(1 for p in predictions if p['risk_level'] == 'MEDIUM'),
            'low_risk_count': sum(1 for p in predictions if p['risk_level'] == 'LOW'),
            'predictions': predictions,
        })
    except FileNotFoundError as e:
        return jsonify({'error': str(e)}), 503
    except Exception as e:
        return jsonify({'error': f'Batch prediction failed: {str(e)}'}), 500


if __name__ == '__main__':
    port = int(os.getenv('ML_SERVICE_PORT', '5001'))
    debug = os.getenv('FLASK_DEBUG', 'false').lower() == 'true'
    app.run(host='0.0.0.0', port=port, debug=debug)
