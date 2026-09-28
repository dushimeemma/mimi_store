ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_distance_km numeric(10,2),
  ADD COLUMN IF NOT EXISTS delivery_rate_rwf integer CHECK (delivery_rate_rwf >= 0),
  ADD COLUMN IF NOT EXISTS delivery_range_km numeric(10,2) CHECK (delivery_range_km > 0);

UPDATE app_settings
SET setting_value =
  (setting_value - 'deliveryFeeRwf') ||
  jsonb_build_object(
    'deliveryRateRwf', 500,
    'deliveryRangeKm', 1,
    'deliveryOriginLatitude', -1.9441,
    'deliveryOriginLongitude', 30.0619
  ),
  updated_at = now()
WHERE setting_key = 'payment';
