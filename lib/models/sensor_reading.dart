
double _readRequiredDouble(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }

  throw FormatException(
    'Field "$key" tidak ditemukan atau bukan angka.',
  );
}

double? _readOptionalDouble(dynamic value) {
  if (value is num) return value.toDouble();

  if (value is String) {
    return double.tryParse(value);
  }

  return null;
}

bool? _readBool(dynamic value) {
  if (value is bool) return value;

  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'hujan':
        return true;

      case 'false':
      case '0':
      case 'no':
      case 'tidak hujan':
        return false;
    }
  }

  return null;
}

DateTime _readTimestamp(Map<String, dynamic> json) {
  final raw = json['recordedAt'] ??
      json['createdAt'] ??
      json['timestamp'];

  if (raw == null) {
    throw const FormatException(
      'Timestamp tidak ditemukan pada respons backend.',
    );
  }

  try {
    return DateTime.parse(raw.toString()).toLocal();
  } on FormatException {
    throw FormatException(
      'Format timestamp tidak valid: $raw',
    );
  }
}

String _readRequiredString(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];

  if (value == null || value.toString().trim().isEmpty) {
    throw FormatException(
      'Field "$key" tidak ditemukan pada respons backend.',
    );
  }

  return value.toString();
}

// ============================================================
// MODEL UMUM SENSOR
// ============================================================

class SensorReading {
  final double value;
  final DateTime timestamp;

  SensorReading({
    required this.value,
    required this.timestamp,
  });

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      value: _readRequiredDouble(json, 'value'),
      timestamp: _readTimestamp(json),
    );
  }
}

// ============================================================
// MODEL DHT - SUHU DAN KELEMBAPAN UDARA
// ============================================================

class DhtReading {
  final double temperature;
  final double humidity;
  final DateTime timestamp;

  DhtReading({
    required this.temperature,
    required this.humidity,
    required this.timestamp,
  });

  factory DhtReading.fromJson(Map<String, dynamic> json) {
    return DhtReading(
      temperature: _readRequiredDouble(json, 'temperature'),
      humidity: _readRequiredDouble(json, 'humidity'),
      timestamp: _readTimestamp(json),
    );
  }
}

// ============================================================
// MODEL SOIL MOISTURE - KELEMBAPAN TANAH
// ============================================================

class SoilReading {
  final double moistureValue;
  final String unit;
  final DateTime timestamp;

  SoilReading({
    required this.moistureValue,
    required this.unit,
    required this.timestamp,
  });

  /// Klasifikasi sementara dari aplikasi.
  ///
  /// Ambang 30 dan 70 masih perlu divalidasi
  /// dengan kalibrasi sensor dan firmware Landia Farm.
  String get condition {
    if (moistureValue < 30.0) {
      return 'Kering';
    }

    if (moistureValue < 70.0) {
      return 'Lembap';
    }

    return 'Basah';
  }

  factory SoilReading.fromJson(Map<String, dynamic> json) {
    return SoilReading(
      moistureValue: _readRequiredDouble(json, 'value'),
      unit: _readRequiredString(json, 'unit'),
      timestamp: _readTimestamp(json),
    );
  }
}

// ============================================================
// MODEL WATER LEVEL - LEVEL AIR TANGKI
// ============================================================

class TankLevelReading {
  /// Nilai asli yang dikirim backend.
  final double value;

  /// Satuan asli yang dikirim backend.
  final String unit;

  /// Jarak opsional. Belum disediakan entity backend saat ini.
  final double distanceCm;

  final bool hasDistanceCm;
  final DateTime timestamp;

  TankLevelReading({
    required this.value,
    required this.unit,
    this.distanceCm = 0.0,
    this.hasDistanceCm = false,
    required this.timestamp,
  });

  /// Kompatibilitas sementara dengan dashboard lama.
  /// Makna nilai harus mengikuti unit, bukan diasumsikan persen.
  double get percentage => value;

  factory TankLevelReading.fromJson(Map<String, dynamic> json) {
    final distance = _readOptionalDouble(json['distanceCm']);

    return TankLevelReading(
      value: _readRequiredDouble(json, 'value'),
      unit: _readRequiredString(json, 'unit'),
      distanceCm: distance ?? 0.0,
      hasDistanceCm: distance != null,
      timestamp: _readTimestamp(json),
    );
  }
}

// ============================================================
// MODEL RAIN SENSOR - SENSOR HUJAN
// ============================================================

class RainSensorReading {
  final double value;
  final String unit;

  /// Backend saat ini belum mengirim status hujan.
  final bool isRaining;
  final bool hasRainStatus;

  final DateTime timestamp;

  RainSensorReading({
    required this.value,
    required this.unit,
    this.isRaining = false,
    this.hasRainStatus = false,
    required this.timestamp,
  });

  String get statusText {
    if (hasRainStatus) {
      return isRaining ? 'Hujan' : 'Tidak Hujan';
    }

    return 'Nilai sensor: ${value.toStringAsFixed(1)} $unit';
  }

  factory RainSensorReading.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawStatus = json['isRaining'] ?? json['status'];
    final parsedStatus = _readBool(rawStatus);

    return RainSensorReading(
      value: _readRequiredDouble(json, 'value'),
      unit: _readRequiredString(json, 'unit'),
      isRaining: parsedStatus == true,
      hasRainStatus: parsedStatus != null,
      timestamp: _readTimestamp(json),
    );
  }
}

// ============================================================
// MODEL FLOW SENSOR - DEBIT ALIRAN AIR
// ============================================================

class WaterFlowSession {
  final String id;

  /// Nilai asli dari backend.
  final double value;

  /// Satuan asli dari backend.
  final String unit;

  /// Belum disediakan entity FlowReading.
  final double durationMinutes;
  final double totalVolumeLiters;
  final double costIdr;

  final bool hasDuration;
  final bool hasTotalVolume;
  final bool hasCost;

  final DateTime timestamp;

  WaterFlowSession({
    required this.id,
    required this.value,
    required this.unit,
    this.durationMinutes = 0.0,
    this.totalVolumeLiters = 0.0,
    this.costIdr = 0.0,
    this.hasDuration = false,
    this.hasTotalVolume = false,
    this.hasCost = false,
    required this.timestamp,
  });

  /// Kompatibilitas sementara dengan dashboard lama.
  double get flowRateLpm => value;

  factory WaterFlowSession.fromJson(
    Map<String, dynamic> json,
  ) {
    final duration = _readOptionalDouble(
      json['durationMinutes'],
    );

    final volume = _readOptionalDouble(
      json['totalVolumeLiters'],
    );

    final cost = _readOptionalDouble(
      json['costIdr'],
    );

    return WaterFlowSession(
      id: (json['id'] ?? json['sensorId'] ?? '').toString(),
      value: _readRequiredDouble(json, 'value'),
      unit: _readRequiredString(json, 'unit'),
      durationMinutes: duration ?? 0.0,
      totalVolumeLiters: volume ?? 0.0,
      costIdr: cost ?? 0.0,
      hasDuration: duration != null,
      hasTotalVolume: volume != null,
      hasCost: cost != null,
      timestamp: _readTimestamp(json),
    );
  }
}

// ============================================================
// MODEL DAILY RECAP - REKAPITULASI HARIAN
// ============================================================

/// Model disiapkan untuk endpoint agregasi harian.
/// Endpoint agregasi tersebut belum tersedia di backend.

class DailyRecapRecord {
  final String date;

  final double avgTemperature;
  final double avgHumidity;
  final double avgSoilMoisture;
  final double avgTankLevel;

  final String dominantRainStatus;
  final WaterFlowSession? flowSession;

  DailyRecapRecord({
    required this.date,
    required this.avgTemperature,
    required this.avgHumidity,
    required this.avgSoilMoisture,
    required this.avgTankLevel,
    required this.dominantRainStatus,
    this.flowSession,
  });

  factory DailyRecapRecord.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawFlowSession = json['flowSession'];

    return DailyRecapRecord(
      date: (json['date'] ?? '').toString(),
      avgTemperature: _readRequiredDouble(
        json,
        'avgTemperature',
      ),
      avgHumidity: _readRequiredDouble(
        json,
        'avgHumidity',
      ),
      avgSoilMoisture: _readRequiredDouble(
        json,
        'avgSoilMoisture',
      ),
      avgTankLevel: _readRequiredDouble(
        json,
        'avgTankLevel',
      ),
      dominantRainStatus: (
        json['dominantRainStatus'] ?? 'Tidak diketahui'
      ).toString(),
      flowSession: rawFlowSession is Map<String, dynamic>
          ? WaterFlowSession.fromJson(rawFlowSession)
          : null,
    );
  }
}
