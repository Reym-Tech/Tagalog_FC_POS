-- Add active and available columns to products table
ALTER TABLE products ADD COLUMN active BOOLEAN DEFAULT true;
ALTER TABLE products ADD COLUMN available BOOLEAN DEFAULT true;

-- Update existing products to be active and available by default
UPDATE products SET active = true WHERE active IS NULL;
UPDATE products SET available = true WHERE available IS NULL;

-- Add comments for documentation
COMMENT ON COLUMN products.active IS 'Whether the product is enabled/disabled by admin';
COMMENT ON COLUMN products.available IS 'Whether the product is currently available/in stock (managed by all staff)';