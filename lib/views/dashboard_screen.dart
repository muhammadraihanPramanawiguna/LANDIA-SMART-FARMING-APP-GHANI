
import 'dart:async';

import 'package:flutter/material.dart';

import '../models/sensor_reading.dart';
import '../services/api_service.dart';
import 'daily_recap_screen.dart';

// ============================================================
// DASHBOARD SCREEN
// ============================================================

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.jwt,
    required this.deviceId,
  });

  final String jwt;
  final String deviceId;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ==========================================================
  // API SERVICE
  // ==========================================================

  late final ApiService _apiService = ApiService(
    jwt: widget.jwt,
    deviceId: widget.deviceId,
  );

  // ==========================================================
  // SENSOR DATA
  // ==========================================================

  DhtReading? _dht;
  SoilReading? _soil;
  TankLevelReading? _tank;
  RainSensorReading? _rain;
  WaterFlowSession? _flow;

  // ==========================================================
  // STATE
  // ==========================================================

  final Map<String, String> _sensorErrors = {};

  bool _isLoading = true;
  bool _isFetching = false;

  String? _errorMessage;

  Timer? _pollingTimer;


  // ==========================================================
  // CONSTANTS
  // ==========================================================

  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color lightGreen = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF3F6F4);

  static const Duration pollingInterval =
      Duration(seconds: 15);

  static const Duration staleThreshold =
      Duration(seconds: 60);

  // ==========================================================
  // GETTERS
  // ==========================================================

  bool get _hasAnyData =>
      _dht != null ||
      _soil != null ||
      _tank != null ||
      _rain != null ||
      _flow != null;



  // ==========================================================
  // LIFECYCLE
  // ==========================================================

  @override
  void initState() {
    super.initState();

    _fetchAllTelemetry();

    _pollingTimer = Timer.periodic(
      pollingInterval,
      (_) {
        if (mounted) {
          _fetchAllTelemetry(silent: true);
        }
      },
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _apiService.dispose();
    super.dispose();
  }

  // ==========================================================
  // FETCH SENSOR
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

  // ==========================================================
  // FETCH ALL TELEMETRY
  // ==========================================================

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
      // ======================================================
      // IMPORTANT:
      // Sensor mengambil telemetry dari Device Sensor C1.
      // Tidak menggunakan sensor ID terpisah.
      // ======================================================

      final results = await Future.wait<Object?>([
        _fetchSensor<DhtReading>(
          'DHT',
          () => _apiService.fetchLatestDht(),
        ),
        _fetchSensor<SoilReading>(
          'Soil',
          () => _apiService.fetchLatestSoil(),
        ),
        _fetchSensor<TankLevelReading>(
          'Water Level',
          () => _apiService.fetchLatestTankLevel(),
        ),
        _fetchSensor<RainSensorReading>(
          'Rain',
          () => _apiService.fetchLatestRain(),
        ),
        _fetchSensor<WaterFlowSession>(
          'Flow',
          () => _apiService.fetchLatestWaterFlow(),
        ),
      ]);

      if (!mounted) return;

      final newDht = results[0] as DhtReading?;
      final newSoil = results[1] as SoilReading?;
      final newTank = results[2] as TankLevelReading?;
      final newRain = results[3] as RainSensorReading?;
      final newFlow = results[4] as WaterFlowSession?;

      final hasNewData = results.any(
        (result) => result != null,
      );

      setState(() {
        // ----------------------------------------------------
        // UPDATE DATA YANG BERHASIL
        // ----------------------------------------------------
        // Sensor gagal tidak menghapus data sebelumnya.

        if (newDht != null) {
          _dht = newDht;
        }

        if (newSoil != null) {
          _soil = newSoil;
        }

        if (newTank != null) {
          _tank = newTank;
        }

        if (newRain != null) {
          _rain = newRain;
        }

        if (newFlow != null) {
          _flow = newFlow;
        }

        _isLoading = false;


        // ----------------------------------------------------
        // ERROR HANDLING
        // ----------------------------------------------------

        if (_sensorErrors.isEmpty) {
          _errorMessage = null;
        } else if (!_hasAnyData) {
          _errorMessage =
              'Belum berhasil mengambil data sensor. '
              'Periksa koneksi internet dan server ThingsBoard.';
        } else if (!hasNewData) {
          _errorMessage =
              'Pembaruan sensor gagal. '
              'Data terakhir yang berhasil diterima '
              'masih ditampilkan.';
        } else {
          _errorMessage =
              'Sebagian sensor gagal diperbarui. '
              'Sensor yang berhasil tetap ditampilkan.';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Gagal mengambil telemetry: $e';
      });
    } finally {
      _isFetching = false;

      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==========================================================
  // GENERAL HELPERS
  // ==========================================================

  bool _isPercentageUnit(String unit) {
    final normalized = unit.trim().toLowerCase();

    return normalized == '%' ||
        normalized == 'percent' ||
        normalized == 'percentage' ||
        normalized == 'persen';
  }

  String _sensorError(String sensorName) {
    return _sensorErrors[sensorName] ??
        'Data sensor belum tersedia.';
  }

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

  String _formatAge(Duration age) {
    if (age.inDays > 0) {
      return '${age.inDays} hari';
    }

    if (age.inHours > 0) {
      return '${age.inHours} jam';
    }

    if (age.inMinutes > 0) {
      return '${age.inMinutes} menit';
    }

    return '${age.inSeconds} detik';
  }

  String _formatRupiah(double amount) {
    final value = amount.round().toString();

    final formatted = value.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (match) => '${match[1]}.',
    );

    return 'Rp $formatted';
  }

  // ==========================================================
  // CARD HELPER
  // ==========================================================

  Widget _buildCard({
    required Widget child,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
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
            tooltip: 'Perbarui Data',
            onPressed: _isFetching
                ? null
                : () => _fetchAllTelemetry(),
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1280),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.sizeOf(context).width < 600 ? 12 : 24,
                              vertical: 16,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildRecapBannerButton(),
                                const SizedBox(height: 16),
                                if (_errorMessage != null) _buildWarningBanner(),
                                _buildSectionTitle('Kondisi Sensor Saat Ini'),
                                const SizedBox(height: 10),
                                _buildDhtCard(),
                                const SizedBox(height: 12),
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final compact = constraints.maxWidth < 520;
                                    if (compact) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _buildSoilCard(),
                                          const SizedBox(height: 12),
                                          _buildRainCard(),
                                        ],
                                      );
                                    }
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(child: _buildSoilCard()),
                                        const SizedBox(width: 12),
                                        Expanded(child: _buildRainCard()),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildTankCard(),
                                const SizedBox(height: 18),
                                _buildSectionTitle('Penggunaan Air'),
                                const SizedBox(height: 10),
                                _buildFlowCard(),
                                const SizedBox(height: 24),
                                _buildLastUpdateInformation(),
                              ],
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
                  _errorMessage ?? 'Pembaruan sensor bermasalah.',
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

  Widget _buildRecapBannerButton() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DailyRecapScreen(
              jwt: widget.jwt,
              deviceId: widget.deviceId,
            ),
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

    final temperature = hasData
        ? _dht!.temperature.toStringAsFixed(1)
        : '--';

    final humidity = hasData
        ? _dht!.humidity.toStringAsFixed(1)
        : '--';

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
              _buildConnectionDot(
                hasData,
                hasData ? _dht!.timestamp : null,
              ),
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
    final hasRainStatus = _rain?.hasRainStatus ?? false;
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

    return _buildCard(
      borderColor: accentColor.withValues(alpha: 0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isRaining
                      ? Icons.water_drop
                      : Icons.wb_sunny,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Sensor Hujan',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              _buildConnectionDot(
                hasData,
                hasData ? _rain!.timestamp : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          _buildFlowMetricItem(
            label: 'Persentase Hujan (rain_percent)',
            value: hasData
                ? '${_rain!.rainPercent.toStringAsFixed(1)} %'
                : '--',
            icon: Icons.water_drop_outlined,
            color: Colors.blue.shade700,
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
              _buildConnectionDot(
                hasData,
                hasData ? _tank!.timestamp : null,
              ),
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
                valueColor: AlwaysStoppedAnimation<Color>(
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
      ? '${_flow!.value.toStringAsFixed(2)} ${_flow!.unit}'
      : '--';

  final volume = hasData && _flow!.hasTotalVolume
      ? '${_flow!.totalVolumeLiters.toStringAsFixed(3)} liter'
      : 'Belum tersedia';

  final duration = hasData && _flow!.hasDuration
      ? '${_flow!.durationMinutes} menit'
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
                    'Monitoring aliran dan penggunaan air',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            _buildConnectionDot(
              hasData,
              hasData ? _flow!.timestamp : null,
            ),
          ],
        ),

        const Divider(height: 24),

        _buildFlowMetricItem(
          label: 'Debit Air',
          value: rate,
          icon: Icons.speed,
          color: Colors.teal.shade700,
        ),

        const SizedBox(height: 12),

        _buildFlowMetricItem(
          label: 'Total Volume Air',
          value: volume,
          icon: Icons.opacity,
          color: Colors.blue.shade700,
        ),

        const SizedBox(height: 12),

        _buildFlowMetricItem(
          label: 'Durasi Penggunaan Air',
          value: duration,
          icon: Icons.timer_outlined,
          color: Colors.orange.shade700,
        ),

        const SizedBox(height: 12),

        _buildFlowMetricItem(
          label: 'Estimasi Biaya Air',
          value: cost,
          icon: Icons.payments_outlined,
          color: Colors.green.shade800,
        ),

        const SizedBox(height: 8),

        const Text(
          'Catatan: estimasi biaya bergantung pada nilai '
          'tarif dan data volume yang dikirim oleh ESP32.',
          style: TextStyle(
            fontSize: 10,
            color: Colors.black54,
          ),
        ),

        if (!hasData)
          _buildUnavailableText(
            message: _sensorError('Flow'),
          ),
      ],
    ),
  );
}

  // ==========================================================
  // FLOW METRIC
  // ==========================================================

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

  Widget _buildConnectionDot(
    bool hasData,
    DateTime? timestamp,
  ) {
    final age = timestamp == null
        ? null
        : DateTime.now().difference(timestamp);

    final fresh = age != null &&
        age >= Duration.zero &&
        age <= staleThreshold;

    final color = !hasData
        ? Colors.grey
        : fresh
            ? Colors.green
            : Colors.orange;

    final message = !hasData
        ? 'Belum ada data sensor'
        : fresh
            ? 'Telemetry diperbarui dalam 60 detik terakhir'
            : 'Data terakhir sudah ${_formatAge(age!)}. '
                'Periksa ESP32 atau koneksi internet.';

    return Tooltip(
      message: message,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
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

    timestamps.sort(
      (a, b) => b.compareTo(a),
    );

    final latest = timestamps.first;
    final age = DateTime.now().difference(latest);

    final isStale = age > staleThreshold;

    final date =
        '${latest.day.toString().padLeft(2, '0')}/'
        '${latest.month.toString().padLeft(2, '0')}/'
        '${latest.year}';

    final time =
        '${latest.hour.toString().padLeft(2, '0')}:'
        '${latest.minute.toString().padLeft(2, '0')}:'
        '${latest.second.toString().padLeft(2, '0')}';

    return Center(
      child: Column(
        children: [
          Text(
            'Data terbaru diterima: $date $time',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          if (isStale) ...[
            const SizedBox(height: 4),
            Text(
              'DATA LAMA — pembaruan terakhir '
              '${_formatAge(age)} lalu. ESP32 mungkin offline.',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.deepOrange,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
