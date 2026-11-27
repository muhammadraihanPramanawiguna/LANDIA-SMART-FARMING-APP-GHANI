import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/sensor_reading.dart';

class ThingsBoardSession {
  final String jwt;
  final String deviceId;
  final String deviceName;

  const ThingsBoardSession({
    required this.jwt,
    required this.deviceId,
    required this.deviceName,
  });
}

class ApiService {
  ApiService({
    this.jwt = '',
    this.deviceId = '',
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const String baseUrl =
      'http://194.233.73.154:8080';

  final String jwt;
  final String deviceId;
  final http.Client _client;

  static const Duration requestTimeout =
      Duration(seconds: 20);

  static Uri _url(
    String path, [
    Map<String, String>? query,
  ]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query,
    );
  }

  // ==========================================================
  // HTTP REQUEST
  // ==========================================================

  static Future<Map<String, dynamic>> _requestJson(
    http.Client client,
    String method,
    Uri uri, {
    String? body,
    String? bearer,
    Map<String, String>? headers,
  }) async {
    final requestHeaders = <String, String>{
      'Accept': 'application/json',
      ...?headers,
    };

    if (body != null) {
      requestHeaders['Content-Type'] =
          'application/json';
    }

    if (bearer != null && bearer.isNotEmpty) {
      requestHeaders['X-Authorization'] =
          'Bearer $bearer';
    }

    late http.Response response;

    try {
      if (method == 'POST') {
        response = await client
            .post(
              uri,
              headers: requestHeaders,
              body: body,
            )
            .timeout(requestTimeout);
      } else {
        response = await client
            .get(
              uri,
              headers: requestHeaders,
            )
            .timeout(requestTimeout);
      }
    } catch (e) {
      throw Exception(
        'Gagal menghubungi ThingsBoard: $e',
      );
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'ThingsBoard HTTP ${response.statusCode}: '
        '${response.body}',
      );
    }

    if (response.body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        'Respons ThingsBoard bukan JSON object.',
      );
    }

    return decoded;
  }

  // ==========================================================
  // LOGIN + FIND DEVICE
  // ==========================================================

  static Future<ThingsBoardSession>
      loginAndFindDevice({
    required String username,
    required String password,
    String expectedDeviceName = 'Sensor C1',
  }) async {
    final client = http.Client();

    try {
      final login = await _requestJson(
        client,
        'POST',
        _url('/api/auth/login'),
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final jwt = login['token']?.toString();

      if (jwt == null || jwt.isEmpty) {
        throw const FormatException(
          'JWT tidak ditemukan pada respons login.',
        );
      }

      final user = await _requestJson(
        client,
        'GET',
        _url('/api/auth/user'),
        bearer: jwt,
      );

      final customer = user['customer'];

      final customerId = customer is Map
          ? customer['id']
          : user['customerId'];

      final customerUuid = customerId is Map
          ? customerId['id']?.toString()
          : customerId?.toString();

      if (customerUuid == null ||
          customerUuid.isEmpty ||
          customerUuid == 'null') {
        throw Exception(
          'Customer ID tidak ditemukan. '
          'Pastikan akun memiliki akses ke device.',
        );
      }

      final devices = await _requestJson(
        client,
        'GET',
        _url(
          '/api/customer/$customerUuid/devices',
          {
            'pageSize': '100',
            'page': '0',
          },
        ),
        bearer: jwt,
      );

      final data = devices['data'];

      if (data is! List) {
        throw const FormatException(
          'Daftar device ThingsBoard tidak valid.',
        );
      }

      for (final item in data) {
        if (item is! Map) continue;

        if (item['name']?.toString() ==
            expectedDeviceName) {
          final id = item['id'];

          final uuid = id is Map
              ? id['id']?.toString()
              : null;

          if (uuid != null && uuid.isNotEmpty) {
            return ThingsBoardSession(
              jwt: jwt,
              deviceId: uuid,
              deviceName: expectedDeviceName,
            );
          }
        }
      }

      throw Exception(
        'Device "$expectedDeviceName" tidak ditemukan.',
      );
    } finally {
      client.close();
    }
  }

  // ==========================================================
  // LATEST TELEMETRY
  // ==========================================================

  Future<Map<String, dynamic>> _latest(
    List<String> keys,
  ) async {
    return _requestJson(
      _client,
      'GET',
      _url(
        '/api/plugins/telemetry/DEVICE/'
        '$deviceId/values/timeseries',
        {
          'keys': keys.join(','),
          'limit': '1',
        },
      ),
      bearer: jwt,
    );
  }

  (double, DateTime)? _point(
    Map<String, dynamic> json,
    String key,
  ) {
    final values = json[key];

    if (values is! List ||
        values.isEmpty ||
        values.first is! Map) {
      return null;
    }

    final point = values.first as Map;

    final value = double.tryParse(
      point['value'].toString(),
    );

    final ts = int.tryParse(
      point['ts'].toString(),
    );

    if (value == null || ts == null) {
      return null;
    }

    return (
      value,
      DateTime.fromMillisecondsSinceEpoch(ts)
          .toLocal(),
    );
  }

  // ==========================================================
  // DHT
  // ==========================================================

  Future<DhtReading> fetchLatestDht([
    String ignored = '',
  ]) async {
    final json = await _latest([
      'temperature',
      'humidity',
    ]);

    final temperature =
        _point(json, 'temperature');

    final humidity =
        _point(json, 'humidity');

    if (temperature == null ||
        humidity == null) {
      throw const FormatException(
        'Telemetry temperature/humidity belum tersedia.',
      );
    }

    final timestamp =
        temperature.$2.isAfter(humidity.$2)
            ? temperature.$2
            : humidity.$2;

    return DhtReading(
      temperature: temperature.$1,
      humidity: humidity.$1,
      timestamp: timestamp,
    );
  }

  // ==========================================================
  // SOIL
  // ==========================================================

  Future<SoilReading> fetchLatestSoil([
    String ignored = '',
  ]) async {
    final json = await _latest([
      'soil_moisture',
    ]);

    final point =
        _point(json, 'soil_moisture');

    if (point == null) {
      throw const FormatException(
        'Telemetry soil_moisture belum tersedia.',
      );
    }

    return SoilReading(
      moistureValue: point.$1,
      unit: '%',
      timestamp: point.$2,
    );
  }

  // ==========================================================
  // TANK
  // ==========================================================

  Future<TankLevelReading>
      fetchLatestTankLevel([
    String ignored = '',
  ]) async {
    final json = await _latest([
      'water_level_distance_cm',
      'water_level_percent',
    ]);

    final percent =
        _point(json, 'water_level_percent');

    final distance =
        _point(json, 'water_level_distance_cm');

    if (percent == null && distance == null) {
      throw const FormatException(
        'Telemetry level air belum tersedia.',
      );
    }

    return TankLevelReading(
      value: percent?.$1 ?? distance!.$1,
      unit: percent != null ? '%' : 'cm',
      distanceCm: distance?.$1 ?? 0,
      hasDistanceCm: distance != null,
      timestamp: percent?.$2 ?? distance!.$2,
    );
  }

  // ==========================================================
  // RAIN
  // ==========================================================

  Future<RainSensorReading> fetchLatestRain([
    String ignored = '',
  ]) async {
    final json = await _latest([
      'rain_percent',
      'is_raining',
    ]);

    final rainPercent =
        _point(json, 'rain_percent');

    final rainStatus =
        _point(json, 'is_raining');

    if (rainPercent == null &&
        rainStatus == null) {
      throw const FormatException(
        'Telemetry hujan belum tersedia.',
      );
    }

    return RainSensorReading(
      value: rainPercent?.$1 ??
          rainStatus!.$1,
      unit: rainPercent != null
          ? '%'
          : 'boolean',
      isRaining:
          (rainStatus?.$1 ?? 0) != 0,
      hasRainStatus:
          rainStatus != null,
      timestamp:
          rainPercent?.$2 ?? rainStatus!.$2,
    );
  }

  // ==========================================================
  // FLOW
  // ==========================================================

  Future<WaterFlowSession>
      fetchLatestWaterFlow([
    String ignored = '',
  ]) async {
    final json = await _latest([
      'flow_rate',
      'total_water_liters',
    ]);

    final rate =
        _point(json, 'flow_rate');

    final total =
        _point(json, 'total_water_liters');

    if (rate == null && total == null) {
      throw const FormatException(
        'Telemetry debit air belum tersedia.',
      );
    }

    return WaterFlowSession(
      id: deviceId,
      value: rate?.$1 ?? 0,
      unit: 'L/min',
      totalVolumeLiters:
          total?.$1 ?? 0,
      hasTotalVolume:
          total != null,
      timestamp:
          rate?.$2 ?? total!.$2,
    );
  }

  // ==========================================================
  // HISTORICAL TELEMETRY
  // ==========================================================

  Future<Map<String, List<Map<String, dynamic>>>>
      fetchHistoricalTelemetry({
    required DateTime start,
    required DateTime end,
    required List<String> keys,
  }) async {
    final startTs =
        start.millisecondsSinceEpoch;

    final endTs =
        end.millisecondsSinceEpoch;

    final result = await _requestJson(
      _client,
      'GET',
      _url(
        '/api/plugins/telemetry/DEVICE/'
        '$deviceId/values/timeseries',
        {
          'keys': keys.join(','),
          'startTs': startTs.toString(),
          'endTs': endTs.toString(),
          'limit': '10000',
          'orderBy': 'ASC',
        },
      ),
      bearer: jwt,
    );

    final parsed =
        <String, List<Map<String, dynamic>>>{};

    for (final key in keys) {
      final raw = result[key];

      if (raw is List) {
        parsed[key] = raw
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(
                item,
              ),
            )
            .toList();
      } else {
        parsed[key] = [];
      }
    }

    return parsed;
  }

  // ==========================================================
  // DAILY RECAP
  // ==========================================================

  Future<DailyRecapRecord>
      fetchDailyRecapForDate(
    DateTime selectedDate,
  ) async {
    final date = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );

    final start = date;

    final end = DateTime(
      date.year,
      date.month,
      date.day + 1,
    );

    final keys = [
      'temperature',
      'humidity',
      'soil_moisture',
      'water_level_percent',
      'rain_percent',
      'is_raining',
      'flow_rate',
      'total_water_liters',
      'water_consumption_m3',
      'water_cost_rupiah',
    ];

    final historical =
        await fetchHistoricalTelemetry(
      start: start,
      end: end,
      keys: keys,
    );

    // --------------------------------------------------------
    // PARSING
    // --------------------------------------------------------

    List<double> values(String key) {
      return historical[key]!
          .map((item) {
            return double.tryParse(
              item['value'].toString(),
            );
          })
          .whereType<double>()
          .where((value) => value.isFinite)
          .toList();
    }

    double average(List<double> list) {
      if (list.isEmpty) return 0;

      return list.reduce((a, b) => a + b) /
          list.length;
    }

    double? minimum(List<double> list) {
      if (list.isEmpty) return null;

      return list.reduce(
        (a, b) => a < b ? a : b,
      );
    }

    double? maximum(List<double> list) {
      if (list.isEmpty) return null;

      return list.reduce(
        (a, b) => a > b ? a : b,
      );
    }

    final temperatures =
        values('temperature');

    final humidities =
        values('humidity');

    final soils =
        values('soil_moisture');

    final tanks =
        values('water_level_percent');

    final rains =
        values('is_raining');

    final rainPercent =
        values('rain_percent');

    final flowRates =
        values('flow_rate');

    final totalWater =
        values('total_water_liters');

    final waterConsumption =
        values('water_consumption_m3');

    final waterCost =
        values('water_cost_rupiah');

    // --------------------------------------------------------
    // DOMINANT RAIN STATUS
    // --------------------------------------------------------

    String rainStatus;

    if (rains.isNotEmpty) {
      final rainingCount = rains
          .where((value) => value != 0)
          .length;

      rainStatus = rainingCount >=
              (rains.length / 2)
          ? 'Hujan'
          : 'Tidak Hujan';
    } else if (rainPercent.isNotEmpty) {
      rainStatus =
          'Data sensor hujan tersedia';
    } else {
      rainStatus = 'Tidak tersedia';
    }

    // --------------------------------------------------------
    // WATER USAGE
    // --------------------------------------------------------

    double totalVolume = 0;
    bool hasVolume = false;

    if (totalWater.length >= 2) {
      final first = totalWater.first;
      final last = totalWater.last;

      // Telemetry total diasumsikan cumulative counter.
      // Jika counter reset, jangan hasilkan nilai negatif.
      final delta = last - first;

      if (delta >= 0) {
        totalVolume = delta;
        hasVolume = true;
      }
    } else if (waterConsumption.isNotEmpty) {
      // Jika telemetry berupa m3.
      totalVolume =
          waterConsumption.last * 1000;

      hasVolume = true;
    }

    double totalCost = 0;
    bool hasCost = false;

    if (waterCost.length >= 2) {
      final delta =
          waterCost.last - waterCost.first;

      if (delta >= 0) {
        totalCost = delta;
        hasCost = true;
      }
    } else if (waterCost.length == 1) {
      totalCost = waterCost.first;
      hasCost = true;
    }

    double flowAverage =
        average(flowRates);

    final flowSession =
        flowRates.isEmpty &&
                !hasVolume &&
                !hasCost
            ? null
            : WaterFlowSession(
                id: deviceId,
                value: flowAverage,
                unit: 'L/min',
                totalVolumeLiters:
                    totalVolume,
                costIdr: totalCost,
                hasTotalVolume:
                    hasVolume,
                hasCost:
                    hasCost,
                timestamp: date,
              );

    // --------------------------------------------------------
    // TOTAL DATA POINTS
    // --------------------------------------------------------

    final totalDataPoints = [
      temperatures.length,
      humidities.length,
      soils.length,
      tanks.length,
      rains.length,
      rainPercent.length,
      flowRates.length,
      totalWater.length,
    ].fold<int>(
      0,
      (sum, count) => sum + count,
    );

    // --------------------------------------------------------
    // CREATE RECORD
    // --------------------------------------------------------

    return DailyRecapRecord(
      date:
          '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',

      avgTemperature:
          average(temperatures),

      avgHumidity:
          average(humidities),

      avgSoilMoisture:
          average(soils),

      avgTankLevel:
          average(tanks),

      dominantRainStatus:
          rainStatus,

      flowSession:
          flowSession,

      totalDataPoints:
          totalDataPoints,

      temperatureDataPoints:
          temperatures.length,

      humidityDataPoints:
          humidities.length,

      soilDataPoints:
          soils.length,

      tankDataPoints:
          tanks.length,

      minTemperature:
          minimum(temperatures),

      maxTemperature:
          maximum(temperatures),

      minHumidity:
          minimum(humidities),

      maxHumidity:
          maximum(humidities),

      minSoilMoisture:
          minimum(soils),

      maxSoilMoisture:
          maximum(soils),

      minTankLevel:
          minimum(tanks),

      maxTankLevel:
          maximum(tanks),

      hasTemperature:
          temperatures.isNotEmpty,

      hasHumidity:
          humidities.isNotEmpty,

      hasSoilMoisture:
          soils.isNotEmpty,

      hasTankLevel:
          tanks.isNotEmpty,
    );
  }

  // ==========================================================
  // DAILY RECAP LIST
  // ==========================================================

  Future<List<DailyRecapRecord>>
      fetchDailyRecaps() async {
    final today = DateTime.now();

    final recap =
        await fetchDailyRecapForDate(today);

    return [recap];
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  void dispose() {
    _client.close();
  }
}