
/// Model data sensor Landia Farm.
///
/// Parsing telemetry ThingsBoard dilakukan oleh ApiService.
/// File ini hanya menyimpan data yang akan digunakan Dashboard.

class SensorReading {
  final double value;
  final DateTime timestamp;

  const SensorReading({
    required this.value,
    required this.timestamp,
  });
}

// ============================================================
// DHT11 - SUHU DAN KELEMBAPAN UDARA
// ============================================================

class DhtReading {
  final double temperature;
  final double humidity;
  final DateTime timestamp;

  const DhtReading({
    required this.temperature,
    required this.humidity,
    required this.timestamp,
  });
}

// ============================================================
// SOIL MOISTURE - KELEMBAPAN TANAH
// ============================================================

class SoilReading {
  final double moistureValue;
  final String unit;
  final DateTime timestamp;

  const SoilReading({
    required this.moistureValue,
    required this.unit,
    required this.timestamp,
  });

  /// Ambang klasifikasi sementara.
  /// Tetap perlu divalidasi dengan kalibrasi sensor lapangan.
  String get condition {
    if (moistureValue < 30) return 'Kering';
    if (moistureValue < 70) return 'Lembap';
    return 'Basah';
  }
}

// ============================================================
// JSN-SR04M - LEVEL AIR TANGKI
// ============================================================

class TankLevelReading {
  final double value;
  final String unit;

  final double distanceCm;
  final bool hasDistanceCm;

  final DateTime timestamp;

  const TankLevelReading({
    required this.value,
    required this.unit,
    this.distanceCm = 0,
    this.hasDistanceCm = false,
    required this.timestamp,
  });

  double get percentage => value;
}

// ============================================================
// RAIN SENSOR - SENSOR HUJAN
// ============================================================

class RainSensorReading {
  /// Telemetry rain_percent.
  final double value;
  final String unit;

  /// Telemetry is_raining.
  final bool isRaining;
  final bool hasRainStatus;

  final DateTime timestamp;

  const RainSensorReading({
    required this.value,
    required this.unit,
    this.isRaining = false,
    this.hasRainStatus = false,
    required this.timestamp,
  });

  double get rainPercent => value;

  String get statusText {
    if (!hasRainStatus) {
      return 'Status tidak tersedia';
    }

    return isRaining ? 'Hujan' : 'Tidak Hujan';
  }
}

// ============================================================
// FLOW SENSOR ZJ-S201 - ALIRAN AIR
// ============================================================

class WaterFlowSession {
  final String id;

  /// flow_rate dalam L/min.
  final double value;
  final String unit;

  /// total_water_liters.
  final double totalVolumeLiters;
  final bool hasTotalVolume;

  /// water_consumption_m3.
  final double consumptionM3;
  final bool hasConsumptionM3;

  /// water_cost_rupiah.
  final double costIdr;
  final bool hasCost;

  /// water_tariff_rupiah_per_m3.
  final double tariffPerM3;
  final bool hasTariff;

  /// Belum ada telemetry durasi dari ESP32.
  final double durationMinutes;
  final bool hasDuration;

  final DateTime timestamp;

  const WaterFlowSession({
    required this.id,
    required this.value,
    required this.unit,
    this.totalVolumeLiters = 0,
    this.hasTotalVolume = false,
    this.consumptionM3 = 0,
    this.hasConsumptionM3 = false,
    this.costIdr = 0,
    this.hasCost = false,
    this.tariffPerM3 = 0,
    this.hasTariff = false,
    this.durationMinutes = 0,
    this.hasDuration = false,
    required this.timestamp,
  });

  double get flowRateLpm => value;
}

// ============================================================
// DAILY RECAP - REKAPITULASI HARIAN
// ============================================================

class DailyRecapRecord {
  final String date;

  final double avgTemperature;
  final double avgHumidity;
  final double avgSoilMoisture;
  final double avgTankLevel;

  final String dominantRainStatus;
  final WaterFlowSession? flowSession;

  const DailyRecapRecord({
    required this.date,
    required this.avgTemperature,
    required this.avgHumidity,
    required this.avgSoilMoisture,
    required this.avgTankLevel,
    required this.dominantRainStatus,
    this.flowSession,
  });
}
