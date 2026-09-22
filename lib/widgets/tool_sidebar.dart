import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/editor_controller.dart';
import '../theme.dart';
import 'dialogs.dart';

/// Vertical tool rail: pencil, sharp, flat, indication, eraser, color,
/// thickness, clear (port of `build_sidebar`).
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
          _tool(editor, Tool.crayon, const Icon(Icons.edit), 'Pencil — free drawing'),
          _tool(editor, Tool.sharp, const _Glyph('♯'), 'Add a sharp'),
          _tool(editor, Tool.flat, const _Glyph('♭'), 'Add a flat'),
          _tool(editor, Tool.indication, const _Glyph('T', italic: true),
              'Add a text indication'),
          _tool(editor, Tool.eraser, const Icon(Icons.cleaning_services_outlined),
              'Eraser — remove an element'),
          const SizedBox(height: 6),
          const Divider(height: 1, color: AppColors.surface0),
          const SizedBox(height: 6),
          // Pencil color
          Tooltip(
            message: 'Pencil color',
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
            message: 'Clear all annotations on this page',
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

  /// Tools whose size is adjusted with the slider (pencil = thickness,
  /// symbols = scale). The unit and range depend on the active tool.
  static bool _sizableTool(Tool? tool) =>
      tool == Tool.crayon ||
      tool == Tool.sharp ||
      tool == Tool.flat ||
      tool == Tool.indication;

  /// Single contextual slider: drives the pencil thickness or the symbol
  /// scale depending on the active tool, each keeping its own value.
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
