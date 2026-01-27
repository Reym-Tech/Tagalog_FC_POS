import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  static void debugPrintUrl(String endpoint) {
    print('🌐 API Call: $baseUrl/$endpoint');
  }

  static Map<String, String> getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static Future<bool> testConnection() async {
    try {
      print('Testing connection to: $baseUrl');
      final response = await http.get(
        Uri.parse('$baseUrl/api/test.php'),
        headers: getHeaders(),
      ).timeout(const Duration(seconds: 5));

      print('Connection test response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    print('🌐 Response status: ${response.statusCode}');

    try {
      final decodedBody = json.decode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decodedBody;
      } else {
        throw Exception(decodedBody['message'] ?? 'HTTP ${response.statusCode}: Something went wrong');
      }
    } catch (e) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.toLowerCase().contains('success')) {
          return {'success': true, 'message': response.body};
        }
        throw Exception('Failed to parse JSON response: $e');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    }
  }

  // ========== AUTHENTICATION ==========
  static Future<Map<String, dynamic>> login(String username, String password) async {
    print('🔐 Attempting login for user: $username');
    debugPrintUrl('api/auth.php');

    try {
      final Map<String, String> body = {
        'username': username,
        'password': password,
      };

      print('Request body: $body');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth.php'),
        headers: getHeaders(),
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      print('📡 Login response status: ${response.statusCode}');

      return _handleResponse(response);
    } catch (e) {
      print('❌ Login error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // ========== PRODUCTS ==========
  static Future<List<Map<String, dynamic>>> getProducts() async {
    try {
      debugPrintUrl('api/products.php');
      final response = await http.get(
        Uri.parse('$baseUrl/api/products.php'),
        headers: getHeaders(),
      ).timeout(const Duration(seconds: 10));

      final result = _handleResponse(response);

      if (result.containsKey('data')) {
        final productsData = result['data'] as List;
        return productsData.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting products: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> addProduct(Map<String, dynamic> productData) async {
    try {
      debugPrintUrl('api/products.php');
      print('📦 Sending add product request: $productData');

      final response = await http.post(
        Uri.parse('$baseUrl/api/products.php'),
        headers: getHeaders(),
        body: json.encode({
          'product_name': productData['product_name'],
          'product_description': productData['product_description'],
          'product_price': productData['product_price'],
          'product_category': productData['product_category'],
        }),
      ).timeout(const Duration(seconds: 10));

      print('📦 Add product response: ${response.statusCode}');

      return _handleResponse(response);
    } catch (e) {
      print('❌ Add product error: $e');
      return {
        'success': false,
        'message': 'Network error: ${e.toString()}',
      };
    }
  }

  // ========== SALES ==========
  static Future<List<Map<String, dynamic>>> getSales({String? startDate, String? endDate}) async {
    try {
      String url = '$baseUrl/api/sales.php';
      final params = <String, String>{};

      if (startDate != null && endDate != null) {
        params['start_date'] = startDate;
        params['end_date'] = endDate;
      }

      if (params.isNotEmpty) {
        url += '?' + Uri(queryParameters: params).query;
      }

      debugPrintUrl('api/sales.php');
      final response = await http.get(
        Uri.parse(url),
        headers: getHeaders(),
      );

      final result = _handleResponse(response);

      if (result.containsKey('data')) {
        final salesData = result['data'] as List;
        return salesData.map((item) => item as Map<String, dynamic>).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('Error getting sales: $e');
      return [];
    }
  }
}