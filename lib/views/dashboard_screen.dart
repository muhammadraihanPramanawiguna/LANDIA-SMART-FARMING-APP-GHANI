
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/sensor_reading.dart';
import '../services/api_service.dart';
import 'daily_recap_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();

  DhtReading? _dht;
  SoilReading? _soil;
  TankLevelReading? _tank;
  RainSensorReading? _rain;
  WaterFlowSession? _flow;

  final Map<String, String> _sensorErrors = {};

  bool _isLoading = true;
  bool _isFetching = false;

  String? _errorMessage;
  Timer? _pollingTimer;

  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color lightGreen = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF3F6F4);

  bool get _hasAnyData =>
      _dht != null ||
      _soil != null ||
      _tank != null ||
      _rain != null ||
      _flow != null;

  bool _isPercentageUnit(String unit) {
    final normalized = unit.trim().toLowerCase();

    return normalized == '%' ||
        normalized == 'percent' ||
        normalized == 'percentage' ||
        normalized == 'persen';
  }

  @override
  void initState() {
    super.initState();

    _fetchAllTelemetry();

    // Polling setiap 10 detik.
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _fetchAllTelemetry(silent: true),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _apiService.dispose();
    super.dispose();
  }

  // ==========================================================
  // FETCH SENSOR DATA
  // ==========================================================

  Future<T?> _fetchSensor<T>(
    String sensorName,
    Future<T> Function() request,
  ) async {
    try {
      final result = await request();

      _sensorErrors.remove(sensorName);

      return result;
    } catch (e) {
      _sensorErrors[sensorName] = e.toString();

      return null;
    }
  }

  Future<void> _fetchAllTelemetry({
    bool silent = false,
  }) async {
    if (_isFetching || !mounted) return;

    _isFetching = true;

    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<Object?>([
        _fetchSensor(
          'DHT',
          () => _apiService.fetchLatestDht(
            ApiService.dhtSensorId,
          ),
        ),
        _fetchSensor(
          'Soil',
          () => _apiService.fetchLatestSoil(
            ApiService.soilSensorId,
          ),
        ),
        _fetchSensor(
          'Water Level',
          () => _apiService.fetchLatestTankLevel(
            ApiService.waterLevelSensorId,
          ),
        ),
        _fetchSensor(
          'Rain',
          () => _apiService.fetchLatestRain(
            ApiService.rainSensorId,
          ),
        ),
        _fetchSensor(
          'Flow',
          () => _apiService.fetchLatestWaterFlow(
            ApiService.flowSensorId,
          ),
        ),
      ]);

      if (!mounted) return;

      final dht = results[0] as DhtReading?;
      final soil = results[1] as SoilReading?;
      final tank = results[2] as TankLevelReading?;
      final rain = results[3] as RainSensorReading?;
      final flow = results[4] as WaterFlowSession?;

      final hasNewData = results.any(
        (result) => result != null,
      );

      setState(() {
        // Pertahankan data terakhir jika request sensor gagal.
        if (dht != null) _dht = dht;
        if (soil != null) _soil = soil;
        if (tank != null) _tank = tank;
        if (rain != null) _rain = rain;
        if (flow != null) _flow = flow;

        _isLoading = false;

        if (_sensorErrors.isNotEmpty) {
          if (!_hasAnyData) {
            _errorMessage =
                'Belum berhasil mengambil data sensor. '
                'Periksa koneksi jaringan dan backend.';
          } else if (!hasNewData) {
            _errorMessage =
                'Pembaruan gagal. Data terakhir yang berhasil '
                'diterima masih ditampilkan.';
          } else {
            _errorMessage =
                'Sebagian sensor gagal diperbarui. '
                'Data sensor lainnya tetap ditampilkan.';
          }
        } else {
          _errorMessage = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal mengambil data sensor: $e';
      });
    } finally {
      _isFetching = false;
    }
  }

  // ==========================================================
  // HELPER
  // ==========================================================

  Color _getSoilConditionColor(String condition) {
    switch (condition) {
      case 'Kering':
        return Colors.orange.shade700;
      case 'Lembap':
        return Colors.green.shade700;
      case 'Basah':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  String _sensorError(String sensorName) {
    return _sensorErrors[sensorName] ??
        'Data sensor belum tersedia.';
  }

  Widget _buildUnavailableText({
    String message = 'Data sensor belum tersedia.',
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black54,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildCard({
    required Widget child,
    Color? borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E293B),
      ),
    );
  }

  // ==========================================================
  // MAIN BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Landia Farm',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            Text(
              'Smart Farming Monitoring',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: _isFetching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Perbarui Data',
            onPressed: _isFetching
                ? null
                : () => _fetchAllTelemetry(),
          ),
        ],
      ),
      body: _isLoading && !_hasAnyData
          ? const Center(
              child: CircularProgressIndicator(
                color: lightGreen,
              ),
            )
          : !_hasAnyData
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: () => _fetchAllTelemetry(),
                  color: lightGreen,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildRecapBannerButton(context),

                      const SizedBox(height: 16),

                      if (_errorMessage != null)
                        _buildWarningBanner(),

                      _buildSectionTitle(
                        'Pemantauan Sensor Langsung',
                      ),

                      const SizedBox(height: 10),

                      _buildDhtCard(),

                      const SizedBox(height: 12),

                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildSoilCard()),
                          const SizedBox(width: 12),
                          Expanded(child: _buildRainCard()),
                        ],
                      ),

                      const SizedBox(height: 12),

                      _buildTankCard(),

                      const SizedBox(height: 18),

                      _buildSectionTitle(
                        'Data Aliran Air (Sensor Flow)',
                      ),

                      const SizedBox(height: 10),

                      _buildFlowCard(),

                      const SizedBox(height: 24),

                      _buildLastUpdateInformation(),
                    ],
                  ),
                ),
    );
  }

  // ==========================================================
  // WARNING BANNER
  // ==========================================================

  Widget _buildWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.orange.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade900,
                  ),
                ),
                if (_sensorErrors.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ..._sensorErrors.keys.map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '• $name: gagal diperbarui',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
              size: 56,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ??
                  'Data sensor belum tersedia.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isFetching
                  ? null
                  : () => _fetchAllTelemetry(),
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

  // ==========================================================
  // DAILY RECAP BUTTON
  // ==========================================================

  Widget _buildRecapBannerButton(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DailyRecapScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2E7D32),
              Color(0xFF43A047),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: lightGreen.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(
                Icons.table_chart_rounded,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rekapan Laporan Harian',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Lihat rekap sensor dan laporan PDF',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // DHT CARD
  // ==========================================================

  Widget _buildDhtCard() {
    final hasData = _dht != null;

    final temperature =
        hasData ? _dht!.temperature.toStringAsFixed(1) : '--';

    final humidity =
        hasData ? _dht!.humidity.toStringAsFixed(1) : '--';

    return _buildCard(
      borderColor: Colors.orange.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.thermostat,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sensor DHT (Lingkungan Udara)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              _buildConnectionDot(hasData),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildDhtMetric(
                  label: 'Suhu Udara',
                  value: '$temperature °C',
                  background: Colors.orange.shade50,
                  valueColor: Colors.orange.shade800,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDhtMetric(
                  label: 'Kelembapan Udara',
                  value: '$humidity %',
                  background: Colors.cyan.shade50,
                  valueColor: Colors.cyan.shade800,
                ),
              ),
            ],
          ),
          if (!hasData)
            _buildUnavailableText(
              message: _sensorError('DHT'),
            ),
        ],
      ),
    );
  }

  Widget _buildDhtMetric({
    required String label,
    required String value,
    required Color background,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // SOIL CARD
  // ==========================================================

  Widget _buildSoilCard() {
    final hasData = _soil != null;

    final moisture = hasData
        ? _soil!.moistureValue.toStringAsFixed(1)
        : '--';

    final unit = hasData ? _soil!.unit : '';

    final isPercentage =
        hasData && _isPercentageUnit(_soil!.unit);

    final condition = !hasData
        ? 'Tidak tersedia'
        : isPercentage
            ? _soil!.condition
            : 'Belum dikalibrasi';

    final badgeColor =
        _getSoilConditionColor(condition);

    return _buildCard(
      borderColor: Colors.brown.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.brown.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.grass,
              color: Colors.brown.shade700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Sensor Tanah',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasData ? '$moisture $unit' : '--',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.brown.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              condition,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: badgeColor,
              ),
            ),
          ),
          if (!hasData)
            _buildUnavailableText(
              message: _sensorError('Soil'),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // RAIN CARD
  // ==========================================================

  Widget _buildRainCard() {
    final hasData = _rain != null;
    final hasRainStatus =
        _rain?.hasRainStatus ?? false;
    final isRaining = _rain?.isRaining ?? false;

    final statusText = !hasData
        ? 'Tidak tersedia'
        : _rain!.statusText;

    final accentColor = !hasData
        ? Colors.grey.shade700
        : hasRainStatus
            ? (isRaining
                ? Colors.indigo.shade700
                : Colors.amber.shade800)
            : Colors.blue.shade700;

    final bgColor = !hasData
        ? Colors.grey.shade100
        : hasRainStatus
            ? (isRaining
                ? Colors.indigo.shade50
                : Colors.amber.shade50)
            : Colors.blue.shade50;

    final icon = !hasData
        ? Icons.cloud_off
        : hasRainStatus
            ? (isRaining
                ? Icons.water_drop
                : Icons.wb_sunny)
            : Icons.grain;

    return _buildCard(
      borderColor: accentColor.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Sensor Hujan',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              !hasData
                  ? 'Data tidak tersedia'
                  : hasRainStatus
                      ? (isRaining
                          ? 'Terdeteksi Hujan'
                          : 'Tidak Hujan')
                      : 'Status hujan belum tersedia',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ),
          if (!hasData)
            _buildUnavailableText(
              message: _sensorError('Rain'),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // WATER LEVEL CARD
  // ==========================================================

  Widget _buildTankCard() {
    final hasData = _tank != null;

    final value = hasData
        ? _tank!.value.toStringAsFixed(1)
        : '--';

    final unit = hasData ? _tank!.unit : '';

    final isPercentage =
        hasData && _isPercentageUnit(_tank!.unit);

    final hasDistance =
        _tank?.hasDistanceCm ?? false;

    final distance = hasDistance
        ? '${_tank!.distanceCm.toStringAsFixed(1)} cm'
        : 'Jarak belum tersedia';

    final percentageValue = hasData && isPercentage
        ? _tank!.value.clamp(0.0, 100.0)
        : 0.0;

    return _buildCard(
      borderColor: Colors.blue.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.water,
                  color: Colors.blue.shade700,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Level Air Tangki',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              _buildConnectionDot(hasData),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            hasData ? '$value $unit' : '--',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 24,
              color: Colors.blue.shade800,
            ),
          ),

          if (isPercentage) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentageValue / 100,
                minHeight: 10,
                backgroundColor: Colors.blue.shade50,
                valueColor:
                    AlwaysStoppedAnimation<Color>(
                  Colors.blue.shade600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 8),

          Text(
            hasDistance
                ? distance
                : isPercentage
                    ? 'Persentase level tangki'
                    : 'Nilai dan satuan sesuai data backend',
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),

          if (!hasData)
            _buildUnavailableText(
              message: _sensorError('Water Level'),
            ),
        ],
      ),
    );
  }

  // ==========================================================
  // FLOW CARD
  // ==========================================================

  Widget _buildFlowCard() {
    final hasData = _flow != null;

    final rate = hasData
        ? '${_flow!.value.toStringAsFixed(1)} ${_flow!.unit}'
        : '--';

    final duration = hasData && _flow!.hasDuration
        ? '${_flow!.durationMinutes.toStringAsFixed(1)} menit'
        : 'Belum tersedia';

    final volume = hasData && _flow!.hasTotalVolume
        ? '${_flow!.totalVolumeLiters.toStringAsFixed(1)} liter'
        : 'Belum tersedia';

    final cost = hasData && _flow!.hasCost
        ? _formatRupiah(_flow!.costIdr)
        : 'Belum tersedia';

    return _buildCard(
      borderColor: Colors.teal.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.waves,
                  color: Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sensor Flow (Aliran Air)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF334155),
                      ),
                    ),
                    Text(
                      'Monitoring aliran air',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              _buildConnectionDot(hasData),
            ],
          ),

          const Divider(height: 24),

          _buildFlowMetricItem(
            label: 'Nilai Flow',
            value: rate,
            icon: Icons.speed,
            color: Colors.teal.shade700,
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildFlowMetricItem(
                  label: 'Durasi Aliran',
                  value: duration,
                  icon: Icons.timer_outlined,
                  color: Colors.teal.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFlowMetricItem(
                  label: 'Volume Air',
                  value: volume,
                  icon: Icons.opacity,
                  color: Colors.teal.shade700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildFlowMetricItem(
            label: 'Biaya Penyiraman',
            value: cost,
            icon: Icons.payments_outlined,
            color: Colors.green.shade800,
          ),

          if (!hasData)
            _buildUnavailableText(
              message: _sensorError('Flow'),
            ),
        ],
      ),
    );
  }

  Widget _buildFlowMetricItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.teal.shade50.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: color,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // CONNECTION INDICATOR
  // ==========================================================

  Widget _buildConnectionDot(bool isAvailable) {
    return Tooltip(
      message: isAvailable
          ? 'Data sensor tersedia'
          : 'Data sensor belum tersedia',
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isAvailable
              ? Colors.green
              : Colors.grey,
        ),
      ),
    );
  }

  // ==========================================================
  // LAST UPDATE INFORMATION
  // ==========================================================

  Widget _buildLastUpdateInformation() {
    final timestamps = <DateTime>[
      if (_dht != null) _dht!.timestamp,
      if (_soil != null) _soil!.timestamp,
      if (_tank != null) _tank!.timestamp,
      if (_rain != null) _rain!.timestamp,
      if (_flow != null) _flow!.timestamp,
    ];

    if (timestamps.isEmpty) {
      return const SizedBox.shrink();
    }

    timestamps.sort((a, b) => b.compareTo(a));

    final latest = timestamps.first;

    final date =
        '${latest.day.toString().padLeft(2, '0')}/'
        '${latest.month.toString().padLeft(2, '0')}/'
        '${latest.year}';

    final time =
        '${latest.hour.toString().padLeft(2, '0')}:'
        '${latest.minute.toString().padLeft(2, '0')}:'
        '${latest.second.toString().padLeft(2, '0')}';

    return Center(
      child: Text(
        'Data terbaru diterima: $date $time',
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black54,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ==========================================================
  // RUPIAH FORMATTER
  // ==========================================================

  String _formatRupiah(double amount) {
    final intVal = amount.round();

    final formatted = intVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]}.',
    );

    return 'Rp $formatted';
  }
}
