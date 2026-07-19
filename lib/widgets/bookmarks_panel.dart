import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/editor_controller.dart';
import '../theme.dart';
import 'dialogs.dart';

class BookmarksPanel extends StatelessWidget {
  const BookmarksPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorController>();
    final bookmarks = [...editor.doc.bookmarks]
      ..sort((a, b) => a.page.compareTo(b.page));

    return Column(
      children: [
        Expanded(
          child: bookmarks.isEmpty
              ? const Center(
                  child: Text('Aucun signet',
                      style: TextStyle(color: AppColors.subtext)))
              : ListView.builder(
                  itemCount: bookmarks.length,
                  itemBuilder: (ctx, i) {
                    final bm = bookmarks[i];
                    return ListTile(
                      dense: true,
                      title: Text('p.${bm.page + 1}   ${bm.label}',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => editor.goToSourcePage(bm.page),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => editor.removeBookmark(bm.page),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('Signet à la page courante'),
            onPressed: editor.currentPdfPath == null
                ? null
                : () async {
                    final page = editor.currentSourcePage;
                    final label = await promptText(
                      context,
                      title: 'Nouveau signet',
                      label: 'Nom du signet (page ${page + 1})',
                    );
                    if (label != null) editor.addBookmark(label);
                  },
          ),
        ),
      ],
    );
  }
}
