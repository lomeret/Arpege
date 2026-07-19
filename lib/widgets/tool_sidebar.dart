import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/editor_controller.dart';
import '../theme.dart';
import 'dialogs.dart';

/// Rail vertical d'outils : crayon, dièse, bémol, indication, gomme,
/// couleur, épaisseur, effacer (port de `build_sidebar`).
class ToolSidebar extends StatelessWidget {
  const ToolSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorController>();

    return Container(
      width: 62,
      color: AppColors.mantle,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(
        children: [
          _tool(editor, Tool.crayon, const Icon(Icons.edit), 'Crayon — dessin libre'),
          _tool(editor, Tool.sharp, const _Glyph('♯'), 'Ajouter un dièse'),
          _tool(editor, Tool.flat, const _Glyph('♭'), 'Ajouter un bémol'),
          _tool(editor, Tool.indication, const _Glyph('T', italic: true),
              'Ajouter une indication texte'),
          _tool(editor, Tool.eraser, const Icon(Icons.cleaning_services_outlined),
              'Gomme — supprimer un élément'),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.surface0),
          const SizedBox(height: 6),
          // Couleur du crayon
          Tooltip(
            message: 'Couleur du crayon',
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () async {
                final color = await pickColor(context, editor.crayonColor);
                if (color != null) editor.setCrayonColor(color);
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: editor.crayonColor,
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (final size in const [2, 4, 6])
            _sizeButton(editor, size, size == 2 ? 6 : (size == 4 ? 10 : 14)),
          const Spacer(),
          Tooltip(
            message: 'Effacer toutes les annotations de la page',
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
              onPressed: editor.currentPdfPath == null
                  ? null
                  : editor.clearCurrentPage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tool(EditorController editor, Tool tool, Widget icon, String tip) {
    final selected = editor.activeTool == tool;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Tooltip(
        message: tip,
        child: Material(
          color: selected ? AppColors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => editor.setTool(selected ? null : tool),
            child: SizedBox(
              width: 42,
              height: 42,
              child: IconTheme(
                data: IconThemeData(
                    color: selected ? AppColors.crust : AppColors.text,
                    size: 22),
                child: DefaultTextStyle(
                  style: TextStyle(
                      color: selected ? AppColors.crust : AppColors.text,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                  child: Center(child: icon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sizeButton(EditorController editor, int size, double diameter) {
    final selected = editor.crayonSize == size;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: 'Épaisseur du trait : $size pt',
        child: Material(
          color: selected ? AppColors.surface1 : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => editor.setCrayonSize(size),
            child: SizedBox(
              width: 42,
              height: 34,
              child: Center(
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: const BoxDecoration(
                      color: AppColors.text, shape: BoxShape.circle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  final String text;
  final bool italic;
  const _Glyph(this.text, {this.italic = false});

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(fontStyle: italic ? FontStyle.italic : FontStyle.normal));
  }
}
