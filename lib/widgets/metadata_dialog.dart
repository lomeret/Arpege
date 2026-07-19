import 'package:flutter/material.dart';

import '../models/score.dart';

const _labels = {
  'title': 'Titre',
  'composer': 'Compositeur',
  'arranger': 'Arrangeur',
  'key': 'Tonalité',
  'tempo': 'Tempo',
  'genre': 'Genre',
};

/// Éditeur des métadonnées d'une partition (port de `MetadataDialog`).
/// Renvoie les nouvelles valeurs, ou `null` si annulé.
Future<Map<String, String>?> showMetadataDialog(
    BuildContext context, Score score) {
  final controllers = <String, TextEditingController>{
    for (final f in ['title', 'composer', 'arranger', 'key', 'tempo', 'genre'])
      f: TextEditingController(text: score.get(f)),
  };
  final notesCtrl = TextEditingController(text: score.notes);

  return showDialog<Map<String, String>>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Métadonnées de la partition'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in controllers.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: TextField(
                    controller: entry.value,
                    decoration: InputDecoration(labelText: _labels[entry.key]),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                score.path,
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            final values = <String, String>{
              for (final e in controllers.entries) e.key: e.value.text,
              'notes': notesCtrl.text,
            };
            Navigator.of(ctx).pop(values);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
}
