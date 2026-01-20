import os
from datetime import datetime, timezone

from flask import Flask, jsonify, request
from supabase import create_client, Client

try:
    import google.generativeai as genai
except Exception:
    genai = None

app = Flask(__name__)

SUPABASE_URL = os.getenv("SUPABASE_URL", "").strip()
SUPABASE_KEY = os.getenv("SUPABASE_KEY", "").strip()
SUPABASE_TABLE = os.getenv("SUPABASE_TABLE", "sensor_readings").strip()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "").strip()
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-2.5-flash").strip()

# Safe ranges (adjust to your needs)
THRESHOLDS = {
    "ph": {"min": 6.5, "max": 8.5, "criticalMin": 5.0, "criticalMax": 10.0},
    "temp": {"min": 25.0, "max": 30.0, "criticalMin": 10.0, "criticalMax": 45.0},
    "tds": {"min": 100.0, "max": 500.0, "criticalMin": 0.0, "criticalMax": 1500.0},
}


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _coerce_float(value, field_name: str) -> float:
    try:
        return float(value)
    except Exception as e:
        raise ValueError(f"Invalid {field_name}: {value}") from e


def _normalize_payload(payload: dict) -> dict:
    # Accept both 'pH' and 'ph' from Arduino
    ph = payload.get("ph", payload.get("pH"))
    temp = payload.get("temp", payload.get("temperature"))
    tds = payload.get("tds")

    if ph is None or temp is None or tds is None:
        raise ValueError("Missing one of required fields: pH/ph, temp, tds")

    ph = _coerce_float(ph, "pH")
    temp = _coerce_float(temp, "temp")
    tds = _coerce_float(tds, "tds")

    # Accept ISO timestamp or epoch seconds; otherwise assign now
    ts = payload.get("timestamp")
    timestamp_iso = None
    if ts is None or str(ts).strip() == "":
        timestamp_iso = _utc_now_iso()
    else:
        ts_str = str(ts).strip()
        try:
            # epoch seconds
            if ts_str.isdigit():
                timestamp_iso = datetime.fromtimestamp(int(ts_str), tz=timezone.utc).isoformat()
            else:
                # assume ISO8601
                timestamp_iso = datetime.fromisoformat(ts_str.replace("Z", "+00:00")).astimezone(timezone.utc).isoformat()
        except Exception:
            timestamp_iso = _utc_now_iso()

    return {"ph": ph, "temp": temp, "tds": tds, "timestamp": timestamp_iso}


def _rule_based_prediction(ph: float, temp: float, tds: float) -> tuple[str, float]:
    # Simple heuristic: count how many metrics are outside safe range
    issues = 0
    if ph < THRESHOLDS["ph"]["min"] or ph > THRESHOLDS["ph"]["max"]:
        issues += 1
    if temp < THRESHOLDS["temp"]["min"] or temp > THRESHOLDS["temp"]["max"]:
        issues += 1
    if tds < THRESHOLDS["tds"]["min"] or tds > THRESHOLDS["tds"]["max"]:
        issues += 1

    if issues == 0:
        return "Good", 0.8
    if issues == 1:
        return "Moderate", 0.55
    return "Bad", 0.7


def _is_critical(ph: float, temp: float, tds: float) -> bool:
    return (
        ph < THRESHOLDS["ph"]["criticalMin"]
        or ph > THRESHOLDS["ph"]["criticalMax"]
        or temp < THRESHOLDS["temp"]["criticalMin"]
        or temp > THRESHOLDS["temp"]["criticalMax"]
        or tds < THRESHOLDS["tds"]["criticalMin"]
        or tds > THRESHOLDS["tds"]["criticalMax"]
    )


def _gemini_recommendation(ph: float, temp: float, tds: float, prediction: str) -> str | None:
    if not GEMINI_API_KEY:
        return None
    if genai is None:
        return None

    genai.configure(api_key=GEMINI_API_KEY)
    model = genai.GenerativeModel(GEMINI_MODEL)

    prompt = (
        "You are a water quality assistant for aquaculture (tilapia).\n"
        f"Readings: pH={ph:.2f}, temp={temp:.2f}°C, TDS={tds:.0f} ppm.\n"
        f"Prediction: {prediction}.\n"
        "Give 1-2 short actionable recommendations. Keep it concise."
    )

    resp = model.generate_content(prompt)
    text = getattr(resp, "text", None)
    return text.strip() if text else None


def _get_supabase() -> Client:
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise RuntimeError("SUPABASE_URL/SUPABASE_KEY not set")
    return create_client(SUPABASE_URL, SUPABASE_KEY)


@app.get("/health")
def health():
    return jsonify({"status": "running", "timestamp": _utc_now_iso()})


@app.post("/api/sensor/reading")
def sensor_reading():
    try:
        payload = request.get_json(silent=True) or {}
        reading = _normalize_payload(payload)

        ph = reading["ph"]
        temp = reading["temp"]
        tds = reading["tds"]

        # 1) Prediction (fast, backend-side)
        prediction, confidence = _rule_based_prediction(ph, temp, tds)

        # 2) Recommendation (optional; needs GEMINI_API_KEY)
        recommendation = _gemini_recommendation(ph, temp, tds, prediction)

        is_alert = _is_critical(ph, temp, tds)

        # 3) Insert fully-populated row into Supabase
        row = {
            "ph": ph,
            "temp": temp,
            "tds": tds,
            "timestamp": reading["timestamp"],
            "prediction": prediction,
            "confidence": confidence,
            "recommendation": recommendation,
            "is_alert": bool(is_alert),
        }

        # Supabase REST rejects unknown null keys sometimes depending on policies;
        # keep it clean.
        row = {k: v for k, v in row.items() if v is not None}

        supabase = _get_supabase()
        res = supabase.table(SUPABASE_TABLE).insert(row).execute()

        inserted = None
        try:
            inserted = res.data[0] if res.data else None
        except Exception:
            inserted = None

        return jsonify(
            {
                "status": "success",
                "message": "Data received, processed, and stored",
                "inserted": inserted,
                "computed": {
                    "prediction": prediction,
                    "confidence": confidence,
                    "recommendation": recommendation,
                    "is_alert": bool(is_alert),
                },
            }
        )

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 400


if __name__ == "__main__":
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "5000"))

    print("=" * 60)
    print("🌊 SWAI Dashboard - Sensor Server")
    print("=" * 60)
    print(f"✓ Server starting on http://{host}:{port}")
    print(f"✓ Arduino endpoint: http://<YOUR_IP>:{port}/api/sensor/reading")
    print(f"✓ Health check: http://localhost:{port}/health")
    if not SUPABASE_URL or not SUPABASE_KEY:
        print("⚠️  SUPABASE_URL/SUPABASE_KEY not set (export env vars or use .env)")
    if GEMINI_API_KEY and genai is None:
        print("⚠️  GEMINI_API_KEY set but google-generativeai not installed")
    print("=" * 60)

    app.run(host=host, port=port, debug=False)
