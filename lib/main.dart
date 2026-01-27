import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tagalog_fried_chicken2/providers/sales_providers.dart';
import 'providers/auth_provider.dart';
import 'providers/product_provider.dart';
import 'Landing page & Login page/landingpage.dart';
import 'Landing page & Login page/login.dart';
import 'SideDrawerComponents/dashboard.dart';
import 'SideDrawerComponents/logout.dart';
import 'SideDrawerComponents/pos.dart';
import 'SideDrawerComponents/saleshistory.dart';
import 'SideDrawerComponents/settings.dart';
import 'SideDrawerComponents/user_management.dart';
import 'SideDrawerComponents/change_password.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🔄 Initializing app...');

  try {
    // Initialize Supabase service
    final supabaseService = SupabaseService();
    await supabaseService.initialize();
    print('✅ Supabase initialized successfully');

    // Test connection
    final connectionTest = await supabaseService.testConnection();
    if (connectionTest) {
      print('✅ Supabase connection test successful');
    } else {
      print('⚠️ Supabase connection test failed');
    }

  } catch (e) {
    print('❌ Initialization error: $e');
    print('⚠️ App may have limited functionality');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => SaleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tagalog Fried Chicken POS',
      theme: ThemeData(
        primarySwatch: Colors.red,
        appBarTheme: const AppBarTheme(
          color: Color(0xFFB71C1C),
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB71C1C),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
      home: const AppInitializer(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/pos': (context) => const PosPage(),
        '/sales': (context) => const SalesHistoryPage(),
        '/settings': (context) => const SettingsPage(),
        '/user-management': (context) => const UserManagementPage(),
        '/change-password': (context) => const ChangePasswordPage(isForced: true),
        '/logout': (context) => const LogoutPage(),
      },
      builder: EasyLoading.init(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.initialize();

      await Provider.of<ProductProvider>(context, listen: false).loadProducts();
      await Provider.of<SaleProvider>(context, listen: false).loadSalesHistory();

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      print('App initialization error: $e');
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.red[700]),
              const SizedBox(height: 20),
              const Text(
                'Initializing POS System...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Connecting to database...',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return authProvider.isLoggedIn ? const DashboardPage() : const LandingPage();
      },
    );
  }
}