import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../SideDrawerComponents/change_password.dart';

Widget drawerWidget(BuildContext context) {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final userData = authProvider.userData;
  final isLoggedIn = userData['is_logged_in'] ?? false;
  final userRole = userData['role'] ?? '';
  final fullName = userData['full_name'] ?? 'Guest User';

  return Drawer(
    backgroundColor: Colors.white,
    child: Column(
      children: [
        // Drawer Header with Logo and User Info
        Container(
          color: Colors.red[900],
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 15),

              // Logo/Brand
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TAGALOG',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'FRIED CHICKEN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // User Info
              if (isLoggedIn) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          userRole == 'admin'
                              ? Icons.admin_panel_settings
                              : Icons.person,
                          color: Colors.red[900],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              userRole.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person_outline,
                          color: Colors.red[900],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Guest User',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Please login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Dashboard
              ListTile(
                leading: Icon(
                  Icons.dashboard,
                  color: Colors.red[900],
                  size: 24,
                ),
                title: Text(
                  "Dashboard",
                  style: TextStyle(color: Colors.grey[800]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/dashboard');
                },
              ),

              // POS
              ListTile(
                leading: Icon(
                  Icons.point_of_sale,
                  color: Colors.red[900],
                  size: 24,
                ),
                title: Text(
                  "Point of Sale",
                  style: TextStyle(color: Colors.grey[800]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/pos');
                },
              ),

              // Sales History
              ListTile(
                leading: Icon(
                  Icons.history,
                  color: Colors.red[900],
                  size: 24,
                ),
                title: Text(
                  "Sales History",
                  style: TextStyle(color: Colors.grey[800]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/sales');
                },
              ),

              // Settings - Available to all users (with security inside the page)
              ListTile(
                leading: Icon(
                  Icons.settings,
                  color: Colors.red[900],
                  size: 24,
                ),
                title: Text(
                  "Settings",
                  style: TextStyle(color: Colors.grey[800]),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/settings');
                },
              ),

              // Change Password - Available to logged in users
              if (isLoggedIn)
                ListTile(
                  leading: Icon(
                    Icons.lock_reset,
                    color: Colors.red[900],
                    size: 24,
                  ),
                  title: Text(
                    "Change Password",
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePasswordPage(isForced: false),
                      ),
                    );
                  },
                ),

              // User Management - Admin only (with security inside the page)
              if (userRole == 'admin')
                ListTile(
                  leading: Icon(
                    Icons.people,
                    color: Colors.red[900],
                    size: 24,
                  ),
                  title: Text(
                    "User Management",
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/user-management');
                  },
                ),

              // Divider
              const Divider(
                height: 20,
                thickness: 1,
                indent: 16,
                endIndent: 16,
              ),

              // System Status
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isLoggedIn ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isLoggedIn ? 'Online' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: isLoggedIn ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Log Out at the bottom (only show if logged in)
        if (isLoggedIn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(
                Icons.logout,
                color: Colors.red[900],
                size: 24,
              ),
              title: Text(
                "Log Out",
                style: TextStyle(color: Colors.grey[800]),
              ),
              onTap: () async {
                Navigator.pop(context);

                // Show confirmation dialog
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  // Logout user
                  await authProvider.logout();

                  // Navigate to landing page
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                        (route) => false,
                  );
                }
              },
            ),
          ),

        // Login Button (only show if not logged in)
        if (!isLoggedIn)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(
                Icons.login,
                color: Colors.red[900],
                size: 24,
              ),
              title: Text(
                "Logout",
                style: TextStyle(color: Colors.grey[800]),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/logout');
              },
            ),
          ),

        // Footer
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[50],
          child: Column(
            children: [
              Text(
                'Tagalog Fried Chicken POS',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}