import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../app_actions.dart';
import '../models/score.dart';
import '../state/editor_controller.dart';
import '../state/library_controller.dart';
import '../theme.dart';
import 'dialogs.dart';
import 'metadata_dialog.dart';

class LibraryPanel extends StatefulWidget {
  const LibraryPanel({super.key});

  @override
  State<LibraryPanel> createState() => _LibraryPanelState();
}

class _LibraryPanelState extends State<LibraryPanel> {
  String _query = '';

  Future<void> _open(String scoreId) async {
    final editor = context.read<EditorController>();
    final ok = await editor.openScoreId(scoreId);
    if (!ok && mounted) {
      final score = context.read<LibraryController>().getScore(scoreId);
      await showInfo(context, 'Fichier introuvable',
          'Le fichier n\'existe plus :\n${score?.path ?? ''}');
    }
  }

  Future<void> _editMetadata(String scoreId) async {
    final library = context.read<LibraryController>();
    final score = library.getScore(scoreId);
    if (score == null) return;
    final values = await showMetadataDialog(context, score);
    if (values != null) {
      await library.updateMetadata(scoreId, values);
    }
  }

  Future<void> _remove(String scoreId) async {
    final library = context.read<LibraryController>();
    final score = library.getScore(scoreId);
    final ok = await confirm(
      context,
      title: 'Retirer de la bibliothèque',
      message:
          'Retirer « ${score?.title ?? ''} » de la bibliothèque ?\n(Le fichier PDF et ses annotations ne sont pas supprimés.)',
      okLabel: 'Retirer',
    );
    if (ok) await library.removeScore(scoreId);
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final editor = context.watch<EditorController>();
    final scores = library.search(_query);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher (titre, compositeur…)',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: scores.isEmpty
              ? const Center(
                  child: Text('Bibliothèque vide',
                      style: TextStyle(color: AppColors.subtext)))
              : ListView.builder(
                  itemCount: scores.length,
                  itemBuilder: (ctx, i) {
                    final Score score = scores[i];
                    final exists = File(score.path).existsSync();
                    final title = score.title.isNotEmpty
                        ? score.title
                        : p.basename(score.path);
                    final subtitle =
                        score.composer.isNotEmpty ? score.composer : null;
                    return ListTile(
                      dense: true,
                      selected: score.id == editor.currentScoreId,
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: exists ? AppColors.text : AppColors.surface1,
                        ),
                      ),
                      subtitle: subtitle != null
                          ? Text(subtitle,
                              maxLines: 1, overflow: TextOverflow.ellipsis)
                          : null,
                      onTap: () => _open(score.id),
                      trailing: _scoreMenu(context, library, score.id),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter…'),
                  onPressed: () =>
                      pickAndOpenPdf(context, context.read<EditorController>()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scoreMenu(
      BuildContext context, LibraryController library, String scoreId) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (value) {
        if (value == 'open') {
          _open(scoreId);
        } else if (value == 'meta') {
          _editMetadata(scoreId);
        } else if (value == 'remove') {
          _remove(scoreId);
        } else if (value.startsWith('setlist:')) {
          library.addToSetlist(value.substring(8), scoreId);
        }
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(value: 'open', child: Text('Ouvrir')),
        const PopupMenuItem(value: 'meta', child: Text('Métadonnées…')),
        if (library.setlists.isNotEmpty) const PopupMenuDivider(),
        for (final sl in library.setlists)
          PopupMenuItem(
              value: 'setlist:${sl.id}', child: Text('Ajouter à : ${sl.name}')),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: 'remove', child: Text('Retirer de la bibliothèque')),
      ],
    );
  }
}
