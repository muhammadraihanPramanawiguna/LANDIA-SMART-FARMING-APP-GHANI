
import 'package:flutter/foundation.dart';

// ============================================================
// IRRIGATION TRIGGER ENUM
// ============================================================

enum IrrigationTrigger {
  automatic,
  manual,
}

// ============================================================
// JSON PARSING HELPERS
// ============================================================

/// Parsing angka desimal.
///
/// Mendukung:
/// - int
/// - double
/// - String numeric
///
/// Nilai invalid akan menggunakan defaultValue.
double _parseDouble(
  dynamic value, {
  double defaultValue = 0.0,
}) {
  double? result;

  if (value is num) {
    result = value.toDouble();
  } else if (value is String) {
    result = double.tryParse(value.trim());
  }

  if (result == null || !result.isFinite) {
    return defaultValue;
  }

  return result;
}

/// Parsing integer.
///
/// Berbeda dengan kode sebelumnya, helper ini tidak langsung
/// mengubah 10.5 menjadi 10 tanpa validasi.
///
/// Jika nilai desimal bukan bilangan bulat, akan menggunakan
/// defaultValue.
int _parseInt(
  dynamic value, {
  int defaultValue = 0,
}) {
  num? result;

  if (value is int) {
    return value;
  }

  if (value is num) {
    result = value;
  } else if (value is String) {
    result = num.tryParse(value.trim());
  }

  if (result == null || !result.isFinite) {
    return defaultValue;
  }

  if (result % 1 != 0) {
    return defaultValue;
  }

  return result.toInt();
}

/// Parsing timestamp.
///
/// Field yang didukung:
/// - timestamp
/// - recordedAt
/// - createdAt
/// - date
///
/// Format yang didukung:
/// - DateTime
/// - ISO 8601 String
/// - Unix timestamp dalam detik
/// - Unix timestamp dalam milidetik
DateTime _parseTimestamp(Map<String, dynamic> json) {
  final candidates = [
    json['timestamp'],
    json['recordedAt'],
    json['createdAt'],
    json['date'],
  ];

  for (final candidate in candidates) {
    if (candidate is DateTime) {
      return candidate.toLocal();
    }

    // --------------------------------------------------------
    // Unix Timestamp
    // --------------------------------------------------------

    if (candidate is num) {
      final value = candidate.toInt();

      // Timestamp 10 digit biasanya detik.
      // Timestamp 13 digit biasanya milidetik.
      final milliseconds = value.abs() < 100000000000
          ? value * 1000
          : value;

      try {
        return DateTime.fromMillisecondsSinceEpoch(
          milliseconds,
          isUtc: true,
        ).toLocal();
      } catch (_) {
        continue;
      }
    }

    // --------------------------------------------------------
    // String Timestamp
    // --------------------------------------------------------

    if (candidate is String && candidate.trim().isNotEmpty) {
      final normalized = candidate.trim();

      // Coba ISO 8601 terlebih dahulu.
      final parsedDate = DateTime.tryParse(normalized);

      if (parsedDate != null) {
        return parsedDate.toLocal();
      }

      // Coba numeric timestamp dari String.
      final parsedNumber = num.tryParse(normalized);

      if (parsedNumber != null && parsedNumber.isFinite) {
        final value = parsedNumber.toInt();

        final milliseconds = value.abs() < 100000000000
            ? value * 1000
            : value;

        try {
          return DateTime.fromMillisecondsSinceEpoch(
            milliseconds,
            isUtc: true,
          ).toLocal();
        } catch (_) {
          continue;
        }
      }
    }
  }

  throw const FormatException(
    'Timestamp tidak tersedia atau format tanggal tidak valid.',
  );
}

/// Parsing ID.
///
/// ID wajib tersedia dan tidak boleh kosong.
String _parseId(dynamic value) {
  if (value == null) {
    throw const FormatException(
      'ID history tidak tersedia.',
    );
  }

  final id = value.toString().trim();

  if (id.isEmpty) {
    throw const FormatException(
      'ID history tidak boleh kosong.',
    );
  }

  return id;
}

/// Parsing angka non-negatif.
double _parseNonNegativeDouble(
  dynamic value, {
  String fieldName = 'Nilai',
}) {
  final parsed = _parseDouble(
    value,
    defaultValue: double.nan,
  );

  if (!parsed.isFinite || parsed < 0) {
    throw FormatException(
      '$fieldName tidak valid: $value',
    );
  }

  return parsed;
}

/// Parsing integer non-negatif.
int _parseNonNegativeInt(
  dynamic value, {
  String fieldName = 'Nilai',
}) {
  final parsed = _parseInt(
    value,
    defaultValue: -1,
  );

  if (parsed < 0) {
    throw FormatException(
      '$fieldName tidak valid: $value',
    );
  }

  return parsed;
}

/// Parsing trigger irigasi.
///
/// Nilai yang didukung:
/// - automatic
/// - auto
/// - manual
///
/// Tidak dikenal akan menghasilkan FormatException.
IrrigationTrigger _parseTrigger(dynamic value) {
  if (value == null) {
    throw const FormatException(
      'Field trigger tidak tersedia.',
    );
  }

  final normalized = value
      .toString()
      .trim()
      .toLowerCase();

  switch (normalized) {
    case 'automatic':
    case 'auto':
    case 'otomatis':
      return IrrigationTrigger.automatic;

    case 'manual':
    case 'manual control':
      return IrrigationTrigger.manual;

    default:
      throw FormatException(
        'Trigger irigasi tidak dikenal: $value',
      );
  }
}

/// Mengubah enum menjadi String untuk JSON.
String _triggerToJson(IrrigationTrigger trigger) {
  switch (trigger) {
    case IrrigationTrigger.automatic:
      return 'automatic';

    case IrrigationTrigger.manual:
      return 'manual';
  }
}

// ============================================================
// RAIN EVENT
// ============================================================

@immutable
class RainEvent {
  final String id;
  final DateTime timestamp;
  final int durationMinutes;
  final double rainfallMm;

  const RainEvent({
    required this.id,
    required this.timestamp,
    required this.durationMinutes,
    required this.rainfallMm,
  });

  factory RainEvent.fromJson(
    Map<String, dynamic> json,
  ) {
    return RainEvent(
      id: _parseId(json['id']),
      timestamp: _parseTimestamp(json),
      durationMinutes: _parseNonNegativeInt(
        json['durationMinutes'],
        fieldName: 'Duration minutes',
      ),
      rainfallMm: _parseNonNegativeDouble(
        json['rainfallMm'],
        fieldName: 'Rainfall mm',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'durationMinutes': durationMinutes,
      'rainfallMm': rainfallMm,
    };
  }
}

// ============================================================
// FERTILIZER EVENT
// ============================================================

@immutable
class FertilizerEvent {
  final String id;
  final DateTime timestamp;
  final int volumeMl;
  final int durationMinutes;

  const FertilizerEvent({
    required this.id,
    required this.timestamp,
    required this.volumeMl,
    required this.durationMinutes,
  });

  factory FertilizerEvent.fromJson(
    Map<String, dynamic> json,
  ) {
    return FertilizerEvent(
      id: _parseId(json['id']),
      timestamp: _parseTimestamp(json),
      volumeMl: _parseNonNegativeInt(
        json['volumeMl'],
        fieldName: 'Volume ml',
      ),
      durationMinutes: _parseNonNegativeInt(
        json['durationMinutes'],
        fieldName: 'Duration minutes',
      ),
    );
  }

  /// Mengubah volume mL menjadi liter jika mencapai 1000 mL.
  String get formattedVolume {
    if (volumeMl >= 1000) {
      final liters = volumeMl / 1000.0;

      return '${liters.toStringAsFixed(2)} L ($volumeMl mL)';
    }

    return '$volumeMl mL';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'volumeMl': volumeMl,
      'durationMinutes': durationMinutes,
    };
  }
}

// ============================================================
// IRRIGATION LOG EVENT
// ============================================================

@immutable
class IrrigationLogEvent {
  final String id;
  final DateTime timestamp;
  final int durationMinutes;
  final double volumeLiters;
  final IrrigationTrigger trigger;

  const IrrigationLogEvent({
    required this.id,
    required this.timestamp,
    required this.durationMinutes,
    required this.volumeLiters,
    required this.trigger,
  });

  factory IrrigationLogEvent.fromJson(
    Map<String, dynamic> json,
  ) {
    return IrrigationLogEvent(
      id: _parseId(json['id']),
      timestamp: _parseTimestamp(json),
      durationMinutes: _parseNonNegativeInt(
        json['durationMinutes'],
        fieldName: 'Duration minutes',
      ),
      volumeLiters: _parseNonNegativeDouble(
        json['volumeLiters'],
        fieldName: 'Volume liters',
      ),
      trigger: _parseTrigger(json['trigger']),
    );
  }

  /// Label untuk ditampilkan di UI.
  String get triggerLabel {
    switch (trigger) {
      case IrrigationTrigger.automatic:
        return 'Otomatis';

      case IrrigationTrigger.manual:
        return 'Manual';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'durationMinutes': durationMinutes,
      'volumeLiters': volumeLiters,
      'trigger': _triggerToJson(trigger),
    };
  }
}
