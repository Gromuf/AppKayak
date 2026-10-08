import 'dart:io';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/athlete_run.dart';
import 'create_session_screen.dart';

class SummaryScreen extends StatelessWidget {
  final String title;
  final String embarcation;
  final bool hasPortes;
  final int portesCount;
  final bool isConcentration;
  final int concentrationStep;
  final Map<String, List<AthleteRun>> athleteRuns;

  const SummaryScreen({
    super.key,
    required this.title,
    required this.embarcation,
    required this.hasPortes,
    required this.portesCount,
    this.isConcentration = false,
    this.concentrationStep = 1,
    required this.athleteRuns,
  });

  String _formatTime(int milliseconds) {
    if (milliseconds == 0) return "-";
    int seconds = (milliseconds / 1000).truncate();
    int minutes = (seconds / 60).truncate();
    String minutesStr = (minutes % 60).toString().padLeft(2, '0');
    String secondsStr = (seconds % 60).toString().padLeft(2, '0');
    int millis = (milliseconds % 1000 / 100).truncate();
    return "$minutesStr:$secondsStr.$millis";
  }

  // Calcul exact des portes cumulées en mode concentration
  int _calculateTotalConcentrationPortes() {
    if (!isConcentration || portesCount <= 0) return 0;
    int total = 0;
    for (int p = concentrationStep; p < portesCount; p += concentrationStep) {
      for (int i = 1; i <= p; i++) {
        total += 1;
      }
    }
    for (int i = 1; i <= portesCount; i++) {
      total += 1;
    }
    return total;
  }

  // ---------------------------------------------------------------------------
  // DONNÉES COMMUNES À L'EXPORT (PDF + Excel)
  // ---------------------------------------------------------------------------

  String get _embarcationLabel =>
      '$embarcation${hasPortes ? " ($portesCount portes)" : ""}';

  String get _concentrationLabel =>
      'Concentration (pas de +$concentrationStep) - ${_calculateTotalConcentrationPortes()} portes cumulées par run';

  List<String> _buildHeaders(int maxRunsCount) {
    final headers = <String>['Athlète'];
    for (int i = 0; i < maxRunsCount; i++) {
      headers.add('Temps ${i + 1}');
    }
    if (hasPortes) headers.add('Pénalités moy.');
    if (isConcentration) headers.add('Portes cumulées / run');
    headers.add('Best');
    headers.add('Moyenne');
    return headers;
  }

  List<List<String>> _buildRows(int maxRunsCount) {
    final rows = <List<String>>[];
    final concentrationTotal = _calculateTotalConcentrationPortes();

    athleteRuns.forEach((athlete, runs) {
      int? bestTime;
      int? avgTime;
      double? avgPenalties;

      if (runs.isNotEmpty) {
        bestTime = runs.map((r) => r.totalMs).reduce((a, b) => a < b ? a : b);
        avgTime = (runs.map((r) => r.totalMs).reduce((a, b) => a + b) / runs.length).round();
        avgPenalties = runs.map((r) => r.penaltySec).reduce((a, b) => a + b) / runs.length;
      }

      final row = <String>[athlete];

      for (int i = 0; i < maxRunsCount; i++) {
        if (i < runs.length) {
          final run = runs[i];
          row.add(run.penaltySec > 0
              ? "${_formatTime(run.rawTimeMs)} -> ${_formatTime(run.totalMs)} (+${run.penaltySec}s)"
              : _formatTime(run.rawTimeMs));
        } else {
          row.add('-');
        }
      }

      if (hasPortes) {
        row.add(avgPenalties != null ? "${avgPenalties.toStringAsFixed(1)} s" : "-");
      }
      if (isConcentration) {
        row.add('$concentrationTotal');
      }
      row.add(bestTime != null ? _formatTime(bestTime) : "-");
      row.add(avgTime != null ? _formatTime(avgTime) : "-");

      rows.add(row);
    });

    return rows;
  }

  String _fileBaseName() {
    final safeTitle = title.replaceAll(RegExp(r'[^\w\-]+'), '_');
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return '${safeTitle}_$stamp';
  }

  // ---------------------------------------------------------------------------
  // EXPORT PDF
  // ---------------------------------------------------------------------------

  Future<void> _exportPdf(BuildContext context, int maxRunsCount) async {
    try {
      final currentDate = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());
      final headers = _buildHeaders(maxRunsCount);
      final rows = _buildRows(maxRunsCount);

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) => [
            pw.Text(title, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text('Date : $currentDate'),
            pw.Text('Embarcation : $_embarcationLabel'),
            if (isConcentration) pw.Text('Type de séance : $_concentrationLabel'),
            pw.SizedBox(height: 14),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: rows,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(5),
            ),
          ],
        ),
      );

      final bytes = await doc.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_fileBaseName()}.pdf');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Résultats - $title',
      );
    } catch (e) {
      _showError(context, e);
    }
  }

  // ---------------------------------------------------------------------------
  // EXPORT EXCEL (.xlsx) - s'ouvre dans Excel, Google Sheets, LibreOffice
  // ---------------------------------------------------------------------------

  Future<void> _exportExcel(BuildContext context, int maxRunsCount) async {
    try {
      final currentDate = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());
      final headers = _buildHeaders(maxRunsCount);
      final rows = _buildRows(maxRunsCount);

      final excel = Excel.createExcel();
      const sheetName = 'Resultats';
      excel.rename(excel.getDefaultSheet()!, sheetName);
      final sheet = excel[sheetName];

      sheet.appendRow([TextCellValue(title)]);
      sheet.appendRow([TextCellValue('Date : $currentDate')]);
      sheet.appendRow([TextCellValue('Embarcation : $_embarcationLabel')]);
      if (isConcentration) {
        sheet.appendRow([TextCellValue('Type de séance : $_concentrationLabel')]);
      }
      sheet.appendRow([TextCellValue('')]);

      sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
      for (final row in rows) {
        sheet.appendRow(row.map((c) => TextCellValue(c)).toList());
      }

      final bytes = excel.save();
      if (bytes == null) throw Exception('Impossible de générer le fichier Excel');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_fileBaseName()}.xlsx');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        subject: 'Résultats - $title',
      );
    } catch (e) {
      _showError(context, e);
    }
  }

  void _showError(BuildContext context, Object e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur d\'export : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    int maxRunsCount = 0;
    for (var runs in athleteRuns.values) {
      if (runs.length > maxRunsCount) maxRunsCount = runs.length;
    }

    int concentrationTotalPortes = _calculateTotalConcentrationPortes();

    return Scaffold(
      appBar: AppBar(
        title: Text('Récapitulatif - $title'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12.0),
            width: double.infinity,
            color: Colors.blue.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Embarcation : $embarcation ${hasPortes ? "($portesCount portes)" : ""}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                if (isConcentration) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Mode Concentration (+ $concentrationStep) ➔ $concentrationTotalPortes portes cumulées',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                  ),
                ],
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Résultats par athlète',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12.0),
              itemCount: athleteRuns.length,
              itemBuilder: (context, index) {
                final entry = athleteRuns.entries.elementAt(index);
                final athlete = entry.key;
                final runs = entry.value;

                int? bestTime;
                int? avgTime;
                double? avgPenalties;

                if (runs.isNotEmpty) {
                  bestTime = runs.map((r) => r.totalMs).reduce((a, b) => a < b ? a : b);
                  avgTime = (runs.map((r) => r.totalMs).reduce((a, b) => a + b) / runs.length).round();
                  avgPenalties = runs.map((r) => r.penaltySec).reduce((a, b) => a + b) / runs.length;
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CORRECTION ANTI-OVERFLOW : Utilisation d'un Wrap flexible pour le nom et les scores Best/Moy
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Text(
                              athlete,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (bestTime != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.green.shade200),
                                    ),
                                    child: Text(
                                      'Best: ${_formatTime(bestTime)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 11),
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                if (avgTime != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                    child: Text(
                                      'Moy: ${_formatTime(avgTime)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 12),

                        if (runs.isEmpty)
                          const Text('Aucun run enregistré', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
                        else
                          Column(
                            children: runs.asMap().entries.map((runEntry) {
                              int runIdx = runEntry.key;
                              AthleteRun run = runEntry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Run ${runIdx + 1}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    Flexible(
                                      child: Text(
                                        run.penaltySec > 0
                                            ? "${_formatTime(run.rawTimeMs)} ➔ ${_formatTime(run.totalMs)} (+${run.penaltySec}s)"
                                            : _formatTime(run.rawTimeMs),
                                        style: const TextStyle(fontFamily: 'Monospace', fontSize: 12, fontWeight: FontWeight.bold),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

                        if (hasPortes && avgPenalties != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Pénalités moyennes : ${avgPenalties.toStringAsFixed(1)} s',
                            style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _exportPdf(context, maxRunsCount),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('PDF', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => _exportExcel(context, maxRunsCount),
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Excel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const CreateSessionScreen()),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Retour au menu (Nouvelle séance)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}