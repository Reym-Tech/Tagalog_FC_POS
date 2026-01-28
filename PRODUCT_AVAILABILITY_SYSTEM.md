# Product Availability System

## Overview

This system implements a simple product availability toggle without full inventory management. It allows staff to quickly mark products as available or out of stock during their shifts.

## Two-Level Control System

### 1. **Active/Inactive** (Admin Only)
- **Purpose**: Permanent enable/disable of products
- **Access**: Admin users only
- **Icon**: Eye (visibility/visibility_off)
- **Colors**: Orange (disable) / Green (enable)
- **Use Case**: Discontinuing products, seasonal items

### 2. **Available/Out of Stock** (All Users)
- **Purpose**: Temporary availability status
- **Access**: All staff members
- **Icon**: Inventory (inventory/inventory_2_outlined)
- **Colors**: Green (available) / Red (out of stock)
- **Use Case**: Daily stock management, temporary shortages

## Database Schema

```sql
-- Add both columns to products table
ALTER TABLE products ADD COLUMN active BOOLEAN DEFAULT true;
ALTER TABLE products ADD COLUMN available BOOLEAN DEFAULT true;

-- Update existing products
UPDATE products SET active = true WHERE active IS NULL;
UPDATE products SET available = true WHERE available IS NULL;
```

## Product Visibility Logic

A product appears in the POS only if:
- `active = true` (enabled by admin)
- `available = true` (marked as in stock by staff)

**Formula**: `product.isSelectable = product.isActive && product.isAvailable`

## User Interface

### POS System
- **Product Cards**: Show availability toggle in top-right corner
- **Visual Indicators**: 
  - Available: Green check circle
  - Out of Stock: Red cancel circle + "OUT OF STOCK" badge
- **Interaction**: Tap toggle to change availability
- **Disabled State**: Out of stock products are grayed out, buttons disabled

### Settings Page (Product Management)
- **Admin Users See**:
  - Edit button (blue pencil)
  - Availability toggle (green/red inventory icon) - for all users
  - Enable/Disable toggle (orange/green eye icon) - admin only
  - Delete button (red trash) - admin only

- **Staff Users See**:
  - Edit button (blue pencil)
  - Availability toggle (green/red inventory icon) - for all users

### Status Badges
- **DISABLED**: Orange badge (admin control)
- **OUT OF STOCK**: Red badge (staff control)

## Workflow Examples

### Daily Operations (Staff)
1. **Morning Setup**: Check product availability, mark items as available
2. **During Service**: When items run out, tap the availability toggle
3. **Restocking**: When items are restocked, tap to mark available again

### Administrative Tasks (Admin)
1. **New Products**: Add products (automatically active and available)
2. **Seasonal Items**: Disable products during off-season
3. **Discontinued Items**: Disable permanently or delete if no sales history

## Benefits

### For Staff
- ✅ Quick one-tap availability control
- ✅ Visual feedback on product status
- ✅ No complex inventory numbers to manage
- ✅ Prevents selling out-of-stock items

### For Management
- ✅ Real-time visibility of product availability
- ✅ Admin control over product catalog
- ✅ Simple system without inventory complexity
- ✅ Maintains sales history integrity

### For Customers
- ✅ Only see available products
- ✅ No disappointment from ordering unavailable items
- ✅ Faster service (no checking stock)

## Technical Implementation

### Product Model
```dart
class Product {
  final bool isActive;      // Admin control
  final bool isAvailable;   // Staff control
  
  bool get isSelectable => isActive && isAvailable;
}
```

### Database Operations
```dart
// Toggle availability (all users)
await supabase.toggleProductAvailability(productId, isAvailable);

// Toggle active status (admin only)
await supabase.toggleProductStatus(productId, isActive);
```

### POS Filtering
```dart
// Only show selectable products in POS
final products = productProvider.getSelectableProductsByCategory(category);
```

## Error Handling

- **Missing Columns**: Graceful fallback to `true` if columns don't exist
- **Database Errors**: User-friendly error messages
- **Permission Errors**: Admin-only functions hidden from staff
- **Network Issues**: Local state updates with sync on reconnection

## Future Enhancements

- **Low Stock Warnings**: Add quantity thresholds
- **Automatic Restocking**: Integration with suppliers
- **Analytics**: Track availability patterns
- **Notifications**: Alert when items go out of stock
- **Batch Operations**: Mark multiple items at once