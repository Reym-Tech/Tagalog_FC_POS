import 'package:supabase_flutter/supabase_flutter.dart';
import 'password_service.dart';
import '../config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  late String supabaseUrl;
  late String supabaseAnonKey;
  late SupabaseClient client;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  // Initialize Supabase
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await Config.load();

      supabaseUrl = Config.supabaseUrl;
      supabaseAnonKey = Config.supabaseAnonKey;

      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );

      client = Supabase.instance.client;
      _isInitialized = true;
      print('✅ Supabase initialized successfully');
    } catch (e) {
      print('❌ Failed to initialize Supabase: $e');
      rethrow;
    }
  }

  // ========== AUTHENTICATION ==========
  Future<AuthResponse> signUp(String email, String password, String fullName) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
  }

  Future<Session?> signIn(String email, String password) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.session;
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  User? get currentUser => client.auth.currentUser;

  // ========== USERS ==========
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final response = await client
          .from('users')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting users from Supabase: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('❌ Error getting user by ID from Supabase: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    try {
      final response = await client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();
      return response;
    } catch (e) {
      print('❌ Error getting user by username from Supabase: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> loginUser(String username, String password) async {
    try {
      print('🔐 Attempting login for user: $username');
      
      // Get user record from database
      final response = await client
          .from('users')
          .select()
          .eq('username', username)
          .maybeSingle();
      
      if (response != null) {
        final storedPasswordHash = response['password'] as String;
        final isTemporaryPassword = response['temp_password'] == true;
        
        // Verify password against stored hash
        if (PasswordService.verifyPassword(password, storedPasswordHash)) {
          print('✅ User login successful: $username');
          
          // If this was a legacy plain text password, update it to hashed version
          if (!storedPasswordHash.contains(':')) {
            print('🔄 Migrating legacy password to hashed version');
            await _updateUserPassword(username, password);
          }
          
          // Add temp_password flag to response for UI handling
          final userResponse = Map<String, dynamic>.from(response);
          userResponse['needs_password_change'] = isTemporaryPassword;
          
          return userResponse;
        } else {
          print('❌ Invalid password for user: $username');
        }
      } else {
        print('❌ User not found: $username');
      }
      
      return null;
    } catch (e) {
      print('❌ Error during login: $e');
      return null;
    }
  }

  /// Update user password with proper hashing
  Future<bool> _updateUserPassword(String username, String newPassword) async {
    try {
      final hashedPassword = PasswordService.hashPassword(newPassword);
      
      final response = await client
          .from('users')
          .update({'password': hashedPassword})
          .eq('username', username);
      
      print('✅ Password updated with hash for user: $username');
      return true;
    } catch (e) {
      print('❌ Error updating password: $e');
      return false;
    }
  }

  /// Create new user with hashed password
  Future<Map<String, dynamic>?> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
  }) async {
    try {
      // Validate password security
      if (!PasswordService.isPasswordSecure(password)) {
        throw Exception('Password does not meet security requirements');
      }

      final hashedPassword = PasswordService.hashPassword(password);
      
      final userData = {
        'username': username,
        'password': hashedPassword,
        'full_name': fullName,
        'role': role,
      };

      final response = await client
          .from('users')
          .insert(userData)
          .select()
          .single();

      print('✅ User created successfully: $username');
      return response;
    } catch (e) {
      print('❌ Error creating user: $e');
      return null;
    }
  }

  /// Reset user password (admin function)
  Future<String?> resetUserPassword(String username) async {
    try {
      final tempPassword = PasswordService.generateTempPassword();
      final hashedPassword = PasswordService.hashPassword(tempPassword);
      
      // Mark this as a temporary password that needs to be changed
      final response = await client
          .from('users')
          .update({
            'password': hashedPassword,
            'temp_password': true, // Flag to indicate temporary password
          })
          .eq('username', username);
      
      print('✅ Password reset for user: $username');
      return tempPassword; // Return temp password to give to user
    } catch (e) {
      print('❌ Error resetting password: $e');
      return null;
    }
  }

  /// Change user password (user function)
  Future<bool> changeUserPassword(String username, String oldPassword, String newPassword) async {
    try {
      // First verify old password
      final user = await loginUser(username, oldPassword);
      if (user == null) {
        print('❌ Old password verification failed');
        return false;
      }

      // Validate new password
      if (!PasswordService.isPasswordSecure(newPassword)) {
        throw Exception('New password does not meet security requirements');
      }

      // Update with new hashed password and clear temp_password flag
      final hashedPassword = PasswordService.hashPassword(newPassword);
      
      final response = await client
          .from('users')
          .update({
            'password': hashedPassword,
            'temp_password': false, // Clear temporary password flag
          })
          .eq('username', username);

      print('✅ Password changed successfully for user: $username');
      return true;
    } catch (e) {
      print('❌ Error changing password: $e');
      return false;
    }
  }

  Future<void> addUser(Map<String, dynamic> userData) async {
    try {
      await client.from('users').insert(userData);
    } catch (e) {
      print('❌ Error adding user to Supabase: $e');
      rethrow;
    }
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await client
          .from('users')
          .update(data)
          .eq('id', userId);
    } catch (e) {
      print('❌ Error updating user in Supabase: $e');
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      // First check if this user has any sales history
      final salesCheck = await client
          .from('sales')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      
      if (salesCheck.isNotEmpty) {
        throw Exception('Cannot delete user: This user has sales history. User accounts with sales records cannot be deleted for audit purposes.');
      }
      
      // If no sales history, proceed with deletion
      await client
          .from('users')
          .delete()
          .eq('id', userId);
      
      print('✅ User deleted successfully');
    } catch (e) {
      print('❌ Error deleting user from Supabase: $e');
      rethrow;
    }
  }

  // ========== PRODUCTS ==========
  Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      final response = await client
          .from('products')
          .select()
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting products from Supabase: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getProductById(String productId) async {
    try {
      final response = await client
          .from('products')
          .select()
          .eq('id', productId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('❌ Error getting product by ID from Supabase: $e');
      return null;
    }
  }

  Future<void> addProduct(Map<String, dynamic> productData) async {
    try {
      final data = Map<String, dynamic>.from(productData);
      data.remove('id');
      await client.from('products').insert(data);
    } catch (e) {
      print('❌ Error adding product to Supabase: $e');
      rethrow;
    }
  }

  Future<void> updateProduct(String productId, Map<String, dynamic> data) async {
    try {
      await client
          .from('products')
          .update(data)
          .eq('id', productId);
    } catch (e) {
      print('❌ Error updating product in Supabase: $e');
      rethrow;
    }
  }

  Future<void> deleteProduct(String productId) async {
    try {
      // First check if this product has any sales history
      final salesCheck = await client
          .from('sale_items')
          .select('id')
          .eq('product_id', productId)
          .limit(1);
      
      if (salesCheck.isNotEmpty) {
        throw Exception('Cannot delete product: This product has sales history. Consider disabling it instead.');
      }
      
      // If no sales history, proceed with deletion
      await client
          .from('products')
          .delete()
          .eq('id', productId);
      
      print('✅ Product deleted successfully');
    } catch (e) {
      print('❌ Error deleting product from Supabase: $e');
      rethrow;
    }
  }

  Future<void> toggleProductStatus(String productId, bool isActive) async {
    try {
      // Check if the active column exists first
      final testQuery = await client
          .from('products')
          .select('active')
          .eq('id', productId)
          .limit(1);
      
      // If we get here, the column exists
      await client
          .from('products')
          .update({'active': isActive})
          .eq('id', productId);
      
      print('✅ Product status updated: ${isActive ? 'enabled' : 'disabled'}');
    } catch (e) {
      if (e.toString().contains('column "active" does not exist')) {
        throw Exception('The active column does not exist in the products table. Please run the database migration first:\n\nALTER TABLE products ADD COLUMN active BOOLEAN DEFAULT true;');
      }
      print('❌ Error updating product status: $e');
      rethrow;
    }
  }

  Future<void> toggleProductAvailability(String productId, bool isAvailable) async {
    try {
      // Check if the available column exists first
      final testQuery = await client
          .from('products')
          .select('available')
          .eq('id', productId)
          .limit(1);
      
      // If we get here, the column exists
      await client
          .from('products')
          .update({'available': isAvailable})
          .eq('id', productId);
      
      print('✅ Product availability updated: ${isAvailable ? 'available' : 'out of stock'}');
    } catch (e) {
      if (e.toString().contains('column "available" does not exist')) {
        throw Exception('The available column does not exist in the products table. Please run the database migration first:\n\nALTER TABLE products ADD COLUMN available BOOLEAN DEFAULT true;');
      }
      print('❌ Error updating product availability: $e');
      rethrow;
    }
  }

  // ========== SALES ==========
  Future<List<Map<String, dynamic>>> getSales() async {
    try {
      final response = await client
          .from('sales')
          .select('''
            *,
            user:users(full_name, username),
            sale_items(*)
          ''')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting sales from Supabase: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    try {
      print('🔄 Creating sale in Supabase with data: $saleData');

      final cleanData = Map<String, dynamic>.from(saleData);
      cleanData.remove('id');

      // Handle user_id properly
      if (cleanData.containsKey('user_id')) {
        final userId = cleanData['user_id'];
        if (userId == null || userId.toString().isEmpty || userId.toString() == 'null') {
          cleanData.remove('user_id');
        } else {
          cleanData['user_id'] = userId.toString();
        }
      }

      // Add timestamp if not present
      if (!cleanData.containsKey('created_at')) {
        cleanData['created_at'] = DateTime.now().toIso8601String();
      }

      print('📤 Creating sale with data: $cleanData');

      final response = await client
          .from('sales')
          .insert(cleanData)
          .select()
          .single();

      print('✅ Sale created successfully: $response');
      return response;

    } catch (e) {
      print('❌ Error creating sale: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSaleItems(String saleId) async {
    try {
      final response = await client
          .from('sale_items')
          .select()
          .eq('sale_id', saleId)
          .order('created_at');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting sale items from Supabase: $e');
      return [];
    }
  }

  Future<void> addSaleItems(List<Map<String, dynamic>> items) async {
    try {
      print('🔄 Adding ${items.length} sale items to Supabase');

      final cleanedItems = items.map((item) {
        final cleanItem = Map<String, dynamic>.from(item);
        cleanItem.remove('id');

        // Ensure IDs are strings
        if (cleanItem.containsKey('sale_id')) {
          cleanItem['sale_id'] = cleanItem['sale_id'].toString();
        }
        if (cleanItem.containsKey('product_id')) {
          cleanItem['product_id'] = cleanItem['product_id'].toString();
        }

        // Add timestamp if not present
        if (!cleanItem.containsKey('created_at')) {
          cleanItem['created_at'] = DateTime.now().toIso8601String();
        }

        return cleanItem;
      }).toList();

      await client.from('sale_items').insert(cleanedItems);
      print('✅ Sale items added successfully');

    } catch (e) {
      print('❌ Error adding sale items: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSaleDetails(String saleId) async {
    try {
      // Get sale info
      final saleResponse = await client
          .from('sales')
          .select('''
            *,
            user:users(full_name, username)
          ''')
          .eq('id', saleId)
          .single();

      // Get sale items
      final itemsResponse = await getSaleItems(saleId);

      return {
        'sale': saleResponse,
        'items': itemsResponse,
      };
    } catch (e) {
      print('❌ Error getting sale details: $e');
      throw Exception('Failed to get sale details: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getSalesByDateRange(String startDate, String endDate) async {
    try {
      final response = await client
          .from('sales')
          .select('''
            *,
            user:users(full_name, username),
            sale_items(*)
          ''')
          .gte('created_at', '${startDate}T00:00:00')
          .lte('created_at', '${endDate}T23:59:59')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error getting sales by date range: $e');
      return [];
    }
  }

  // ========== STATISTICS & ANALYTICS ==========
  Future<double> getTodaySales() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final response = await client
          .from('sales')
          .select('total_amount')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', today.add(const Duration(days: 1)).toIso8601String());

      final sales = List<Map<String, dynamic>>.from(response);

      return sales.fold<double>(0.0, (sum, sale) {
        final amount = sale['total_amount'];
        if (amount is num) {
          return sum + amount.toDouble();
        }
        return sum;
      });
    } catch (e) {
      print('❌ Error getting today sales from Supabase: $e');
      return 0.0;
    }
  }

  Future<Map<String, dynamic>> getSalesSummary() async {
    try {
      final now = DateTime.now();
      
      // Today's sales
      final startOfToday = DateTime(now.year, now.month, now.day);
      final todayResponse = await client
          .from('sales')
          .select('total_amount')
          .gte('created_at', startOfToday.toIso8601String())
          .lt('created_at', now.add(const Duration(days: 1)).toIso8601String());

      // This week's sales
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekDay = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final weekResponse = await client
          .from('sales')
          .select('total_amount')
          .gte('created_at', startOfWeekDay.toIso8601String());

      // This month's sales
      final startOfMonth = DateTime(now.year, now.month, 1);
      final monthResponse = await client
          .from('sales')
          .select('total_amount')
          .gte('created_at', startOfMonth.toIso8601String());

      final todaySales = List<Map<String, dynamic>>.from(todayResponse);
      final weekSales = List<Map<String, dynamic>>.from(weekResponse);
      final monthSales = List<Map<String, dynamic>>.from(monthResponse);

      return {
        'today': {
          'sales': todaySales.length,
          'revenue': todaySales.fold<double>(0.0, (sum, sale) => 
              sum + ((sale['total_amount'] as num?)?.toDouble() ?? 0.0)),
        },
        'week': {
          'sales': weekSales.length,
          'revenue': weekSales.fold<double>(0.0, (sum, sale) => 
              sum + ((sale['total_amount'] as num?)?.toDouble() ?? 0.0)),
        },
        'month': {
          'sales': monthSales.length,
          'revenue': monthSales.fold<double>(0.0, (sum, sale) => 
              sum + ((sale['total_amount'] as num?)?.toDouble() ?? 0.0)),
        },
      };
    } catch (e) {
      print('❌ Error getting sales summary: $e');
      return {
        'today': {'sales': 0, 'revenue': 0.0},
        'week': {'sales': 0, 'revenue': 0.0},
        'month': {'sales': 0, 'revenue': 0.0},
      };
    }
  }

  Future<List<Map<String, dynamic>>> getTopProducts({int limit = 10}) async {
    try {
      // Try using RPC function first
      final response = await client.rpc('get_top_products', params: {'limit': limit});
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('⚠️ RPC function not available, using direct query: $e');

      try {
        // Fallback to direct query
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        
        final response = await client
            .from('sale_items')
            .select('''
              product_id,
              product_name,
              quantity,
              product_price,
              total_price,
              sales!inner(created_at)
            ''')
            .gte('sales.created_at', thirtyDaysAgo.toIso8601String());

        final items = List<Map<String, dynamic>>.from(response);

        // Group by product
        final Map<String, Map<String, dynamic>> grouped = {};

        for (var item in items) {
          final productId = item['product_id'].toString();
          final productName = item['product_name'] as String;
          final quantity = (item['quantity'] as num).toInt();
          final totalPrice = (item['total_price'] as num).toDouble();

          if (!grouped.containsKey(productId)) {
            grouped[productId] = {
              'product_id': productId,
              'product_name': productName,
              'product_category': 'Unknown',
              'total_quantity_sold': 0,
              'total_revenue': 0.0,
              'total_sales_count': 0,
            };
          }

          grouped[productId]!['total_quantity_sold'] = 
              (grouped[productId]!['total_quantity_sold'] as int) + quantity;
          grouped[productId]!['total_revenue'] = 
              (grouped[productId]!['total_revenue'] as double) + totalPrice;
          grouped[productId]!['total_sales_count'] = 
              (grouped[productId]!['total_sales_count'] as int) + 1;
        }

        // Sort by quantity sold and limit
        final sortedProducts = grouped.values.toList();
        sortedProducts.sort((a, b) => 
            (b['total_quantity_sold'] as int).compareTo(a['total_quantity_sold'] as int));

        return sortedProducts.take(limit).toList();
      } catch (e) {
        print('❌ Error getting top products: $e');
        return [];
      }
    }
  }

  // ========== REAL-TIME SUBSCRIPTIONS ==========
  RealtimeChannel getProductsSubscription() {
    return client.channel('products')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'products',
      callback: (payload) {
        print('Product update: $payload');
      },
    );
  }

  RealtimeChannel getSalesSubscription() {
    return client.channel('sales')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'sales',
      callback: (payload) {
        print('Sale update: $payload');
      },
    );
  }

  // ========== UTILITY METHODS ==========
  String? getCurrentUserId() {
    return client.auth.currentUser?.id;
  }

  bool isValidUUID(String? uuid) {
    if (uuid == null || uuid.isEmpty) return false;

    final uuidPattern = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );

    return uuidPattern.hasMatch(uuid);
  }

  Future<bool> testConnection() async {
    try {
      await client.from('products').select('count').limit(1);
      return true;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }
}