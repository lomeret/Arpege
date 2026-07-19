import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Réordonner / masquer / dupliquer les pages (port de `PageOrderDialog`).
/// N'affecte jamais le PDF d'origine : renvoie une séquence d'indices source.
Future<List<int>?> showPageOrderDialog(
  BuildContext context, {
  required int pageCount,
  required List<int> sequence,
  required Future<ui.Image> Function(int page) thumbProvider,
}) {
  return showDialog<List<int>>(
    context: context,
    builder: (ctx) => _PageOrderDialog(
      pageCount: pageCount,
      initial: sequence,
      thumbProvider: thumbProvider,
    ),
  );
}

class _PageOrderDialog extends StatefulWidget {
  final int pageCount;
  final List<int> initial;
  final Future<ui.Image> Function(int page) thumbProvider;

  const _PageOrderDialog({
    required this.pageCount,
    required this.initial,
    required this.thumbProvider,
  });

  @override
  State<_PageOrderDialog> createState() => _PageOrderDialogState();
}

class _PageOrderDialogState extends State<_PageOrderDialog> {
  late List<int> _seq = List.of(widget.initial);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Gérer les pages'),
      content: SizedBox(
        width: 360,
        height: 520,
        child: Column(
          children: [
            const Text(
              'Glissez pour réordonner. La séquence n\'altère pas le PDF d\'origine.',
              style: TextStyle(color: AppColors.subtext),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: true,
                itemCount: _seq.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _seq.removeAt(oldIndex);
                    _seq.insert(newIndex, item);
                  });
                },
                itemBuilder: (ctx, i) {
                  final src = _seq[i];
                  return Card(
                    key: ValueKey('$i-$src'),
                    color: AppColors.surface0,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      leading: SizedBox(
                        width: 40,
                        height: 56,
                        child: FutureBuilder<ui.Image>(
                          future: widget.thumbProvider(src),
                          builder: (ctx, snap) => snap.hasData
                              ? RawImage(image: snap.data, fit: BoxFit.contain)
                              : const ColoredBox(color: AppColors.surface1),
                        ),
                      ),
                      title: Text('Page ${src + 1}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
                            tooltip: 'Dupliquer',
                            onPressed: () =>
                                setState(() => _seq.insert(i + 1, src)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.visibility_off, size: 18),
                            tooltip: 'Masquer',
                            onPressed: () => setState(() => _seq.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(
              () => _seq = List.generate(widget.pageCount, (i) => i)),
          child: const Text('Réinitialiser'),
        ),
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler')),
        ElevatedButton(
            onPressed: () => Navigator.of(context).pop(_seq),
            child: const Text('OK')),
      ],
    );
  }
}
