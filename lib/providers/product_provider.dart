import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../models/product.dart';

class ProductProvider with ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;
  String _errorMessage = '';

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  final SupabaseService _supabase = SupabaseService();

  Future<void> loadProducts() async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      print('📥 Loading products from Supabase...');
      final productsData = await _supabase.getProducts();
      _products = productsData.map((map) => Product.fromMap(map)).toList();
      print('✅ Loaded ${_products.length} products from Supabase');

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      print('❌ Error loading products: $e');
      _errorMessage = 'Failed to load products: ${e.toString()}';
      _products = [];
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addProduct({
    required String productName,
    required String productDescription,
    required double productPrice,
    required String productCategory,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final productData = {
        'name': productName,
        'description': productDescription,
        'price': productPrice,
        'category': productCategory,
      };

      await _supabase.addProduct(productData);
      await loadProducts(); // Refresh products

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error adding product: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(Product updatedProduct) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final productData = {
        'name': updatedProduct.productName,
        'description': updatedProduct.productDescription,
        'price': updatedProduct.productPrice,
        'category': updatedProduct.productCategory,
      };

      await _supabase.updateProduct(updatedProduct.productId, productData);
      await loadProducts(); // Refresh products

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error updating product: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      await _supabase.deleteProduct(productId);
      await loadProducts(); // Refresh products

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error deleting product: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Product? getProductById(String productId) {
    try {
      return _products.firstWhere((product) => product.productId == productId);
    } catch (e) {
      return null;
    }
  }

  List<Product> getProductsByCategory(String category) {
    return _products.where((product) => product.productCategory == category).toList();
  }

  List<String> getCategories() {
    final categories = _products.map((p) => p.productCategory).toSet().toList();
    categories.removeWhere((cat) => cat.isEmpty);
    categories.sort();
    return categories;
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }
}