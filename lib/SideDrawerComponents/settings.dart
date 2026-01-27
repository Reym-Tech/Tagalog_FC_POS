import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Components/drawerComponents.dart';
import '../../providers/product_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/product.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productPriceController = TextEditingController();
  final TextEditingController _productDescController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();

  bool _showAddCategory = false;
  String _selectedCategory = '';
  List<String> _categories = [];
  String? _editingProductId;
  Product? _editingProduct;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProductsAndCategories();
    });
  }

  Future<void> _loadProductsAndCategories() async {
    try {
      final provider = Provider.of<ProductProvider>(context, listen: false);
      await provider.loadProducts(); // CHANGED FROM fetchProducts() TO loadProducts()

      // Extract unique categories from products
      final products = provider.products;
      final Set<String> uniqueCategories = {};

      for (var product in products) {
        if (product.productCategory.isNotEmpty) {
          uniqueCategories.add(product.productCategory);
        }
      }

      setState(() {
        _categories = uniqueCategories.toList();
        if (_categories.isNotEmpty && _selectedCategory.isEmpty) {
          _selectedCategory = _categories.first;
        }
      });
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  void _clearForm() {
    _productNameController.clear();
    _productPriceController.clear();
    _productDescController.clear();
    _newCategoryController.clear();
    _showAddCategory = false;
    _editingProductId = null;
    _editingProduct = null;
    _isSaving = false;
    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.first;
    }
    setState(() {});
  }

  // Check if product already exists
  bool _productExists(String productName) {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    return productProvider.products.any((product) =>
    product.productName.toLowerCase() == productName.toLowerCase() &&
        product.productId != _editingProductId);
  }

  Future<void> _saveProduct() async {
    if (_isSaving) return; // Prevent multiple clicks

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final productProvider = Provider.of<ProductProvider>(context, listen: false);

    if (!authProvider.isLoggedIn) { // CHANGED FROM userData['is_logged_in']
      _showErrorSnackbar('Please login first');
      return;
    }

    final productName = _productNameController.text.trim();
    final productDescription = _productDescController.text.trim();
    final priceText = _productPriceController.text.trim();
    final category = _showAddCategory
        ? _newCategoryController.text.trim()
        : _selectedCategory;

    // Validation
    if (productName.isEmpty || priceText.isEmpty) {
      _showErrorSnackbar('Please fill all required fields');
      return;
    }

    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      _showErrorSnackbar('Please enter a valid price');
      return;
    }

    if (category.isEmpty) {
      _showErrorSnackbar('Please select or enter a category');
      return;
    }

    // Check if product already exists (only for new products, not for editing)
    if (_editingProduct == null && _productExists(productName)) {
      _showProductExistsDialog(productName);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (_editingProduct != null) {
        // Update existing product
        final updatedProduct = _editingProduct!.copyWith(
          productName: productName,
          productDescription: productDescription,
          productPrice: price,
          productCategory: category,
        );

        final success = await productProvider.updateProduct(updatedProduct);

        if (success) {
          _showSuccessSnackbar('Product updated successfully!');
          _clearForm();
          await _loadProductsAndCategories();
        } else {
          _showErrorSnackbar('Failed to update product: ${productProvider.errorMessage}');
        }
      } else {
        // Add new product
        final success = await productProvider.addProduct(
          productName: productName,
          productDescription: productDescription,
          productPrice: price,
          productCategory: category,
        );

        if (success) {
          _showSuccessSnackbar('Product added successfully!');

          // Add new category to list if it doesn't exist
          if (_showAddCategory && !_categories.contains(category)) {
            setState(() {
              _categories.add(category);
              _selectedCategory = category;
            });
          }

          _clearForm();
          await _loadProductsAndCategories();
        } else {
          _showErrorSnackbar('Failed to add product: ${productProvider.errorMessage}');
        }
      }
    } catch (e) {
      print('Error saving product: $e');
      _showErrorSnackbar('Error: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showProductExistsDialog(String productName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Already Exists'),
        content: Text('A product named "$productName" already exists. Please use a different name.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _editProduct(String productId) {
    final productProvider = Provider.of<ProductProvider>(context, listen: false);
    final product = productProvider.products.firstWhere(
          (p) => p.productId == productId,
    );

    setState(() {
      _editingProduct = product;
      _editingProductId = productId;
      _productNameController.text = product.productName;
      _productDescController.text = product.productDescription;
      _productPriceController.text = product.productPrice.toString();
      _selectedCategory = product.productCategory;

      if (!_categories.contains(product.productCategory)) {
        _categories.add(product.productCategory);
      }
    });

    // Scroll to form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(context);
    });
  }

  Future<void> _deleteProduct(String productId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final productProvider = Provider.of<ProductProvider>(context, listen: false);
      final success = await productProvider.deleteProduct(productId);

      if (success) {
        _showSuccessSnackbar('Product deleted successfully!');
        await _loadProductsAndCategories();
      } else {
        _showErrorSnackbar('Failed to delete product: ${productProvider.errorMessage}');
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildLoginRequiredSection(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 60,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 20),
          Text(
            'Login Required',
            style: TextStyle(
              fontSize: isMobile ? 22 : 26,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Please login to access product management features',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedSection(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange[100]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: 60,
            color: Colors.orange[400],
          ),
          const SizedBox(height: 20),
          Text(
            'Admin Access Required',
            style: TextStyle(
              fontSize: isMobile ? 22 : 26,
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Product management is restricted to administrators only',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              color: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductFormSection(bool isMobile) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _editingProduct != null ? 'Edit Product' : 'Add New Product',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                if (_editingProduct != null)
                  IconButton(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.close),
                    tooltip: 'Cancel Editing',
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Product Name
            _buildFormField(
              label: 'Product Name *',
              hint: 'Enter product name',
              controller: _productNameController,
              icon: Icons.shopping_bag,
              isMobile: isMobile,
            ),

            const SizedBox(height: 15),

            // Product Price
            _buildFormField(
              label: 'Product Price *',
              hint: 'Enter price (e.g., 29.99)',
              controller: _productPriceController,
              icon: Icons.attach_money,
              keyboardType: TextInputType.number,
              isMobile: isMobile,
            ),

            const SizedBox(height: 15),

            // Product Description
            _buildFormField(
              label: 'Description',
              hint: 'Enter product description',
              controller: _productDescController,
              icon: Icons.description,
              maxLines: 3,
              isMobile: isMobile,
            ),

            const SizedBox(height: 15),

            // Category Selection
            Row(
              children: [
                Icon(Icons.category, color: Colors.grey[600]),
                const SizedBox(width: 10),
                Text(
                  'Category',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (!_showAddCategory)
              DropdownButtonFormField<String>(
                value: _selectedCategory.isEmpty && _categories.isNotEmpty
                    ? _categories.first
                    : _selectedCategory,
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  hintText: 'Select Category',
                  prefixIcon: const Icon(Icons.arrow_drop_down),
                ),
              ),

            if (_showAddCategory)
              _buildFormField(
                label: 'New Category',
                hint: 'Enter new category name',
                controller: _newCategoryController,
                icon: Icons.add_circle,
                isMobile: isMobile,
              ),

            const SizedBox(height: 10),

            // Toggle between select and add category
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAddCategory = !_showAddCategory;
                      if (_showAddCategory) {
                        _newCategoryController.clear();
                      }
                    });
                  },
                  child: Text(
                    _showAddCategory
                        ? 'Select Existing Category'
                        : 'Create New Category',
                    style: const TextStyle(color: Colors.blue),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Save/Cancel Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_editingProduct != null)
                  OutlinedButton(
                    onPressed: _clearForm,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 20 : 30,
                        vertical: 15,
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _editingProduct != null
                        ? Colors.orange
                        : Colors.green,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 20 : 30,
                      vertical: 15,
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _editingProduct != null
                            ? Icons.save
                            : Icons.add,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _editingProduct != null ? 'Update' : 'Add Product',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool isMobile = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey[600]),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            hintText: hint,
          ),
        ),
      ],
    );
  }

  Widget _buildProductsList(ProductProvider productProvider, bool isMobile) {
    if (productProvider.products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 20),
            Text(
              'No Products Found',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add your first product using the form above',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage Products',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            if (isMobile)
              _buildMobileProductsList(productProvider)
            else
              _buildDesktopProductsTable(productProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileProductsList(ProductProvider productProvider) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: productProvider.products.length,
      itemBuilder: (context, index) {
        final product = productProvider.products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        product.productName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.productCategory,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  product.productDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₱${product.productPrice.toStringAsFixed(2)}', // CHANGED FROM $ TO ₱
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _editProduct(product.productId),
                          icon: const Icon(Icons.edit, color: Colors.blue),
                        ),
                        IconButton(
                          onPressed: () => _deleteProduct(product.productId),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDesktopProductsTable(ProductProvider productProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('ID')),
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Description')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Price'), numeric: true),
          DataColumn(label: Text('Actions')),
        ],
        rows: productProvider.products.map((product) {
          return DataRow(
            cells: [
              DataCell(Text(product.productId.substring(0, 8))), // Show first 8 chars of UUID
              DataCell(Text(product.productName)),
              DataCell(
                SizedBox(
                  width: 200,
                  child: Text(
                    product.productDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text(product.productCategory)),
              DataCell(Text(
                '₱${product.productPrice.toStringAsFixed(2)}', // CHANGED FROM $ TO ₱
                style: const TextStyle(fontWeight: FontWeight.bold),
              )),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _editProduct(product.productId),
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Edit',
                    ),
                    IconButton(
                      onPressed: () => _deleteProduct(product.productId),
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Delete',
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final authProvider = Provider.of<AuthProvider>(context);
    final productProvider = Provider.of<ProductProvider>(context);
    final isAdmin = authProvider.isAdmin; // CHANGED FROM userData['role']
    final isLoggedIn = authProvider.isLoggedIn; // CHANGED FROM userData['is_logged_in']

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red[700],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: isMobile ? drawerWidget(context) : null,
      body: Row(
        children: [
          // Sidebar for desktop/tablet
          if (!isMobile) drawerWidget(context),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Product Management',
                    style: TextStyle(
                      fontSize: isMobile ? 28 : 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Manage products and categories',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      color: Colors.grey[600],
                    ),
                  ),

                  // Info Section
                  Container(
                    margin: const EdgeInsets.only(top: 20, bottom: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.blue[100]!),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isAdmin ? Icons.admin_panel_settings : Icons.security,
                          color: Colors.blue[700],
                          size: 30,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAdmin ? 'Admin Mode' : 'User Access',
                                style: TextStyle(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                isAdmin
                                    ? 'You have full access to manage products and categories.'
                                    : isLoggedIn
                                    ? 'Product management is restricted to administrators only.'
                                    : 'Please login to access system settings.',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Show appropriate content based on login and role
                  if (!isLoggedIn)
                    _buildLoginRequiredSection(isMobile)
                  else if (!isAdmin)
                    _buildAccessDeniedSection(isMobile)
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Form
                        _buildProductFormSection(isMobile),

                        const SizedBox(height: 30),

                        // Products List/Table
                        _buildProductsList(productProvider, isMobile),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _productPriceController.dispose();
    _productDescController.dispose();
    _newCategoryController.dispose();
    super.dispose();
  }
}