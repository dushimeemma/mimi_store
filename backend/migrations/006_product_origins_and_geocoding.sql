ALTER TABLE products
  ADD COLUMN IF NOT EXISTS origin_name text,
  ADD COLUMN IF NOT EXISTS origin_latitude numeric(10,7),
  ADD COLUMN IF NOT EXISTS origin_longitude numeric(10,7);

UPDATE products
SET origin_name = 'Kabuye Health Center, Kigali, Rwanda',
    origin_latitude = -1.8795,
    origin_longitude = 30.0708
WHERE origin_name IS NULL
   OR origin_latitude IS NULL
   OR origin_longitude IS NULL;

ALTER TABLE products
  ALTER COLUMN origin_name SET DEFAULT 'Kabuye Health Center, Kigali, Rwanda',
  ALTER COLUMN origin_name SET NOT NULL,
  ALTER COLUMN origin_latitude SET DEFAULT -1.8795,
  ALTER COLUMN origin_latitude SET NOT NULL,
  ALTER COLUMN origin_longitude SET DEFAULT 30.0708,
  ALTER COLUMN origin_longitude SET NOT NULL;

ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS delivery_breakdown jsonb NOT NULL DEFAULT '[]'::jsonb;

CREATE TABLE IF NOT EXISTS geocoding_cache (
  cache_key text PRIMARY KEY,
  query text NOT NULL,
  display_name text NOT NULL,
  latitude numeric(10,7) NOT NULL,
  longitude numeric(10,7) NOT NULL,
  provider text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

UPDATE app_settings
SET setting_value = setting_value
  - 'deliveryOriginLatitude'
  - 'deliveryOriginLongitude',
    updated_at = now()
WHERE setting_key = 'payment';
