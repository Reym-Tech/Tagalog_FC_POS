import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PasswordService {
  /// Generate a random salt for password hashing
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64.encode(saltBytes);
  }

  /// Hash a password with salt
  /// Returns: "salt:hash" format
  static String hashPassword(String password) {
    try {
      final salt = _generateSalt();
      final bytes = utf8.encode(password + salt);
      final digest = sha256.convert(bytes);
      
      // Store salt and hash together, separated by colon
      return '$salt:${digest.toString()}';
    } catch (e) {
      print('❌ Error hashing password: $e');
      throw Exception('Failed to hash password');
    }
  }

  /// Verify a password against a stored hash
  /// storedHash format: "salt:hash"
  static bool verifyPassword(String password, String storedHash) {
    try {
      // Handle legacy plain text passwords (for migration)
      if (!storedHash.contains(':')) {
        print('⚠️ Legacy plain text password detected');
        return password == storedHash;
      }

      final parts = storedHash.split(':');
      if (parts.length != 2) {
        print('❌ Invalid hash format');
        return false;
      }
      
      final salt = parts[0];
      final expectedHash = parts[1];
      
      // Hash the provided password with the stored salt
      final bytes = utf8.encode(password + salt);
      final digest = sha256.convert(bytes);
      
      final isValid = digest.toString() == expectedHash;
      print(isValid ? '✅ Password verification successful' : '❌ Password verification failed');
      
      return isValid;
    } catch (e) {
      print('❌ Error verifying password: $e');
      return false;
    }
  }

  /// Generate a secure temporary password
  static String generateTempPassword({int length = 8}) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    
    return String.fromCharCodes(Iterable.generate(
      length, 
      (_) => chars.codeUnitAt(random.nextInt(chars.length))
    ));
  }

  /// Check if a password meets security requirements
  static bool isPasswordSecure(String password) {
    if (password.length < 6) return false;
    
    // Add more security requirements as needed
    // - Must contain uppercase letter
    // - Must contain number
    // - Must contain special character
    
    return true;
  }

  /// Get password strength description
  static String getPasswordStrength(String password) {
    if (password.length < 4) return 'Very Weak';
    if (password.length < 6) return 'Weak';
    if (password.length < 8) return 'Fair';
    if (password.length < 12) return 'Good';
    return 'Strong';
  }
}