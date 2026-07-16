"""Loads the saved Random Forest model and turns feature dicts into predictions."""

from pathlib import Path

import joblib
import pandas as pd

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "model" / "best_model.joblib"
FEATURES_PATH = BASE_DIR / "model" / "feature_names.joblib"

model = joblib.load(MODEL_PATH)
feature_names = joblib.load(FEATURES_PATH)


def predict_life_expectancy(features: dict) -> float:
    row = pd.DataFrame([features], columns=feature_names)
    prediction = model.predict(row)[0]
    return float(prediction)


def reload_model() -> None:
    global model
    model = joblib.load(MODEL_PATH)
