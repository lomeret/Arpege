import 'package:flutter/material.dart';

/// Demande une chaîne à l'utilisateur (équivalent de `QInputDialog.getText`).
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? label,
  String initial = '',
  String okLabel = 'OK',
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler')),
        ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: Text(okLabel)),
      ],
    ),
  );
}

/// Demande une confirmation oui/non.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'Confirmer',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler')),
        ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(okLabel)),
      ],
    ),
  );
  return result ?? false;
}

const _palette = [
  Color(0xFFE74C3C), // rouge (défaut)
  Color(0xFFE67E22), // orange
  Color(0xFFF1C40F), // jaune
  Color(0xFF27AE60), // vert
  Color(0xFF2980B9), // bleu
  Color(0xFF8E44AD), // violet
  Color(0xFF16A085), // turquoise
  Color(0xFF000000), // noir
  Color(0xFF7F8C8D), // gris
  Color(0xFFEC407A), // rose
];

/// Choix d'une couleur de crayon dans une palette de préréglages.
Future<Color?> pickColor(BuildContext context, Color current) {
  return showDialog<Color>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Couleur du crayon'),
      content: SizedBox(
        width: 260,
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in _palette)
              InkWell(
                onTap: () => Navigator.of(ctx).pop(color),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.value == current.value
                          ? Colors.white
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler')),
      ],
    ),
  );
}

/// Affiche un message d'information simple.
Future<void> showInfo(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK')),
      ],
    ),
  );
}
