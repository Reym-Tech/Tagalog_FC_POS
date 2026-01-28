import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../components/drawerComponents.dart';
import '../providers/sales_providers.dart';
import '../services/csv_export_service.dart';

class SalesHistoryPage extends StatefulWidget {
  const SalesHistoryPage({super.key});

  @override
  State<SalesHistoryPage> createState() => _SalesHistoryPageState();
}

class _SalesHistoryPageState extends State<SalesHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String _selectedFilter = 'Today';
  bool _isLoading = false;
  bool _isExporting = false;
  List<Map<String, dynamic>> _salesData = [];
  Map<String, dynamic> _salesStats = {};

  final List<String> _dateFilters = ['Today', 'This Week', 'This Month', 'All'];

  double _safeToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // Remove currency symbols and commas
      final cleanedValue = value.replaceAll('₱', '').replaceAll(',', '').trim();
      final parsed = double.tryParse(cleanedValue);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSalesData();
    });
  }

  Future<void> _loadSalesData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    await _applyDateFilter(_selectedFilter);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _applyDateFilter(String filter) async {
    if (!mounted) return;

    setState(() => _selectedFilter = filter);

    DateTime startDate;
    DateTime endDate = DateTime.now();

    switch (filter) {
      case 'Today':
        startDate = DateTime(endDate.year, endDate.month, endDate.day);
        break;
      case 'This Week':
        startDate = endDate.subtract(const Duration(days: 7));
        break;
      case 'This Month':
        startDate = DateTime(endDate.year, endDate.month, 1);
        break;
      case 'All':
        startDate = DateTime(2024, 1, 1);
        break;
      default:
        startDate = endDate.subtract(const Duration(days: 30));
    }

    _startDate = startDate;
    _endDate = endDate;

    await _fetchSalesData(startDate, endDate);
  }

  Future<void> _fetchSalesData(DateTime startDate, DateTime endDate) async {
    try {
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);
      await saleProvider.loadSalesHistory();

      final allSales = saleProvider.salesHistory;
      print('DEBUG: Total sales loaded: ${allSales.length}');

      // Filter sales by date range
      final filteredSales = allSales.where((sale) {
        try {
          final saleDateStr = sale['created_at']?.toString() ?? '';
          if (saleDateStr.isEmpty) return false;

          final saleDate = DateTime.parse(saleDateStr);
          final isAfterStart = saleDate.isAfter(startDate.subtract(const Duration(seconds: 1)));
          final isBeforeEnd = saleDate.isBefore(endDate.add(const Duration(days: 1)));

          return isAfterStart && isBeforeEnd;
        } catch (e) {
          print('DEBUG: Error parsing sale date: $e, sale: $sale');
          return false;
        }
      }).toList();

      print('DEBUG: Filtered sales count: ${filteredSales.length}');

      // Process sales data - now each sale has nested sale_items
      final List<Map<String, dynamic>> salesList = [];
      double totalAmount = 0.0;
      int totalItems = 0;

      for (var sale in filteredSales) {
        try {
          final saleId = sale['id']?.toString() ?? '';
          final transactionNumber = sale['transaction_number']?.toString() ?? saleId;
          final saleTotal = _safeToDouble(sale['total_amount']);
          final saleItems = sale['sale_items'] as List<dynamic>? ?? [];
          
          // Get user info
          final user = sale['user'] as Map<String, dynamic>?;
          final cashierName = user?['full_name']?.toString() ?? 'Unknown Cashier';

          // Count total items
          int saleItemsCount = 0;
          for (var item in saleItems) {
            final quantity = item['quantity'] is int ? item['quantity'] as int : 0;
            saleItemsCount += quantity;
          }

          // Create sale record
          final saleRecord = {
            'sale_id': saleId,
            'sale_number': transactionNumber,
            'sale_date': sale['created_at'] ?? '',
            'items': saleItems.map((item) => {
              'product_name': item['product_name']?.toString() ?? 'Unknown',
              'product_price': _safeToDouble(item['product_price']),
              'quantity': item['quantity'] is int ? item['quantity'] as int : 0,
              'subtotal': _safeToDouble(item['total_price']),
            }).toList(),
            'total_amount': saleTotal,
            'amount_paid': _safeToDouble(sale['amount_paid']),
            'change_amount': _safeToDouble(sale['change_amount']),
            'cashier_name': cashierName,
          };

          salesList.add(saleRecord);
          totalAmount += saleTotal;
          totalItems += saleItemsCount;

          print('DEBUG: Processed sale $saleId: $transactionNumber, Total: $saleTotal, Items: $saleItemsCount');
        } catch (e) {
          print('DEBUG: Error processing sale: $e, sale: $sale');
        }
      }

      // Sort by date (newest first)
      salesList.sort((a, b) {
        try {
          final dateA = DateTime.parse(a['sale_date'] as String);
          final dateB = DateTime.parse(b['sale_date'] as String);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      print('DEBUG: Final sales list count: ${salesList.length}');
      print('DEBUG: Total amount: $totalAmount');
      print('DEBUG: Total items: $totalItems');

      if (mounted) {
        setState(() {
          _salesData = salesList;
          _salesStats = {
            'total_amount': totalAmount,
            'total_items': totalItems,
            'total_transactions': salesList.length,
            'average_order': salesList.isNotEmpty ? totalAmount / salesList.length : 0.0,
          };
        });
      }
    } catch (e) {
      print('Error fetching sales: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load sales data: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate ?? DateTime.now() : _endDate ?? DateTime.now(),
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });

      if (_startDate != null && _endDate != null) {
        _selectedFilter = 'Custom';
        await _fetchSalesData(_startDate!, _endDate!);
      }
    }
  }

  Future<void> _exportToCSV() async {
    if (!mounted) return;

    setState(() => _isExporting = true);

    try {
      await CsvExportService.exportSalesData(
        context: context,
        salesData: _salesData,
        filterPeriod: _selectedFilter,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting: $e')),
      );
      print('Export error: $e');
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  List<Map<String, dynamic>> _filterSales(String query) {
    if (query.isEmpty) return _salesData;

    final lowerQuery = query.toLowerCase();
    return _salesData.where((sale) {
      final saleNumber = sale['sale_number']?.toString().toLowerCase() ?? '';
      final cashierName = sale['cashier_name']?.toString().toLowerCase() ?? '';
      final items = sale['items'] as List;
      final hasMatchingItem = items.any((item) {
        final productName = item['product_name']?.toString().toLowerCase() ?? '';
        return productName.contains(lowerQuery);
      });

      return saleNumber.contains(lowerQuery) ||
          cashierName.contains(lowerQuery) ||
          hasMatchingItem;
    }).toList();
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: '₱',
      decimalDigits: 2,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final filteredSales = _filterSales(_searchController.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales History', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red[700],
        leading: isMobile ? Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ) : null,
        actions: [
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            IconButton(
              onPressed: _exportToCSV,
              icon: const Icon(Icons.download, color: Colors.white),
              tooltip: 'Export to CSV',
            ),
          IconButton(
            onPressed: _loadSalesData,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: isMobile ? drawerWidget(context) : null,
      body: Row(
        children: [
          if (!isMobile) drawerWidget(context),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sales History',
                    style: TextStyle(
                      fontSize: isMobile ? 28 : 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Track and review all sales transactions',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      color: Colors.grey[600],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search by sale number, cashier, or product...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Filter Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Filter by Date',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                        ),

                        const SizedBox(height: 20),

                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _dateFilters.map((filter) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: GestureDetector(
                                  onTap: () => _applyDateFilter(filter),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: _selectedFilter == filter ? Colors.red[700] : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _selectedFilter == filter ? Colors.red[700]! : Colors.grey[300]!,
                                      ),
                                    ),
                                    child: Text(
                                      filter,
                                      style: TextStyle(
                                        color: _selectedFilter == filter ? Colors.white : Colors.grey[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Custom Date Range
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Custom Date Range',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectDate(context, true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _startDate != null
                                                  ? DateFormat('MMM dd, yyyy').format(_startDate!)
                                                  : 'Start Date',
                                              style: const TextStyle(color: Colors.grey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: Text('to', style: TextStyle(color: Colors.grey)),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectDate(context, false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.grey[300]!),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _endDate != null
                                                  ? DateFormat('MMM dd, yyyy').format(_endDate!)
                                                  : 'End Date',
                                              style: const TextStyle(color: Colors.grey),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Sales Summary Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Sales Summary',
                              style: TextStyle(
                                fontSize: isMobile ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${filteredSales.length} transactions',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Stats Cards
                        if (isMobile) ...[
                          _buildSalesStatCard(
                            title: 'Total Sales',
                            value: _formatCurrency(_safeToDouble(_salesStats['total_amount'])),
                            icon: Icons.attach_money,
                            color: Colors.green,
                            isMobile: true,
                          ),
                          const SizedBox(height: 15),
                          _buildSalesStatCard(
                            title: 'Average Order',
                            value: _formatCurrency(_safeToDouble(_salesStats['average_order'])),
                            icon: Icons.analytics,
                            color: Colors.blue,
                            isMobile: true,
                          ),
                          const SizedBox(height: 15),
                          _buildSalesStatCard(
                            title: 'Total Items',
                            value: '${_salesStats['total_items'] ?? 0}',
                            icon: Icons.shopping_cart,
                            color: Colors.orange,
                            isMobile: true,
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildSalesStatCard(
                                  title: 'Total Sales',
                                  value: _formatCurrency(_safeToDouble(_salesStats['total_amount'])),
                                  icon: Icons.attach_money,
                                  color: Colors.green,
                                  isMobile: false,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildSalesStatCard(
                                  title: 'Average Order',
                                  value: _formatCurrency(_safeToDouble(_salesStats['average_order'])),
                                  icon: Icons.analytics,
                                  color: Colors.blue,
                                  isMobile: false,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildSalesStatCard(
                                  title: 'Total Items',
                                  value: '${_salesStats['total_items'] ?? 0}',
                                  icon: Icons.shopping_cart,
                                  color: Colors.orange,
                                  isMobile: false,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Sales List Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: filteredSales.isEmpty
                        ? _buildEmptyState(isMobile)
                        : Column(
                      children: [
                        // Table Header
                        Container(
                          padding: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Sale #',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Date & Time',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Cashier',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Total',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),

                        // Sales List
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredSales.length,
                          separatorBuilder: (context, index) => Divider(color: Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final sale = filteredSales[index];
                            String saleDate = sale['sale_date']?.toString() ?? '';
                            DateTime dateTime;

                            try {
                              dateTime = DateTime.parse(saleDate);
                            } catch (e) {
                              dateTime = DateTime.now();
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      sale['sale_number']?.toString() ?? 'N/A',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('MM/dd').format(dateTime),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          DateFormat('hh:mm a').format(dateTime),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      sale['cashier_name']?.toString() ?? 'Cashier',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      _formatCurrency(_safeToDouble(sale['total_amount'])),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _showSaleDetails(context, sale);
                                    },
                                    icon: const Icon(Icons.visibility, color: Colors.blue),
                                    tooltip: 'View Details',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 20),
          Text(
            'No sales found',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start making sales to see transaction history here',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: Colors.grey[400],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/pos');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Go to POS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? 22 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSaleDetails(BuildContext context, Map<String, dynamic> sale) {
    String saleDate = sale['sale_date']?.toString() ?? '';
    DateTime dateTime;

    try {
      dateTime = DateTime.parse(saleDate);
    } catch (e) {
      dateTime = DateTime.now();
    }

    final items = sale['items'] as List;

    // Debug print
    print('DEBUG: Showing details for sale: ${sale['sale_number']}');
    print('DEBUG: Total amount: ${sale['total_amount']}');
    print('DEBUG: Amount paid: ${sale['amount_paid']}');
    print('DEBUG: Change amount: ${sale['change_amount']}');
    print('DEBUG: Items count: ${items.length}');

    // Calculate subtotal from items if needed
    double subtotal = _safeToDouble(sale['total_amount']);
    print('DEBUG: Initial subtotal from sale: $subtotal');

    if (subtotal == 0 && items.isNotEmpty) {
      subtotal = items.fold(0.0, (sum, item) {
        final itemSubtotal = _safeToDouble(item['subtotal']);
        print('DEBUG: Item subtotal: $itemSubtotal');
        return sum + itemSubtotal;
      });
      print('DEBUG: Calculated subtotal from items: $subtotal');
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sale #${sale['sale_number'] ?? 'N/A'}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Sale Number:', sale['sale_number']?.toString() ?? 'N/A'),
              _buildDetailRow('Date:', DateFormat('MMMM dd, yyyy').format(dateTime)),
              _buildDetailRow('Time:', DateFormat('hh:mm a').format(dateTime)),
              _buildDetailRow('Cashier:', sale['cashier_name']?.toString() ?? 'N/A'),
              const SizedBox(height: 16),
              const Divider(),
              const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '• ${item['product_name'] ?? 'Unknown'}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      'x${item['quantity'] ?? 0}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '₱${_safeToDouble(item['product_price']).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '₱${_safeToDouble(item['subtotal']).toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 16),
              const Divider(),
              _buildDetailRow('Subtotal:', _formatCurrency(subtotal)),
              _buildDetailRow('Amount Paid:', _formatCurrency(_safeToDouble(sale['amount_paid']))),
              _buildDetailRow('Change Given:', _formatCurrency(_safeToDouble(sale['change_amount']))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}