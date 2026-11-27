import 'package:flutter/foundation.dart';

// ============================================================
// HELPER PARSING
// ============================================================

/// Parsing angka secara aman.
///
/// Mendukung:
/// - int
/// - double
/// - String angka
///
/// Mengembalikan null jika data tidak valid.
double? _parseDouble(dynamic value) {
  if (value == null) return null;

  if (value is double) {
    return value.isFinite ? value : null;
  }

  if (value is int) {
    return value.toDouble();
  }

  if (value is num) {
    final result = value.toDouble();

    return result.isFinite ? result : null;
  }

  if (value is String) {
    final normalized = value.trim();

    if (normalized.isEmpty) return null;

    final result = double.tryParse(normalized);

    if (result == null || !result.isFinite) {
      return null;
    }

    return result;
  }

  return null;
}

/// Parsing angka yang wajib tersedia.
///
/// Jika data tidak valid, throw FormatException.
double _readRequiredDouble(
  Map<String, dynamic> json,
  String key,
) {
  final value = _parseDouble(json[key]);

  if (value == null) {
    throw FormatException(
      'Field "$key" tidak valid atau tidak tersedia.',
    );
  }

  return value;
}

/// Parsing angka optional.
///
/// Jika tidak tersedia atau invalid, return null.
double? _readOptionalDouble(dynamic value) {
  return _parseDouble(value);
}

/// Parsing timestamp.
///
/// Mendukung:
/// - ts dalam milliseconds epoch
/// - timestamp dalam milliseconds epoch
/// - timestamp berupa ISO 8601 string
/// - dateTime berupa ISO 8601 string
///
/// Jika timestamp tidak tersedia, menggunakan waktu sekarang.
DateTime _readTimestamp(
  Map<String, dynamic> json,
) {
  final rawTimestamp =
      json['ts'] ??
      json['timestamp'] ??
      json['dateTime'];

  if (rawTimestamp == null) {
    return DateTime.now();
  }

  // Timestamp numeric / epoch milliseconds.
  if (rawTimestamp is num) {
    final value = rawTimestamp.toInt();

    try {
      return DateTime.fromMillisecondsSinceEpoch(
        value,
        isUtc: true,
      ).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  // Timestamp dalam String.
  if (rawTimestamp is String) {
    final value = rawTimestamp.trim();

    if (value.isEmpty) {
      return DateTime.now();
    }

    // String angka dianggap epoch milliseconds.
    final numeric = int.tryParse(value);

    if (numeric != null) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(
          numeric,
          isUtc: true,
        ).toLocal();
      } catch (_) {
        return DateTime.now();
      }
    }

    // String ISO 8601.
    final parsed = DateTime.tryParse(value);

    if (parsed != null) {
      return parsed.toLocal();
    }
  }

  return DateTime.now();
}

// ============================================================
// MODEL DATA SENSOR UMUM
// ============================================================

/// Model data sensor Landia Farm.
///
/// Parsing telemetry ThingsBoard dilakukan di ApiService.
/// Model ini hanya menyimpan data yang digunakan aplikasi.
@immutable
class SensorReading {
  final double value;
  final DateTime timestamp;

  const SensorReading({
    required this.value,
    required this.timestamp,
  });

  factory SensorReading.fromJson(
    Map<String, dynamic> json,
  ) {
    return SensorReading(
      value: _readRequiredDouble(
        json,
        'value',
      ),
      timestamp: _readTimestamp(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ============================================================
// DHT11 - SUHU DAN KELEMBAPAN UDARA
// ============================================================

@immutable
class DhtReading {
  final double temperature;
  final double humidity;
  final DateTime timestamp;

  const DhtReading({
    required this.temperature,
    required this.humidity,
    required this.timestamp,
  });

  factory DhtReading.fromJson(
    Map<String, dynamic> json,
  ) {
    return DhtReading(
      temperature: _readRequiredDouble(
        json,
        'temperature',
      ),
      humidity: _readRequiredDouble(
        json,
        'humidity',
      ),
      timestamp: _readTimestamp(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ============================================================
// SOIL MOISTURE - KELEMBAPAN TANAH
// ============================================================

@immutable
class SoilReading {
  final double moistureValue;
  final String unit;
  final DateTime timestamp;

  const SoilReading({
    required this.moistureValue,
    required this.unit,
    required this.timestamp,
  });

  factory SoilReading.fromJson(
    Map<String, dynamic> json,
  ) {
    return SoilReading(
      moistureValue: _readRequiredDouble(
        json,
        'moistureValue',
      ),
      unit: (json['unit'] ?? '%').toString(),
      timestamp: _readTimestamp(json),
    );
  }

  /// Klasifikasi sementara.
  ///
  /// Harus divalidasi dengan kalibrasi sensor
  /// kelembapan tanah di kondisi lapangan.
  String get condition {
    if (moistureValue < 30) {
      return 'Kering';
    }

    if (moistureValue < 70) {
      return 'Lembap';
    }

    return 'Basah';
  }

  Map<String, dynamic> toJson() {
    return {
      'moistureValue': moistureValue,
      'unit': unit,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ============================================================
// JSN-SR04M - LEVEL AIR TANGKI
// ============================================================

@immutable
class TankLevelReading {
  /// Nilai utama yang ditampilkan dashboard.
  ///
  /// Bisa berupa persentase level air atau jarak,
  /// tergantung telemetry yang digunakan ApiService.
  final double value;

  final String unit;

  /// Jarak sensor ke permukaan air.
  final double distanceCm;

  /// Apakah jarak tersedia.
  final bool hasDistanceCm;

  final DateTime timestamp;

  const TankLevelReading({
    required this.value,
    required this.unit,
    this.distanceCm = 0,
    this.hasDistanceCm = false,
    required this.timestamp,
  });

  factory TankLevelReading.fromJson(
    Map<String, dynamic> json,
  ) {
    final distance =
        _readOptionalDouble(
      json['distanceCm'],
    );

    return TankLevelReading(
      value: _readRequiredDouble(
        json,
        'value',
      ),
      unit: (json['unit'] ?? '%').toString(),
      distanceCm: distance ?? 0,
      hasDistanceCm: distance != null,
      timestamp: _readTimestamp(json),
    );
  }

  /// Alias untuk nilai persentase.
  ///
  /// Jika value bukan persentase, getter ini
  /// tetap mengembalikan value sesuai model.
  double get percentage => value;

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'unit': unit,
      'distanceCm': hasDistanceCm
          ? distanceCm
          : null,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ============================================================
// RAIN SENSOR - SENSOR HUJAN
// ============================================================

@immutable
class RainSensorReading {
  /// Telemetry rain_percent.
  final double value;

  final String unit;

  /// Telemetry is_raining.
  final bool isRaining;

  /// Menandakan apakah telemetry status hujan tersedia.
  final bool hasRainStatus;

  final DateTime timestamp;

  const RainSensorReading({
    required this.value,
    required this.unit,
    this.isRaining = false,
    this.hasRainStatus = false,
    required this.timestamp,
  });

  factory RainSensorReading.fromJson(
    Map<String, dynamic> json,
  ) {
    final rainStatus =
        _parseRainStatus(
      json['isRaining'],
    );

    return RainSensorReading(
      value: _readRequiredDouble(
        json,
        'value',
      ),
      unit: (json['unit'] ?? '%').toString(),
      isRaining: rainStatus ?? false,
      hasRainStatus: rainStatus != null,
      timestamp: _readTimestamp(json),
    );
  }

  double get rainPercent => value;

  String get statusText {
    if (!hasRainStatus) {
      return 'Status tidak tersedia';
    }

    return isRaining
        ? 'Hujan'
        : 'Tidak Hujan';
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'unit': unit,
      'isRaining': hasRainStatus
          ? isRaining
          : null,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Parsing status hujan.
///
/// Mendukung:
/// - bool
/// - 1 / 0
/// - "true" / "false"
/// - "1" / "0"
/// - "hujan" / "tidak hujan"
bool? _parseRainStatus(dynamic value) {
  if (value == null) return null;

  if (value is bool) {
    return value;
  }

  if (value is num) {
    if (value == 1) return true;
    if (value == 0) return false;
  }

  if (value is String) {
    final normalized =
        value.trim().toLowerCase();

    switch (normalized) {
      case 'true':
      case '1':
      case 'yes':
      case 'hujan':
      case 'rain':
        return true;

      case 'false':
      case '0':
      case 'no':
      case 'tidak hujan':
      case 'not raining':
        return false;
    }
  }

  return null;
}

// ============================================================
// FLOW SENSOR ZJ-S201 - ALIRAN AIR
// ============================================================

@immutable
class WaterFlowSession {
  final String id;

  /// Debit air.
  final double value;

  final String unit;

  /// Durasi aliran dalam menit.
  final double durationMinutes;

  /// Total volume air dalam liter.
  final double totalVolumeLiters;

  /// Biaya air dalam rupiah.
  final double costIdr;

  /// Availability flag.
  final bool hasDuration;
  final bool hasTotalVolume;
  final bool hasCost;

  final DateTime timestamp;

  const WaterFlowSession({
    required this.id,
    required this.value,
    required this.unit,
    this.durationMinutes = 0,
    this.totalVolumeLiters = 0,
    this.costIdr = 0,
    this.hasDuration = false,
    this.hasTotalVolume = false,
    this.hasCost = false,
    required this.timestamp,
  });

  /// Debit air dalam liter per menit.
  double get flowRateLpm => value;

  /// Alias total volume.
  double get volumeLiters =>
      totalVolumeLiters;

  /// Alias biaya.
  double get waterCost =>
      costIdr;

  factory WaterFlowSession.fromJson(
    Map<String, dynamic> json,
  ) {
    final duration =
        _readOptionalDouble(
      json['durationMinutes'],
    );

    final volume =
        _readOptionalDouble(
      json['totalVolumeLiters'],
    );

    final cost =
        _readOptionalDouble(
      json['costIdr'],
    );

    return WaterFlowSession(
      id: (json['id'] ?? '').toString(),
      value: _readRequiredDouble(
        json,
        'value',
      ),
      unit: (json['unit'] ?? 'L/min').toString(),
      durationMinutes: duration ?? 0,
      totalVolumeLiters: volume ?? 0,
      costIdr: cost ?? 0,
      hasDuration: duration != null,
      hasTotalVolume: volume != null,
      hasCost: cost != null,
      timestamp: _readTimestamp(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'value': value,
      'unit': unit,
      'durationMinutes': hasDuration
          ? durationMinutes
          : null,
      'totalVolumeLiters': hasTotalVolume
          ? totalVolumeLiters
          : null,
      'costIdr': hasCost
          ? costIdr
          : null,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ============================================================
// DAILY RECAP - REKAP LAPORAN HARIAN
// ============================================================

@immutable
class DailyRecapRecord {
  /// Tanggal laporan.
  ///
  /// Format yang direkomendasikan:
  /// yyyy-MM-dd
  final String date;

  // ----------------------------------------------------------
  // RATA-RATA SENSOR
  // ----------------------------------------------------------

  final double avgTemperature;
  final double avgHumidity;
  final double avgSoilMoisture;
  final double avgTankLevel;

  // ----------------------------------------------------------
  // STATUS HUJAN
  // ----------------------------------------------------------

  final String dominantRainStatus;

  // ----------------------------------------------------------
  // DATA FLOW
  // ----------------------------------------------------------

  final WaterFlowSession? flowSession;

  // ----------------------------------------------------------
  // JUMLAH DATA
  // ----------------------------------------------------------

  /// Total telemetry yang berhasil diproses.
  final int totalDataPoints;

  /// Jumlah data valid masing-masing sensor.
  final int temperatureDataPoints;
  final int humidityDataPoints;
  final int soilDataPoints;
  final int tankDataPoints;

  // ----------------------------------------------------------
  // TEMPERATURE MIN MAX
  // ----------------------------------------------------------

  final double? minTemperature;
  final double? maxTemperature;

  // ----------------------------------------------------------
  // HUMIDITY MIN MAX
  // ----------------------------------------------------------

  final double? minHumidity;
  final double? maxHumidity;

  // ----------------------------------------------------------
  // SOIL MIN MAX
  // ----------------------------------------------------------

  final double? minSoilMoisture;
  final double? maxSoilMoisture;

  // ----------------------------------------------------------
  // TANK MIN MAX
  // ----------------------------------------------------------

  final double? minTankLevel;
  final double? maxTankLevel;

  // ----------------------------------------------------------
  // DATA AVAILABILITY
  // ----------------------------------------------------------

  final bool hasTemperature;
  final bool hasHumidity;
  final bool hasSoilMoisture;
  final bool hasTankLevel;

  const DailyRecapRecord({
    required this.date,
    required this.avgTemperature,
    required this.avgHumidity,
    required this.avgSoilMoisture,
    required this.avgTankLevel,
    required this.dominantRainStatus,
    this.flowSession,
    this.totalDataPoints = 0,
    this.temperatureDataPoints = 0,
    this.humidityDataPoints = 0,
    this.soilDataPoints = 0,
    this.tankDataPoints = 0,
    this.minTemperature,
    this.maxTemperature,
    this.minHumidity,
    this.maxHumidity,
    this.minSoilMoisture,
    this.maxSoilMoisture,
    this.minTankLevel,
    this.maxTankLevel,
    this.hasTemperature = false,
    this.hasHumidity = false,
    this.hasSoilMoisture = false,
    this.hasTankLevel = false,
  });

  /// Apakah laporan memiliki minimal satu data sensor.
  bool get hasSensorData {
    return hasTemperature ||
        hasHumidity ||
        hasSoilMoisture ||
        hasTankLevel;
  }

  /// Apakah laporan memiliki data telemetry.
  bool get hasAnyData {
    return totalDataPoints > 0 ||
        hasSensorData ||
        flowSession != null;
  }

  /// Persentase data sensor yang tersedia
  /// tidak dihitung karena jumlah target sampling
  /// belum ditentukan.
  ///
  /// Getter ini hanya menunjukkan jumlah sensor
  /// yang memiliki data.
  int get availableSensorCount {
    var count = 0;

    if (hasTemperature) count++;
    if (hasHumidity) count++;
    if (hasSoilMoisture) count++;
    if (hasTankLevel) count++;

    return count;
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,

      'avgTemperature': avgTemperature,
      'avgHumidity': avgHumidity,
      'avgSoilMoisture': avgSoilMoisture,
      'avgTankLevel': avgTankLevel,

      'dominantRainStatus':
          dominantRainStatus,

      'flowSession':
          flowSession?.toJson(),

      'totalDataPoints':
          totalDataPoints,

      'temperatureDataPoints':
          temperatureDataPoints,

      'humidityDataPoints':
          humidityDataPoints,

      'soilDataPoints':
          soilDataPoints,

      'tankDataPoints':
          tankDataPoints,

      'minTemperature':
          minTemperature,

      'maxTemperature':
          maxTemperature,

      'minHumidity':
          minHumidity,

      'maxHumidity':
          maxHumidity,

      'minSoilMoisture':
          minSoilMoisture,

      'maxSoilMoisture':
          maxSoilMoisture,

      'minTankLevel':
          minTankLevel,

      'maxTankLevel':
          maxTankLevel,

      'hasTemperature':
          hasTemperature,

      'hasHumidity':
          hasHumidity,

      'hasSoilMoisture':
          hasSoilMoisture,

      'hasTankLevel':
          hasTankLevel,
    };
  }
}