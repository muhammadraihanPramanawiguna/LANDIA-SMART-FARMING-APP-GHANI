import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

/// Opens the dashboard directly after silently authenticating with the
/// Customer account supplied at build time. No interactive login page.
/// NOTE: dart-define values are packaged in the APK and are not secret storage.
class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({super.key});

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  String? _error;
  bool _loading = true;

  static const _username = String.fromEnvironment('TB_USERNAME');
  static const _password = String.fromEnvironment('TB_PASSWORD');

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_username.isEmpty || _password.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Konfigurasi akun ThingsBoard belum diberikan saat build. '
            'Build aplikasi dengan TB_USERNAME dan TB_PASSWORD.';
      });
      return;
    }
    try {
      final session = await ApiService.loginAndFindDevice(
        username: _username,
        password: _password,
        expectedDeviceName: ApiService.deviceName,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => DashboardScreen(
          jwt: session.jwt,
          deviceId: session.deviceId,
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal menghubungkan aplikasi ke ThingsBoard. '
            'Periksa internet, akun Customer, dan akses Sensor C1.\n\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F4),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.eco, size: 68, color: Color(0xFF1B5E20)),
              const SizedBox(height: 16),
              const Text('LANDIA FARM', style: TextStyle(
                fontSize: 25, fontWeight: FontWeight.bold,
                color: Color(0xFF1B3321))),
              const SizedBox(height: 20),
              if (_loading) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 14),
                const Text('Menghubungkan ke ThingsBoard...'),
              ] else ...[
                const Icon(Icons.cloud_off, color: Colors.orange, size: 38),
                const SizedBox(height: 12),
                Text(_error ?? 'Koneksi gagal', textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => setState(() {
                    _loading = true;
                    _error = null;
                    _start();
                  }),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
