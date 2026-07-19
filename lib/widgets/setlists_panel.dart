import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../state/editor_controller.dart';
import '../state/library_controller.dart';
import '../theme.dart';
import 'dialogs.dart';

class SetlistsPanel extends StatelessWidget {
  const SetlistsPanel({super.key});

  Future<void> _open(BuildContext context, String scoreId) async {
    final editor = context.read<EditorController>();
    final ok = await editor.openScoreId(scoreId);
    if (!ok && context.mounted) {
      final score = context.read<LibraryController>().getScore(scoreId);
      await showInfo(context, 'Fichier introuvable',
          'Le fichier n\'existe plus :\n${score?.path ?? ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final editor = context.watch<EditorController>();
    final activeId = editor.activeSetlistId;
    final songs = activeId != null ? library.setlistScores(activeId) : <dynamic>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: Text('Setlists', style: TextStyle(color: AppColors.subtext)),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            itemCount: library.setlists.length,
            itemBuilder: (ctx, i) {
              final sl = library.setlists[i];
              return ListTile(
                dense: true,
                selected: sl.id == activeId,
                title: Text('${sl.name}  (${sl.scoreIds.length})',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => editor.selectSetlist(sl.id),
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final name = await promptText(context,
                          title: 'Renommer la setlist',
                          label: 'Nom',
                          initial: sl.name);
                      if (name != null && name.trim().isNotEmpty) {
                        await library.renameSetlist(sl.id, name.trim());
                      }
                    } else if (v == 'delete') {
                      if (editor.activeSetlistId == sl.id) {
                        editor.selectSetlist(null);
                      }
                      await library.removeSetlist(sl.id);
                    }
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(value: 'rename', child: Text('Renommer…')),
                    PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                  ],
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.playlist_add, size: 18),
            label: const Text('Nouvelle setlist'),
            onPressed: () async {
              final name = await promptText(context,
                  title: 'Nouvelle setlist', label: 'Nom de la setlist');
              if (name != null && name.trim().isNotEmpty) {
                final sl = await library.addSetlist(name.trim());
                editor.selectSetlist(sl.id);
              }
            },
          ),
        ),
        const Divider(height: 1),
        const Padding(
          padding: EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: Text('Morceaux', style: TextStyle(color: AppColors.subtext)),
        ),
        Expanded(
          child: activeId == null
              ? const Center(
                  child: Text('Sélectionnez une setlist',
                      style: TextStyle(color: AppColors.subtext)))
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (ctx, i) {
                    final score = songs[i];
                    final title = score.title.isNotEmpty
                        ? score.title
                        : p.basename(score.path);
                    return ListTile(
                      dense: true,
                      selected: score.id == editor.currentScoreId,
                      title: Text(title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _open(context, score.id),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 18),
                        onSelected: (v) async {
                          final ids =
                              library.getSetlist(activeId)!.scoreIds;
                          if (v == 'up' && i > 0) {
                            final tmp = ids[i - 1];
                            ids[i - 1] = ids[i];
                            ids[i] = tmp;
                            await library.setSetlistOrder(activeId, ids);
                          } else if (v == 'down' && i < ids.length - 1) {
                            final tmp = ids[i + 1];
                            ids[i + 1] = ids[i];
                            ids[i] = tmp;
                            await library.setSetlistOrder(activeId, ids);
                          } else if (v == 'remove') {
                            await library.removeFromSetlist(activeId, score.id);
                          }
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(value: 'up', child: Text('Monter')),
                          PopupMenuItem(value: 'down', child: Text('Descendre')),
                          PopupMenuDivider(),
                          PopupMenuItem(
                              value: 'remove',
                              child: Text('Retirer de la setlist')),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
