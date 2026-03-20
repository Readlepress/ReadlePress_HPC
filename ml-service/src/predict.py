"""
Prediction module for mastery decline risk.

Loads the trained GradientBoostingClassifier from joblib and provides
prediction functions for individual and batch risk scoring.
"""

import os
from typing import Optional

import joblib
import numpy as np
import pandas as pd

MODEL_DIR = os.path.join(os.path.dirname(__file__), '..', 'models')
MODEL_PATH = os.path.join(MODEL_DIR, 'decline_predictor.joblib')

_loaded_model = None
_feature_cols = None


def _load_model():
    global _loaded_model, _feature_cols
    if _loaded_model is not None:
        return

    if not os.path.exists(MODEL_PATH):
        raise FileNotFoundError(
            f"Model not found at {MODEL_PATH}. Run train.py first."
        )

    data = joblib.load(MODEL_PATH)
    _loaded_model = data['model']
    _feature_cols = data['feature_cols']


def predict_decline_risk(student_features: dict) -> dict:
    """
    Predict mastery decline risk for a student×competency pair.

    Args:
        student_features: dict with keys matching training feature columns:
            current_ewm, event_count, trend_slope, days_since_last_event,
            observation_frequency, descriptor_level_variance, term_position,
            peer_comparison

    Returns:
        dict with:
            risk_score: float 0-1 (probability of decline)
            risk_level: LOW | MEDIUM | HIGH
            contributing_factors: list of human-readable factor descriptions
    """
    _load_model()

    feature_vector = pd.DataFrame([{
        col: student_features.get(col, 0.0) for col in _feature_cols
    }])

    risk_proba = _loaded_model.predict_proba(feature_vector)[0]
    risk_score = float(risk_proba[1]) if len(risk_proba) > 1 else 0.0

    if risk_score >= 0.7:
        risk_level = 'HIGH'
    elif risk_score >= 0.4:
        risk_level = 'MEDIUM'
    else:
        risk_level = 'LOW'

    contributing_factors = _identify_contributing_factors(student_features, risk_score)

    return {
        'risk_score': round(risk_score, 4),
        'risk_level': risk_level,
        'contributing_factors': contributing_factors,
    }


def _identify_contributing_factors(features: dict, risk_score: float) -> list:
    """Identify the top contributing factors to the risk prediction."""
    factors = []

    trend_slope = features.get('trend_slope', 0)
    if trend_slope < -0.02:
        factors.append(f"Declining mastery trend (slope: {trend_slope:.4f})")

    days = features.get('days_since_last_event', 0)
    if days > 30:
        factors.append(f"No recent observations ({int(days)} days since last event)")

    freq = features.get('observation_frequency', 0)
    if freq < 0.5:
        factors.append(f"Low observation frequency ({freq:.1f} per week)")

    variance = features.get('descriptor_level_variance', 0)
    if variance > 0.08:
        factors.append(f"High descriptor level variance ({variance:.3f})")

    ewm = features.get('current_ewm', 0)
    if ewm < 0.3:
        factors.append(f"Low current mastery level ({ewm:.2f})")

    peer_comp = features.get('peer_comparison', 0)
    if peer_comp < -0.15:
        factors.append(f"Below class average by {abs(peer_comp):.2f}")

    term_pos = features.get('term_position', 0.5)
    if term_pos > 0.8 and ewm < 0.5:
        factors.append("Late in term with below-average mastery")

    if not factors:
        if risk_score >= 0.4:
            factors.append("Combined feature pattern indicates moderate risk")
        else:
            factors.append("No significant risk factors identified")

    return factors
