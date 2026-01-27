import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ReceiptService {
  static Future<void> printReceipt({
    required String saleNumber,
    required double totalAmount,
    required double amountPaid,
    required double changeAmount,
    required List<dynamic> items,
    required DateTime timestamp,
    required BuildContext context,
    String? cashierName,
  }) async {
    try {
      // For now, we'll show a dialog with print options
      await _showPrintDialog(
        context: context,
        saleNumber: saleNumber,
        totalAmount: totalAmount,
        amountPaid: amountPaid,
        changeAmount: changeAmount,
        items: items,
        timestamp: timestamp,
        cashierName: cashierName,
      );
    } catch (e) {
      print('❌ Error printing receipt: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing receipt: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> _showPrintDialog({
    required BuildContext context,
    required String saleNumber,
    required double totalAmount,
    required double amountPaid,
    required double changeAmount,
    required List<dynamic> items,
    required DateTime timestamp,
    String? cashierName,
  }) async {
    final receiptText = _generateReceiptText(
      saleNumber: saleNumber,
      totalAmount: totalAmount,
      amountPaid: amountPaid,
      changeAmount: changeAmount,
      items: items,
      timestamp: timestamp,
      cashierName: cashierName,
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.print, color: Colors.blue),
            SizedBox(width: 8),
            Text('Print Receipt'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a print option:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // Copy to clipboard option
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.green),
                title: const Text('Copy to Clipboard'),
                subtitle: const Text('Copy receipt text to share or print elsewhere'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: receiptText));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Receipt copied to clipboard!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
              
              const Divider(),
              
              // View receipt text option
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.blue),
                title: const Text('View Receipt Text'),
                subtitle: const Text('View the formatted receipt text'),
                onTap: () {
                  Navigator.pop(context);
                  _showReceiptTextDialog(context, receiptText);
                },
              ),
              
              const Divider(),
              
              // Future: Connect to printer option (disabled for now)
              ListTile(
                leading: Icon(Icons.print_disabled, color: Colors.grey[400]),
                title: Text(
                  'Print to Printer',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                subtitle: Text(
                  'Coming soon - Connect to thermal printer',
                  style: TextStyle(color: Colors.grey[500]),
                ),
                enabled: false,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  static void _showReceiptTextDialog(BuildContext context, String receiptText) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Receipt Text'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                receiptText,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: receiptText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Receipt copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _generateReceiptText({
    required String saleNumber,
    required double totalAmount,
    required double amountPaid,
    required double changeAmount,
    required List<dynamic> items,
    required DateTime timestamp,
    String? cashierName,
  }) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('================================');
    buffer.writeln('       TAGALOG FRIED CHICKEN');
    buffer.writeln('================================');
    buffer.writeln();
    buffer.writeln('Sale #: $saleNumber');
    buffer.writeln('Date: ${DateFormat('MMM dd, yyyy HH:mm:ss').format(timestamp)}');
    if (cashierName != null && cashierName.isNotEmpty) {
      buffer.writeln('Cashier: $cashierName');
    }
    buffer.writeln();
    buffer.writeln('--------------------------------');
    buffer.writeln('ITEMS:');
    buffer.writeln('--------------------------------');
    
    // Items
    for (var item in items) {
      final productName = item is Map ? item['productName'] : item.productName;
      final quantity = item is Map ? item['quantity'] : item.quantity;
      final productPrice = item is Map ? item['productPrice'] : item.productPrice;
      final subtotal = item is Map ? item['subtotal'] : item.subtotal;
      
      buffer.writeln('${productName.toString()}');
      buffer.writeln('  ${quantity}x ₱${(productPrice as num).toStringAsFixed(2)} = ₱${(subtotal as num).toStringAsFixed(2)}');
      buffer.writeln();
    }
    
    // Totals
    buffer.writeln('--------------------------------');
    buffer.writeln('SUBTOTAL:        ₱${totalAmount.toStringAsFixed(2)}');
    buffer.writeln('AMOUNT PAID:     ₱${amountPaid.toStringAsFixed(2)}');
    buffer.writeln('CHANGE:          ₱${changeAmount.toStringAsFixed(2)}');
    buffer.writeln('--------------------------------');
    buffer.writeln();
    buffer.writeln('     Thank you for your purchase!');
    buffer.writeln('         Please come again');
    buffer.writeln();
    buffer.writeln('================================');
    
    return buffer.toString();
  }
}