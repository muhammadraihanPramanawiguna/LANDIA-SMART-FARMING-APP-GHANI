import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_reading.dart';
import '../models/history_models.dart'; // keeping your existing Rain/Fertilizer/Irrigation history imports if needed

class ApiService {
  final String baseUrl;
  final bool useMockData;

  ApiService({this.baseUrl = 'http://localhost:8080', this.useMockData = true});

  // --- TELEMETRY ENDPOINTS ---

  Future<DhtReading> fetchLatestDht(String deviceId) async {
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return DhtReading(
        temperature: 28.5,
        humidity: 74.0,
        timestamp: DateTime.now(),
      );
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/telemetry/dht/latest?deviceId=$deviceId'),
    );
    if (response.statusCode == 200) {
      return DhtReading.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
        'Failed to load DHT data from server (${response.statusCode})',
      );
    }
  }

  Future<SoilReading> fetchLatestSoil(String deviceId) async {
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return SoilReading(
        moistureValue: 45.2, // will automatically evaluate to 'Lembap'
        timestamp: DateTime.now(),
      );
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/telemetry/soil/latest?deviceId=$deviceId'),
    );
    if (response.statusCode == 200) {
      return SoilReading.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
        'Failed to load soil sensor data (${response.statusCode})',
      );
    }
  }

  Future<TankLevelReading> fetchLatestTankLevel(String deviceId) async {
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return TankLevelReading(
        percentage: 75.0,
        distanceCm: 15.0,
        timestamp: DateTime.now(),
      );
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/telemetry/tank/latest?deviceId=$deviceId'),
    );
    if (response.statusCode == 200) {
      return TankLevelReading.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
        'Failed to load tank level data (${response.statusCode})',
      );
    }
  }

  Future<RainSensorReading> fetchLatestRain(String deviceId) async {
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return RainSensorReading(
        isRaining: false, // "Tidak Hujan"
        timestamp: DateTime.now(),
      );
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/telemetry/rain/latest?deviceId=$deviceId'),
    );
    if (response.statusCode == 200) {
      return RainSensorReading.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
        'Failed to load rain sensor data (${response.statusCode})',
      );
    }
  }

  Future<WaterFlowSession> fetchLatestWaterFlow(String deviceId) async {
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 300));
      return WaterFlowSession(
        id: 'flow-001',
        flowRateLpm: 12.5,
        durationMinutes: 15.0,
        totalVolumeLiters: 187.5,
        costIdr: 1500.0,
        timestamp: DateTime.now(),
      );
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/telemetry/flow/latest?deviceId=$deviceId'),
    );
    if (response.statusCode == 200) {
      return WaterFlowSession.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(
        'Failed to load water flow data (${response.statusCode})',
      );
    }
  }

  // --- DAILY RECAP ENDPOINT (Rekapan Harian) ---

  Future<List<DailyRecapRecord>> fetchDailyRecaps() async {
    if (useMockData) {
      await Future.delayed(const Duration(milliseconds: 400));
      final now = DateTime.now();
      return [
        DailyRecapRecord(
          date: now.toIso8601String().split('T')[0],
          avgTemperature: 28.2,
          avgHumidity: 75.0,
          avgSoilMoisture: 48.5,
          avgTankLevel: 80.0,
          dominantRainStatus: 'Tidak Hujan',
          flowSession: WaterFlowSession(
            id: 'flow-today',
            flowRateLpm: 12.0,
            durationMinutes: 15.0,
            totalVolumeLiters: 180.0,
            costIdr: 1450.0,
            timestamp: now,
          ),
        ),
        DailyRecapRecord(
          date: now
              .subtract(const Duration(days: 1))
              .toIso8601String()
              .split('T')[0],
          avgTemperature: 29.1,
          avgHumidity: 70.4,
          avgSoilMoisture: 35.0,
          avgTankLevel: 65.0,
          dominantRainStatus: 'Hujan',
          flowSession: WaterFlowSession(
            id: 'flow-yesterday',
            flowRateLpm: 11.5,
            durationMinutes: 20.0,
            totalVolumeLiters: 230.0,
            costIdr: 1900.0,
            timestamp: now.subtract(const Duration(days: 1)),
          ),
        ),
      ];
    }

    final response = await http.get(Uri.parse('$baseUrl/api/v1/recap/daily'));
    if (response.statusCode == 200) {
      List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((item) => DailyRecapRecord.fromJson(item)).toList();
    } else {
      throw Exception(
        'Failed to load daily recap records (${response.statusCode})',
      );
    }
  }
}
