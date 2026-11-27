
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/sensor_reading.dart';

class PdfExportService {
  // ============================================================
  // MAIN EXPORT
  // ============================================================

  /// Membuat dan membagikan PDF rekap harian Landia Farm.
  ///
  /// Data yang digunakan berasal dari DailyRecapRecord.
  /// Export tidak melakukan request API tambahan.
  static Future<void> generateDailyRecapPdf(
    DailyRecapRecord record,
  ) async {
    try {
      final pdf = pw.Document(
        title: 'Laporan Rekap Harian Landia Farm',
        author: 'Landia Farm Smart Monitoring System',
        subject: 'Rekap sensor lingkungan dan irigasi',
      );

      final flow = record.flowSession;

      final rawDate = record.date.trim();

      final safeDate = _sanitizeFileName(
        rawDate.isEmpty ? 'tanpa_tanggal' : rawDate,
      );

      final rainStatus = _safeText(
        record.dominantRainStatus,
        fallback: 'Belum tersedia',
      );

      final generatedAt = DateTime.now();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),

          header: (context) {
            if (context.pageNumber == 1) {
              return pw.SizedBox();
            }

            return pw.Container(
              margin: const pw.EdgeInsets.only(
                bottom: 10,
              ),
              child: pw.Row(
                mainAxisAlignment:
                    pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'LANDIA FARM',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                    ),
                  ),
                  pw.Text(
                    'Rekap Harian Sensor & Irigasi',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            );
          },

          footer: (context) {
            return pw.Column(
              children: [
                pw.Divider(
                  color: PdfColors.grey400,
                ),
                pw.SizedBox(height: 5),
                pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Landia Farm Smart Monitoring System',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'Halaman ${context.pageNumber} '
                      'dari ${context.pagesCount}',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Dicetak: ${_formatDateTime(generatedAt)}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ),
              ],
            );
          },

          build: (context) {
            return [
              // ==================================================
              // HEADER
              // ==================================================

              _buildHeader(
                date: rawDate.isEmpty
                    ? 'Tidak tersedia'
                    : rawDate,
              ),

              pw.SizedBox(height: 18),

              pw.Divider(
                color: PdfColors.grey400,
              ),

              pw.SizedBox(height: 15),

              // ==================================================
              // SUMMARY
              // ==================================================

              _buildSectionTitle(
                'Ringkasan Data Harian',
              ),

              pw.SizedBox(height: 8),

              _buildSummaryCard(record),

              pw.SizedBox(height: 18),

              // ==================================================
              // WEATHER / RAIN
              // ==================================================

              _buildSectionTitle(
                'Kondisi Lingkungan Umum',
              ),

              pw.SizedBox(height: 8),

              _buildRainCard(rainStatus),

              pw.SizedBox(height: 18),

              // ==================================================
              // SENSOR TABLE
              // ==================================================

              _buildSectionTitle(
                'Rata-rata Pembacaan Sensor Harian',
              ),

              pw.SizedBox(height: 8),

              _buildSensorTable(record),

              pw.SizedBox(height: 18),

              // ==================================================
              // SENSOR MIN MAX
              // ==================================================

              _buildSectionTitle(
                'Rentang Pembacaan Sensor',
              ),

              pw.SizedBox(height: 8),

              _buildMinMaxTable(record),

              pw.SizedBox(height: 18),

              // ==================================================
              // WATER FLOW
              // ==================================================

              _buildSectionTitle(
                'Sesi Aliran Air & Biaya Penyiraman',
              ),

              pw.SizedBox(height: 8),

              if (flow != null)
                _buildWaterFlowCard(flow)
              else
                _buildEmptyCard(
                  'Tidak ada data sesi aliran air '
                  'yang tersedia pada tanggal ini.',
                ),

              pw.SizedBox(height: 18),

              // ==================================================
              // DATA QUALITY
              // ==================================================

              _buildSectionTitle(
                'Informasi Ketersediaan Data',
              ),

              pw.SizedBox(height: 8),

              _buildDataAvailabilityCard(record),

              pw.SizedBox(height: 12),

              _buildDisclaimer(),
            ];
          },
        ),
      );

      // ==========================================================
      // SAVE & SHARE
      // ==========================================================

      final pdfBytes = await pdf.save();

      if (pdfBytes.isEmpty) {
        throw Exception(
          'PDF berhasil dibuat tetapi file kosong.',
        );
      }

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            'Laporan_Landia_Farm_$safeDate.pdf',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[PDF EXPORT] Gagal membuat PDF: $e',
      );

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  // ============================================================
  // HEADER
  // ============================================================

  static pw.Widget _buildHeader({
    required String date,
  }) {
    return pw.Row(
      mainAxisAlignment:
          pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'LANDIA FARM',
                style: pw.TextStyle(
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),

              pw.SizedBox(height: 5),

              pw.Text(
                'Laporan Rekap Harian Sensor & Irigasi',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),

              pw.SizedBox(height: 3),

              pw.Text(
                'Smart Farming Monitoring System',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),

        pw.SizedBox(width: 10),

        pw.Container(
          padding: const pw.EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: pw.BoxDecoration(
            color: PdfColors.green50,
            borderRadius:
                pw.BorderRadius.circular(6),
            border: pw.Border.all(
              color: PdfColors.green200,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment:
                pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Tanggal Rekap',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),

              pw.SizedBox(height: 3),

              pw.Text(
                date,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  static pw.Widget _buildSectionTitle(
    String title,
  ) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 16,
          decoration: pw.BoxDecoration(
            color: PdfColors.green700,
            borderRadius:
                pw.BorderRadius.circular(2),
          ),
        ),

        pw.SizedBox(width: 7),

        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  static pw.Widget _buildSummaryCard(
    DailyRecapRecord record,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(
          color: PdfColors.green200,
        ),
        borderRadius:
            pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          _buildPdfRow(
            'Total sampel telemetry',
            '${record.totalDataPoints}',
          ),

          pw.SizedBox(height: 7),

          _buildPdfRow(
            'Sampel suhu',
            '${record.temperatureDataPoints}',
          ),

          pw.SizedBox(height: 7),

          _buildPdfRow(
            'Sampel kelembapan udara',
            '${record.humidityDataPoints}',
          ),

          pw.SizedBox(height: 7),

          _buildPdfRow(
            'Sampel kelembapan tanah',
            '${record.soilDataPoints}',
          ),

          pw.SizedBox(height: 7),

          _buildPdfRow(
            'Sampel level tangki',
            '${record.tankDataPoints}',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RAIN CARD
  // ============================================================

  static pw.Widget _buildRainCard(
    String status,
  ) {
    final normalized = status.toLowerCase();

    final isRain = normalized.contains('hujan');

    final backgroundColor = isRain
        ? PdfColors.blue50
        : PdfColors.grey100;

    final borderColor = isRain
        ? PdfColors.blue200
        : PdfColors.grey300;

    final textColor = isRain
        ? PdfColors.blue900
        : PdfColors.grey900;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: backgroundColor,
        border: pw.Border.all(
          color: borderColor,
        ),
        borderRadius:
            pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(
              'Status cuaca / hujan dominan',
              style: const pw.TextStyle(
                fontSize: 10,
              ),
            ),
          ),

          pw.SizedBox(width: 10),

          pw.Text(
            status,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SENSOR AVERAGE TABLE
  // ============================================================

  static pw.Widget _buildSensorTable(
    DailyRecapRecord record,
  ) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 9,
      ),

      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.green800,
      ),

      cellStyle: const pw.TextStyle(
        fontSize: 9,
      ),

      cellHeight: 28,

      cellPadding:
          const pw.EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 6,
      ),

      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.centerRight,
      },

      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.5,
      ),

      data: [
        [
          'Parameter Sensor',
          'Nilai Rata-rata',
        ],

        [
          'Suhu Udara (DHT)',
          record.hasTemperature
              ? '${_formatNumber(record.avgTemperature)} °C'
              : 'Belum tersedia',
        ],

        [
          'Kelembapan Udara (DHT)',
          record.hasHumidity
              ? '${_formatNumber(record.avgHumidity)} %'
              : 'Belum tersedia',
        ],

        [
          'Kelembapan Tanah',
          record.hasSoilMoisture
              ? '${_formatNumber(record.avgSoilMoisture)} %'
              : 'Belum tersedia',
        ],

        [
          'Level Kapasitas Tangki',
          record.hasTankLevel
              ? '${_formatNumber(record.avgTankLevel)} %'
              : 'Belum tersedia',
        ],
      ],
    );
  }

  // ============================================================
  // SENSOR MIN MAX TABLE
  // ============================================================

  static pw.Widget _buildMinMaxTable(
    DailyRecapRecord record,
  ) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 9,
      ),

      headerDecoration: const pw.BoxDecoration(
        color: PdfColors.teal700,
      ),

      cellStyle: const pw.TextStyle(
        fontSize: 9,
      ),

      cellHeight: 28,

      cellPadding:
          const pw.EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 6,
      ),

      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
      },

      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.5,
      ),

      data: [
        [
          'Sensor',
          'Minimum',
          'Maximum',
        ],

        [
          'Suhu Udara',
          record.hasTemperature
              ? _formatOptional(
                  record.minTemperature,
                  suffix: ' °C',
                )
              : 'Belum tersedia',
          record.hasTemperature
              ? _formatOptional(
                  record.maxTemperature,
                  suffix: ' °C',
                )
              : 'Belum tersedia',
        ],

        [
          'Kelembapan Udara',
          record.hasHumidity
              ? _formatOptional(
                  record.minHumidity,
                  suffix: ' %',
                )
              : 'Belum tersedia',
          record.hasHumidity
              ? _formatOptional(
                  record.maxHumidity,
                  suffix: ' %',
                )
              : 'Belum tersedia',
        ],

        [
          'Kelembapan Tanah',
          record.hasSoilMoisture
              ? _formatOptional(
                  record.minSoilMoisture,
                  suffix: ' %',
                )
              : 'Belum tersedia',
          record.hasSoilMoisture
              ? _formatOptional(
                  record.maxSoilMoisture,
                  suffix: ' %',
                )
              : 'Belum tersedia',
        ],

        [
          'Level Tangki',
          record.hasTankLevel
              ? _formatOptional(
                  record.minTankLevel,
                  suffix: ' %',
                )
              : 'Belum tersedia',
          record.hasTankLevel
              ? _formatOptional(
                  record.maxTankLevel,
                  suffix: ' %',
                )
              : 'Belum tersedia',
        ],
      ],
    );
  }

  // ============================================================
  // WATER FLOW CARD
  // ============================================================

  static pw.Widget _buildWaterFlowCard(
    WaterFlowSession flow,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        border: pw.Border.all(
          color: PdfColors.teal300,
        ),
        borderRadius:
            pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          _buildPdfRow(
            'Debit aliran air',
            '${_formatNumber(flow.flowRateLpm)} L/min',
          ),

          pw.SizedBox(height: 8),

          _buildPdfRow(
            'Volume air terpakai',
            flow.hasTotalVolume
                ? '${_formatNumber(flow.totalVolumeLiters)} Liter'
                : 'Belum tersedia',
          ),

          pw.SizedBox(height: 8),

          _buildPdfRow(
            'Durasi aliran air',
            flow.hasDuration
                ? '${_formatNumber(flow.durationMinutes, decimals: 0)} Menit'
                : 'Belum tersedia',
          ),

          pw.SizedBox(height: 10),

          pw.Divider(
            color: PdfColors.teal200,
          ),

          pw.SizedBox(height: 4),

          _buildPdfRow(
            'Total biaya air',
            flow.hasCost
                ? 'Rp ${_formatIdr(flow.costIdr)}'
                : 'Belum tersedia',
            isBold: true,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DATA AVAILABILITY
  // ============================================================

  static pw.Widget _buildDataAvailabilityCard(
    DailyRecapRecord record,
  ) {
    final items = <String, bool>{
      'Data suhu udara': record.hasTemperature,
      'Data kelembapan udara': record.hasHumidity,
      'Data kelembapan tanah':
          record.hasSoilMoisture,
      'Data level tangki': record.hasTankLevel,
      'Data aliran air':
          record.flowSession != null,
    };

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(
          color: PdfColors.grey300,
        ),
        borderRadius:
            pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: items.entries.map((entry) {
          return pw.Padding(
            padding:
                const pw.EdgeInsets.only(
              bottom: 6,
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 8,
                  height: 8,
                  decoration: pw.BoxDecoration(
                    color: entry.value
                        ? PdfColors.green600
                        : PdfColors.grey500,
                    shape: pw.BoxShape.circle,
                  ),
                ),

                pw.SizedBox(width: 7),

                pw.Expanded(
                  child: pw.Text(
                    entry.key,
                    style: const pw.TextStyle(
                      fontSize: 9,
                    ),
                  ),
                ),

                pw.Text(
                  entry.value
                      ? 'Tersedia'
                      : 'Tidak tersedia',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight:
                        pw.FontWeight.bold,
                    color: entry.value
                        ? PdfColors.green800
                        : PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================
  // DISCLAIMER
  // ============================================================

  static pw.Widget _buildDisclaimer() {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.amber50,
        border: pw.Border.all(
          color: PdfColors.amber200,
        ),
        borderRadius:
            pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'Catatan: Laporan ini dibuat berdasarkan telemetry '
        'yang tersedia pada sistem saat rekap dilakukan. '
        'Nilai "Belum tersedia" menunjukkan data sensor '
        'atau parameter tersebut tidak tersedia pada '
        'periode yang dipilih. Nilai rata-rata dihitung '
        'berdasarkan data telemetry yang berhasil diterima.',
        style: const pw.TextStyle(
          fontSize: 8,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY CARD
  // ============================================================

  static pw.Widget _buildEmptyCard(
    String message,
  ) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(
          color: PdfColors.grey300,
        ),
        borderRadius:
            pw.BorderRadius.circular(8),
      ),
      child: pw.Text(
        message,
        style: pw.TextStyle(
          fontSize: 10,
          color: PdfColors.grey700,
          fontStyle: pw.FontStyle.italic,
        ),
      ),
    );
  }

  // ============================================================
  // PDF ROW
  // ============================================================

  static pw.Widget _buildPdfRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: 9,
      fontWeight: isBold
          ? pw.FontWeight.bold
          : pw.FontWeight.normal,
      color: isBold
          ? PdfColors.green900
          : PdfColors.black,
    );

    return pw.Row(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Text(
            label,
            style: style,
          ),
        ),

        pw.SizedBox(width: 10),

        pw.Expanded(
          flex: 4,
          child: pw.Text(
            value,
            style: style,
            textAlign: pw.TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // NUMBER FORMATTING
  // ============================================================

  static String _formatNumber(
    double value, {
    int decimals = 1,
  }) {
    if (!value.isFinite) {
      return 'Belum tersedia';
    }

    return value.toStringAsFixed(decimals);
  }

  static String _formatOptional(
    double? value, {
    int decimals = 1,
    String suffix = '',
  }) {
    if (value == null || !value.isFinite) {
      return 'Belum tersedia';
    }

    return '${value.toStringAsFixed(decimals)}$suffix';
  }

  // ============================================================
  // RUPIAH FORMATTING
  // ============================================================

  static String _formatIdr(
    double amount,
  ) {
    if (!amount.isFinite) {
      return 'Belum tersedia';
    }

    final rounded = amount.abs().round();

    final digits = rounded.toString();

    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]}.',
    );

    return amount < 0
        ? '-$formatted'
        : formatted;
  }

  // ============================================================
  // TEXT SAFETY
  // ============================================================

  static String _safeText(
    String value, {
    String fallback = 'Belum tersedia',
  }) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      return fallback;
    }

    return normalized;
  }

  static String _sanitizeFileName(
    String value,
  ) {
    return value.replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '-',
    );
  }

  // ============================================================
  // DATETIME FORMATTING
  // ============================================================

  static String _formatDateTime(
    DateTime dateTime,
  ) {
    final date = dateTime.toLocal();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${twoDigits(date.day)}/'
        '${twoDigits(date.month)}/'
        '${date.year} '
        '${twoDigits(date.hour)}:'
        '${twoDigits(date.minute)}';
  }
}
