CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_role AS ENUM ('customer', 'super_admin', 'admin', 'driver');
CREATE TYPE order_status AS ENUM ('awaiting_payment', 'payment_confirmed', 'ready_for_pickup', 'assigned', 'out_for_delivery', 'delivered', 'cancelled');
CREATE TYPE payment_status AS ENUM ('pending', 'successful', 'failed');

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL,
  password_hash text NOT NULL,
  full_name text NOT NULL,
  phone text,
  role user_role NOT NULL DEFAULT 'customer',
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_email_unique ON users (lower(email));

CREATE TABLE refresh_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX refresh_tokens_user_id_idx ON refresh_tokens(user_id);

CREATE TABLE products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  category text NOT NULL,
  description text NOT NULL DEFAULT '',
  price_rwf integer NOT NULL CHECK (price_rwf >= 0),
  stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
  image_url text,
  badge text,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX products_active_category_idx ON products(active, category);

CREATE TABLE app_settings (
  setting_key text PRIMARY KEY,
  setting_value jsonb NOT NULL,
  updated_by uuid REFERENCES users(id),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number text NOT NULL UNIQUE,
  customer_id uuid NOT NULL REFERENCES users(id),
  assigned_driver_id uuid REFERENCES users(id),
  status order_status NOT NULL DEFAULT 'awaiting_payment',
  subtotal_rwf integer NOT NULL CHECK (subtotal_rwf >= 0),
  delivery_rwf integer NOT NULL CHECK (delivery_rwf >= 0),
  total_rwf integer NOT NULL CHECK (total_rwf >= 0),
  delivery_address text NOT NULL,
  latitude numeric(10,7),
  longitude numeric(10,7),
  customer_phone text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX orders_customer_created_idx ON orders(customer_id, created_at DESC);
CREATE INDEX orders_driver_status_idx ON orders(assigned_driver_id, status);

CREATE TABLE order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id),
  product_name text NOT NULL,
  unit_price_rwf integer NOT NULL,
  quantity integer NOT NULL CHECK (quantity > 0),
  line_total_rwf integer NOT NULL
);
CREATE INDEX order_items_order_id_idx ON order_items(order_id);

CREATE TABLE payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL UNIQUE REFERENCES orders(id),
  provider text NOT NULL DEFAULT 'mtn_momo',
  provider_reference uuid NOT NULL UNIQUE,
  amount_rwf integer NOT NULL,
  payer_phone text NOT NULL,
  status payment_status NOT NULL DEFAULT 'pending',
  provider_payload jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX payments_status_idx ON payments(status);

INSERT INTO app_settings(setting_key, setting_value)
VALUES ('payment', '{"momoNumber":"+250788440177","deliveryFeeRwf":2500,"freeDeliveryThresholdRwf":100000}'::jsonb)
ON CONFLICT (setting_key) DO NOTHING;
