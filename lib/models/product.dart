class Product {
  final String productId; // Changed from int to String for UUID
  final String productName;
  final String productDescription;
  final double productPrice;
  final String productCategory;

  Product({
    required this.productId,
    required this.productName,
    required this.productDescription,
    required this.productPrice,
    required this.productCategory,
  });

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      productId: map['id']?.toString() ?? map['product_id']?.toString() ?? '0',
      productName: map['name'] ?? map['product_name'] ?? '',
      productDescription: map['description'] ?? map['product_description'] ?? '',
      productPrice: double.tryParse(map['price']?.toString() ?? map['product_price']?.toString() ?? '0') ?? 0.0,
      productCategory: map['category'] ?? map['product_category'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': productId,
      'name': productName,
      'description': productDescription,
      'price': productPrice,
      'category': productCategory,
    };
  }

  Product copyWith({
    String? productId,
    String? productName,
    String? productDescription,
    double? productPrice,
    String? productCategory,
  }) {
    return Product(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      productDescription: productDescription ?? this.productDescription,
      productPrice: productPrice ?? this.productPrice,
      productCategory: productCategory ?? this.productCategory,
    );
  }
}