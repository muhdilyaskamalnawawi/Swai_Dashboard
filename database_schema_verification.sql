-- ========================================
-- SWAI Dashboard - Database Schema Verification
-- ========================================
-- Run this in Supabase SQL Editor to ensure all columns exist

-- 1. Check if prediction and recommendation columns exist
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'sensor_readings'
  AND column_name IN ('prediction', 'recommendation');

-- 2. If columns are missing, add them (safe to run - will error if they exist)
-- ALTER TABLE sensor_readings ADD COLUMN IF NOT EXISTS prediction TEXT;
-- ALTER TABLE sensor_readings ADD COLUMN IF NOT EXISTS recommendation TEXT;

-- 3. Verify the complete table structure
SELECT column_name, data_type, column_default, is_nullable
FROM information_schema.columns
WHERE table_name = 'sensor_readings'
ORDER BY ordinal_position;

-- 4. Check sample data to see if predictions are being saved
SELECT 
  id,
  ph,
  temp,
  tds,
  prediction IS NOT NULL as has_prediction,
  recommendation IS NOT NULL as has_recommendation,
  timestamp
FROM sensor_readings
ORDER BY timestamp DESC
LIMIT 10;

-- Expected structure:
-- id (uuid)
-- ph (float8)
-- temp (float8)
-- tds (float8)
-- prediction (text) - nullable
-- recommendation (text) - nullable
-- timestamp (timestamp without time zone)
-- is_alert (boolean)
-- created_at (timestamp without time zone)
