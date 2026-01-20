"""\
ML Model & Dataset Report Utility

Prints details about the saved SWAI water quality model artifacts:
- assets/models/water_model_improved.tflite (TFLite I/O, size)
- assets/models/feature_info.txt (feature columns, classes)
- assets/models/scaler.pkl (StandardScaler stats)
- assets/models/label_encoder.pkl (LabelEncoder classes)

Optionally summarizes a dataset CSV if provided.

Usage:
  python ml_model_report.py
  python ml_model_report.py --dataset "C:\\path\\to\\water_data.csv"
  python ml_model_report.py --model assets\\models\\water_model_improved.tflite

Notes:
  - For TFLite introspection, the script tries TensorFlow first, then tflite-runtime.
  - For dataset summary, the script tries pandas; if not available, it prints a minimal CSV summary.
"""

from __future__ import annotations

import argparse
import csv
import pickle
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Optional


DEFAULT_MODEL_PATH = Path("assets/models/water_model_improved.tflite")
DEFAULT_FEATURE_INFO_PATH = Path("assets/models/feature_info.txt")
DEFAULT_SCALER_PATH = Path("assets/models/scaler.pkl")
DEFAULT_LABEL_ENCODER_PATH = Path("assets/models/label_encoder.pkl")


@dataclass
class TfliteIoInfo:
    input_shape: Optional[list[int]] = None
    input_dtype: Optional[str] = None
    output_shape: Optional[list[int]] = None
    output_dtype: Optional[str] = None


def _bytes_to_kb(num_bytes: int) -> float:
    return num_bytes / 1024.0


def _try_load_pickle(path: Path) -> Optional[Any]:
    try:
        with path.open("rb") as f:
            return pickle.load(f)
    except Exception:
        return None


def _read_feature_info(path: Path) -> dict[str, Any]:
    info: dict[str, Any] = {}
    if not path.exists():
        return info

    # The file is a few lines like:
    # Feature columns: [...]
    # Number of features: 5
    # Classes: [...]
    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line or ":" not in line:
            continue
        key, value = line.split(":", 1)
        info[key.strip().lower()] = value.strip()
    return info


def _get_tflite_io_info(model_path: Path) -> Optional[TfliteIoInfo]:
    # Try TensorFlow first.
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
        return None

    interpreter.allocate_tensors()
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    def _tolist(x: Any) -> Optional[list[int]]:
        try:
            return list(map(int, x))
        except Exception:
            return None

    info = TfliteIoInfo()
    if input_details:
        info.input_shape = _tolist(input_details[0].get("shape"))
        info.input_dtype = str(input_details[0].get("dtype"))
    if output_details:
        info.output_shape = _tolist(output_details[0].get("shape"))
        info.output_dtype = str(output_details[0].get("dtype"))

    return info


def _print_kv(label: str, value: Any) -> None:
    print(f"- {label}: {value}")


def _dataset_summary_pandas(dataset_path: Path, target_col: str, feature_cols: list[str]) -> None:
    import pandas as pd  # type: ignore

    df = pd.read_csv(dataset_path)

    # Match training-time renames from upgrade_model_confidence.py
    col_mapping = {
        "Temp": "Temperature",
        "Water_Status": "Quality",
    }
    df = df.rename(columns=col_mapping)

    print("\nDataset")
    print("------")
    _print_kv("Path", dataset_path)
    _print_kv("Rows", df.shape[0])
    _print_kv("Columns", df.shape[1])
    _print_kv("Column names", list(df.columns))

    missing = df.isna().sum()
    missing_nonzero = missing[missing > 0]
    if len(missing_nonzero) > 0:
        print("\nMissing values (non-zero)")
        print("------------------------")
        for col, count in missing_nonzero.sort_values(ascending=False).items():
            _print_kv(col, int(count))
    else:
        print("\nMissing values: none")

    if target_col in df.columns:
        print("\nClass distribution")
        print("------------------")
        counts = df[target_col].value_counts(dropna=False)
        for cls, count in counts.items():
            _print_kv(str(cls), int(count))

    # Compute engineered features if the model expects them.
    # These are derived exactly like upgrade_model_confidence.py:
    # - pH_deviation = |pH - 7.0|
    # - temp_normalized = (Temperature - 25) / 5
    engineered = set(feature_cols) - set(df.columns)
    if engineered:
        if "pH_deviation" in engineered and "pH" in df.columns:
            df["pH_deviation"] = (df["pH"] - 7.0).abs()
        if "temp_normalized" in engineered and "Temperature" in df.columns:
            df["temp_normalized"] = (df["Temperature"] - 25.0) / 5.0

    available_features = [c for c in feature_cols if c in df.columns]
    if available_features:
        print("\nFeature ranges (model inputs)")
        print("----------------------------")
        for col in available_features:
            series = df[col]
            series_num = pd.to_numeric(series, errors="coerce").dropna()
            if series_num.empty:
                _print_kv(col, "non-numeric or all missing")
                continue

            min_v = float(series_num.min())
            max_v = float(series_num.max())
            mean_v = float(series_num.mean())
            std_v = float(series_num.std(ddof=0))
            p05 = float(series_num.quantile(0.05))
            p50 = float(series_num.quantile(0.50))
            p95 = float(series_num.quantile(0.95))

            _print_kv(
                col,
                f"min={min_v:.4g}, p05={p05:.4g}, median={p50:.4g}, p95={p95:.4g}, max={max_v:.4g}, mean={mean_v:.4g}, std={std_v:.4g}",
            )


def _dataset_summary_minimal(dataset_path: Path) -> None:
    print("\nDataset (minimal)")
    print("-----------------")
    _print_kv("Path", dataset_path)

    with dataset_path.open("r", encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.reader(f)
        header = next(reader, [])
        row_count = 0
        for _ in reader:
            row_count += 1

    _print_kv("Columns", header)
    _print_kv("Rows (excluding header)", row_count)
    print("Note: install pandas for richer stats.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Print ML model + dataset details")
    parser.add_argument("--model", default=str(DEFAULT_MODEL_PATH), help="Path to .tflite model")
    parser.add_argument("--feature-info", default=str(DEFAULT_FEATURE_INFO_PATH), help="Path to feature_info.txt")
    parser.add_argument("--scaler", default=str(DEFAULT_SCALER_PATH), help="Path to scaler.pkl")
    parser.add_argument("--encoder", default=str(DEFAULT_LABEL_ENCODER_PATH), help="Path to label_encoder.pkl")
    parser.add_argument("--dataset", default=None, help="Optional path to dataset CSV")
    parser.add_argument("--target-col", default="Quality", help="Target label column in dataset")
    parser.add_argument(
        "--show-input-order",
        action="store_true",
        help="Print the exact model input feature order (from feature_info.txt when available)",
    )
    args = parser.parse_args()

    model_path = Path(args.model)
    feature_info_path = Path(args.feature_info)
    scaler_path = Path(args.scaler)
    encoder_path = Path(args.encoder)
    dataset_path = Path(args.dataset) if args.dataset else None

    print("Model artifacts")
    print("---------------")

    if model_path.exists():
        size_bytes = model_path.stat().st_size
        _print_kv("TFLite model", model_path)
        _print_kv("Model size", f"{_bytes_to_kb(size_bytes):.2f} KB")

        io = _get_tflite_io_info(model_path)
        if io is not None:
            _print_kv("Input shape", io.input_shape)
            _print_kv("Input dtype", io.input_dtype)
            _print_kv("Output shape", io.output_shape)
            _print_kv("Output dtype", io.output_dtype)
        else:
            print("- TFLite I/O: unavailable (install tensorflow or tflite-runtime)")
    else:
        print(f"- TFLite model: not found ({model_path})")

    feature_info = _read_feature_info(feature_info_path)
    if feature_info:
        _print_kv("feature_info.txt", feature_info_path)
        if "feature columns" in feature_info:
            _print_kv("Features", feature_info["feature columns"])
        if "number of features" in feature_info:
            _print_kv("Num features", feature_info["number of features"])
        if "classes" in feature_info:
            _print_kv("Classes", feature_info["classes"])
    else:
        print(f"- feature_info.txt: not found ({feature_info_path})")

    if args.show_input_order:
        print("\nModel input order")
        print("---------------")
        raw_features = feature_info.get("feature columns") if feature_info else None
        if raw_features:
            print(raw_features)
        else:
            print("Unavailable (feature_info.txt missing).")

    scaler = _try_load_pickle(scaler_path)
    if scaler is not None:
        _print_kv("scaler.pkl", scaler_path)
        mean_ = getattr(scaler, "mean_", None)
        scale_ = getattr(scaler, "scale_", None)
        if mean_ is not None:
            _print_kv("Scaler mean_", mean_)
        if scale_ is not None:
            _print_kv("Scaler scale_", scale_)
    else:
        print(f"- scaler.pkl: not found or unreadable ({scaler_path})")

    encoder = _try_load_pickle(encoder_path)
    if encoder is not None:
        _print_kv("label_encoder.pkl", encoder_path)
        classes_ = getattr(encoder, "classes_", None)
        if classes_ is not None:
            _print_kv("Encoder classes_", list(classes_))
    else:
        print(f"- label_encoder.pkl: not found or unreadable ({encoder_path})")

    if dataset_path is not None:
        if not dataset_path.exists():
            print(f"\nDataset: not found ({dataset_path})")
            return 1

        # Parse features from feature_info if possible; else use defaults.
        features: list[str] = ["pH", "TDS", "Temperature"]
        raw_features = feature_info.get("feature columns")
        if raw_features:
            # raw_features is a Python-like list string; eval is risky, so do a safe-ish parse.
            cleaned = raw_features.strip().lstrip("[").rstrip("]")
            parsed: list[str] = []
            for part in cleaned.split(","):
                p = part.strip().strip("'").strip('"')
                if p:
                    parsed.append(p)
            if parsed:
                features = parsed

        try:
            import pandas as _  # type: ignore

            _dataset_summary_pandas(dataset_path, target_col=args.target_col, feature_cols=features)
        except Exception:
            _dataset_summary_minimal(dataset_path)

    print("\nDone.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
