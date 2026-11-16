enum IrrigationTrigger { automatic, manual }

class RainEvent {
  final String id;
  final DateTime timestamp;
  final int durationMinutes;
  final double rainfallMm;

  RainEvent({
    required this.id,
    required this.timestamp,
    required this.durationMinutes,
    required this.rainfallMm,
  });

  factory RainEvent.fromJson(Map<String, dynamic> json) {
    return RainEvent(
      id: json['id']?.toString() ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      rainfallMm: (json['rainfallMm'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class FertilizerEvent {
  final String id;
  final DateTime timestamp;
  final int volumeMl;
  final int durationMinutes;

  FertilizerEvent({
    required this.id,
    required this.timestamp,
    required this.volumeMl,
    required this.durationMinutes,
  });

  factory FertilizerEvent.fromJson(Map<String, dynamic> json) {
    return FertilizerEvent(
      id: json['id']?.toString() ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      volumeMl: (json['volumeMl'] as num?)?.toInt() ?? 0,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
    );
  }

  String get formattedVolume {
    if (volumeMl >= 1000) {
      double liters = volumeMl / 1000.0;
      return '${liters.toStringAsFixed(2)} L ($volumeMl mL)';
    }
    return '$volumeMl mL';
  }
}

class IrrigationLogEvent {
  final String id;
  final DateTime timestamp;
  final int durationMinutes;
  final double volumeLiters;
  final IrrigationTrigger trigger;

  IrrigationLogEvent({
    required this.id,
    required this.timestamp,
    required this.durationMinutes,
    required this.volumeLiters,
    required this.trigger,
  });

  factory IrrigationLogEvent.fromJson(Map<String, dynamic> json) {
    final rawTrigger = json['trigger']?.toString().toUpperCase() ?? '';
    return IrrigationLogEvent(
      id: json['id']?.toString() ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      volumeLiters: (json['volumeLiters'] as num?)?.toDouble() ?? 0.0,
      trigger: rawTrigger == 'AUTOMATIC'
          ? IrrigationTrigger.automatic
          : IrrigationTrigger.manual,
    );
  }
}
