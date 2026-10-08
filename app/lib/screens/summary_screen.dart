import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
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

  String _generateGoogleDocHtml(int maxRunsCount) {
    String currentDate = DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now());
    int concentrationTotalPortes = _calculateTotalConcentrationPortes();

    StringBuffer html = StringBuffer();
    html.write("<h1>$title</h1>");
    html.write("<p><b>Date :</b> $currentDate</p>");
    html.write("<p><b>Embarcation :</b> $embarcation ${hasPortes ? "($portesCount portes)" : ""}</p>");
    if (isConcentration) {
      html.write("<p><b>Type de séance :</b> Concentration (Pas de +$concentrationStep) — <b>Total portes cumulées par run :</b> $concentrationTotalPortes portes</p>");
    }
    html.write("<br>");

    html.write("<table border='1' cellspacing='0' cellpadding='6' style='border-collapse: collapse; border-color: #ccc;'>");
    html.write("<tr style='background-color: #f2f2f2;'>");
    html.write("<th>Athlète</th>");
    for (int i = 0; i < maxRunsCount; i++) {
      html.write("<th>Temps ${i + 1}</th>");
    }
    if (hasPortes) {
      html.write("<th>Pénalités moy.</th>");
    }
    if (isConcentration) {
      html.write("<th>Portes cumulées / run</th>");
    }
    html.write("<th>Best</th>");
    html.write("<th>Moyenne</th>");
    html.write("</tr>");

    athleteRuns.forEach((athlete, runs) {
      int? bestTime;
      int? avgTime;
      double? avgPenalties;

      if (runs.isNotEmpty) {
        bestTime = runs.map((r) => r.totalMs).reduce((a, b) => a < b ? a : b);
        avgTime = (runs.map((r) => r.totalMs).reduce((a, b) => a + b) / runs.length).round();
        avgPenalties = runs.map((r) => r.penaltySec).reduce((a, b) => a + b) / runs.length;
      }

      html.write("<tr>");
      html.write("<td><b>$athlete</b></td>");

      for (int i = 0; i < maxRunsCount; i++) {
        if (i < runs.length) {
          final run = runs[i];
          String cellText = run.penaltySec > 0
              ? "${_formatTime(run.rawTimeMs)} &rarr; ${_formatTime(run.totalMs)} (+${run.penaltySec}s)"
              : _formatTime(run.rawTimeMs);
          html.write("<td style='font-family: monospace;'>$cellText</td>");
        } else {
          html.write("<td style='text-align: center;'>-</td>");
        }
      }

      if (hasPortes) {
        String penText = avgPenalties != null ? "${avgPenalties.toStringAsFixed(1)} s" : "-";
        html.write("<td style='font-family: monospace; text-align: center; color: #d9534f;'>$penText</td>");
      }

      if (isConcentration) {
        html.write("<td style='text-align: center; font-weight: bold;'>$concentrationTotalPortes</td>");
      }

      String bestText = bestTime != null ? _formatTime(bestTime) : "-";
      String avgText = avgTime != null ? _formatTime(avgTime) : "-";
      html.write("<td style='font-family: monospace; font-weight: bold; color: #5cb85c;'>$bestText</td>");
      html.write("<td style='font-family: monospace; font-weight: bold;'>$avgText</td>");
      html.write("</tr>");
    });

    html.write("</table>");
    return html.toString();
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      final htmlContent = _generateGoogleDocHtml(maxRunsCount);
                      Share.share(htmlContent, subject: 'Résultats - $title');
                    },
                    icon: const Icon(Icons.description),
                    label: const Text('Exporter vers Google Doc', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
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