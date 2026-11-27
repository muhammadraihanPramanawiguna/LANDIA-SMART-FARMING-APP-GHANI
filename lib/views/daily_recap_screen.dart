import 'package:flutter/material.dart';

import '../models/sensor_reading.dart';
import '../services/api_service.dart';
import '../services/pdf_export_service.dart';

class DailyRecapScreen extends StatefulWidget {
  const DailyRecapScreen({
    super.key,
    required this.jwt,
    required this.deviceId,
  });

  final String jwt;
  final String deviceId;

  @override
  State<DailyRecapScreen> createState() =>
      _DailyRecapScreenState();
}

class _DailyRecapScreenState
    extends State<DailyRecapScreen> {
  late final ApiService _apiService;

  DateTime _selectedDate = DateTime.now();

  DailyRecapRecord? _record;

  bool _isLoading = true;
  bool _isExporting = false;

  String? _errorMessage;

  static const Color primaryGreen =
      Color(0xFF1B5E20);

  static const Color lightGreen =
      Color(0xFF2E7D32);

  static const Color backgroundColor =
      Color(0xFFF3F6F4);

  @override
  void initState() {
    super.initState();

    _apiService = ApiService(
      jwt: widget.jwt,
      deviceId: widget.deviceId,
    );

    _loadRecap();
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }

  // ==========================================================
  // LOAD RECAP
  // ==========================================================

  Future<void> _loadRecap() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final record =
          await _apiService.fetchDailyRecapForDate(
        _selectedDate,
      );

      if (!mounted) return;

      setState(() {
        _record = record;
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
  // DATE PICKER
  // ==========================================================

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      helpText: 'Pilih tanggal laporan',
      confirmText: 'PILIH',
      cancelText: 'BATAL',
    );

    if (selected == null) return;

    setState(() {
      _selectedDate = selected;
    });

    await _loadRecap();
  }

  // ==========================================================
  // EXPORT PDF
  // ==========================================================

  Future<void> _exportPdf() async {
    if (_record == null) return;

    setState(() {
      _isExporting = true;
    });

    try {
      await PdfExportService.generateDailyRecapPdf(
        _record!,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuat PDF: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
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
          'Laporan Harian',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh laporan',
            onPressed:
                _isLoading ? null : _loadRecap,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: lightGreen,
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorView();
    }

    if (_record == null) {
      return _buildEmptyView();
    }

    return RefreshIndicator(
      onRefresh: _loadRecap,
      color: lightGreen,
      child: ListView(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDateCard(),
                    const SizedBox(height: 16),
                    _buildSummaryCard(),
                    const SizedBox(height: 16),
                    _buildSensorSection(),
                    const SizedBox(height: 16),
                    _buildRainCard(),
                    const SizedBox(height: 16),
                    _buildWaterSection(),
                    const SizedBox(height: 16),
                    _buildDataInformation(),
                    const SizedBox(height: 20),
                    _buildExportButton(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DATE CARD
  // ==========================================================

  Widget _buildDateCard() {
    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.calendar_month,
                color: primaryGreen,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tanggal laporan',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _formatDate(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            ElevatedButton(
              onPressed: _selectDate,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Pilih'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // SUMMARY
  // ==========================================================

  Widget _buildSummaryCard() {
    final record = _record!;

    return Card(
      elevation: 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Kondisi Pertanian',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _summaryMetric(
                    icon: Icons.thermostat,
                    label: 'Suhu rata-rata',
                    value:
                        record.hasTemperature
                            ? '${record.avgTemperature.toStringAsFixed(1)} °C'
                            : '--',
                    color: Colors.orange,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _summaryMetric(
                    icon: Icons.water_drop,
                    label: 'Kelembapan udara',
                    value:
                        record.hasHumidity
                            ? '${record.avgHumidity.toStringAsFixed(1)} %'
                            : '--',
                    color: Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _summaryMetric(
                    icon: Icons.grass,
                    label: 'Kelembapan tanah',
                    value:
                        record.hasSoilMoisture
                            ? '${record.avgSoilMoisture.toStringAsFixed(1)} %'
                            : '--',
                    color: Colors.green,
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _summaryMetric(
                    icon: Icons.water,
                    label: 'Level tangki',
                    value:
                        record.hasTankLevel
                            ? '${record.avgTankLevel.toStringAsFixed(1)} %'
                            : '--',
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),

          const SizedBox(height: 8),

          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SENSOR SECTION
  // ==========================================================

  Widget _buildSensorSection() {
    final record = _record!;

    return _sectionCard(
      title: 'Statistik Kondisi Sensor',
      icon: Icons.analytics,
      children: [
        if (!record.hasTemperature || !record.hasHumidity)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Data suhu atau kelembapan udara tidak tersedia pada tanggal ini. '
                    'Nilai tidak dihitung agar laporan tidak menampilkan angka yang keliru.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        if (record.hasTemperature)
          _statRow(
            'Suhu udara',
            record.avgTemperature,
            record.minTemperature,
            record.maxTemperature,
            '°C',
          ),

        if (record.hasHumidity)
          _statRow(
            'Kelembapan udara',
            record.avgHumidity,
            record.minHumidity,
            record.maxHumidity,
            '%',
          ),

        if (record.hasSoilMoisture)
          _statRow(
            'Kelembapan tanah',
            record.avgSoilMoisture,
            record.minSoilMoisture,
            record.maxSoilMoisture,
            '%',
          ),

        if (record.hasTankLevel)
          _statRow(
            'Level tangki',
            record.avgTankLevel,
            record.minTankLevel,
            record.maxTankLevel,
            '%',
          ),

        if (!record.hasTemperature &&
            !record.hasHumidity &&
            !record.hasSoilMoisture &&
            !record.hasTankLevel)
          const Text(
            'Tidak ada data sensor yang tersedia.',
            style: TextStyle(
              color: Colors.black54,
            ),
          ),
      ],
    );
  }

  Widget _statRow(
    String label,
    double average,
    double? minimum,
    double? maximum,
    String unit,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          LayoutBuilder(
            builder: (context, constraints) {
              final metrics = <Widget>[
                _smallMetric('Rata-rata', '${average.toStringAsFixed(1)} $unit'),
                _smallMetric('Terendah', minimum == null ? '--' : '${minimum.toStringAsFixed(1)} $unit'),
                _smallMetric('Tertinggi', maximum == null ? '--' : '${maximum.toStringAsFixed(1)} $unit'),
              ];
              if (constraints.maxWidth < 480) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: metrics
                      .map((metric) => SizedBox(
                            width: (constraints.maxWidth - 12) / 2,
                            child: metric,
                          ))
                      .toList(),
                );
              }
              return Row(
                children: metrics.map((metric) => Expanded(child: metric)).toList(),
              );
            },
          ),

          const Divider(),
        ],
      ),
    );
  }

  Widget _smallMetric(
    String label,
    String value,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.black54,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // RAIN CARD
  // ==========================================================

  Widget _buildRainCard() {
    final status =
        _record!.dominantRainStatus;

    final isRain =
        status.toLowerCase().contains('hujan') &&
        !status.toLowerCase().contains('tidak');

    final color =
        isRain ? Colors.blue : Colors.orange;

    return _sectionCard(
      title: 'Status Cuaca',
      icon: Icons.cloud,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                isRain
                    ? Icons.umbrella
                    : Icons.wb_sunny,
                color: color,
                size: 30,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status dominan hari ini',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      status,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================
  // WATER SECTION
  // ==========================================================

  Widget _buildWaterSection() {
    final flow =
        _record!.flowSession;

    return _sectionCard(
      title: 'Penggunaan Air',
      icon: Icons.water,
      children: [
        if (flow == null)
          const Text(
            'Belum terdapat data penggunaan air '
            'yang dapat dihitung.',
            style: TextStyle(
              color: Colors.black54,
            ),
          )
        else ...[
          _waterMetric(
            'Debit rata-rata',
            '${flow.flowRateLpm.toStringAsFixed(2)} L/min',
          ),

          if (flow.hasTotalVolume)
            _waterMetric(
              'Volume air',
              '${flow.totalVolumeLiters.toStringAsFixed(2)} Liter',
            ),

          if (flow.hasDuration)
            _waterMetric(
              'Durasi aliran',
              '${flow.durationMinutes.toStringAsFixed(1)} menit',
            ),

          if (flow.hasCost)
            _waterMetric(
              'Biaya air',
              _formatRupiah(flow.costIdr),
            ),

          if (!flow.hasTotalVolume &&
              !flow.hasCost)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Volume dan biaya belum dapat dihitung '
                'dari telemetry yang tersedia.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _waterMetric(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DATA INFORMATION
  // ==========================================================

  Widget _buildDataInformation() {
    final record = _record!;

    return Card(
      color: Colors.blue.shade50,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.blue.shade700,
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                'Jumlah data telemetry yang berhasil '
                'diproses: ${record.totalDataPoints}',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // EXPORT BUTTON
  // ==========================================================

  Widget _buildExportButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed:
            _isExporting || _record == null
                ? null
                : _exportPdf,
        icon: _isExporting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.picture_as_pdf,
              ),
        label: Text(
          _isExporting
              ? 'Membuat PDF...'
              : 'Export Laporan PDF',
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ==========================================================
  // SECTION CARD
  // ==========================================================

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: primaryGreen,
                ),

                const SizedBox(width: 8),

                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            ...children,
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
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 60,
              color: Colors.red.shade300,
            ),

            const SizedBox(height: 16),

            const Text(
              'Gagal mengambil laporan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              _errorMessage ?? 'Terjadi kesalahan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _loadRecap,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
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
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 60,
              color: Colors.grey,
            ),

            SizedBox(height: 16),

            Text(
              'Data laporan belum tersedia',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

            SizedBox(height: 8),

            Text(
              'Belum ada telemetry pada tanggal '
              'yang dipilih.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // FORMATTING
  // ==========================================================

  String _formatDate(DateTime date) {
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${date.day} ${months[date.month - 1]} '
        '${date.year}';
  }

  String _formatRupiah(double amount) {
    final digits = amount.round().toString();

    final formatted =
        digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'Rp $formatted';
  }
}