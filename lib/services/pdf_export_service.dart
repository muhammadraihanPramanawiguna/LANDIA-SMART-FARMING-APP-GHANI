import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sensor_reading.dart';

class PdfExportService {
  /// Generates and shares/prints a PDF report for a specific daily recap record
  static Future<void> generateDailyRecapPdf(DailyRecapRecord record) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
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
                    ],
                  ),
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
                      border: pw.Border.all(color: PdfColors.green200),
                    ),
                    child: pw.Text(
                      'Tanggal: ${record.date}',
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

              // Weather Status Summary
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
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.all(
                    const pw.Radius.circular(8),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Status Cuaca / Hujan Dominan:'),
                    pw.Text(
                      record.dominantRainStatus,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Sensor Averages Table
              pw.Text(
                'Rata-rata Pembacaan Sensor Harian',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.green800,
                ),
                cellHeight: 28,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerRight,
                },
                data: <List<String>>[
                  ['Parameter Sensor', 'Nilai Rata-rata'],
                  [
                    'Suhu Udara (DHT)',
                    '${record.avgTemperature.toStringAsFixed(1)} °C',
                  ],
                  [
                    'Kelembapan Udara (DHT)',
                    '${record.avgHumidity.toStringAsFixed(1)} %',
                  ],
                  [
                    'Kelembapan Tanah',
                    '${record.avgSoilMoisture.toStringAsFixed(1)} %',
                  ],
                  [
                    'Level Kapasitas Tangki',
                    '${record.avgTankLevel.toStringAsFixed(1)} %',
                  ],
                ],
              ),
              pw.SizedBox(height: 20),

              // Water Flow & Cost Section
              pw.Text(
                'Sesi Aliran Air & Estimasi Biaya (Sensor Flow)',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey900,
                ),
              ),
              pw.SizedBox(height: 8),
              if (record.flowSession != null) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.teal300),
                    borderRadius: pw.BorderRadius.all(
                      const pw.Radius.circular(8),
                    ),
                    color: PdfColors.teal50,
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _buildPdfRow(
                        'Volume Air Terpakai:',
                        '${record.flowSession!.totalVolumeLiters.toStringAsFixed(1)} Liter',
                      ),
                      pw.SizedBox(height: 6),
                      _buildPdfRow(
                        'Durasi Aliran Air:',
                        '${record.flowSession!.durationMinutes.toStringAsFixed(0)} Menit',
                      ),
                      pw.SizedBox(height: 6),
                      _buildPdfRow(
                        'Debit Aliran Rata-rata:',
                        '${record.flowSession!.flowRateLpm.toStringAsFixed(1)} L/m³',
                      ),
                      pw.SizedBox(height: 8),
                      pw.Divider(color: PdfColors.teal200),
                      pw.SizedBox(height: 4),
                      _buildPdfRow(
                        'Total Biaya Air (Sekali Siram):',
                        'Rp ${_formatIdr(record.flowSession!.costIdr)}',
                        isBold: true,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                pw.Text(
                  'Tidak ada data sesi aliran air tercatat pada tanggal ini.',
                  style: pw.TextStyle(
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                  ),
                ),
              ],

              // Footer
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Landia Farm Smart Monitoring System',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Dicetak otomatis pada: ${DateTime.now().toString().split(".")[0]}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    // Trigger printing/sharing dialog
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Laporan_Landia_Farm_${record.date}.pdf',
    );
  }

  static pw.Widget _buildPdfRow(
    String label,
    String value, {
    bool isBold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: isBold ? PdfColors.green900 : PdfColors.black,
          ),
        ),
      ],
    );
  }

  static String _formatIdr(double amount) {
    final intVal = amount.round();
    return intVal.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }
}
