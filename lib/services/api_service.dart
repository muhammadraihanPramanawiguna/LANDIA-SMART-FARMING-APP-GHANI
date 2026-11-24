import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/sensor_reading.dart';

class ThingsBoardSession {
  final String jwt;
  final String deviceId;
  final String deviceName;
  const ThingsBoardSession({required this.jwt, required this.deviceId, required this.deviceName});
}

class ApiService {
  ApiService({this.jwt = '', this.deviceId = '', http.Client? client})
      : _client = client ?? http.Client();

  static const String baseUrl = 'http://194.233.73.154:8080';
  final String jwt;
  final String deviceId;
  final http.Client _client;

  static Uri _url(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  static Future<Map<String, dynamic>> _requestJson(
    http.Client client, String method, Uri uri,
    {String? body, String? bearer, Map<String, String>? headers}
  ) async {
    final requestHeaders = <String, String>{'Accept': 'application/json', ...?headers};
    if (body != null) requestHeaders['Content-Type'] = 'application/json';
    if (bearer != null) requestHeaders['X-Authorization'] = 'Bearer $bearer';
    late http.Response response;
    if (method == 'POST') {
      response = await client.post(uri, headers: requestHeaders, body: body).timeout(const Duration(seconds: 12));
    } else {
      response = await client.get(uri, headers: requestHeaders).timeout(const Duration(seconds: 12));
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('ThingsBoard HTTP ${response.statusCode}: ${response.body}');
    }
    if (response.body.isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Respons ThingsBoard bukan JSON object.');
    return decoded;
  }

  static Future<ThingsBoardSession> loginAndFindDevice({
    required String username,
    required String password,
    String expectedDeviceName = 'Sensor C1',
  }) async {
    final client = http.Client();
    try {
      final login = await _requestJson(client, 'POST', _url('/api/auth/login'),
        body: jsonEncode({'username': username, 'password': password}));
      final jwt = login['token']?.toString();
      if (jwt == null || jwt.isEmpty) throw const FormatException('JWT tidak ditemukan pada respons login.');

      final user = await _requestJson(client, 'GET', _url('/api/auth/user'), bearer: jwt);
      final customer = user['customer'];
      final customerId = customer is Map ? customer['id'] : user['customerId'];
      final customerUuid = customerId is Map ? customerId['id']?.toString() : customerId?.toString();
      if (customerUuid == null || customerUuid.isEmpty || customerUuid == 'null') {
        throw Exception('Akun berhasil login, tetapi customerId tidak ditemukan. Pastikan akun memiliki akses Customer ke device.');
      }

      final devices = await _requestJson(client, 'GET',
        _url('/api/customer/$customerUuid/devices', {'pageSize': '100', 'page': '0'}), bearer: jwt);
      final data = devices['data'];
      if (data is! List) throw const FormatException('Daftar device ThingsBoard tidak valid.');
      for (final item in data) {
        if (item is! Map) continue;
        if (item['name']?.toString() == expectedDeviceName) {
          final id = item['id'];
          final uuid = id is Map ? id['id']?.toString() : null;
          if (uuid != null && uuid.isNotEmpty) {
            return ThingsBoardSession(jwt: jwt, deviceId: uuid, deviceName: expectedDeviceName);
          }
        }
      }
      throw Exception('Device "$expectedDeviceName" tidak ditemukan pada daftar device milik akun Customer.');
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _latest(List<String> keys) async {
    final json = await _requestJson(_client, 'GET',
      _url('/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries', {
        'keys': keys.join(','), 'limit': '1'
      }), bearer: jwt);
    return json;
  }

  (double, DateTime)? _point(Map<String, dynamic> json, String key) {
    final values = json[key];
    if (values is! List || values.isEmpty || values.first is! Map) return null;
    final point = values.first as Map;
    final value = double.tryParse(point['value'].toString());
    final ts = int.tryParse(point['ts'].toString());
    if (value == null || ts == null) return null;
    return (value, DateTime.fromMillisecondsSinceEpoch(ts).toLocal());
  }

  Future<DhtReading> fetchLatestDht([String ignored = '']) async {
    final json = await _latest(['temperature', 'humidity']);
    final t = _point(json, 'temperature'); final h = _point(json, 'humidity');
    if (t == null || h == null) throw const FormatException('Telemetry temperature/humidity belum tersedia.');
    return DhtReading(temperature: t.$1, humidity: h.$1, timestamp: t.$2.isAfter(h.$2) ? t.$2 : h.$2);
  }

  Future<SoilReading> fetchLatestSoil([String ignored = '']) async {
    final json = await _latest(['soil_moisture']); final p = _point(json, 'soil_moisture');
    if (p == null) throw const FormatException('Telemetry soil_moisture belum tersedia.');
    return SoilReading(moistureValue: p.$1, unit: '%', timestamp: p.$2);
  }

  Future<TankLevelReading> fetchLatestTankLevel([String ignored = '']) async {
    final json = await _latest(['water_level_distance_cm', 'water_level_percent']);
    final percent = _point(json, 'water_level_percent'); final distance = _point(json, 'water_level_distance_cm');
    if (percent == null && distance == null) throw const FormatException('Telemetry level air belum tersedia.');
    return TankLevelReading(value: percent?.$1 ?? distance!.$1, unit: percent != null ? '%' : 'cm',
      distanceCm: distance?.$1 ?? 0, hasDistanceCm: distance != null, timestamp: percent?.$2 ?? distance!.$2);
  }

  Future<RainSensorReading> fetchLatestRain([String ignored = '']) async {
    final json = await _latest(['rain_percent', 'is_raining']);
    final p = _point(json, 'rain_percent'); final r = _point(json, 'is_raining');
    if (p == null && r == null) throw const FormatException('Telemetry hujan belum tersedia.');
    return RainSensorReading(value: p?.$1 ?? r!.$1, unit: p != null ? '%' : 'boolean',
      isRaining: (r?.$1 ?? 0) != 0, hasRainStatus: r != null, timestamp: p?.$2 ?? r!.$2);
  }

  Future<WaterFlowSession> fetchLatestWaterFlow([String ignored = '']) async {
    final json = await _latest(['flow_rate', 'total_water_liters']);
    final rate = _point(json, 'flow_rate'); final total = _point(json, 'total_water_liters');
    if (rate == null && total == null) throw const FormatException('Telemetry debit air belum tersedia.');
    return WaterFlowSession(id: deviceId, value: rate?.$1 ?? 0, unit: 'L/min',
      totalVolumeLiters: total?.$1 ?? 0, hasTotalVolume: total != null,
      timestamp: rate?.$2 ?? total!.$2);
  }

  Future<List<DailyRecapRecord>> fetchDailyRecaps() async =>
      throw UnsupportedError('Rekap harian agregat belum dibuat. Dashboard telemetry ThingsBoard sudah digunakan.');

  void dispose() => _client.close();
}
