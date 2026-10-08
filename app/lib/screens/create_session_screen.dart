import 'package:flutter/material.dart';
import 'chrono_screen.dart';

// Petite structure pour lier un athlète à sa catégorie individuelle
class ParticipantEntry {
  String name;
  String category; // 'K1' ou 'C1'

  ParticipantEntry({required this.name, this.category = 'K1'});
}

class CreateSessionScreen extends StatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  State<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends State<CreateSessionScreen> {
  final _titleController = TextEditingController();
  String _selectedEmbarcation = 'Slalom';
  final List<String> _embarcations = ['Slalom', 'Descente'];
  
  // Liste des participants enrichie (Nom + Catégorie)
  final List<ParticipantEntry> _participants = [];
  final _newParticipantController = TextEditingController();

  bool _hasPortes = true;
  final _portesCountController = TextEditingController();

  // Options pour la concentration
  bool _isConcentration = false;
  int _concentrationStep = 1;

  void _addParticipant() {
    final name = _newParticipantController.text.trim();
    if (name.isNotEmpty && !_participants.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
      setState(() {
        _participants.add(ParticipantEntry(name: name, category: 'K1'));
        _newParticipantController.clear();
      });
    }
  }

  void _removeParticipant(ParticipantEntry participant) {
    setState(() {
      _participants.remove(participant);
    });
  }

  // Boîte de dialogue qui s'ouvre lorsqu'on clique sur le footer
  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('À propos & Contact'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Application de chronométrage canoë-kayak'),
              SizedBox(height: 12),
              Text('Développé par : Louis Beaumois', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('Contact : louis.beaumois@gmail.com'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isSlalom = _selectedEmbarcation == 'Slalom';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Création de Séance'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Titre de la séance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            const Text('Embarcation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedEmbarcation,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _embarcations.map((String emb) {
                return DropdownMenuItem<String>(value: emb, child: Text(emb));
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedEmbarcation = newValue;
                    if (newValue != 'Slalom') {
                      _isConcentration = false;
                    }
                    if (newValue == 'Descente') {
                      _hasPortes = false;
                    } else {
                      _hasPortes = true;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 20),

            const Text('Participants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newParticipantController,
                    decoration: const InputDecoration(
                      hintText: 'Nom du participant',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _addParticipant(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addParticipant,
                  child: const Text('Ajouter'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Liste des participants en COLONNE avec choix K1/C1 et suppression
            if (_participants.isEmpty)
              const Text('Aucun participant ajouté.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _participants.length,
                itemBuilder: (context, index) {
                  final participant = _participants[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            participant.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ),
                        // Sélecteur de catégorie K1 / C1
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue.shade300),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: DropdownButton<String>(
                            value: participant.category,
                            underline: const SizedBox(),
                            items: ['K1', 'C1'].map((String cat) {
                              return DropdownMenuItem<String>(
                                value: cat,
                                child: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold)),
                              );
                            }).toList(),
                            onChanged: (String? newCat) {
                              if (newCat != null) {
                                setState(() {
                                  participant.category = newCat;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Bouton Suppression (Croix rouge)
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => _removeParticipant(participant),
                          tooltip: 'Supprimer',
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),

            // Section Portes (uniquement si Slalom)
            if (isSlalom) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Activer les portes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Switch(
                    value: _hasPortes,
                    onChanged: (value) => setState(() {
                      _hasPortes = value;
                      if (!value) _isConcentration = false;
                    }),
                  ),
                ],
              ),
              if (_hasPortes) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _portesCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Ex: 18',
                    labelText: 'Nombre de portes',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    border: Border.all(color: Colors.blue.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Séance type concentration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Switch(
                            value: _isConcentration,
                            onChanged: (value) => setState(() => _isConcentration = value),
                          ),
                        ],
                      ),
                      if (_isConcentration) ...[
                        const SizedBox(height: 10),
                        const Text('Pas de progression :', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _buildStepButton(1),
                            const SizedBox(width: 10),
                            _buildStepButton(2),
                            const SizedBox(width: 10),
                            _buildStepButton(3),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: 30),

            // Bouton de lancement
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  if (_titleController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Veuillez entrer un titre pour la séance !')),
                    );
                    return;
                  }
                  if (_participants.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Veuillez ajouter au moins un participant !')),
                    );
                    return;
                  }

                  // Validation obligatoire du nombre de portes si actif
                  int portesVal = 0;
                  if (isSlalom && _hasPortes) {
                    portesVal = int.tryParse(_portesCountController.text) ?? 0;
                    if (portesVal <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Veuillez indiquer un nombre de portes valide !')),
                      );
                      return;
                    }
                  }

                  List<String> participantNames = _participants
                      .map((p) => "${p.name} (${p.category})")
                      .toList();

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChronoSessionScreen(
                        title: _titleController.text.trim(),
                        embarcation: _selectedEmbarcation,
                        participants: participantNames,
                        hasPortes: isSlalom ? _hasPortes : false,
                        portesCount: portesVal,
                        isConcentration: isSlalom ? _isConcentration : false,
                        concentrationStep: _concentrationStep,
                      ),
                    ),
                  );
                },
                child: const Text('Commencer la séance', style: TextStyle(fontSize: 18)),
              ),
            ),

            const SizedBox(height: 25),

            // --- FOOTER CRÉATEUR / CONTACT ---
            Center(
              child: TextButton(
                onPressed: _showContactDialog,
                child: const Text(
                  'Contact',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepButton(int step) {
    bool isSelected = _concentrationStep == step;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue : Colors.white,
          foregroundColor: isSelected ? Colors.white : Colors.black,
        ),
        onPressed: () => setState(() => _concentrationStep = step),
        child: Text('+$step'),
      ),
    );
  }
}