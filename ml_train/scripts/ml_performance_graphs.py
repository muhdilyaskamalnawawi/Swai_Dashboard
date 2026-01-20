"""\
ML Performance Graphs Utility

Generates performance visuals for the SWAI water-quality classifier:
- Confusion matrix heatmap (from dataset + saved model artifacts)
- Training curves (from a saved history CSV, if available)

Typical usage:
  python ml_performance_graphs.py --dataset "C:\\path\\to\\water_data.csv"

If you re-train with upgrade_model_confidence.py (updated), you'll also get:
  assets/models/training_history.csv
  assets/models/plots/*.png

This script will look for history CSV automatically, or you can pass it:
  python ml_performance_graphs.py --history assets\\models\\training_history.csv

Notes:
- Requires matplotlib for plotting. Install: pip install matplotlib
- Confusion matrix computation uses scikit-learn.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
from typing import Any, Optional


DEFAULT_MODEL_PATH = Path("assets/models/water_model_improved.tflite")
DEFAULT_FEATURE_INFO_PATH = Path("assets/models/feature_info.txt")
DEFAULT_SCALER_PATH = Path("assets/models/scaler.pkl")
DEFAULT_LABEL_ENCODER_PATH = Path("assets/models/label_encoder.pkl")
DEFAULT_HISTORY_PATH = Path("assets/models/training_history.csv")
DEFAULT_PLOTS_DIR = Path("assets/models/plots")


def _read_feature_info(path: Path) -> dict[str, str]:
    info: dict[str, str] = {}
    if not path.exists():
        return info

    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or ":" not in line:
            continue
        key, value = line.split(":", 1)
        info[key.strip().lower()] = value.strip()
    return info


def _parse_feature_list(raw_features: Optional[str]) -> list[str]:
    if not raw_features:
        return ["pH", "TDS", "Temperature"]

    cleaned = raw_features.strip().lstrip("[").rstrip("]")
    parsed: list[str] = []
    for part in cleaned.split(","):
        p = part.strip().strip("'").strip('"')
        if p:
            parsed.append(p)
    return parsed or ["pH", "TDS", "Temperature"]


def _load_tflite_interpreter(model_path: Path):
    interpreter = None
    try:
        import tensorflow as tf  # type: ignore

        interpreter = tf.lite.Interpreter(model_path=str(model_path))
    except Exception:
        interpreter = None

    if interpreter is None:
        try:
            from tflite_runtime.interpreter import Interpreter  # type: ignore

            interpreter = Interpreter(model_path=str(model_path))
        except Exception:
            interpreter = None

    if interpreter is None:
        raise RuntimeError(
            "Could not create a TFLite interpreter. Install tensorflow or tflite-runtime."
        )

    interpreter.allocate_tensors()
    return interpreter


def _predict_tflite(interpreter, X):
    import numpy as np

    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    input_index = input_details[0]["index"]
    output_index = output_details[0]["index"]

    preds = []
    for i in range(X.shape[0]):
        x = X[i : i + 1].astype("float32")
        interpreter.set_tensor(input_index, x)
        interpreter.invoke()
        out = interpreter.get_tensor(output_index)
        preds.append(out[0])

    return np.asarray(preds)


def _plot_training_curves(history_csv: Path, out_dir: Path) -> None:
    import pandas as pd  # type: ignore
    import matplotlib.pyplot as plt  # type: ignore

    df = pd.read_csv(history_csv)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Plot loss and accuracy if present
    def _plot(metric: str, title: str, filename: str) -> None:
        plt.figure(figsize=(9, 5))
        if metric in df.columns:
            plt.plot(df[metric], label=metric)
        val_metric = f"val_{metric}"
        if val_metric in df.columns:
            plt.plot(df[val_metric], label=val_metric)
        plt.title(title)
        plt.xlabel("epoch")
        plt.ylabel(metric)
        plt.grid(True, alpha=0.3)
        plt.legend()
        plt.tight_layout()
        plt.savefig(out_dir / filename, dpi=160)
        plt.close()

    if "loss" in df.columns or "val_loss" in df.columns:
        _plot("loss", "Training loss", "training_loss.png")
    if "accuracy" in df.columns or "val_accuracy" in df.columns:
        _plot("accuracy", "Training accuracy", "training_accuracy.png")
    if "precision" in df.columns or "val_precision" in df.columns:
        _plot("precision", "Training precision", "training_precision.png")
    if "recall" in df.columns or "val_recall" in df.columns:
        _plot("recall", "Training recall", "training_recall.png")


def _plot_confusion_matrix(cm, class_names: list[str], out_path: Path) -> None:
    import matplotlib.pyplot as plt  # type: ignore

    plt.figure(figsize=(7, 6))
    plt.imshow(cm, interpolation="nearest")
    plt.title("Confusion matrix")
    plt.colorbar()

    tick_marks = range(len(class_names))
    plt.xticks(tick_marks, class_names, rotation=45, ha="right")
    plt.yticks(tick_marks, class_names)

    # annotate counts
    for i in range(cm.shape[0]):
        for j in range(cm.shape[1]):
            plt.text(j, i, str(cm[i, j]), ha="center", va="center")

    plt.ylabel("Actual")
    plt.xlabel("Predicted")
    plt.tight_layout()
    out_path.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(out_path, dpi=180)
    plt.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate ML performance graphs")
    parser.add_argument("--dataset", default=None, help="Path to dataset CSV (optional)")
    parser.add_argument("--target-col", default="Quality", help="Target label column name")
    parser.add_argument("--model", default=str(DEFAULT_MODEL_PATH), help="Path to TFLite model")
    parser.add_argument(
        "--feature-info",
        default=str(DEFAULT_FEATURE_INFO_PATH),
        help="Path to feature_info.txt",
    )
    parser.add_argument("--scaler", default=str(DEFAULT_SCALER_PATH), help="Path to scaler.pkl")
    parser.add_argument(
        "--encoder", default=str(DEFAULT_LABEL_ENCODER_PATH), help="Path to label_encoder.pkl"
    )
    parser.add_argument(
        "--history",
        default=None,
        help="Path to training_history.csv (optional; default assets/models/training_history.csv)",
    )
    parser.add_argument(
        "--out-dir", default=str(DEFAULT_PLOTS_DIR), help="Output directory for PNG plots"
    )

    args = parser.parse_args()

    out_dir = Path(args.out_dir)

    # 1) Training curves (if history exists)
    history_path = Path(args.history) if args.history else DEFAULT_HISTORY_PATH
    try:
        if history_path.exists():
            _plot_training_curves(history_path, out_dir)
            print(f"Saved training curves to: {out_dir}")
        else:
            print("No training history CSV found; skipping training curves.")
            print(f"Looked for: {history_path}")
    except ModuleNotFoundError as e:
        print(f"Plotting training curves skipped (missing dependency): {e}")
        print("Install: pip install matplotlib pandas")

    # 2) Confusion matrix (requires dataset)
    if not args.dataset:
        print("No dataset provided; skipping confusion matrix.")
        print('Run: python ml_performance_graphs.py --dataset "C:\\path\\to\\water_data.csv"')
        return 0

    dataset_path = Path(args.dataset)
    if not dataset_path.exists():
        print(f"Dataset not found: {dataset_path}")
        return 1

    model_path = Path(args.model)
    feature_info = _read_feature_info(Path(args.feature_info))
    features = _parse_feature_list(feature_info.get("feature columns"))

    try:
        import pandas as pd  # type: ignore
        import numpy as np
        from sklearn.metrics import confusion_matrix, classification_report

        # Load dataset and align with training-time column renames
        df = pd.read_csv(dataset_path)
        df = df.rename(columns={"Temp": "Temperature", "Water_Status": "Quality"})

        # Compute engineered features if needed
        if "pH_deviation" in features and "pH" in df.columns:
            df["pH_deviation"] = (df["pH"] - 7.0).abs()
        if "temp_normalized" in features and "Temperature" in df.columns:
            df["temp_normalized"] = (df["Temperature"] - 25.0) / 5.0

        # Drop missing
        needed_cols = [c for c in features if c in df.columns]
        if args.target_col in df.columns:
            needed_cols = needed_cols + [args.target_col]
        df = df.dropna(subset=needed_cols)

        if args.target_col not in df.columns:
            print(f"Target column not found in dataset: {args.target_col}")
            print(f"Available columns: {list(df.columns)}")
            return 1

        X = df[features].to_numpy(dtype=float)
        y_raw = df[args.target_col].astype(str).to_numpy()

        # Load scaler + encoder
        import pickle

        scaler = pickle.load(Path(args.scaler).open("rb"))
        encoder = pickle.load(Path(args.encoder).open("rb"))
        class_names = list(getattr(encoder, "classes_", []))

        X_scaled = scaler.transform(X)

        interpreter = _load_tflite_interpreter(model_path)
        probs = _predict_tflite(interpreter, X_scaled)
        y_pred_idx = np.argmax(probs, axis=1)

        # Map true labels into encoder indices
        y_true_idx = encoder.transform(y_raw)

        print("\nClassification report")
        print("---------------------")
        print(classification_report(y_true_idx, y_pred_idx, target_names=class_names))

        cm = confusion_matrix(y_true_idx, y_pred_idx)

        try:
            _plot_confusion_matrix(cm, class_names, out_dir / "confusion_matrix.png")
            print(f"Saved confusion matrix to: {out_dir / 'confusion_matrix.png'}")
        except ModuleNotFoundError as e:
            print(f"Confusion matrix plot skipped (missing dependency): {e}")
            print("Install: pip install matplotlib")

    except ModuleNotFoundError as e:
        print(f"Dataset evaluation skipped (missing dependency): {e}")
        print("Install: pip install pandas numpy scikit-learn matplotlib")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
