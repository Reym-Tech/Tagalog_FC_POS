import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../components/drawerComponents.dart';
import '../components/network_status.dart';
import '../providers/sales_providers.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic> _salesSummary = {};
  List<Map<String, dynamic>> _topProducts = [];
  List<Map<String, dynamic>> _recentSales = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);

      // Load sales history
      await saleProvider.loadSalesHistory();

      // Get sales summary
      _salesSummary = await saleProvider.getSalesSummary();

      // Get top products
      _topProducts = await saleProvider.getTopProductsReport();

      // Get recent sales
      _recentSales = saleProvider.salesHistory.take(5).toList();

      print('✅ Dashboard data loaded successfully');
      print('📊 Sales summary: $_salesSummary');
      print('🏆 Top products: ${_topProducts.length}');
      print('📝 Recent sales: ${_recentSales.length}');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

    } catch (e) {
      print('❌ Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load dashboard data: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _syncData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);

      if (authProvider.isOnline) {
        // Sync products
        await productProvider.loadProducts();

        // Sync sales
        await saleProvider.loadSalesHistory();

        // Sync unsynced sales
        await _syncUnsyncedSales();

        // Reload dashboard data
        await _loadDashboardData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot sync: Offline mode'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncUnsyncedSales() async {
    try {
      final saleProvider = Provider.of<SaleProvider>(context, listen: false);
      
      // Since we're now Supabase-only, just refresh the sales history
      await saleProvider.loadSalesHistory();
      
      print('✅ Sales data refreshed successfully');
    } catch (e) {
      print('❌ Error refreshing sales data: $e');
    }
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
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red[700],
        leading: isMobile ? Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ) : null,
        actions: [
          NetworkStatusIndicator(),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: _isLoading ? null : _syncData,
            tooltip: 'Sync Data',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isLoading ? null : _loadDashboardData,
            tooltip: 'Refresh Dashboard',
          ),
          if (authProvider.fullName != null)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  Icon(
                    authProvider.isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    authProvider.fullName!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
      drawer: isMobile ? drawerWidget(context) : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 60),
            const SizedBox(height: 20),
            Text(
              'Error loading dashboard',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: const Text('Try Again'),
            ),
          ],
        ),
      )
          : Row(
        children: [
          if (!isMobile) drawerWidget(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: isMobile ? 28 : 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    authProvider.isOnline
                        ? 'Connected to Supabase (Online Mode)'
                        : 'Using Local Database (Offline Mode)',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      color: Colors.grey[600],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Stats Grid - Sales metrics cards
                  if (isMobile) ...[
                    _buildSalesCard(
                      title: "Today's Sales",
                      icon: Icons.attach_money,
                      value: _formatCurrency((_salesSummary['today']?['revenue'] ?? 0.0).toDouble()),
                      subtitle: "Total Transactions",
                      subtitleValue: (_salesSummary['today']?['sales'] ?? 0).toString(),
                      color: Colors.green,
                      isMobile: true,
                    ),
                    const SizedBox(height: 15),
                    _buildSalesCard(
                      title: "This Week",
                      icon: Icons.trending_up,
                      value: _formatCurrency((_salesSummary['week']?['revenue'] ?? 0.0).toDouble()),
                      subtitle: "Total Transactions",
                      subtitleValue: (_salesSummary['week']?['sales'] ?? 0).toString(),
                      color: Colors.blue,
                      isMobile: true,
                    ),
                    const SizedBox(height: 15),
                    _buildSalesCard(
                      title: "This Month",
                      icon: Icons.calendar_today,
                      value: _formatCurrency((_salesSummary['month']?['revenue'] ?? 0.0).toDouble()),
                      subtitle: "Total Transactions",
                      subtitleValue: (_salesSummary['month']?['sales'] ?? 0).toString(),
                      color: Colors.purple,
                      isMobile: true,
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildSalesCard(
                            title: "Today's Sales",
                            icon: Icons.attach_money,
                            value: _formatCurrency((_salesSummary['today']?['revenue'] ?? 0.0).toDouble()),
                            subtitle: "Total Transactions",
                            subtitleValue: (_salesSummary['today']?['sales'] ?? 0).toString(),
                            color: Colors.green,
                            isMobile: false,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildSalesCard(
                            title: "This Week",
                            icon: Icons.trending_up,
                            value: _formatCurrency((_salesSummary['week']?['revenue'] ?? 0.0).toDouble()),
                            subtitle: "Total Transactions",
                            subtitleValue: (_salesSummary['week']?['sales'] ?? 0).toString(),
                            color: Colors.blue,
                            isMobile: false,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildSalesCard(
                            title: "This Month",
                            icon: Icons.calendar_today,
                            value: _formatCurrency((_salesSummary['month']?['revenue'] ?? 0.0).toDouble()),
                            subtitle: "Total Transactions",
                            subtitleValue: (_salesSummary['month']?['sales'] ?? 0).toString(),
                            color: Colors.purple,
                            isMobile: false,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 30),

                  Divider(
                    color: Colors.grey[300],
                    thickness: 1,
                  ),

                  const SizedBox(height: 30),

                  // Best Selling Products Section
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
                              'Top Selling Products',
                              style: TextStyle(
                                fontSize: isMobile ? 20 : 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[900],
                              ),
                            ),
                            if (_topProducts.isNotEmpty)
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/sales');
                                },
                                child: const Row(
                                  children: [
                                    Text('View Sales History'),
                                    SizedBox(width: 5),
                                    Icon(Icons.arrow_forward, size: 16),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        if (_topProducts.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inventory,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  'No sales data yet',
                                  style: TextStyle(
                                    fontSize: isMobile ? 16 : 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/pos');
                                  },
                                  child: const Text('Start Selling'),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: _topProducts.take(5).map((product) {
                              return _buildTopProductItem(product, isMobile);
                            }).toList(),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Recent Sales Activity
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
                          'Recent Sales Activity',
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Last 5 transactions',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            color: Colors.grey[600],
                          ),
                        ),

                        const SizedBox(height: 20),

                        if (_recentSales.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 50,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  'No recent transactions',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/pos');
                                  },
                                  child: const Text('Start Selling'),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: _recentSales.map((sale) {
                              return _buildRecentSaleItem(sale, isMobile);
                            }).toList(),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Status Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: authProvider.isOnline ? Colors.green[50] : Colors.blue[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: authProvider.isOnline ? Colors.green[200]! : Colors.blue[200]!
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          authProvider.isOnline ? Icons.cloud_done : Icons.cloud_off,
                          color: authProvider.isOnline ? Colors.green[700] : Colors.blue[700],
                          size: 30,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authProvider.isOnline ? 'Online Mode' : 'Offline Mode',
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: authProvider.isOnline ? Colors.green[900] : Colors.blue[900],
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                authProvider.isOnline
                                    ? 'Data is synced with cloud database. All changes are saved online.'
                                    : 'Data is stored locally. Changes will sync when back online.',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: authProvider.isOnline ? Colors.green[800] : Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/pos');
                          },
                          icon: Icon(
                            Icons.arrow_forward,
                            color: authProvider.isOnline ? Colors.green[700] : Colors.blue[700],
                          ),
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

  Widget _buildTopProductItem(Map<String, dynamic> product, bool isMobile) {
    try {
      final productName = product['product_name']?.toString() ?? 'Unknown';
      final category = product['product_category']?.toString() ?? '';
      final quantitySold = product['total_quantity']?.toString() ?? product['total_quantity_sold']?.toString() ?? '0';
      final revenue = product['total_revenue'] != null
          ? _formatCurrency(double.tryParse(product['total_revenue'].toString()) ?? 0.0)
          : '₱0.00';

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.fastfood,
                color: Colors.red[700],
                size: isMobile ? 20 : 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$quantitySold sold',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  revenue,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error building product item: $e');
      return Container();
    }
  }

  Widget _buildRecentSaleItem(Map<String, dynamic> sale, bool isMobile) {
    try {
      final transactionNumber = sale['transaction_number']?.toString() ?? 'N/A';
      final saleDate = sale['created_at']?.toString() ?? '';
      final totalAmount = double.tryParse(sale['total_amount']?.toString() ?? '0') ?? 0.0;
      
      // Get user info from nested user object (same pattern as sales history)
      final user = sale['user'] as Map<String, dynamic>?;
      final cashierName = user?['full_name']?.toString() ?? 'Unknown Cashier';
      final userName = user?['username']?.toString() ?? '';

      String formattedDate = saleDate;
      try {
        final date = DateTime.parse(saleDate);
        formattedDate = DateFormat('MMM dd, hh:mm a').format(date);
      } catch (e) {
        formattedDate = saleDate;
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.receipt,
                color: Colors.green[700],
                size: isMobile ? 20 : 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transactionNumber,
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'By: $cashierName${userName.isNotEmpty ? ' (@$userName)' : ''}',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatCurrency(totalAmount),
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Error building recent sale item: $e');
      return Container();
    }
  }

  Widget _buildSalesCard({
    required String title,
    required IconData icon,
    required String value,
    required String subtitle,
    required String subtitleValue,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 25),
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
                title,
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  color: Colors.grey[700],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 28 : 36,
              fontWeight: FontWeight.bold,
              color: Colors.grey[900],
            ),
          ),

          const SizedBox(height: 20),

          Divider(
            color: Colors.grey[200],
            height: 1,
          ),

          const SizedBox(height: 15),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                subtitleValue,
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[900],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}