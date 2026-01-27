// landingpage.dart
import 'package:flutter/material.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1024;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 20.0 : screenSize.width * 0.1,
              vertical: isMobile ? 10.0 : 30.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo/Brand Section with Tagalog aligned
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    SizedBox(height: isMobile ? 10 : 15),
                    // Logo and Brand Name
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 10),
                        Text(
                          'TAGALOG',
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[900],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isMobile ? 10 : 15),

                    // Logo and Brand Name
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 10),
                        Text(
                          'FRIED CHICKEN',
                          style: TextStyle(
                            fontSize: isMobile ? 28 : 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[900],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 10),

                    // Subtitle
                    Text(
                      'Point of Sale System',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 20,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isMobile ? 40 : 60),

                // Features Grid with consistent sizes
                if (isMobile) ...[
                  // Mobile layout - vertical with same height
                  SizedBox(
                    height: 180, // Fixed height for mobile
                    child: _buildFeatureCard(
                      icon: Icons.point_of_sale,
                      title: 'Easy POS',
                      description: 'Simple and intuitive point of sale interface',
                      isMobile: true,
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    height: 180, // Fixed height for mobile
                    child: _buildFeatureCard(
                      icon: Icons.trending_up,
                      title: 'Sales Track',
                      description: 'Monitor your sales in real-time',
                      isMobile: true,
                    ),
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    height: 180, // Fixed height for mobile
                    child: _buildFeatureCard(
                      icon: Icons.analytics,
                      title: 'Analytics',
                      description: 'Detailed insights and reports',
                      isMobile: true,
                    ),
                  ),
                ] else ...[
                  // Tablet/Desktop layout - horizontal with same height
                  SizedBox(
                    height: 220, // Fixed height for desktop/tablet
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _buildFeatureCard(
                            icon: Icons.point_of_sale,
                            title: 'Easy POS',
                            description: 'Simple and intuitive point of sale interface',
                            isMobile: false,
                          ),
                        ),
                        SizedBox(width: isTablet ? 20 : 40),
                        Expanded(
                          child: _buildFeatureCard(
                            icon: Icons.trending_up,
                            title: 'Sales Track',
                            description: 'Monitor your sales in real-time',
                            isMobile: false,
                          ),
                        ),
                        SizedBox(width: isTablet ? 20 : 40),
                        Expanded(
                          child: _buildFeatureCard(
                            icon: Icons.analytics,
                            title: 'Analytics',
                            description: 'Detailed insights and reports',
                            isMobile: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                SizedBox(height: isMobile ? 40 : 60),

                // Main Message
                SizedBox(
                  width: double.infinity,
                  child: Container(
                    padding: EdgeInsets.all(isMobile ? 25 : 35),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red[100]!),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Manage your business with ease',
                          style: TextStyle(
                            fontSize: isMobile ? 22 : 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[900],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Streamline your fried chicken business operations with our comprehensive POS system',
                          style: TextStyle(
                            fontSize: isMobile ? 15 : 18,
                            color: Colors.red[800],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isMobile ? 40 : 60),

                // Get Started Button
                SizedBox(
                  width: isMobile ? double.infinity : screenSize.width * 0.4,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 18 : 22,
                        horizontal: 32,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 30),

                // Footer
                Text(
                  '© 2024 Fried Chicken POS. All rights reserved.',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isMobile,
  }) {
    return Container(
      height: double.infinity, // Fill the parent SizedBox height
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: isMobile ? 30 : 40,
              color: Colors.red[700],
            ),
          ),
          SizedBox(height: isMobile ? 15 : 20),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: Colors.red[900],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: isMobile ? 13 : 15,
                color: Colors.grey[700],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}