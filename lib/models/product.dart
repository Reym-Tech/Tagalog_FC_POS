class Product {
  final String productId; // Changed from int to String for UUID
  final String productName;
  final String productDescription;
  final double productPrice;
  final String productCategory;
  final bool isActive; // Admin control: enabled/disabled
  final bool isAvailable; // Staff control: available/out of stock

  Product({
    required this.productId,
    required this.productName,
    required this.productDescription,
    required this.productPrice,
    required this.productCategory,
    this.isActive = true, // Default to active
    this.isAvailable = true, // Default to available
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      productId: map['id']?.toString() ?? map['product_id']?.toString() ?? '0',
      productName: map['name'] ?? map['product_name'] ?? '',
      productDescription: map['description'] ?? map['product_description'] ?? '',
      productPrice: double.tryParse(map['price']?.toString() ?? map['product_price']?.toString() ?? '0') ?? 0.0,
      productCategory: map['category'] ?? map['product_category'] ?? '',
      isActive: map['active'] ?? map['is_active'] ?? true, // Default to true if column doesn't exist
      isAvailable: map['available'] ?? map['is_available'] ?? true, // Default to true if column doesn't exist
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': productId,
      'name': productName,
      'description': productDescription,
      'price': productPrice,
      'category': productCategory,
      'active': isActive, // Include active field
      'available': isAvailable, // Include available field
    };
  }

  Product copyWith({
    String? productId,
    String? productName,
    String? productDescription,
    double? productPrice,
    String? productCategory,
    bool? isActive, // Allow copying with different active state
    bool? isAvailable, // Allow copying with different available state
  }) {
    return Product(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productDescription: productDescription ?? this.productDescription,
      productPrice: productPrice ?? this.productPrice,
      productCategory: productCategory ?? this.productCategory,
      isActive: isActive ?? this.isActive, // Copy active state
      isAvailable: isAvailable ?? this.isAvailable, // Copy available state
    );
  }

  // Helper method to check if product should be shown in POS
  bool get isSelectable => isActive && isAvailable;
}