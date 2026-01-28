import 'package:flutter/material.dart';
// import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../components/drawerComponents.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../models/product.dart';
import '../models/sale_item.dart';
import '../providers/sales_providers.dart';
import '../services/supabase_service.dart';
import '../services/receipt_service.dart';

class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final TextEditingController _paymentController = TextEditingController();
  bool _isProcessing = false;
  String _errorMessage = '';
  bool _showReceiptDialog = false;
  Map<String, dynamic>? _lastSaleResult;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<ProductProvider>(context, listen: false).loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final productProvider = Provider.of<ProductProvider>(context);
    final saleProvider = Provider.of<SaleProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.isAdmin;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'POS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.red[700],
        leading: isMobile ? Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ) : null,
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(context, '/settings');
              },
              tooltip: 'Add Product',
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              Provider.of<ProductProvider>(context, listen: false).loadProducts();
            },
            tooltip: 'Refresh Products',
          ),
        ],
      ),
      drawer: isMobile ? drawerWidget(context) : null,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile) drawerWidget(context),

              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _buildProductsGrid(isMobile, productProvider, saleProvider, authProvider),
                    ),
                    _buildOrderSummary(context, saleProvider, isMobile),
                  ],
                ),
              ),

              if (!isMobile) _buildOrderCartSidebar(context, saleProvider),
            ],
          ),

          // Receipt dialog overlay
          if (_showReceiptDialog)
            _buildReceiptOverlay(context, saleProvider),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(bool isMobile, ProductProvider productProvider, SaleProvider saleProvider, AuthProvider authProvider) {
    if (productProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (productProvider.getActiveProducts().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory, size: 60, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              'No products available',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            if (authProvider.isAdmin)
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
                child: const Text('Add Products'),
              )
            else
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
                },
                child: const Text('View'),
              ),
          ],
        ),
      );
    }

    final categories = productProvider.getCategories();

    return DefaultTabController(
      length: categories.length,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              tabs: categories.map((category) => Tab(text: category)).toList(),
              labelColor: Colors.red[700],
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: Colors.red[700],
              indicatorSize: TabBarIndicatorSize.tab,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
          Expanded(
            child: TabBarView(
              children: categories.map((category) {
                final categoryProducts = productProvider.getActiveProductsByCategory(category);

                return GridView.builder(
                  padding: const EdgeInsets.all(15.0),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 2 : 3,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: categoryProducts.length,
                  itemBuilder: (context, index) {
                    return _buildProductCard(categoryProducts[index], saleProvider, isMobile);
                  },
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product, SaleProvider saleProvider, bool isMobile) {
    // Find the actual cart item, or null if not in cart
    final cartItem = saleProvider.cartItems.where(
          (item) => item.productId == product.productId,
    ).isNotEmpty 
        ? saleProvider.cartItems.firstWhere((item) => item.productId == product.productId)
        : null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Header with product name and availability toggle
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    product.productName,
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: product.isAvailable ? Colors.grey[900] : Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Availability toggle for all users
                Consumer<ProductProvider>(
                  builder: (context, productProvider, child) {
                    return GestureDetector(
                      onTap: () async {
                        final success = await productProvider.toggleProductAvailability(
                          product.productId, 
                          !product.isAvailable
                        );
                        if (success) {
                          // If product becomes unavailable, remove it from cart
                          if (!product.isAvailable) {
                            saleProvider.removeFromCart(product.productId);
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(productProvider.errorMessage),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: product.isAvailable ? Colors.green[100] : Colors.red[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          product.isAvailable ? Icons.check_circle : Icons.cancel,
                          size: 16,
                          color: product.isAvailable ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Availability status badge
            if (!product.isAvailable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'OUT OF STOCK',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ),

            if (!product.isAvailable) const SizedBox(height: 8),

            Expanded(
              child: Text(
                product.productDescription,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: product.isAvailable ? Colors.grey[600] : Colors.grey[400],
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '₱${product.productPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: product.isAvailable ? Colors.red[700] : Colors.grey[400],
                      ),
                    ),
                    Text(
                      product.productCategory,
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),

                // Add/Minus buttons - disabled if not available
                if (cartItem != null && cartItem.quantity > 0)
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: product.isAvailable ? Colors.red[50] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            onPressed: product.isAvailable ? () {
                              if (cartItem!.quantity > 1) {
                                saleProvider.updateQuantity(product.productId, cartItem.quantity - 1);
                              } else {
                                saleProvider.removeFromCart(product.productId);
                              }
                            } : null,
                            icon: const Icon(Icons.remove, size: 16),
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                          ),
                        ),
                        Container(
                          width: 28,
                          alignment: Alignment.center,
                          child: Text(
                            cartItem!.quantity.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: product.isAvailable ? Colors.black : Colors.grey[500],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: IconButton(
                            onPressed: product.isAvailable ? () {
                              saleProvider.updateQuantity(product.productId, cartItem!.quantity + 1);
                            } : null,
                            icon: const Icon(Icons.add, size: 16),
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: product.isAvailable ? () {
                        saleProvider.addToCart(SaleItem(
                          productId: product.productId,
                          productName: product.productName,
                          productCategory: product.productCategory,
                          productPrice: product.productPrice,
                          quantity: 1,
                        ));
                      } : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: product.isAvailable ? Colors.red[700] : Colors.grey[400],
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        minimumSize: Size.zero,
                      ),
                      child: Text(
                        product.isAvailable ? 'ADD' : 'OUT',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(BuildContext context, SaleProvider saleProvider, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total Items: ${saleProvider.cartItems.fold(0, (sum, item) => sum + item.quantity)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Total: ₱${saleProvider.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[900],
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: saleProvider.cartItems.isNotEmpty ? () => _showCheckoutDialog(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text(
              'CHECKOUT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCartSidebar(BuildContext context, SaleProvider saleProvider) {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_cart, color: Colors.red[700]),
                const SizedBox(width: 10),
                Text(
                  'Order Cart',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
                const Spacer(),
                if (saleProvider.cartItems.isNotEmpty)
                  IconButton(
                    onPressed: () => _clearCartConfirmation(context),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Clear Cart',
                  ),
                Text(
                  '₱${saleProvider.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: saleProvider.cartItems.isEmpty
                ? _buildEmptyCartMessage()
                : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: saleProvider.cartItems.length,
              itemBuilder: (context, index) {
                return _buildCartItem(saleProvider.cartItems[index], saleProvider);
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: saleProvider.cartItems.isNotEmpty ? () => _showCheckoutDialog(context) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    'PROCEED TO PAYMENT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Add items to start an order',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(SaleItem item, SaleProvider saleProvider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.fastfood, color: Colors.red[700], size: 20),
        ),
        title: Text(
          item.productName,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text('₱${item.productPrice.toStringAsFixed(2)} each'),
        trailing: Container(
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: () {
                    if (item.quantity > 1) {
                      saleProvider.updateQuantity(item.productId, item.quantity - 1);
                    } else {
                      saleProvider.removeFromCart(item.productId);
                    }
                  },
                  icon: const Icon(Icons.remove, size: 14),
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                ),
              ),
              Container(
                width: 24,
                alignment: Alignment.center,
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  onPressed: () {
                    saleProvider.updateQuantity(item.productId, item.quantity + 1);
                  },
                  icon: const Icon(Icons.add, size: 14),
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearCartConfirmation(BuildContext context) {
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to clear all items from the cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              saleProvider.clearCart();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context) {
    final saleProvider = Provider.of<SaleProvider>(context, listen: false);

    _paymentController.clear();
    saleProvider.updatePayment(0.0);
    _lastSaleResult = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Center(child: Text('Checkout Summary')),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      ...saleProvider.cartItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Quantity: ${item.quantity}',
                                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                                  ),
                                  Text(
                                    '₱${item.subtotal.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16, color: Colors.grey),
                            ],
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Total Amount:',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '₱${saleProvider.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: _paymentController,
                        decoration: InputDecoration(
                          labelText: 'Amount Paid (₱)',
                          hintText: 'Enter payment amount',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          prefixIcon: const Text('₱', style: TextStyle(fontSize: 16)),
                          prefixIconConstraints: const BoxConstraints(minWidth: 36),
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        style: const TextStyle(fontSize: 16),
                        onChanged: (value) {
                          final amount = double.tryParse(value) ?? 0.0;
                          saleProvider.updatePayment(amount);
                          setState(() {
                            _errorMessage = '';
                          });
                        },
                      ),

                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: saleProvider.changeAmount >= 0 ? Colors.green[50] : Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: saleProvider.changeAmount >= 0 ? Colors.green : Colors.red,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Change:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              '₱${saleProvider.changeAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: saleProvider.changeAmount >= 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (saleProvider.changeAmount < 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Insufficient payment! Please enter more amount.',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),

                      if (_errorMessage.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                    _paymentController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                    final paymentAmount = double.tryParse(_paymentController.text) ?? 0.0;

                    if (paymentAmount <= 0) {
                      setState(() {
                        _errorMessage = 'Please enter payment amount';
                      });
                      return;
                    }

                    // Update the payment amount in the provider BEFORE processing
                    saleProvider.updatePayment(paymentAmount);

                    if (saleProvider.changeAmount < 0) {
                      setState(() {
                        _errorMessage = 'Payment amount is insufficient';
                      });
                      return;
                    }

                    setState(() {
                      _isProcessing = true;
                      _errorMessage = '';
                    });

                    try {
                      final result = await saleProvider.processSale();
                      _lastSaleResult = result;

                      print('🔄 Sale result: ${result['success']} - ${result['message']}');

                      setState(() {
                        _isProcessing = false;
                      });

                      Navigator.pop(context);

                      if (result['success'] == true) {
                        // Show receipt for successful sales
                        setState(() {
                          _showReceiptDialog = true;
                        });

                        // Auto-hide receipt after 10 seconds
                        Future.delayed(const Duration(seconds: 10), () {
                          if (mounted) {
                            setState(() {
                              _showReceiptDialog = false;
                            });
                          }
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Sale completed!'),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 3),
                          ),
                        );

                        _paymentController.clear();
                      } else {
                        // Show error message for failed sales
                        setState(() {
                          _errorMessage = result['message'] ?? 'Failed to process sale';
                        });
                      }
                    } catch (e) {
                      print('❌ Exception in checkout: $e');
                      setState(() {
                        _errorMessage = 'Error: ${e.toString()}';
                        _isProcessing = false;
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text('Confirm Payment'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReceiptOverlay(BuildContext context, SaleProvider saleProvider) {
    final now = DateTime.now();
    final saleResult = _lastSaleResult;
    
    // Use data from the sale result instead of current cart state
    final saleNumber = saleResult?['sale_number'] ?? 'TXN${now.millisecondsSinceEpoch}'.substring(0, 10);
    final totalAmount = saleResult?['total_amount']?.toDouble() ?? saleProvider.totalAmount;
    final paymentAmount = saleResult?['amount_paid']?.toDouble() ?? saleProvider.amountPaid;
    final changeAmount = saleResult?['change_amount']?.toDouble() ?? (paymentAmount - totalAmount);
    
    // Get items from the sale result or fallback to current cart
    final items = saleResult?['items'] ?? saleProvider.cartItems;

    final isSuccess = _lastSaleResult?['success'] == true;
    final saleMessage = _lastSaleResult?['message'] ?? 'Payment Processed';

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: isMobile ? screenWidth * 0.95 : screenWidth * 0.8,
              margin: const EdgeInsets.all(20),
              constraints: BoxConstraints(
                maxWidth: isMobile ? 400 : 500,
                maxHeight: screenHeight * 0.9,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      color: isSuccess ? Colors.green[700] : Colors.orange[700],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSuccess ? Icons.check_circle : Icons.warning,
                          color: Colors.white,
                          size: isMobile ? 24 : 30,
                        ),
                        SizedBox(width: isMobile ? 8 : 10),
                        Expanded(
                          child: Text(
                            isSuccess ? 'Payment Successful!' : 'Payment Processed',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _showReceiptDialog = false;
                              saleProvider.clearCart();
                            });
                          },
                          icon: const Icon(Icons.close, color: Colors.white),
                          padding: EdgeInsets.zero,
                          iconSize: isMobile ? 20 : 24,
                        ),
                      ],
                    ),
                  ),

                  // Status message if not successful
                  if (!isSuccess)
                    Container(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border(bottom: BorderSide(color: Colors.orange[200]!)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange[700], size: isMobile ? 16 : 18),
                          SizedBox(width: isMobile ? 8 : 10),
                          Expanded(
                            child: Text(
                              saleMessage,
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                color: Colors.orange[900],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Receipt content
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sale info
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Sale #$saleNumber',
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy hh:mm a').format(now),
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: isMobile ? 12 : 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Consumer<AuthProvider>(
                                builder: (context, authProvider, child) {
                                  final cashierName = authProvider.fullName ?? authProvider.username ?? 'Cashier';
                                  return Text(
                                    'Cashier: $cashierName',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: isMobile ? 11 : 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isMobile ? 16 : 20),
                        const Divider(),

                        // Items list
                        if (items != null && items.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Items Purchased:',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: isMobile ? 8 : 10),

                              ...items.map((item) {
                                // Handle both SaleItem objects and Map data
                                final productName = item is Map ? item['productName'] : item.productName;
                                final quantity = item is Map ? item['quantity'] : item.quantity;
                                final productPrice = item is Map ? item['productPrice'] : item.productPrice;
                                final subtotal = item is Map ? item['subtotal'] : item.subtotal;
                                
                                return Padding(
                                  padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              productName.toString(),
                                              style: TextStyle(
                                                fontSize: isMobile ? 13 : 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              '${quantity} x ₱${(productPrice as num).toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: isMobile ? 11 : 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: isMobile ? 8 : 10),
                                      Text(
                                        '₱${(subtotal as num).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: isMobile ? 13 : 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          )
                        else
                          Container(
                            padding: EdgeInsets.all(isMobile ? 20 : 24),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: isMobile ? 40 : 48,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: isMobile ? 8 : 12),
                                Text(
                                  'No items in receipt',
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const Divider(),
                        SizedBox(height: isMobile ? 8 : 10),

                        // Totals
                        _buildReceiptTotalRow('Subtotal:', '₱${totalAmount.toStringAsFixed(2)}', isMobile),
                        _buildReceiptTotalRow('Paid:', '₱${paymentAmount.toStringAsFixed(2)}', isMobile),
                        _buildReceiptTotalRow(
                          'Change:',
                          '₱${changeAmount.toStringAsFixed(2)}',
                          isMobile,
                          color: changeAmount >= 0 ? Colors.green[700] : Colors.red[700],
                        ),

                        SizedBox(height: isMobile ? 16 : 20),

                        // Thank you message
                        Container(
                          padding: EdgeInsets.all(isMobile ? 10 : 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Thank you for your purchase!',
                                style: TextStyle(
                                  fontSize: isMobile ? 13 : 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: isMobile ? 2 : 4),
                              Text(
                                isSuccess ? 'Please come again' : 'Please check with staff if needed',
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Action buttons
                  Padding(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // Get cashier information from AuthProvider
                              final authProvider = Provider.of<AuthProvider>(context, listen: false);
                              final cashierName = authProvider.fullName ?? authProvider.username ?? 'Cashier';
                              
                              await ReceiptService.printReceipt(
                                saleNumber: saleNumber,
                                totalAmount: totalAmount,
                                amountPaid: paymentAmount,
                                changeAmount: changeAmount,
                                items: items ?? [],
                                timestamp: now,
                                context: context,
                                cashierName: cashierName,
                              );
                            },
                            icon: Icon(Icons.print, size: isMobile ? 18 : 20),
                            label: Text(
                              'Print Receipt',
                              style: TextStyle(fontSize: isMobile ? 14 : 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isMobile ? 8 : 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _showReceiptDialog = false;
                                saleProvider.clearCart();
                                _lastSaleResult = null;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Done',
                              style: TextStyle(fontSize: isMobile ? 14 : 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptTotalRow(String label, String value, bool isMobile, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}