"""
Backend/scripts/train_model.py
Phase 5 — ML Model Training

Trains a Random Forest classifier on the data collected by data_collector.py
and saves the model + scaler to Backend/ml_data/ for use by the /predict endpoint.

Usage:
    cd Backend
    python scripts/train_model.py

Requirements (already in requirements.txt or install manually):
    pip install scikit-learn pandas joblib

Output:
    Backend/ml_data/model.pkl        — trained RandomForest model
    Backend/ml_data/scaler.pkl       — fitted StandardScaler
    Backend/ml_data/model_meta.json  — accuracy, feature list, training date
"""

import sys
import json
import logging
from pathlib import Path
from datetime import datetime, timezone

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
logger = logging.getLogger("train_model")

# ── Paths ─────────────────────────────────────────────────────────────────────

ML_DIR      = Path(__file__).resolve().parents[1] / "ml_data"
DATA_FILE   = ML_DIR / "training_data.csv"
MODEL_FILE  = ML_DIR / "model.pkl"
SCALER_FILE = ML_DIR / "scaler.pkl"
META_FILE   = ML_DIR / "model_meta.json"

# ── Feature columns used for training ─────────────────────────────────────────

FEATURE_COLS = [
    "rsi",
    "macd",
    "macd_signal",
    "macd_hist",
    "ema_20",
    "ema_50",
    "bb_upper",
    "bb_lower",
    "close",
    "high",
    "low",
    "open",
    "volume",
]

LABEL_COL = "label"   # 1=BUY, -1=SELL, 0=HOLD


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    # ── 1. Import dependencies ────────────────────────────────────────────────
    try:
        import pandas as pd
        import numpy as np
        from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
        from sklearn.preprocessing import StandardScaler
        from sklearn.model_selection import train_test_split, cross_val_score
        from sklearn.metrics import (
            classification_report,
            accuracy_score,
            confusion_matrix,
        )
        import joblib
    except ImportError as e:
        logger.error(
            "Missing dependency: %s\n"
            "Install with: pip install scikit-learn pandas joblib numpy",
            e,
        )
        sys.exit(1)

    # ── 2. Load data ──────────────────────────────────────────────────────────
    if not DATA_FILE.exists():
        logger.error(
            "Training data not found at %s\n"
            "Run: python scripts/data_collector.py first.",
            DATA_FILE,
        )
        sys.exit(1)

    logger.info("Loading training data from %s …", DATA_FILE)
    df = pd.read_csv(DATA_FILE)
    logger.info("  Raw rows: %d", len(df))

    # ── 3. Feature engineering ────────────────────────────────────────────────

    # Derived features
    df["ema_cross"]    = df["ema_20"] - df["ema_50"]          # EMA crossover signal
    df["bb_width"]     = df["bb_upper"] - df["bb_lower"]      # Bollinger Band width
    df["bb_position"]  = (df["close"] - df["bb_lower"]) / (df["bb_width"] + 1e-10)
    df["price_range"]  = df["high"] - df["low"]               # candle range
    df["body_size"]    = abs(df["close"] - df["open"])        # candle body
    df["upper_wick"]   = df["high"] - df[["open", "close"]].max(axis=1)
    df["lower_wick"]   = df[["open", "close"]].min(axis=1) - df["low"]
    df["rsi_overbought"] = (df["rsi"] > 70).astype(int)
    df["rsi_oversold"]   = (df["rsi"] < 30).astype(int)
    df["macd_positive"]  = (df["macd"] > 0).astype(int)
    df["macd_cross"]     = (df["macd"] > df["macd_signal"]).astype(int)

    # Pair one-hot encoding
    pair_dummies = pd.get_dummies(df["pair"], prefix="pair")
    df = pd.concat([df, pair_dummies], axis=1)

    extended_features = FEATURE_COLS + [
        "ema_cross", "bb_width", "bb_position", "price_range",
        "body_size", "upper_wick", "lower_wick",
        "rsi_overbought", "rsi_oversold", "macd_positive", "macd_cross",
    ] + list(pair_dummies.columns)

    # Drop rows with any NaN in features or label
    df_clean = df[extended_features + [LABEL_COL]].dropna()
    logger.info("  Rows after dropping NaN: %d", len(df_clean))

    if len(df_clean) < 100:
        logger.error(
            "Not enough clean rows (%d) to train a reliable model. "
            "Run data_collector.py to fetch more data.",
            len(df_clean),
        )
        sys.exit(1)

    X = df_clean[extended_features].values
    y = df_clean[LABEL_COL].values

    # Label distribution
    unique, counts = np.unique(y, return_counts=True)
    label_dist = dict(zip(unique.tolist(), counts.tolist()))
    logger.info("  Label distribution: %s", label_dist)

    # ── 4. Train / test split ─────────────────────────────────────────────────
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    logger.info("  Train: %d rows | Test: %d rows", len(X_train), len(X_test))

    # ── 5. Scale features ─────────────────────────────────────────────────────
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled  = scaler.transform(X_test)

    # ── 6. Train model ────────────────────────────────────────────────────────
    logger.info("Training RandomForest classifier …")
    model = RandomForestClassifier(
        n_estimators=200,
        max_depth=12,
        min_samples_split=10,
        min_samples_leaf=5,
        class_weight="balanced",   # handles BUY/SELL/HOLD imbalance
        random_state=42,
        n_jobs=-1,
    )
    model.fit(X_train_scaled, y_train)

    # ── 7. Evaluate ───────────────────────────────────────────────────────────
    y_pred = model.predict(X_test_scaled)
    acc    = accuracy_score(y_test, y_pred)

    logger.info("=" * 60)
    logger.info("Test accuracy: %.4f (%.1f%%)", acc, acc * 100)
    logger.info("\nClassification Report:")
    report = classification_report(
        y_test, y_pred,
        target_names=["SELL (-1)", "HOLD (0)", "BUY (1)"],
        labels=[-1, 0, 1],
    )
    for line in report.splitlines():
        logger.info("  %s", line)

    # Cross-validation
    cv_scores = cross_val_score(model, X_train_scaled, y_train, cv=5, scoring="accuracy")
    logger.info(
        "5-fold CV accuracy: %.4f ± %.4f",
        cv_scores.mean(),
        cv_scores.std(),
    )

    # Feature importances (top 10)
    importances = model.feature_importances_
    feat_imp = sorted(
        zip(extended_features, importances),
        key=lambda x: x[1],
        reverse=True,
    )[:10]
    logger.info("\nTop 10 feature importances:")
    for feat, imp in feat_imp:
        logger.info("  %-25s %.4f", feat, imp)

    # ── 8. Save model + scaler ────────────────────────────────────────────────
    ML_DIR.mkdir(parents=True, exist_ok=True)

    joblib.dump(model,  MODEL_FILE)
    joblib.dump(scaler, SCALER_FILE)
    logger.info("\nModel saved  → %s", MODEL_FILE)
    logger.info("Scaler saved → %s", SCALER_FILE)

    # ── 9. Save metadata ──────────────────────────────────────────────────────
    meta = {
        "trained_at":       datetime.now(timezone.utc).isoformat(),
        "accuracy":         round(acc, 4),
        "cv_accuracy_mean": round(float(cv_scores.mean()), 4),
        "cv_accuracy_std":  round(float(cv_scores.std()), 4),
        "train_rows":       int(len(X_train)),
        "test_rows":        int(len(X_test)),
        "label_distribution": {str(k): int(v) for k, v in label_dist.items()},
        "features":         extended_features,
        "model_type":       "RandomForestClassifier",
        "model_params": {
            "n_estimators":    200,
            "max_depth":       12,
            "class_weight":    "balanced",
        },
        "top_features": [{"feature": f, "importance": round(float(i), 4)} for f, i in feat_imp],
        "label_map":    {"-1": "SELL", "0": "HOLD", "1": "BUY"},
    }

    with open(META_FILE, "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
    logger.info("Metadata saved → %s", META_FILE)

    logger.info("=" * 60)
    logger.info("Training complete!")
    logger.info("  Accuracy : %.1f%%", acc * 100)
    logger.info("  Model    : %s", MODEL_FILE)
    logger.info("  Next step: Hit GET /api/v1/signals/predict/EURUSD")
    logger.info("=" * 60)


if __name__ == "__main__":
    main()
