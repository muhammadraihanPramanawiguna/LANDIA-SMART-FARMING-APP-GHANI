class SensorReading {
  final double value;
  final DateTime timestamp;

  SensorReading({required this.value, required this.timestamp});

  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

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
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Model for Soil Moisture Sensor (with condition label)
class SoilReading {
  final double moistureValue;
  final DateTime timestamp;

  SoilReading({required this.moistureValue, required this.timestamp});

  /// Returns condition in Indonesian based on moisture thresholds
  String get condition {
    if (moistureValue < 30.0) return 'Kering';
    if (moistureValue < 70.0) return 'Lembap';
    return 'Basah';
  }

  factory SoilReading.fromJson(Map<String, dynamic> json) {
    return SoilReading(
      moistureValue:
          (json['value'] ?? json['moistureValue'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Model for Ultrasonic / Tank Level Sensor (Percentage + cm)
class TankLevelReading {
  final double percentage;
  final double distanceCm;
  final DateTime timestamp;

  TankLevelReading({
    required this.percentage,
    required this.distanceCm,
    required this.timestamp,
  });

  factory TankLevelReading.fromJson(Map<String, dynamic> json) {
    return TankLevelReading(
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      distanceCm: (json['distanceCm'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Model for Rain Sensor (Boolean status)
class RainSensorReading {
  final bool isRaining;
  final DateTime timestamp;

  RainSensorReading({required this.isRaining, required this.timestamp});

  String get statusText => isRaining ? 'Hujan' : 'Tidak Hujan';

  factory RainSensorReading.fromJson(Map<String, dynamic> json) {
    return RainSensorReading(
      isRaining: json['isRaining'] ?? json['status'] ?? false,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Model for Water Flow Sensor (Once per day session data + cost)
class WaterFlowSession {
  final String id;
  final double flowRateLpm; // L/m³ or L/min
  final double durationMinutes; // Berapa lama air mengalir
  final double totalVolumeLiters; // Total volume air terpakai
  final double costIdr; // Biaya air sekali siram
  final DateTime timestamp;

  WaterFlowSession({
    required this.id,
    required this.flowRateLpm,
    required this.durationMinutes,
    required this.totalVolumeLiters,
    required this.costIdr,
    required this.timestamp,
  });

  factory WaterFlowSession.fromJson(Map<String, dynamic> json) {
    return WaterFlowSession(
      id: json['id']?.toString() ?? '',
      flowRateLpm: (json['flowRateLpm'] as num?)?.toDouble() ?? 0.0,
      durationMinutes: (json['durationMinutes'] as num?)?.toDouble() ?? 0.0,
      totalVolumeLiters: (json['totalVolumeLiters'] as num?)?.toDouble() ?? 0.0,
      costIdr: (json['costIdr'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

/// Model for Daily Recap Table (Rekapan Harian)
class DailyRecapRecord {
  final String date; // e.g. "2026-10-24"
  final double avgTemperature; // Rata-rata suhu DHT
  final double avgHumidity; // Rata-rata kelembapan DHT
  final double avgSoilMoisture; // Rata-rata kelembapan tanah
  final double avgTankLevel; // Rata-rata level tangki (%)
  final String dominantRainStatus; // "Hujan" / "Tidak Hujan"
  final WaterFlowSession? flowSession; // Data flow sekali sehari

  DailyRecapRecord({
    required this.date,
    required this.avgTemperature,
    required this.avgHumidity,
    required this.avgSoilMoisture,
    required this.avgTankLevel,
    required this.dominantRainStatus,
    this.flowSession,
  });

  factory DailyRecapRecord.fromJson(Map<String, dynamic> json) {
    return DailyRecapRecord(
      date: json['date'] ?? '',
      avgTemperature: (json['avgTemperature'] as num?)?.toDouble() ?? 0.0,
      avgHumidity: (json['avgHumidity'] as num?)?.toDouble() ?? 0.0,
      avgSoilMoisture: (json['avgSoilMoisture'] as num?)?.toDouble() ?? 0.0,
      avgTankLevel: (json['avgTankLevel'] as num?)?.toDouble() ?? 0.0,
      dominantRainStatus: json['dominantRainStatus'] ?? 'Tidak Hujan',
      flowSession: json['flowSession'] != null
          ? WaterFlowSession.fromJson(json['flowSession'])
          : null,
    );
  }
}
