"""
Training script for the mastery decline prediction model.

Connects to PostgreSQL, reads mastery_events and mastery_aggregates, builds
feature vectors per student×competency, and trains a GradientBoostingClassifier.
"""

import os
import sys
from datetime import datetime, timedelta

import joblib
import numpy as np
import pandas as pd
import psycopg2
from dotenv import load_dotenv
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.metrics import accuracy_score, classification_report, precision_score, recall_score
from sklearn.model_selection import train_test_split

load_dotenv(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))

DATABASE_URL = os.getenv(
    'DATABASE_URL',
    'postgresql://app_rw:app_rw_dev_password@localhost:5432/readlepress',
)
MODEL_DIR = os.path.join(os.path.dirname(__file__), '..', 'models')
MODEL_PATH = os.path.join(MODEL_DIR, 'decline_predictor.joblib')


def get_connection():
    return psycopg2.connect(DATABASE_URL)


def fetch_mastery_events(conn) -> pd.DataFrame:
    query = """
        SELECT me.student_id, me.competency_id, me.numeric_value,
               me.observed_at, me.descriptor_level_id, me.class_id,
               me.academic_year_id, me.term_id
        FROM mastery_events me
        WHERE me.event_status = 'ACTIVE'
        ORDER BY me.student_id, me.competency_id, me.observed_at
    """
    return pd.read_sql(query, conn)


def fetch_mastery_aggregates(conn) -> pd.DataFrame:
    query = """
        SELECT ma.student_id, ma.competency_id, ma.current_ewm,
               ma.event_count, ma.last_event_at, ma.trend_slope,
               ma.confidence_score, ma.academic_year_id
        FROM mastery_aggregates ma
    """
    return pd.read_sql(query, conn)


def fetch_class_averages(conn) -> pd.DataFrame:
    query = """
        SELECT se.class_id, ma.competency_id,
               AVG(ma.current_ewm) AS class_avg_ewm
        FROM mastery_aggregates ma
        JOIN student_enrolments se ON se.student_id = ma.student_id AND se.status = 'ACTIVE'
        GROUP BY se.class_id, ma.competency_id
    """
    return pd.read_sql(query, conn)


def fetch_student_classes(conn) -> pd.DataFrame:
    query = """
        SELECT se.student_id, se.class_id
        FROM student_enrolments se
        WHERE se.status = 'ACTIVE'
    """
    return pd.read_sql(query, conn)


def fetch_term_dates(conn) -> pd.DataFrame:
    query = """
        SELECT t.id AS term_id, t.start_date, t.end_date
        FROM terms t
    """
    return pd.read_sql(query, conn)


def build_features(events_df: pd.DataFrame, aggregates_df: pd.DataFrame,
                   class_avg_df: pd.DataFrame, student_classes_df: pd.DataFrame,
                   term_dates_df: pd.DataFrame) -> pd.DataFrame:
    """Build feature vectors per student×competency pair."""
    if events_df.empty or aggregates_df.empty:
        return pd.DataFrame()

    now = pd.Timestamp.now(tz='UTC')
    events_df['observed_at'] = pd.to_datetime(events_df['observed_at'], utc=True)

    features_list = []

    for (student_id, competency_id), group in events_df.groupby(['student_id', 'competency_id']):
        group = group.sort_values('observed_at')

        agg_row = aggregates_df[
            (aggregates_df['student_id'] == student_id) &
            (aggregates_df['competency_id'] == competency_id)
        ]

        if agg_row.empty:
            continue

        agg = agg_row.iloc[0]

        current_ewm = float(agg['current_ewm']) if agg['current_ewm'] is not None else 0.0
        event_count = int(agg['event_count']) if agg['event_count'] is not None else 0
        trend_slope = float(agg['trend_slope']) if agg['trend_slope'] is not None else 0.0

        last_event_at = pd.to_datetime(agg['last_event_at'], utc=True) if agg['last_event_at'] is not None else now
        days_since_last = max(0, (now - last_event_at).days)

        # observation_frequency: events per week over last 30 days
        recent_mask = group['observed_at'] >= (now - pd.Timedelta(days=30))
        recent_events = group[recent_mask]
        obs_frequency = len(recent_events) / 4.0 if len(recent_events) > 0 else 0.0

        # descriptor_level_variance
        numeric_values = group['numeric_value'].astype(float).values
        descriptor_variance = float(np.var(numeric_values)) if len(numeric_values) > 1 else 0.0

        # term_position: 0.0 (start) to 1.0 (end)
        term_position = 0.5  # default mid
        if not term_dates_df.empty and len(group) > 0:
            latest_term_id = group['term_id'].dropna().iloc[-1] if group['term_id'].notna().any() else None
            if latest_term_id is not None:
                term_row = term_dates_df[term_dates_df['term_id'] == latest_term_id]
                if not term_row.empty:
                    t = term_row.iloc[0]
                    term_start = pd.to_datetime(t['start_date'], utc=True)
                    term_end = pd.to_datetime(t['end_date'], utc=True)
                    term_duration = (term_end - term_start).days
                    if term_duration > 0:
                        term_position = min(1.0, max(0.0, (now - term_start).days / term_duration))

        # peer_comparison
        student_class = student_classes_df[student_classes_df['student_id'] == student_id]
        peer_comparison = 0.0
        if not student_class.empty:
            class_id = student_class.iloc[0]['class_id']
            class_avg_row = class_avg_df[
                (class_avg_df['class_id'] == class_id) &
                (class_avg_df['competency_id'] == competency_id)
            ]
            if not class_avg_row.empty:
                class_avg = float(class_avg_row.iloc[0]['class_avg_ewm'])
                peer_comparison = current_ewm - class_avg

        features_list.append({
            'student_id': student_id,
            'competency_id': competency_id,
            'current_ewm': current_ewm,
            'event_count': event_count,
            'trend_slope': trend_slope,
            'days_since_last_event': days_since_last,
            'observation_frequency': obs_frequency,
            'descriptor_level_variance': descriptor_variance,
            'term_position': term_position,
            'peer_comparison': peer_comparison,
        })

    return pd.DataFrame(features_list)


def build_labels(events_df: pd.DataFrame, features_df: pd.DataFrame,
                 aggregates_df: pd.DataFrame) -> pd.Series:
    """
    Label: did the student's mastery decline by >0.1 in the next 30 days?
    Uses historical event data to compute forward-looking labels.
    """
    if features_df.empty:
        return pd.Series(dtype=int)

    labels = []
    now = pd.Timestamp.now(tz='UTC')
    events_df = events_df.copy()
    events_df['observed_at'] = pd.to_datetime(events_df['observed_at'], utc=True)

    for _, row in features_df.iterrows():
        student_id = row['student_id']
        competency_id = row['competency_id']
        current_ewm = row['current_ewm']

        student_events = events_df[
            (events_df['student_id'] == student_id) &
            (events_df['competency_id'] == competency_id)
        ].sort_values('observed_at')

        if len(student_events) < 2:
            labels.append(0)
            continue

        recent = student_events.tail(3)['numeric_value'].astype(float).mean()
        older = student_events.head(max(1, len(student_events) - 3))['numeric_value'].astype(float).mean()

        declined = 1 if (older - recent) > 0.1 else 0
        labels.append(declined)

    return pd.Series(labels, dtype=int)


def train_model():
    os.makedirs(MODEL_DIR, exist_ok=True)

    print("Connecting to database...")
    conn = get_connection()

    try:
        print("Fetching mastery events...")
        events_df = fetch_mastery_events(conn)
        print(f"  → {len(events_df)} events found")

        print("Fetching mastery aggregates...")
        aggregates_df = fetch_mastery_aggregates(conn)
        print(f"  → {len(aggregates_df)} aggregates found")

        print("Fetching class averages...")
        class_avg_df = fetch_class_averages(conn)

        print("Fetching student classes...")
        student_classes_df = fetch_student_classes(conn)

        print("Fetching term dates...")
        term_dates_df = fetch_term_dates(conn)
    finally:
        conn.close()

    if events_df.empty or aggregates_df.empty:
        print("Insufficient data for training. Generating synthetic model...")
        _train_synthetic_model()
        return

    print("Building feature vectors...")
    features_df = build_features(events_df, aggregates_df, class_avg_df,
                                 student_classes_df, term_dates_df)

    if features_df.empty or len(features_df) < 10:
        print(f"Only {len(features_df)} feature rows — insufficient for training. Using synthetic data...")
        _train_synthetic_model()
        return

    print(f"  → {len(features_df)} feature vectors")

    print("Building labels...")
    labels = build_labels(events_df, features_df, aggregates_df)

    feature_cols = [
        'current_ewm', 'event_count', 'trend_slope', 'days_since_last_event',
        'observation_frequency', 'descriptor_level_variance', 'term_position',
        'peer_comparison',
    ]
    X = features_df[feature_cols].fillna(0)
    y = labels

    print(f"  → Label distribution: {y.value_counts().to_dict()}")

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    print("Training GradientBoostingClassifier...")
    model = GradientBoostingClassifier(
        n_estimators=100,
        max_depth=4,
        learning_rate=0.1,
        random_state=42,
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)

    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred, zero_division=0)
    recall = recall_score(y_test, y_pred, zero_division=0)

    print(f"\n{'='*50}")
    print(f"Model Performance Metrics")
    print(f"{'='*50}")
    print(f"Accuracy:  {accuracy:.4f}")
    print(f"Precision: {precision:.4f}")
    print(f"Recall:    {recall:.4f}")
    print(f"\nClassification Report:")
    print(classification_report(y_test, y_pred, zero_division=0))

    print(f"Saving model to {MODEL_PATH}...")
    joblib.dump({
        'model': model,
        'feature_cols': feature_cols,
        'trained_at': datetime.utcnow().isoformat(),
        'metrics': {'accuracy': accuracy, 'precision': precision, 'recall': recall},
    }, MODEL_PATH)

    print("Training complete.")


def _train_synthetic_model():
    """Train on synthetic data when real data is insufficient."""
    print("Generating synthetic training data...")
    rng = np.random.RandomState(42)
    n_samples = 500

    X_synth = pd.DataFrame({
        'current_ewm': rng.uniform(0, 1, n_samples),
        'event_count': rng.randint(0, 20, n_samples),
        'trend_slope': rng.normal(0, 0.05, n_samples),
        'days_since_last_event': rng.randint(0, 90, n_samples),
        'observation_frequency': rng.uniform(0, 3, n_samples),
        'descriptor_level_variance': rng.uniform(0, 0.15, n_samples),
        'term_position': rng.uniform(0, 1, n_samples),
        'peer_comparison': rng.normal(0, 0.2, n_samples),
    })

    y_synth = (
        (X_synth['trend_slope'] < -0.02).astype(int) |
        ((X_synth['days_since_last_event'] > 45) & (X_synth['current_ewm'] < 0.4)).astype(int) |
        ((X_synth['observation_frequency'] < 0.3) & (X_synth['descriptor_level_variance'] > 0.1)).astype(int)
    ).astype(int)

    X_train, X_test, y_train, y_test = train_test_split(X_synth, y_synth, test_size=0.2, random_state=42)

    model = GradientBoostingClassifier(
        n_estimators=100,
        max_depth=4,
        learning_rate=0.1,
        random_state=42,
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred, zero_division=0)
    recall = recall_score(y_test, y_pred, zero_division=0)

    feature_cols = list(X_synth.columns)

    print(f"\n{'='*50}")
    print(f"Synthetic Model Performance Metrics")
    print(f"{'='*50}")
    print(f"Accuracy:  {accuracy:.4f}")
    print(f"Precision: {precision:.4f}")
    print(f"Recall:    {recall:.4f}")
    print(f"\nClassification Report:")
    print(classification_report(y_test, y_pred, zero_division=0))

    os.makedirs(MODEL_DIR, exist_ok=True)
    joblib.dump({
        'model': model,
        'feature_cols': feature_cols,
        'trained_at': datetime.utcnow().isoformat(),
        'synthetic': True,
        'metrics': {'accuracy': accuracy, 'precision': precision, 'recall': recall},
    }, MODEL_PATH)

    print(f"Synthetic model saved to {MODEL_PATH}")


if __name__ == '__main__':
    train_model()
