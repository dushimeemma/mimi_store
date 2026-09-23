CREATE TABLE categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text NOT NULL DEFAULT '',
  image_url text,
  active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX categories_name_unique ON categories(lower(name));

INSERT INTO categories(name, slug, sort_order)
SELECT category, regexp_replace(lower(category), '[^a-z0-9]+', '-', 'g'), row_number() OVER (ORDER BY category)
FROM (SELECT DISTINCT category FROM products) source
ON CONFLICT (slug) DO NOTHING;

ALTER TABLE products ADD COLUMN category_id uuid REFERENCES categories(id);
ALTER TABLE products ADD COLUMN sku text;
ALTER TABLE products ADD COLUMN low_stock_threshold integer NOT NULL DEFAULT 5 CHECK (low_stock_threshold >= 0);
UPDATE products p SET category_id=c.id FROM categories c WHERE lower(c.name)=lower(p.category);
CREATE UNIQUE INDEX products_sku_unique ON products(lower(sku)) WHERE sku IS NOT NULL;
CREATE INDEX products_category_id_idx ON products(category_id);

ALTER TABLE orders ADD COLUMN customer_note text;
ALTER TABLE orders ADD COLUMN cancellation_reason text;

CREATE TABLE inventory_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id),
  quantity_delta integer NOT NULL CHECK (quantity_delta <> 0),
  reason text NOT NULL,
  reference text,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX inventory_movements_product_created_idx ON inventory_movements(product_id, created_at DESC);

CREATE TABLE deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL UNIQUE REFERENCES orders(id) ON DELETE CASCADE,
  driver_id uuid REFERENCES users(id),
  status text NOT NULL DEFAULT 'unassigned' CHECK (status IN ('unassigned','assigned','picked_up','out_for_delivery','delivered','failed')),
  notes text,
  proof_url text,
  assigned_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX deliveries_driver_status_idx ON deliveries(driver_id, status);

CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id uuid REFERENCES users(id),
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX audit_logs_created_idx ON audit_logs(created_at DESC);
CREATE INDEX audit_logs_entity_idx ON audit_logs(entity_type, entity_id);

INSERT INTO deliveries(order_id, driver_id, status, assigned_at)
SELECT id, assigned_driver_id, CASE WHEN assigned_driver_id IS NULL THEN 'unassigned' ELSE 'assigned' END,
       CASE WHEN assigned_driver_id IS NULL THEN NULL ELSE updated_at END
FROM orders
ON CONFLICT (order_id) DO NOTHING;

INSERT INTO app_settings(setting_key, setting_value)
VALUES ('store', '{"storeName":"Mimi Store","supportPhone":"+250788440177","supportEmail":"support@mimistore.rw","currency":"RWF"}'::jsonb)
ON CONFLICT (setting_key) DO NOTHING;

UPDATE app_settings
SET setting_value = setting_value || '{"paymentMode":"manual"}'::jsonb
WHERE setting_key='payment' AND NOT (setting_value ? 'paymentMode');
