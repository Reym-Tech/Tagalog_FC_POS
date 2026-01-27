import 'package:tagalog_fried_chicken2/models/sale_item.dart';

class Sale {
  int saleId;
  String saleNumber;
  DateTime saleDate;
  List<SaleItem> items;
  double totalAmount;
  double amountPaid;
  double changeAmount;
  int cashierId;
  String cashierName;

  Sale({
    required this.saleId,
    required this.saleNumber,
    required this.saleDate,
    required this.items,
    required this.totalAmount,
    required this.amountPaid,
    required this.changeAmount,
    required this.cashierId,
    required this.cashierName,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    return Sale(
      saleId: int.parse(json['sale_id'].toString()),
      saleNumber: json['sale_number'],
      saleDate: DateTime.parse(json['sale_date']),
      items: [], // Items are fetched separately
      totalAmount: double.parse(json['subtotal'].toString()),
      amountPaid: double.parse(json['amount_paid'].toString()),
      changeAmount: double.parse(json['change_amount'].toString()),
      cashierId: int.parse(json['cashier_id'].toString()),
      cashierName: json['cashier_name'],
    );
  }

  operator [](String other) {}
}