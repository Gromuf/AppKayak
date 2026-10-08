// Modèle pour stocker un run validé
class AthleteRun {
  final int rawTimeMs;
  final int penaltySec;
  
  AthleteRun({required this.rawTimeMs, required this.penaltySec});

  int get totalMs => rawTimeMs + (penaltySec * 1000);
}