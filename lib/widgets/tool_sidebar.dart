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
          if (_sizableTool(editor.activeTool)) ...[
            const SizedBox(height: 10),
            _sizeSlider(editor),
          ],
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

  /// Outils dont la taille se règle au curseur (crayon = épaisseur,
  /// symboles = échelle). L'unité et la plage dépendent de l'outil actif.
  static bool _sizableTool(Tool? tool) =>
      tool == Tool.crayon ||
      tool == Tool.sharp ||
      tool == Tool.flat ||
      tool == Tool.indication;

  /// Curseur unique, contextuel : pilote l'épaisseur du crayon ou l'échelle
  /// des symboles selon l'outil actif, chacun conservant sa propre valeur.
  Widget _sizeSlider(EditorController editor) {
    final isCrayon = editor.activeTool == Tool.crayon;
    final double min = isCrayon ? 1.0 : 0.4;
    final double max = isCrayon ? 12.0 : 2.5;
    final double value =
        (isCrayon ? editor.crayonSize : editor.notationSize).clamp(min, max);
    final String label = isCrayon
        ? '${editor.crayonSize.round()} pt'
        : '${(editor.notationSize * 100).round()} %';

    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: AppColors.subtext, fontSize: 11)),
        const SizedBox(height: 2),
        SizedBox(
          width: 42,
          height: 150,
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 3,
                activeTrackColor: AppColors.blue,
                inactiveTrackColor: AppColors.surface1,
                thumbColor: AppColors.blue,
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: (v) => isCrayon
                    ? editor.setCrayonSize(v)
                    : editor.setNotationSize(v),
              ),
            ),
          ),
        ),
      ],
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
