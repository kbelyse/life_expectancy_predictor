# Life Expectancy Predictor

Rwanda's life expectancy went from 48.3 years in 2000 to 66.1 years in 2015, nearly doubling in fifteen years. That kind of jump doesn't happen by accident, it comes from decisions on HIV treatment, immunization, schooling, and income growth. This project builds a regression model that learns which of those factors actually move life expectancy, using WHO data from 193 countries, so the same reasoning that explains Rwanda's turnaround can be applied to any developing country deciding where to invest next.

## Dataset

WHO Life Expectancy dataset, 2938 rows covering 193 countries from 2000 to 2015, 22 columns spanning mortality rates, immunization coverage, HIV/AIDS, schooling, income, and GDP. Originally published on Kaggle by kumarajarshi, built from the WHO Global Health Observatory and UN data repositories: https://www.kaggle.com/datasets/kumarajarshi/life-expectancy-who

## What's in this repo

```
linear_regression_model/
├── summative/
│   ├── linear_regression/
│   │   └── multivariate.ipynb   # EDA, feature engineering, model training & comparison
│   ├── API/
│   │   ├── main.py              # FastAPI app (predict + retrain endpoints)
│   │   ├── prediction.py        # loads the saved model and runs predictions
│   │   ├── requirements.txt
│   │   └── model/               # saved model, scaler, feature list
│   └── FlutterApp/               # single-page mobile app that calls the API
└── pyproject.toml
```

## API

Live Swagger docs: **https://life-expectancy-predictor-2mhb.onrender.com/docs**

(This is a free Render instance, so it spins down after inactivity. The first request after a while can take up to 50 seconds to wake it back up, after that it responds normally.)

- `POST /predict` — takes the 19 input indicators and returns a predicted life expectancy
- `POST /retrain` — upload a CSV in the same format as the original dataset to retrain the model on the combined data

## Models compared

Three regression approaches were trained and evaluated on the same train/test split: a stochastic gradient descent linear regression, a Random Forest, and a Decision Tree. The Random Forest came out on top on both MSE and R2, and is the one saved and served by the API. Full comparison, loss curves, and reasoning are in the notebook.

## Running the Flutter app

1. Make sure Flutter is installed (`flutter doctor` should pass).
2. `cd summative/FlutterApp`
3. `flutter pub get`
4. Open `lib/main.dart` and confirm `apiBaseUrl` points at the deployed API.
5. Run on a connected device or emulator: `flutter run`

The app has one page: a field for each of the 19 model inputs, a Predict button, and a result area that shows the prediction or an error message if a value is missing or out of range.

## Running the API locally

```
uv sync
uv run uvicorn main:app --app-dir summative/API --reload
```

Then open `http://127.0.0.1:8000/docs` for Swagger UI.

## Video demo

[add your YouTube link here]
