class Product {
  int productId;
  String productName;
  String productDescription;
  String productCategory;
  double productPrice;

  Product({
    required this.productId,
    required this.productName,
    required this.productDescription,
    required this.productCategory,
    required this.productPrice,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: int.parse(json['product_id'].toString()),
      productName: json['product_name'],
      productDescription: json['product_description'] ?? '',
      productCategory: json['product_category'] ?? '',
      productPrice: double.parse(json['product_price'].toString()),
    );
  }

  num? get quantity => null;

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'product_description': productDescription,
      'product_category': productCategory,
      'product_price': productPrice,
    };
  }
}