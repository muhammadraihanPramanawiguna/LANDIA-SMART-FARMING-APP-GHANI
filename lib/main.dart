import 'package:flutter/material.dart';

import 'views/app_startup_screen.dart';

void main() {
  runApp(const LandiaFarm());
}

class LandiaFarm extends StatelessWidget {
  const LandiaFarm({super.key, this.home});

  /// Halaman utama aplikasi.
  ///
  /// Jika tidak diberikan, aplikasi akan menggunakan DashboardScreen.
  /// Parameter home juga memudahkan pengujian widget tanpa menjalankan
  /// koneksi API sungguhan.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Landia Farm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9F5),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFFF7F9F5),
          foregroundColor: Color(0xFF1B3321),
        ),
      ),
      home: home ?? const AppStartupScreen(),
    );
  }
}
