-- Migration script to add outlet details columns
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS brand_name text;
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS fssai_number text;
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS gst_number text;
ALTER TABLE outlets ADD COLUMN IF NOT EXISTS upi_id text;
