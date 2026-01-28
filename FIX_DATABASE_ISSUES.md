# Fix Database Issues

## Issue 1: Add `active` column to products table

**Step 1:** Go to your Supabase dashboard
**Step 2:** Navigate to SQL Editor
**Step 3:** Run this SQL command:

```sql
-- Add active column to products table
ALTER TABLE products ADD COLUMN active BOOLEAN DEFAULT true;

-- Update existing products to be active by default
UPDATE products SET active = true WHERE active IS NULL;

-- Add comment for documentation
COMMENT ON COLUMN products.active IS 'Whether the product is active/enabled in the POS system';
```

## Issue 2: Verify Supabase connection

**Check your .env file contains:**
```
SUPABASE_URL=your_supabase_url_here
SUPABASE_ANON_KEY=your_supabase_anon_key_here
```

**Test connection:**
1. Open your app
2. Go to Dashboard
3. Should show "Connected to Supabase Database" 
4. Check if products load from Supabase (not local data)

## Issue 3: Clear app cache (if still showing local data)

**Option A: Clear app data on device**
1. Go to device Settings > Apps > Your App > Storage
2. Clear Data and Cache
3. Restart the app

**Option B: Uninstall and reinstall**
1. Uninstall the app from device
2. Run: `flutter build apk --release`
3. Install the new APK

## Issue 4: Verify products are loading from Supabase

**Check the terminal output when app starts:**
- Should see: "📥 Loading products from Supabase..."
- Should see: "✅ Loaded X products from Supabase"
- Should NOT see any SQLite or local database messages

## Issue 5: Test the new functionality

**After adding the `active` column:**
1. Go to Settings > Product Management
2. Try to delete a product that has sales history
3. Should show option to "Disable Instead"
4. Try the enable/disable toggle buttons (eye icons)
5. Disabled products should not appear in POS

**If you get "active column does not exist" error:**
- Make sure you ran the SQL command in Supabase
- Check that the column was added: `SELECT * FROM products LIMIT 1;`
- The query should show the `active` column

## Troubleshooting

**If still showing local data:**
1. Check internet connection
2. Verify Supabase credentials in .env
3. Check Supabase dashboard for recent activity
4. Clear app cache/data
5. Check terminal for connection errors

**If delete still fails:**
1. Make sure you added the `active` column
2. Check Supabase logs for errors
3. Verify foreign key constraints exist in your database