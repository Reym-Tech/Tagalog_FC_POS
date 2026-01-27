// models/sale_item.dart
class SaleItem {
  final String productId; // Changed from int to String for UUID
  final String productName;
  final String productCategory;
  final double productPrice;
  final int quantity;

  SaleItem({
    required this.productId,
    required this.productName,
    required this.productCategory,
    required this.productPrice,
    required this.quantity,
  });

  double get subtotal => productPrice * quantity;

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'product_category': productCategory,
      'product_price': productPrice,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory SaleItem.fromJson(Map<String, dynamic> json) {
    return SaleItem(
      productId: json['product_id']?.toString() ?? json['id']?.toString() ?? '0',
      productName: json['product_name'] ?? '',
      productCategory: json['product_category'] ?? '',
      productPrice: (json['product_price'] ?? json['price'] ?? 0.0).toDouble(),
      quantity: json['quantity'] ?? 0,
    );
  }
}