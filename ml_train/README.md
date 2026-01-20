# ML Training Folder (SWAI Dashboard)

This folder collects **everything related to ML model training**, evaluation, and graph generation.
The Flutter app itself only needs the deployed model file:

- `assets/models/water_model_improved.tflite`

Everything else (plots, history, pickles, training scripts) is kept here so the app bundle stays small and clean.

## What’s inside

### `scripts/`
Training + tooling scripts used during development.

- `upgrade_model_confidence.py`
  - Main training script used for the current model setup.
  - Uses **5 input features**:
    - `pH`, `TDS`, `Temperature`, `pH_deviation = |pH-7|`, `temp_normalized = (Temp-25)/5`
  - Handles imbalance via **data augmentation (noise injection)**
  - Uses **StandardScaler** + **LabelEncoder**
  - Trains a **neural-network classifier** (Dense → Dense → Dense → Softmax)
  - Saves:
    - `assets/models/water_model_improved.tflite`
    - `assets/models/training_history.csv` (+ optional plots if matplotlib installed)

- `ml_model_report.py`
  - Prints model/artifact details and dataset statistics.
  - Can print feature ranges from the dataset.

- `ml_performance_graphs.py`
  - Generates slide-ready graphs:
    - training curves (from `training_history.csv`)
    - confusion matrix (from dataset + trained artifacts)

- `create_compatible_model.py`, `fix_model_compatibility.py`
  - Utility scripts for compatibility/debugging (e.g., export issues / model format issues).

### `artifacts_snapshot/`
A snapshot backup of ML artifacts (model, scaler, encoder, history, etc.) at the time we reorganized the repo.
This is mainly for safekeeping.

### `graphs/`
Generated PNG graphs (training curves, etc.) saved here for easy inclusion in slides.

## Typical workflow

### 1) Train / re-train the model
Run from repo root (so output paths resolve):

- `C:/Users/HP/swai_dashboard/.venv/Scripts/python.exe .\ml_train\scripts\upgrade_model_confidence.py`

### 2) Generate graphs
- `C:/Users/HP/swai_dashboard/.venv/Scripts/python.exe .\ml_train\scripts\ml_performance_graphs.py --dataset "C:\\Users\\HP\\Documents\\SEM 6\\fyp\\MachineLearning\\water_data.csv"`

Graphs will be written to `assets/models/plots/` by default (you can copy them into slides).

### 3) Quick model + dataset reporting
- `C:/Users/HP/swai_dashboard/.venv/Scripts/python.exe .\ml_train\scripts\ml_model_report.py --dataset "C:\\Users\\HP\\Documents\\SEM 6\\fyp\\MachineLearning\\water_data.csv" --show-input-order`

## Why do you have 2 “upgrade model” files?

Originally you had two different training approaches.

To avoid confusion and mismatched feature sets, the repo now keeps **one canonical training script**:
- `upgrade_model_confidence.py` (5 features, matches the deployed Flutter model)
