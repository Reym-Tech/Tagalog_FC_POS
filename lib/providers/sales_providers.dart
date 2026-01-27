import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/sale_item.dart';
import '../services/shared_prefs_service.dart';

class SaleProvider with ChangeNotifier {
  List<SaleItem> _cartItems = [];
  double _totalAmount = 0.0;
  double _amountPaid = 0.0;
  double _changeAmount = 0.0;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _salesHistory = [];

  List<SaleItem> get cartItems => _cartItems;
  double get totalAmount => _totalAmount;
  double get amountPaid => _amountPaid;
  double get changeAmount => _changeAmount;
  bool get isProcessing => _isProcessing;
  List<Map<String, dynamic>> get salesHistory => _salesHistory;

  final SupabaseService _supabase = SupabaseService();

  // ========== CART MANAGEMENT ==========
  void addToCart(SaleItem item) {
    final existingIndex = _cartItems.indexWhere(
            (cartItem) => cartItem.productId == item.productId
    );

    if (existingIndex >= 0) {
      _cartItems[existingIndex] = SaleItem(
        productId: item.productId,
        productName: item.productName,
        productCategory: item.productCategory,
        productPrice: item.productPrice,
        quantity: _cartItems[existingIndex].quantity + item.quantity,
      );
    } else {
      _cartItems.add(item);
    }

    _calculateTotals();
    notifyListeners();
  }

  void removeFromCart(String productId) {
    _cartItems.removeWhere((item) => item.productId == productId);
    _calculateTotals();
    notifyListeners();
  }

  void updateQuantity(String productId, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(productId);
      return;
    }

    final index = _cartItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final item = _cartItems[index];
      _cartItems[index] = SaleItem(
        productId: item.productId,
        productName: item.productName,
        productCategory: item.productCategory,
        productPrice: item.productPrice,
        quantity: newQuantity,
      );
    }

    _calculateTotals();
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _totalAmount = 0.0;
    _amountPaid = 0.0;
    _changeAmount = 0.0;
    notifyListeners();
  }

  void _calculateTotals() {
    _totalAmount = _cartItems.fold(0.0, (sum, item) => sum + item.subtotal);
    _changeAmount = _amountPaid - _totalAmount;
  }

  void updatePayment(double amount) {
    _amountPaid = amount;
    _changeAmount = amount - _totalAmount;
    notifyListeners();
  }

  // ========== SALE PROCESSING ==========
  Future<Map<String, dynamic>> processSale() async {
    _isProcessing = true;
    notifyListeners();

    try {
      final userData = await SharedPrefsService.getUserData();

      print('🔄 STARTING SALE PROCESSING');
      print('📦 Cart items: ${_cartItems.length}');
      print('💰 Total amount: $_totalAmount');
      print('💵 Amount paid: $_amountPaid');

      if (_cartItems.isEmpty) {
        throw Exception('Cart is empty');
      }

      if (_amountPaid < _totalAmount) {
        throw Exception('Amount paid is less than total amount');
      }

      // Generate transaction number
      final now = DateTime.now();
      final transactionNumber = 'TXN${now.millisecondsSinceEpoch}';

      // Get current user ID - use SharedPrefs since we're not using Supabase Auth
      final currentUserId = userData['user_id']?.toString();
      final currentUsername = userData['username']?.toString() ?? '';

      // For now, if no valid user ID, we'll try to get the actual user ID from database
      String? actualUserId;
      if (currentUserId != null && currentUserId != '0' && currentUserId.isNotEmpty) {
        actualUserId = currentUserId;
      } else if (currentUsername.isNotEmpty) {
        // Try to get the actual user ID from database using username
        try {
          final userRecord = await _supabase.getUserByUsername(currentUsername);
          if (userRecord != null) {
            actualUserId = userRecord['id']?.toString();
            print('✅ Found user ID from database: $actualUserId for username: $currentUsername');
          }
        } catch (e) {
          print('⚠️ Could not fetch user ID from database: $e');
        }
      }

      // Prepare sale data
      final saleData = {
        'transaction_number': transactionNumber,
        'total_amount': _totalAmount,
        'amount_paid': _amountPaid,
        'change_amount': _changeAmount,
        'payment_method': 'cash',
        'customer_name': '',
        'discount': 0.0,
        'tax': 0.0,
        'created_at': now.toIso8601String(),
      };

      // Only add user_id if we have a valid one
      if (actualUserId != null && actualUserId.isNotEmpty) {
        saleData['user_id'] = actualUserId;
        print('✅ Adding user_id to sale: $actualUserId');
      } else {
        print('⚠️ No valid user_id found, sale will be created without user reference');
      }

      print('📤 Creating sale in Supabase...');
      final createdSale = await _supabase.createSale(saleData);
      final saleId = createdSale['id']?.toString();

      if (saleId != null && saleId.isNotEmpty) {
        print('✅ Sale created with ID: $saleId');

        // Add sale items
        final saleItems = _cartItems.map((item) {
          return {
            'sale_id': saleId,
            'product_id': item.productId,
            'product_name': item.productName,
            'product_price': item.productPrice,
            'quantity': item.quantity,
            'total_price': item.subtotal,
          };
        }).toList();

        print('📤 Adding ${saleItems.length} sale items...');
        await _supabase.addSaleItems(saleItems);

        // Clear cart and reload history
        // DON'T clear cart here - let the receipt dialog handle it
        await loadSalesHistory();

        print('✅ SALE PROCESSING COMPLETED SUCCESSFULLY');

        return {
          'success': true,
          'message': 'Sale completed successfully!',
          'sale_number': transactionNumber,
          'total_amount': _totalAmount,
          'amount_paid': _amountPaid,
          'change_amount': _changeAmount,
          'items': _cartItems.map((item) => {
            'productName': item.productName,
            'quantity': item.quantity,
            'productPrice': item.productPrice,
            'subtotal': item.subtotal,
          }).toList(),
        };
      } else {
        throw Exception('Failed to create sale - no ID returned');
      }

    } catch (e) {
      print('❌ SALE PROCESSING FAILED: $e');

      return {
        'success': false,
        'message': _getUserFriendlyErrorMessage(e),
        'error_details': e.toString(),
      };
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  String _getUserFriendlyErrorMessage(dynamic error) {
    final errorStr = error.toString();

    if (errorStr.contains('Cart is empty')) {
      return 'Your cart is empty. Add items before checkout.';
    } else if (errorStr.contains('Amount paid is less')) {
      return 'Payment amount is insufficient. Please enter more amount.';
    } else if (errorStr.contains('connection') || errorStr.contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else {
      return 'Unable to process sale. Please try again.';
    }
  }

  // ========== SALES HISTORY ==========
  Future<void> loadSalesHistory() async {
    try {
      print('📥 Loading sales history from Supabase...');
      final sales = await _supabase.getSales();
      _salesHistory = sales;
      print('📥 Loaded ${sales.length} sales from Supabase');
      notifyListeners();
    } catch (e) {
      print('❌ Error loading sales history: $e');
      _salesHistory = [];
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getSaleDetails(String saleId) async {
    try {
      return await _supabase.getSaleDetails(saleId);
    } catch (e) {
      print('❌ Error getting sale details: $e');
      throw Exception('Failed to get sale details: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTopProductsReport() async {
    try {
      return await _supabase.getTopProducts();
    } catch (e) {
      print('❌ Error getting top products: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSalesByDateRange(String startDate, String endDate) async {
    try {
      return await _supabase.getSalesByDateRange(startDate, endDate);
    } catch (e) {
      print('❌ Error getting sales by date range: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSalesSummary() async {
    try {
      return await _supabase.getSalesSummary();
    } catch (e) {
      print('❌ Error getting sales summary: $e');
      return {
        'today': {'sales': 0, 'revenue': 0.0},
        'week': {'sales': 0, 'revenue': 0.0},
        'month': {'sales': 0, 'revenue': 0.0},
      };
    }
  }

  // ========== UTILITIES ==========
  Future<bool> checkConnectivity() async {
    try {
      return await _supabase.testConnection();
    } catch (e) {
      return false;
    }
  }

  Future<void> refresh() async {
    await loadSalesHistory();
    notifyListeners();
  }
}