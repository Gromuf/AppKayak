import 'package:flutter/material.dart';
import 'dart:async';
import '../models/athlete_run.dart';
import 'summary_screen.dart';

class ChronoSessionScreen extends StatefulWidget {
  final String title;
  final String embarcation;
  final List<String> participants;
  final bool hasPortes;
  final int portesCount;
  final bool isConcentration;
  final int concentrationStep;

  const ChronoSessionScreen({
    super.key,
    required this.title,
    required this.embarcation,
    required this.participants,
    required this.hasPortes,
    required this.portesCount,
    this.isConcentration = false,
    this.concentrationStep = 1,
  });

  @override
  State<ChronoSessionScreen> createState() => _ChronoSessionScreenState();
}

class _ChronoSessionScreenState extends State<ChronoSessionScreen> {
  late List<String> _order; // ordre d'affichage (modifiable par drag & drop)
  late Map<String, int> _currentTimes;
  late Map<String, bool> _isRunning;
  late Map<String, bool> _isFinished;
  late Map<String, int> _currentPenalties;
  late Map<String, List<AthleteRun>> _athleteRuns;
  
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _order = List<String>.from(widget.participants);
    _currentTimes = {for (var p in widget.participants) p: 0};
    _isRunning = {for (var p in widget.participants) p: false};
    _isFinished = {for (var p in widget.participants) p: false};
    _currentPenalties = {for (var p in widget.participants) p: 0};
    _athleteRuns = {for (var p in widget.participants) p: []};

    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        for (var p in _order) {
          if (_isRunning[p] == true) {
            _currentTimes[p] = _currentTimes[p]! + 100;
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int milliseconds) {
    int seconds = (milliseconds / 1000).truncate();
    int minutes = (seconds / 60).truncate();
    String minutesStr = (minutes % 60).toString().padLeft(2, '0');
    String secondsStr = (seconds % 60).toString().padLeft(2, '0');
    int millis = (milliseconds % 1000 / 100).truncate();
    return "$minutesStr:$secondsStr.$millis";
  }

  void _saveRun(String participant) {
    setState(() {
      final run = AthleteRun(
        rawTimeMs: _currentTimes[participant]!,
        penaltySec: widget.hasPortes ? _currentPenalties[participant]! : 0,
      );
      _athleteRuns[participant]!.add(run);

      _currentTimes[participant] = 0;
      _isFinished[participant] = false;
      _currentPenalties[participant] = 0;
    });
  }

  // Réorganise les athlètes (drag & drop) et répercute l'ordre sur le récapitulatif / export
  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
      _athleteRuns = {for (var p in _order) p: _athleteRuns[p]!};
    });
  }

  // Lance d'un coup tous les chronos à l'arrêt (ceux déjà en cours ou terminés non enregistrés sont ignorés)
  void _startAll() {
    setState(() {
      for (final p in _order) {
        if (_isRunning[p] != true && _isFinished[p] != true) {
          _isRunning[p] = true;
        }
      }
    });
  }

  void _deleteCurrentChrono(String participant) {
    setState(() {
      _currentTimes[participant] = 0;
      _isFinished[participant] = false;
      _currentPenalties[participant] = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'Embarcation : ${widget.embarcation} ${widget.hasPortes ? "(${widget.portesCount} portes max)" : ""}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _order.any((p) => _isRunning[p] != true && _isFinished[p] != true)
                    ? _startAll
                    : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Tout démarrer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              onReorder: _onReorder,
              itemCount: _order.length,
              itemBuilder: (context, index) {
                final participant = _order[index];
                final isRunning = _isRunning[participant] ?? false;
                final isFinished = _isFinished[participant] ?? false;
                final penaltySec = _currentPenalties[participant] ?? 0;
                final runsList = _athleteRuns[participant] ?? [];
                
                final totalMilliseconds = _currentTimes[participant]! + (penaltySec * 1000);

                return Card(
                  key: ValueKey(participant),
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // LIGNE 1 : Nom de l'athlète et Boutons Start / Stop en vis-à-vis
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ReorderableDragStartListener(
                              index: index,
                              child: Container(
                                width: 48,
                                height: 56,
                                margin: const EdgeInsets.only(right: 10),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.drag_indicator, size: 32, color: Colors.black54),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    participant,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  if (runsList.isNotEmpty)
                                    Text(
                                      '${runsList.length} run(s) enregistrés',
                                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                                    ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    backgroundColor: isRunning || isFinished ? Colors.grey[300] : Colors.green,
                                    foregroundColor: isRunning || isFinished ? Colors.grey : Colors.white,
                                  ),
                                  onPressed: isRunning || isFinished
                                      ? null
                                      : () => setState(() => _isRunning[participant] = true),
                                  child: const Text('Start'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    backgroundColor: !isRunning ? Colors.grey[300] : Colors.red,
                                    foregroundColor: !isRunning ? Colors.grey : Colors.white,
                                  ),
                                  onPressed: !isRunning
                                      ? null
                                      : () => setState(() {
                                            _isRunning[participant] = false;
                                            _isFinished[participant] = true;
                                          }),
                                  child: const Text('Stop'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 10),
                        const Divider(height: 1),
                        const SizedBox(height: 10),

                        // LIGNE 2 : Affichage du Chrono et du Total séparés du nom
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Chrono : ${_formatTime(_currentTimes[participant]!)}",
                              style: const TextStyle(fontSize: 20, fontFamily: 'Monospace', fontWeight: FontWeight.bold),
                            ),
                            if (widget.hasPortes && isFinished) ...[
                              const SizedBox(height: 4),
                              Text(
                                "Total (+${penaltySec}s) : ${_formatTime(totalMilliseconds)}",
                                style: const TextStyle(fontSize: 16, fontFamily: 'Monospace', fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ],
                          ],
                        ),

                        if (widget.hasPortes && isFinished) ...[
                          const SizedBox(height: 12),
                          // PÉNALITÉS EN WRAP (Anti-Overflow garanti)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Pénalités : $penaltySec s',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(40, 30),
                                ),
                                onPressed: penaltySec >= 2 
                                    ? () => setState(() => _currentPenalties[participant] = penaltySec - 2) 
                                    : null,
                                child: const Text('-2s'),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(40, 30),
                                ),
                                onPressed: penaltySec >= 50 
                                    ? () => setState(() => _currentPenalties[participant] = penaltySec - 50) 
                                    : null,
                                child: const Text('-50s'),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(40, 30),
                                ),
                                onPressed: () => setState(() => _currentPenalties[participant] = penaltySec + 2),
                                child: const Text('+2s'),
                              ),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: const Size(40, 30),
                                ),
                                onPressed: () => setState(() => _currentPenalties[participant] = penaltySec + 50),
                                child: const Text('+50s'),
                              ),
                            ],
                          ),
                        ],

                        if (isFinished) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                                onPressed: () => _deleteCurrentChrono(participant),
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: const Text('Supprimer'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () => _saveRun(participant),
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text('Enregistrer le Run'),
                              ),
                            ],
                          ),
                        ],

                        if (runsList.isNotEmpty) ...[
                          const Divider(height: 16),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              'Voir l\'historique des runs (${runsList.length})',
                              style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.bold),
                            ),
                            children: runsList.asMap().entries.map((entry) {
                              int runIndex = entry.key;
                              AthleteRun run = entry.value;
                              return ListTile(
                                dense: true,
                                title: Text('Run ${runIndex + 1}'),
                                subtitle: Text('Temps brut : ${_formatTime(run.rawTimeMs)} | Pénalités : +${run.penaltySec}s'),
                                trailing: Text(
                                  _formatTime(run.totalMs),
                                  style: const TextStyle(fontFamily: 'Monospace', fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              );
                            }).toList(),
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
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SummaryScreen(
                      title: widget.title,
                      embarcation: widget.embarcation,
                      hasPortes: widget.hasPortes,
                      portesCount: widget.portesCount,
                      isConcentration: widget.isConcentration,
                      concentrationStep: widget.concentrationStep,
                      athleteRuns: _athleteRuns,
                    ),
                  ),
                );
              },
              child: const Text('Terminer la séance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}