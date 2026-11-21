
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sensor_reading.dart';

class ApiService {
  ApiService({
  String? host,
  int? port,
  this.scheme = 'http',
  http.Client? client,
})  : host = host ??
          const String.fromEnvironment(
            'LANDIA_API_HOST',
            defaultValue: '192.168.0.190',
          ),
      port = port ??
          const int.fromEnvironment(
            'LANDIA_API_PORT',
            defaultValue: 8086,
          ),
      _client = client ?? http.Client();

  /// IP atau hostname server backend.
  /// Development: 192.168.0.190
  /// Production: hostname atau IP VPS.
  final String host;

  /// Semua request REST melalui API Gateway.
  final int port;

  /// http untuk development, https untuk production.
  final String scheme;

  final http.Client _client;

  // ==========================================
  // SENSOR ID
  // ==========================================

  static const String dhtSensorId = 'landia-dht-01';
  static const String soilSensorId = 'landia-soil-01';
  static const String waterLevelSensorId =
      'landia-water-level-01';
  static const String rainSensorId = 'landia-rain-01';
  static const String flowSensorId = 'landia-flow-01';

  // ==========================================
  // BASE URI - API GATEWAY
  // ==========================================

  Uri _uri(
    String path, [
    Map<String, String>? query,
  ]) {
    return Uri(
      scheme: scheme,
      host: host,
      port: port,
      path: path,
      queryParameters: query,
    );
  }

  // ==========================================
  // HTTP GET + JSON HANDLER
  // ==========================================

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.body}',
        );
      }

      if (response.body.isEmpty) {
        throw const FormatException(
          'Respons API kosong',
        );
      }

      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Respons API bukan objek JSON',
        );
      }

      return decoded;
    } on http.ClientException catch (e) {
      throw Exception(
        'Gagal terhubung ke API Gateway: ${e.message}',
      );
    } on FormatException {
      rethrow;
    }
  }

  // ==========================================
  // DHT SERVICE
  // Gateway: /api/dht/**
  // Backend: GET /api/dht/readings/{sensorId}/latest
  // ==========================================

  Future<DhtReading> fetchLatestDht([
    String sensorId = dhtSensorId,
  ]) async {
    final json = await _getJson(
      _uri('/api/dht/readings/$sensorId/latest'),
    );

    return DhtReading.fromJson(json);
  }

  // ==========================================
  // SOIL SERVICE
  // Gateway: /api/soil/**
  // Backend: GET /api/soil/readings/latest?sensorId=...
  // ==========================================

  Future<SoilReading> fetchLatestSoil([
    String sensorId = soilSensorId,
  ]) async {
    final json = await _getJson(
      _uri(
        '/api/soil/readings/latest',
        {
          'sensorId': sensorId,
        },
      ),
    );

    return SoilReading.fromJson(json);
  }

  // ==========================================
  // WATER LEVEL SERVICE
  // Gateway: /api/water-level/**
  // Backend: GET /api/water-level/readings/{sensorId}/latest
  // ==========================================

  Future<TankLevelReading> fetchLatestTankLevel([
    String sensorId = waterLevelSensorId,
  ]) async {
    final json = await _getJson(
      _uri(
        '/api/water-level/readings/$sensorId/latest',
      ),
    );

    return TankLevelReading.fromJson(json);
  }

  // ==========================================
  // RAIN SERVICE
  // Gateway: /api/rain/**
  // Backend: GET /api/rain/readings/{sensorId}/latest
  // ==========================================

  Future<RainSensorReading> fetchLatestRain([
    String sensorId = rainSensorId,
  ]) async {
    final json = await _getJson(
      _uri(
        '/api/rain/readings/$sensorId/latest',
      ),
    );

    return RainSensorReading.fromJson(json);
  }

  // ==========================================
  // FLOW SERVICE
  // Gateway: /api/flow/**
  // Backend: GET /api/flow/readings/{sensorId}/latest
  // ==========================================

  Future<WaterFlowSession> fetchLatestWaterFlow([
    String sensorId = flowSensorId,
  ]) async {
    final json = await _getJson(
      _uri(
        '/api/flow/readings/$sensorId/latest',
      ),
    );

    return WaterFlowSession.fromJson(json);
  }

  // ==========================================
  // DAILY RECAP
  // Belum tersedia di backend versi terbaru.
  // ==========================================

  Future<List<DailyRecapRecord>> fetchDailyRecaps() async {
    throw UnsupportedError(
      'Daily Recap belum tersedia di backend Landia Farm.',
    );
  }

  // ==========================================
  // DISPOSE
  // ==========================================

  void dispose() {
    _client.close();
  }
}
