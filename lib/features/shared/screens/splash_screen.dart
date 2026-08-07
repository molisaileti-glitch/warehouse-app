// lib/features/shared/screens/splash_screen.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warehouse_rounded, size: 72, color: Colors.white),
            SizedBox(height: 16),
            Text('MavunoHub',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5)),
            SizedBox(height: 8),
            Text('Inventory Management',
                style: TextStyle(color: Colors.white60, fontSize: 14)),
            SizedBox(height: 48),
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white54)),
          ],
        ),
      ),
    );
  }
}