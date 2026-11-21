
enum IrrigationTrigger {
  automatic,
  manual,
}

// ============================================================
// JSON PARSING HELPERS
// ============================================================

/// Mengambil angka desimal dari JSON.
///
/// Mendukung:
/// - int
/// - double
/// - String angka
///
/// Menolak:
/// - null
/// - String tidak valid
/// - NaN
/// - Infinity
///
/// Jika tidak valid, menggunakan defaultValue.
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

/// Mengambil angka integer dari JSON.
///
/// Mendukung:
/// - int
/// - double
/// - String angka
///
/// Contoh:
/// 10.0 -> 10
/// "10" -> 10
/// "10.5" -> 10
int _parseInt(
  dynamic value, {
  int defaultValue = 0,
}) {
  num? result;

  if (value is num) {
    result = value;
  } else if (value is String) {
    result = num.tryParse(value.trim());
  }

  if (result == null || !result.isFinite) {
    return defaultValue;
  }

  return result.toInt();
}

/// Mengambil timestamp dari beberapa kemungkinan nama field.
///
/// Field yang didukung:
/// - timestamp
/// - recordedAt
/// - createdAt
///
/// Tidak membuat timestamp palsu jika semua field tidak tersedia.
DateTime _parseTimestamp(Map<String, dynamic> json) {
  final candidates = [
    json['timestamp'],
    json['recordedAt'],
    json['createdAt'],
  ];

  for (final candidate in candidates) {
    if (candidate is DateTime) {
      return candidate.toLocal();
    }

    if (candidate is String && candidate.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(candidate.trim());

      if (parsed != null) {
        return parsed.toLocal();
      }
    }
  }

  throw const FormatException(
    'Timestamp tidak tersedia atau format tanggal tidak valid.',
  );
}

/// Mengambil ID dari JSON.
///
/// ID tidak boleh null atau kosong.
String _parseId(dynamic value) {
  if (value == null) {
    throw const FormatException(
      'ID riwayat tidak tersedia.',
    );
  }

  final id = value.toString().trim();

  if (id.isEmpty) {
    throw const FormatException(
      'ID riwayat tidak boleh kosong.',
    );
  }

  return id;
}

/// Mengambil angka desimal yang wajib bernilai >= 0.
///
/// Nilai negatif atau tidak valid akan menghasilkan error.
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

/// Mengambil angka integer yang wajib bernilai >= 0.
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

/// Parsing trigger irigasi dengan validasi ketat.
///
/// Nilai yang didukung:
/// - automatic
/// - auto
/// - manual
///
/// Nilai yang tidak dikenal tidak otomatis dianggap manual.
IrrigationTrigger _parseTrigger(dynamic value) {
  if (value == null) {
    throw const FormatException(
      'Field trigger tidak tersedia.',
    );
  }

  final normalized = value.toString().trim().toLowerCase();

  switch (normalized) {
    case 'automatic':
    case 'auto':
      return IrrigationTrigger.automatic;

    case 'manual':
      return IrrigationTrigger.manual;

    default:
      throw FormatException(
        'Trigger irigasi tidak dikenal: $value',
      );
  }
}

// ============================================================
// RAIN EVENT
// ============================================================

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
}

// ============================================================
// FERTILIZER EVENT
// ============================================================

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
}

// ============================================================
// IRRIGATION LOG EVENT
// ============================================================

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
}
