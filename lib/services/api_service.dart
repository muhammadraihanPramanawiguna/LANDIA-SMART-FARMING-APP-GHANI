
import 'dart:async';
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

  static const String baseUrl = String.fromEnvironment(
    'TB_BASE_URL',
    defaultValue: 'http://194.233.73.154:8080',
  );

  static const String deviceName = 'Sensor C1';

  static const String dhtSensorId = 'dht';
  static const String soilSensorId = 'soil';
  static const String waterLevelSensorId = 'water_level';
  static const String rainSensorId = 'rain';
  static const String flowSensorId = 'flow';

  static const List<String> telemetryKeys = [
    'temperature',
    'humidity',
    'soil_moisture',
    'rain_percent',
    'is_raining',
    'flow_rate',
    'total_water_liters',
    'water_consumption_m3',
    'water_cost_rupiah',
    'water_level_distance_cm',
    'water_level_percent',
    'water_tariff_rupiah_per_m3',
  ];

  final String jwt;
  final String deviceId;
  final http.Client _client;

  Future<Map<String, dynamic>>? _telemetryRequest;

  static Uri _url(
    String path, [
    Map<String, String>? query,
  ]) {
    return Uri.parse('$baseUrl$path').replace(
      queryParameters: query,
    );
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    String? body,
    String? bearer,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }

    if (bearer != null && bearer.isNotEmpty) {
      headers['X-Authorization'] = 'Bearer $bearer';
    }

    late http.Response response;

    if (method == 'POST') {
      response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 12));
    } else {
      response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));
    }

    if (response.statusCode < 200 ||
        response.statusCode >= 300) {
      throw Exception(
        'ThingsBoard HTTP ${response.statusCode}: ${response.body}',
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

  static Future<ThingsBoardSession> loginAndFindDevice({
    required String username,
    required String password,
    String expectedDeviceName = 'Sensor C1',
  }) async {
    final client = http.Client();

    Future<Map<String, dynamic>> request(
      String method,
      Uri uri, {
      String? body,
      String? bearer,
    }) async {
      final headers = <String, String>{
        'Accept': 'application/json',
      };

      if (body != null) {
        headers['Content-Type'] = 'application/json';
      }

      if (bearer != null) {
        headers['X-Authorization'] = 'Bearer $bearer';
      }

      late http.Response response;

      if (method == 'POST') {
        response = await client.post(
          uri,
          headers: headers,
          body: body,
        ).timeout(const Duration(seconds: 12));
      } else {
        response = await client.get(
          uri,
          headers: headers,
        ).timeout(const Duration(seconds: 12));
      }

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw Exception(
          'ThingsBoard HTTP ${response.statusCode}: ${response.body}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Respons ThingsBoard tidak valid.',
        );
      }

      return decoded;
    }

    try {
      final login = await request(
        'POST',
        _url('/api/auth/login'),
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final token = login['token']?.toString();

      if (token == null || token.isEmpty) {
        throw const FormatException(
          'JWT tidak ditemukan.',
        );
      }

      final user = await request(
        'GET',
        _url('/api/auth/user'),
        bearer: token,
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
          'Customer ID tidak ditemukan.',
        );
      }

      final devices = await request(
        'GET',
        _url(
          '/api/customer/$customerUuid/devices',
          {
            'pageSize': '100',
            'page': '0',
          },
        ),
        bearer: token,
      );

      final data = devices['data'];

      if (data is! List) {
        throw const FormatException(
          'Daftar perangkat ThingsBoard tidak valid.',
        );
      }

      for (final item in data) {
        if (item is! Map) continue;

        if (item['name']?.toString() != expectedDeviceName) {
          continue;
        }

        final id = item['id'];
        final uuid = id is Map
            ? id['id']?.toString()
            : null;

        if (uuid != null && uuid.isNotEmpty) {
          return ThingsBoardSession(
            jwt: token,
            deviceId: uuid,
            deviceName: expectedDeviceName,
          );
        }
      }

      throw Exception(
        'Device $expectedDeviceName tidak ditemukan pada akun Customer.',
      );
    } finally {
      client.close();
    }
  }

  // ============================================================
  // FETCH ALL TELEMETRY - SATU REQUEST UNTUK SEMUA SENSOR
  // ============================================================

  Future<Map<String, dynamic>> fetchAllTelemetry() {
    if (_telemetryRequest != null) {
      return _telemetryRequest!;
    }

    final request = _requestJson(
      'GET',
      _url(
        '/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries',
        {
          'keys': telemetryKeys.join(','),
          'limit': '1',
        },
      ),
      bearer: jwt,
    );

    _telemetryRequest = request;

    return request.whenComplete(() {
      _telemetryRequest = null;
    });
  }

  // ============================================================
  // PARSING TELEMETRY
  // ============================================================

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
      point['value']?.toString() ?? '',
    );

    final ts = int.tryParse(
      point['ts']?.toString() ?? '',
    );

    if (value == null || ts == null) return null;

    return (
      value,
      DateTime.fromMillisecondsSinceEpoch(ts).toLocal(),
    );
  }

  (bool, DateTime)? _boolPoint(
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

    final raw = point['value']
        ?.toString()
        .trim()
        .toLowerCase();

    final ts = int.tryParse(
      point['ts']?.toString() ?? '',
    );

    if (raw == null || ts == null) return null;

    bool? value;

    if (raw == 'true' || raw == '1') {
      value = true;
    } else if (raw == 'false' || raw == '0') {
      value = false;
    }

    if (value == null) return null;

    return (
      value,
      DateTime.fromMillisecondsSinceEpoch(ts).toLocal(),
    );
  }

  // ============================================================
  // DHT11
  // ============================================================

  Future<DhtReading> fetchLatestDht([
    String ignored = '',
  ]) async {
    final json = await fetchAllTelemetry();

    final temperature = _point(json, 'temperature');
    final humidity = _point(json, 'humidity');

    if (temperature == null || humidity == null) {
      throw const FormatException(
        'Telemetry DHT belum lengkap.',
      );
    }

    return DhtReading(
      temperature: temperature.$1,
      humidity: humidity.$1,
      timestamp: temperature.$2.isAfter(humidity.$2)
          ? temperature.$2
          : humidity.$2,
    );
  }

  // ============================================================
  // SOIL MOISTURE
  // ============================================================

  Future<SoilReading> fetchLatestSoil([
    String ignored = '',
  ]) async {
    final json = await fetchAllTelemetry();
    final point = _point(json, 'soil_moisture');

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

  // ============================================================
  // WATER LEVEL
  // ============================================================

  Future<TankLevelReading> fetchLatestTankLevel([
    String ignored = '',
  ]) async {
    final json = await fetchAllTelemetry();

    final percent = _point(json, 'water_level_percent');
    final distance = _point(json, 'water_level_distance_cm');

    if (percent == null && distance == null) {
      throw const FormatException(
        'Telemetry level air belum tersedia.',
      );
    }

    final timestamps = [
      if (percent != null) percent.$2,
      if (distance != null) distance.$2,
    ]..sort((a, b) => b.compareTo(a));

    return TankLevelReading(
      value: percent?.$1 ?? distance!.$1,
      unit: percent != null ? '%' : 'cm',
      distanceCm: distance?.$1 ?? 0,
      hasDistanceCm: distance != null,
      timestamp: timestamps.first,
    );
  }

  // ============================================================
  // RAIN SENSOR
  // ============================================================

  Future<RainSensorReading> fetchLatestRain([
    String ignored = '',
  ]) async {
    final json = await fetchAllTelemetry();

    final percent = _point(json, 'rain_percent');
    final status = _boolPoint(json, 'is_raining');

    if (percent == null && status == null) {
      throw const FormatException(
        'Telemetry hujan belum tersedia.',
      );
    }

    final timestamps = [
      if (percent != null) percent.$2,
      if (status != null) status.$2,
    ]..sort((a, b) => b.compareTo(a));

    return RainSensorReading(
      value: percent?.$1 ?? 0,
      unit: '%',
      isRaining: status?.$1 ?? false,
      hasRainStatus: status != null,
      timestamp: timestamps.first,
    );
  }

  // ============================================================
  // FLOW SENSOR
  // ============================================================

  Future<WaterFlowSession> fetchLatestWaterFlow([
    String ignored = '',
  ]) async {
    final json = await fetchAllTelemetry();

    final rate = _point(json, 'flow_rate');
    final total = _point(json, 'total_water_liters');
    final consumption = _point(json, 'water_consumption_m3');
    final cost = _point(json, 'water_cost_rupiah');
    final tariff = _point(json, 'water_tariff_rupiah_per_m3');

    if (rate == null &&
        total == null &&
        consumption == null &&
        cost == null &&
        tariff == null) {
      throw const FormatException(
        'Telemetry flow sensor belum tersedia.',
      );
    }

    final timestamps = [
      if (rate != null) rate.$2,
      if (total != null) total.$2,
      if (consumption != null) consumption.$2,
      if (cost != null) cost.$2,
      if (tariff != null) tariff.$2,
    ]..sort((a, b) => b.compareTo(a));

    return WaterFlowSession(
      id: deviceId,
      value: rate?.$1 ?? 0,
      unit: 'L/min',
      totalVolumeLiters: total?.$1 ?? 0,
      hasTotalVolume: total != null,
      consumptionM3: consumption?.$1 ?? 0,
      hasConsumptionM3: consumption != null,
      costIdr: cost?.$1 ?? 0,
      hasCost: cost != null,
      tariffPerM3: tariff?.$1 ?? 0,
      hasTariff: tariff != null,
      timestamp: timestamps.first,
    );
  }

  // ============================================================
  // DAILY RECAP
  // ============================================================

  Future<List<DailyRecapRecord>> fetchDailyRecaps() async {
    throw UnsupportedError(
      'Rekap harian belum diimplementasikan. '
      'Data historis ThingsBoard perlu diambil dan diagregasi.',
    );
  }

  void dispose() {
    _client.close();
  }
}
