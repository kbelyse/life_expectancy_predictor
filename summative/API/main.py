"""FastAPI service for the life expectancy prediction model."""

import io
from pathlib import Path
from typing import Literal

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error, r2_score
from sklearn.model_selection import train_test_split

from prediction import predict_life_expectancy, reload_model

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "model" / "best_model.joblib"
FEATURES_PATH = BASE_DIR / "model" / "feature_names.joblib"
BASE_DATA_PATH = BASE_DIR / "data" / "life_expectancy.csv"

app = FastAPI(
    title="Life Expectancy Prediction API",
    description=(
        "Predicts life expectancy for a country-year from WHO-style health "
        "and socioeconomic indicators. Built on a Random Forest model trained "
        "on the WHO Life Expectancy dataset (2000-2015)."
    ),
    version="1.0.0",
)

# CORS: this API is called from a Flutter mobile app (no browser origin at all,
# so CORS doesn't restrict it) and tested from this same Swagger UI page and
# from a local Flutter-web build during development. I'm listing those origins
# by name instead of "*" so a random website can't embed this API in its own
# frontend and ride on it. No cookies/session auth is used, so credentials
# stay off, and only the two HTTP verbs this API actually exposes (GET, POST)
# are allowed.
ALLOWED_ORIGINS = [
    "http://localhost",
    "http://localhost:8080",
    "http://127.0.0.1",
    "http://127.0.0.1:8080",
    "https://life-expectancy-api-*.onrender.com",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


class LifeExpectancyInput(BaseModel):
    year: int = Field(..., ge=2000, le=2030, description="Year of the record")
    status: Literal["Developing", "Developed"] = Field(
        ..., description="Country development status"
    )
    adult_mortality: float = Field(
        ..., ge=0, le=800, description="Adult mortality rate (per 1000 population, ages 15-60)"
    )
    infant_deaths: int = Field(..., ge=0, le=2000, description="Infant deaths per 1000 population")
    alcohol: float = Field(..., ge=0, le=20, description="Alcohol consumption, litres of pure alcohol per capita")
    percentage_expenditure: float = Field(
        ..., ge=0, le=20000, description="Health expenditure as a percentage of GDP per capita"
    )
    hepatitis_b: float = Field(..., ge=0, le=100, description="Hepatitis B immunization coverage among 1-year-olds (%)")
    measles: int = Field(..., ge=0, le=220000, description="Reported measles cases per 1000 population")
    bmi: float = Field(..., ge=0, le=90, description="Average Body Mass Index of the population")
    under_five_deaths: int = Field(..., ge=0, le=2600, description="Under-five deaths per 1000 population")
    polio: float = Field(..., ge=0, le=100, description="Polio immunization coverage among 1-year-olds (%)")
    total_expenditure: float = Field(
        ..., ge=0, le=20, description="General government health expenditure as % of total government spending"
    )
    diphtheria: float = Field(..., ge=0, le=100, description="Diphtheria immunization coverage among 1-year-olds (%)")
    hiv_aids: float = Field(..., ge=0, le=60, description="Deaths per 1000 live births from HIV/AIDS, ages 0-4")
    gdp: float = Field(..., ge=0, le=120000, description="GDP per capita (USD)")
    thinness_1_19_years: float = Field(..., ge=0, le=30, description="Prevalence of thinness among ages 10-19 (%)")
    thinness_5_9_years: float = Field(..., ge=0, le=30, description="Prevalence of thinness among ages 5-9 (%)")
    income_composition_of_resources: float = Field(
        ..., ge=0, le=1, description="UN Human Development Index income component (0-1)"
    )
    schooling: float = Field(..., ge=0, le=21, description="Average years of schooling")


class PredictionResponse(BaseModel):
    predicted_life_expectancy: float


def to_model_features(payload: LifeExpectancyInput) -> dict:
    return {
        "Year": payload.year,
        "Status": 1 if payload.status == "Developed" else 0,
        "Adult Mortality": payload.adult_mortality,
        "infant deaths": payload.infant_deaths,
        "Alcohol": payload.alcohol,
        "percentage expenditure": payload.percentage_expenditure,
        "Hepatitis B": payload.hepatitis_b,
        "Measles": payload.measles,
        "BMI": payload.bmi,
        "under-five deaths": payload.under_five_deaths,
        "Polio": payload.polio,
        "Total expenditure": payload.total_expenditure,
        "Diphtheria": payload.diphtheria,
        "HIV/AIDS": payload.hiv_aids,
        "GDP": payload.gdp,
        "thinness  1-19 years": payload.thinness_1_19_years,
        "thinness 5-9 years": payload.thinness_5_9_years,
        "Income composition of resources": payload.income_composition_of_resources,
        "Schooling": payload.schooling,
    }


@app.get("/")
def root():
    return {"message": "Life Expectancy Prediction API is running. See /docs for Swagger UI."}


@app.post("/predict", response_model=PredictionResponse)
def predict(payload: LifeExpectancyInput):
    features = to_model_features(payload)
    prediction = predict_life_expectancy(features)
    return PredictionResponse(predicted_life_expectancy=round(prediction, 2))


@app.post("/retrain")
async def retrain(file: UploadFile = File(...)):
    """Retrains the model on the original dataset plus a newly uploaded CSV.

    The uploaded file must have the same columns as the original WHO Life
    Expectancy dataset (Country, Year, Status, Life expectancy, ...).
    """
    if not file.filename.endswith(".csv"):
        raise HTTPException(status_code=400, detail="Please upload a .csv file")

    contents = await file.read()
    try:
        new_data = pd.read_csv(io.BytesIO(contents))
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Could not read CSV: {exc}") from exc

    base_data = pd.read_csv(BASE_DATA_PATH)
    combined = pd.concat([base_data, new_data], ignore_index=True)
    combined.columns = [c.strip() for c in combined.columns]

    required_cols = {"Country", "Year", "Status", "Life expectancy"}
    missing = required_cols - set(combined.columns)
    if missing:
        raise HTTPException(status_code=400, detail=f"Uploaded CSV is missing columns: {missing}")

    combined = combined.dropna(subset=["Life expectancy"])
    num_cols = combined.select_dtypes(include="number").columns.tolist()
    for col in num_cols:
        combined[col] = combined.groupby("Status")[col].transform(lambda s: s.fillna(s.median()))
    combined["Status"] = combined["Status"].map({"Developing": 0, "Developed": 1})

    feature_names = joblib.load(FEATURES_PATH)
    X = combined[feature_names]
    y = combined["Life expectancy"]
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    new_model = RandomForestRegressor(n_estimators=100, max_depth=10, random_state=42)
    new_model.fit(X_train, y_train)
    predictions = new_model.predict(X_test)
    mse = mean_squared_error(y_test, predictions)
    r2 = r2_score(y_test, predictions)

    joblib.dump(new_model, MODEL_PATH)
    reload_model()

    return {
        "message": "Model retrained and reloaded successfully.",
        "rows_used_for_training": len(combined),
        "test_mse": round(float(mse), 3),
        "test_r2": round(float(r2), 3),
    }
