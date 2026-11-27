
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'dashboard_screen.dart';

/// ============================================================
/// APP STARTUP SCREEN
/// ============================================================
///
/// Fungsi:
/// 1. Membaca username dan password ThingsBoard dari dart-define.
/// 2. Login ke ThingsBoard secara otomatis.
/// 3. Mencari device Sensor C1.
/// 4. Membuka DashboardScreen jika login berhasil.
/// 5. Menampilkan error dan tombol retry jika gagal.
///
/// Catatan keamanan:
/// dart-define bukan secure storage.
/// Credential yang dimasukkan saat build tetap dapat diekstrak
/// dari APK. Untuk production, sebaiknya gunakan backend proxy
/// dengan autentikasi aplikasi.
///
/// ============================================================

class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({
    super.key,
  });

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  // ==========================================================
  // CONFIGURATION
  // ==========================================================

  static const String _username =
      String.fromEnvironment('TB_USERNAME');

  static const String _password =
      String.fromEnvironment('TB_PASSWORD');

  /// Nama device ThingsBoard Landia Farm.
  ///
  /// Tidak menggunakan ApiService.deviceName karena getter
  /// tersebut belum tersedia pada ApiService saat ini.
  static const String _expectedDeviceName = 'Sensor C1';

  // ==========================================================
  // STATE
  // ==========================================================

  bool _loading = true;
  String? _error;

  // Mencegah proses startup/retry berjalan bersamaan.
  bool _isStarting = false;

  // ==========================================================
  // LIFECYCLE
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _start();
  }

  // ==========================================================
  // STARTUP AUTHENTICATION
  // ==========================================================

  Future<void> _start() async {
    if (_isStarting) return;

    _isStarting = true;

    if (!mounted) {
      _isStarting = false;
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // --------------------------------------------------------
    // Validate build configuration
    // --------------------------------------------------------

    if (_username.trim().isEmpty || _password.isEmpty) {
      if (!mounted) {
        _isStarting = false;
        return;
      }

      setState(() {
        _loading = false;
        _error =
            'Konfigurasi akun ThingsBoard belum tersedia.\n\n'
            'Build aplikasi menggunakan:\n'
            'TB_USERNAME dan TB_PASSWORD.';
      });

      _isStarting = false;
      return;
    }

    // --------------------------------------------------------
    // Login and find device
    // --------------------------------------------------------

    try {
      final session = await ApiService.loginAndFindDevice(
        username: _username,
        password: _password,
        expectedDeviceName: _expectedDeviceName,
      );

      if (!mounted) {
        _isStarting = false;
        return;
      }

      // ------------------------------------------------------
      // Navigate to dashboard
      // ------------------------------------------------------

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            jwt: session.jwt,
            deviceId: session.deviceId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        _isStarting = false;
        return;
      }

      setState(() {
        _loading = false;
        _error =
            'Gagal menghubungkan aplikasi ke ThingsBoard.\n\n'
            'Periksa hal berikut:\n'
            '• Koneksi internet\n'
            '• Username dan password\n'
            '• Akun ThingsBoard\n'
            '• Akses terhadap device Sensor C1\n\n'
            'Detail error:\n$e';
      });
    } finally {
      _isStarting = false;
    }
  }

  // ==========================================================
  // RETRY
  // ==========================================================

  void _retry() {
    _start();
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ------------------------------------------------
                // Logo
                // ------------------------------------------------

                const Icon(
                  Icons.eco,
                  size: 72,
                  color: Color(0xFF1B5E20),
                ),

                const SizedBox(height: 18),

                // ------------------------------------------------
                // App Name
                // ------------------------------------------------

                const Text(
                  'LANDIA FARM',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B3321),
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Smart Farming IoT Monitoring',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 32),

                // ------------------------------------------------
                // Loading State
                // ------------------------------------------------

                if (_loading) ...[
                  const CircularProgressIndicator(
                    color: Color(0xFF1B5E20),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Menghubungkan ke ThingsBoard...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Mohon tunggu beberapa saat.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ]

                // ------------------------------------------------
                // Error State
                // ------------------------------------------------

                else ...[
                  const Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: Colors.orange,
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Koneksi Gagal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B3321),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.orange.shade200,
                      ),
                    ),
                    child: Text(
                      _error ?? 'Terjadi kesalahan koneksi.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ------------------------------------------------
                  // Retry Button
                  // ------------------------------------------------

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            const Color(0xFF1B5E20),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
