
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/sensor_reading.dart';

class PdfExportService {
  /// Membuat dan membagikan laporan PDF rekap harian Landia Farm.
  static Future<void> generateDailyRecapPdf(
    DailyRecapRecord record,
  ) async {
    final pdf = pw.Document();

    final flow = record.flowSession;

    // Nama file aman untuk berbagai sistem operasi.
    final rawDate = record.date.trim();
    final safeDate = rawDate.isEmpty
        ? 'tanpa_tanggal'
        : rawDate.replaceAll(
            RegExp(r'[\\/:*?"<>|]'),
            '-',
          );

    final rainStatus = record.dominantRainStatus.trim().isEmpty
        ? 'Belum tersedia'
        : record.dominantRainStatus.trim();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),

        // Footer akan muncul di setiap halaman.
        footer: (context) {
          return pw.Column(
            children: [
              pw.Divider(color: PdfColors.grey400),
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
                  'Dicetak: ${_formatDateTime(DateTime.now())}',
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
            // ==========================================
            // HEADER LAPORAN
            // ==========================================

            pw.Row(
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
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.green900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Laporan Rekap Harian Sensor & Irigasi',
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey700,
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
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.green50,
                    borderRadius: pw.BorderRadius.all(
                      const pw.Radius.circular(6),
                    ),
                    border: pw.Border.all(
                      color: PdfColors.green200,
                    ),
                  ),
                  child: pw.Text(
                    'Tanggal: $rawDate',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 15),

            // ==========================================
            // KONDISI LINGKUNGAN
            // ==========================================

            pw.Text(
              'Kondisi Lingkungan Umum',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),

            pw.SizedBox(height: 8),

            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.all(
                  const pw.Radius.circular(8),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      'Status Cuaca / Hujan Dominan:',
                      style: const pw.TextStyle(
                        fontSize: 11,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    rainStatus,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // ==========================================
            // TABEL RATA-RATA SENSOR
            // ==========================================

            pw.Text(
              'Rata-rata Pembacaan Sensor Harian',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),

            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 10,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green800,
              ),
              cellStyle: const pw.TextStyle(
                fontSize: 10,
              ),
              cellHeight: 28,
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
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
              data: <List<String>>[
                ['Parameter Sensor', 'Nilai Rata-rata'],
                [
                  'Suhu Udara (DHT)',
                  '${_formatNumber(record.avgTemperature)} °C',
                ],
                [
                  'Kelembapan Udara (DHT)',
                  '${_formatNumber(record.avgHumidity)} %',
                ],
                [
                  'Kelembapan Tanah',
                  '${_formatNumber(record.avgSoilMoisture)} %',
                ],
                [
                  'Level Kapasitas Tangki',
                  '${_formatNumber(record.avgTankLevel)} %',
                ],
              ],
            ),

            pw.SizedBox(height: 20),

            // ==========================================
            // DATA FLOW SENSOR
            // ==========================================

            pw.Text(
              'Sesi Aliran Air & Biaya Penyiraman',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),

            pw.SizedBox(height: 8),

            if (flow != null) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.teal300,
                  ),
                  borderRadius: pw.BorderRadius.all(
                    const pw.Radius.circular(8),
                  ),
                  color: PdfColors.teal50,
                ),
                child: pw.Column(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                  children: [
                    _buildPdfRow(
                      'Debit Aliran Air:',
                      '${_formatNumber(flow.flowRateLpm)} L/min',
                    ),

                    pw.SizedBox(height: 8),

                    _buildPdfRow(
                      'Volume Air Terpakai:',
                      flow.hasTotalVolume
                          ? '${_formatNumber(flow.totalVolumeLiters)} Liter'
                          : 'Belum tersedia',
                    ),

                    pw.SizedBox(height: 8),

                    _buildPdfRow(
                      'Durasi Aliran Air:',
                      flow.hasDuration
                          ? '${_formatNumber(flow.durationMinutes, decimals: 0)} Menit'
                          : 'Belum tersedia',
                    ),

                    pw.SizedBox(height: 10),
                    pw.Divider(color: PdfColors.teal200),
                    pw.SizedBox(height: 4),

                    _buildPdfRow(
                      'Total Biaya Air:',
                      flow.hasCost
                          ? 'Rp ${_formatIdr(flow.costIdr)}'
                          : 'Belum tersedia',
                      isBold: true,
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Text(
                'Catatan: Nilai yang belum tersedia menunjukkan '
                'data tersebut belum dikirim oleh backend.',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ] else ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(
                    const pw.Radius.circular(8),
                  ),
                ),
                child: pw.Text(
                  'Tidak ada data sesi aliran air tercatat '
                  'pada tanggal ini.',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
            ],
          ];
        },
      ),
    );

    // ==========================================
    // SHARE PDF
    // ==========================================

    final pdfBytes = await pdf.save();

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Laporan_Landia_Farm_$safeDate.pdf',
    );
  }

  // ==========================================================
  // PDF ROW
  // ==========================================================

  static pw.Widget _buildPdfRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    final style = pw.TextStyle(
      fontSize: 10,
      fontWeight:
          isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: isBold
          ? PdfColors.green900
          : PdfColors.black,
    );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.Text(
            label,
            style: style,
          ),
        ),
        pw.SizedBox(width: 12),
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

  // ==========================================================
  // NUMBER FORMATTING
  // ==========================================================

  /// Format angka dengan validasi finite.
  static String _formatNumber(
    double value, {
    int decimals = 1,
  }) {
    if (!value.isFinite) {
      return 'Belum tersedia';
    }

    return value.toStringAsFixed(decimals);
  }

  /// Format angka menjadi format Rupiah.
  ///
  /// Contoh:
  /// 150000 -> 150.000
  /// 1500000 -> 1.500.000
  static String _formatIdr(double amount) {
    if (!amount.isFinite) {
      return 'Belum tersedia';
    }

    final isNegative = amount < 0;
    final digits = amount.abs().round().toString();

    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]}.',
    );

    return isNegative ? '-$formatted' : formatted;
  }

  // ==========================================================
  // DATETIME FORMATTING
  // ==========================================================

  static String _formatDateTime(DateTime dateTime) {
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
