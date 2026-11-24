import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() { _username.dispose(); _password.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Username dan password ThingsBoard wajib diisi.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final session = await ApiService.loginAndFindDevice(
        username: _username.text.trim(), password: _password.text,
        expectedDeviceName: 'Sensor C1',
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => DashboardScreen(jwt: session.jwt, deviceId: session.deviceId)));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Icon(Icons.eco, size: 64, color: Color(0xFF1B5E20)),
            const SizedBox(height: 16),
            const Text('LANDIA FARM', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Masuk menggunakan akun ThingsBoard dosen', textAlign: TextAlign.center),
            const SizedBox(height: 28),
            TextField(controller: _username, keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Username / Email ThingsBoard', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person))),
            const SizedBox(height: 14),
            TextField(controller: _password, obscureText: _obscure,
              decoration: InputDecoration(labelText: 'Password ThingsBoard', border: const OutlineInputBorder(), prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)))),
            const SizedBox(height: 16),
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            FilledButton(onPressed: _loading ? null : _login,
              child: Padding(padding: const EdgeInsets.all(14), child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('MASUK'))),
            const SizedBox(height: 12),
            const Text('Aplikasi mengambil telemetry langsung dari ThingsBoard. Link aktivasi bukan username atau password.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.black54)),
          ])))));
  }
}
