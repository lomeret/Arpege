import 'package:flutter/material.dart';

/// Prompts the user for a string (equivalent of `QInputDialog.getText`).
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
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: Text(okLabel)),
      ],
    ),
  );
}

/// Asks for a yes/no confirmation.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String okLabel = 'Confirm',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(okLabel)),
      ],
    ),
  );
  return result ?? false;
}

const _palette = [
  Color(0xFFE74C3C), // red (default)
  Color(0xFFE67E22), // orange
  Color(0xFFF1C40F), // yellow
  Color(0xFF27AE60), // green
  Color(0xFF2980B9), // blue
  Color(0xFF8E44AD), // purple
  Color(0xFF16A085), // teal
  Color(0xFF000000), // black
  Color(0xFF7F8C8D), // gray
  Color(0xFFEC407A), // pink
];

/// Picks a pencil color from a preset palette.
Future<Color?> pickColor(BuildContext context, Color current) {
  return showDialog<Color>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Pencil color'),
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
                      color: color == current
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
            child: const Text('Cancel')),
      ],
    ),
  );
}

/// Shows a simple information message.
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
