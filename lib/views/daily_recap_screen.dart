
import 'package:flutter/material.dart';

import '../services/api_service.dart';

class DailyRecapScreen extends StatefulWidget {
  const DailyRecapScreen({super.key});

  @override
  State<DailyRecapScreen> createState() =>
      _DailyRecapScreenState();
}

class _DailyRecapScreenState extends State<DailyRecapScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isSupported = false;
  String? _errorMessage;

  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color lightGreen = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF3F6F4);

  @override
  void initState() {
    super.initState();
    _loadRecaps();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  // ==========================================================
  // LOAD DAILY RECAP
  // ==========================================================

  Future<void> _loadRecaps() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final records = await _apiService.fetchDailyRecaps();

      if (!mounted) return;

      setState(() {
        _isSupported = true;
        _isLoading = false;
      });

      // Endpoint agregasi belum tersedia.
      // Ketika backend sudah menyediakan endpoint,
      // data records akan digunakan untuk membangun kartu rekap.
      if (records.isEmpty) {
        return;
      }
    } on UnsupportedError {
      if (!mounted) return;

      setState(() {
        _isSupported = false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ==========================================================
  // MAIN BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Rekapan Laporan Harian',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Periksa Ketersediaan Rekap',
            onPressed: _isLoading ? null : _loadRecaps,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: lightGreen,
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : !_isSupported
                  ? _buildUnavailableView()
                  : _buildEmptyView(),
    );
  }

  // ==========================================================
  // FEATURE NOT AVAILABLE
  // ==========================================================

  Widget _buildUnavailableView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_outlined,
                size: 64,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Rekap Harian Belum Tersedia',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Backend Landia Farm saat ini sudah menyediakan '
              'data pembacaan sensor, tetapi belum memiliki '
              'endpoint untuk mengolah data menjadi laporan harian.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            _buildInformationCard(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadRecaps,
                icon: const Icon(Icons.refresh),
                label: const Text('Periksa Kembali'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: lightGreen,
                  side: const BorderSide(
                    color: lightGreen,
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // INFORMATION CARD
  // ==========================================================

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.green.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data yang nantinya tersedia',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 14),
          _buildFeatureItem(
            Icons.thermostat,
            'Rata-rata suhu dan kelembapan udara',
          ),
          _buildFeatureItem(
            Icons.grass,
            'Rata-rata kelembapan tanah',
          ),
          _buildFeatureItem(
            Icons.water,
            'Rata-rata level air tangki',
          ),
          _buildFeatureItem(
            Icons.cloud,
            'Rekapitulasi kondisi sensor hujan',
          ),
          _buildFeatureItem(
            Icons.waves,
            'Total volume dan durasi aliran air',
          ),
          _buildFeatureItem(
            Icons.picture_as_pdf,
            'Ekspor laporan harian ke PDF',
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color: lightGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // EMPTY VIEW
  // ==========================================================

  Widget _buildEmptyView() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'Belum Ada Rekapan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Belum ada data agregasi harian yang tersedia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // ERROR VIEW
  // ==========================================================

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off,
              size: 60,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal Memuat Rekapan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadRecaps,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: lightGreen,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
