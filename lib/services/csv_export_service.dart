import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'shared_prefs_service.dart';

class CsvExportService {
  static Future<void> exportSalesData({
    required BuildContext context,
    required List<Map<String, dynamic>> salesData,
    required String filterPeriod,
  }) async {
    try {
      if (salesData.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No sales data to export')),
        );
        return;
      }

      // Get current user info for better cashier names
      final userData = await SharedPrefsService.getUserData();
      final currentUserName = userData['full_name']?.toString() ?? userData['username']?.toString() ?? 'Admin User';

      final csvData = await _prepareCsvData(salesData, currentUserName);
      final csvString = const ListToCsvConverter().convert(csvData);
      
      await _showExportDialog(
        context: context,
        csvString: csvString,
        filterPeriod: filterPeriod,
        salesCount: salesData.length,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error preparing export: $e')),
      );
    }
  }

  static Future<List<List<dynamic>>> _prepareCsvData(List<Map<String, dynamic>> salesData, String fallbackCashierName) async {
    List<List<dynamic>> csvData = [];

    // Add summary header
    final totalSales = salesData.length;
    final totalRevenue = salesData.fold(0.0, (sum, sale) => sum + _safeToDouble(sale['total_amount']));
    final totalItemsSold = salesData.fold(0, (sum, sale) {
      final items = sale['items'] as List? ?? [];
      return sum + items.fold(0, (itemSum, item) => itemSum + (_safeToInt(item['quantity'])));
    });

    csvData.add(['SALES REPORT SUMMARY']);
    csvData.add(['Generated', DateFormat('MMM dd, HH:mm').format(DateTime.now())]); // Even shorter format
    csvData.add(['Total Sales', totalSales]);
    csvData.add(['Total Revenue', '₱${totalRevenue.toStringAsFixed(2)}']);
    csvData.add(['Total Items Sold', totalItemsSold]);
    csvData.add([]); // Empty row

    // Headers
    csvData.add([
      'Sale Number',
      'Date',
      'Time',
      'Cashier',
      'Items Count',
      'Items Detail',
      'Total Amount',
      'Amount Paid',
      'Change Given',
      'Payment Method'
    ]);

    // Data rows
    for (final sale in salesData) {
      try {
        final dateTime = DateTime.parse(sale['sale_date'] as String);
        final date = DateFormat('yyyy-MM-dd').format(dateTime);
        final time = DateFormat('HH:mm:ss').format(dateTime);

        final items = sale['items'] as List? ?? [];
        final itemsCount = items.length;
        
        // Extract cashier name properly
        String cashierName = fallbackCashierName;
        if (sale.containsKey('cashier_name') && sale['cashier_name'] != null && sale['cashier_name'].toString().isNotEmpty) {
          final salesCashierName = sale['cashier_name'].toString();
          if (salesCashierName != 'Unknown Cashier' && salesCashierName.isNotEmpty) {
            cashierName = salesCashierName;
          }
        } else if (sale.containsKey('user') && sale['user'] != null) {
          final user = sale['user'] as Map<String, dynamic>?;
          final userName = user?['full_name']?.toString() ?? user?['username']?.toString();
          if (userName != null && userName.isNotEmpty) {
            cashierName = userName;
          }
        }
        
        final itemsDetail = items.map<String>((item) {
          final name = item['product_name']?.toString() ?? 'Unknown';
          final quantity = item['quantity']?.toString() ?? '0';
          final price = _safeToDouble(item['product_price']).toStringAsFixed(2);
          final subtotal = _safeToDouble(item['subtotal']).toStringAsFixed(2);
          return '$name x$quantity @₱$price = ₱$subtotal';
        }).join('; ');

        csvData.add([
          sale['sale_number']?.toString() ?? '',
          date,
          time,
          cashierName,
          itemsCount,
          itemsDetail,
          _safeToDouble(sale['total_amount']).toStringAsFixed(2),
          _safeToDouble(sale['amount_paid']).toStringAsFixed(2),
          _safeToDouble(sale['change_amount']).toStringAsFixed(2),
          sale['payment_method']?.toString() ?? 'Cash',
        ]);
      } catch (e) {
        print('Error processing sale for CSV: $e');
        continue;
      }
    }

    return csvData;
  }

  static double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _safeToInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static Future<void> _showExportDialog({
    required BuildContext context,
    required String csvString,
    required String filterPeriod,
    required int salesCount,
  }) async {
    final fileName = 'sales_report_${filterPeriod.toLowerCase()}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download, color: Colors.green),
            SizedBox(width: 8),
            Text('Export Sales Report'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Period: $filterPeriod'),
                    Text('Sales Count: $salesCount'),
                    Text('File Name: $fileName'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Choose export option:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              // Copy to clipboard option
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.blue),
                title: const Text('Copy to Clipboard'),
                subtitle: const Text('Copy CSV data to share or paste elsewhere'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: csvString));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('CSV data copied to clipboard!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),
              
              const Divider(),
              
              // View CSV data option
              ListTile(
                leading: const Icon(Icons.visibility, color: Colors.orange),
                title: const Text('View CSV Data'),
                subtitle: const Text('Preview the CSV content'),
                onTap: () {
                  Navigator.pop(context);
                  _showCsvPreviewDialog(context, csvString, fileName);
                },
              ),
              
              const Divider(),
              
              // Save to device option (if supported)
              ListTile(
                leading: const Icon(Icons.save, color: Colors.green),
                title: const Text('Save to Device'),
                subtitle: const Text('Save CSV file to Downloads folder'),
                onTap: () async {
                  Navigator.pop(context);
                  await _saveToDevice(context, csvString, fileName);
                },
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

  static void _showCsvPreviewDialog(BuildContext context, String csvString, String fileName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('CSV Preview: $fileName'),
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
              child: SelectableText(
                csvString,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV data copied to clipboard!'),
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

  static Future<void> _saveToDevice(BuildContext context, String csvString, String fileName) async {
    try {
      // For mobile platforms, try to save to Downloads
      if (Platform.isAndroid || Platform.isIOS) {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final file = File('${directory.path}/$fileName');
          await file.writeAsString(csvString);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('File saved to: ${file.path}'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => OpenFile.open(file.path),
              ),
            ),
          );
        } else {
          throw Exception('Could not access storage directory');
        }
      } else {
        // For desktop platforms, save to Documents
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(csvString);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved to: ${file.path}'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              onPressed: () => OpenFile.open(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error saving file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save file: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Copy Instead',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV data copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ),
      );
    }
  }
}