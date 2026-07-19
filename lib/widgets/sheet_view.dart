import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/editor_controller.dart';
import '../theme.dart';
import 'annotation_painter.dart';

const double _kSpreadGap = 60;
const double _kFitMargin = 40;
const double _kZoomMin = 0.03;
const double _kZoomMax = 6.0;

/// Vue de la partition : zoom/pan (InteractiveViewer) + canvas d'annotations.
class SheetView extends StatefulWidget {
  const SheetView({super.key});

  @override
  State<SheetView> createState() => _SheetViewState();
}

class _SheetViewState extends State<SheetView> {
  late EditorController c;
  bool _wired = false;

  List<PageSlot> _slots = [];
  Size _canvasSize = Size.zero;
  Size _viewport = Size.zero;
  String _key = '';
  bool _building = false;

  // Slot actif pendant un tracé/effacement.
  PageSlot? _activeSlot;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_wired) {
      c = context.read<EditorController>();
      c.addListener(_onControllerChanged);
      c.fitViewCallback = _fit;
      c.zoomByCallback = _zoomBy;
      _wired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildSlots(fit: true));
    }
  }

  @override
  void dispose() {
    c.removeListener(_onControllerChanged);
    super.dispose();
  }

  String _computeKey() =>
      '${c.currentPdfPath}|${c.seqPos}|${c.spreadView}|${c.effectiveSequence.join(",")}';

  void _onControllerChanged() {
    final key = _computeKey();
    if (key != _key) {
      _rebuildSlots(fit: true);
    } else if (mounted) {
      setState(() {}); // simple repaint (annotations, outils…)
    }
  }

  Future<void> _rebuildSlots({bool fit = false}) async {
    if (_building) return;
    _building = true;
    _key = _computeKey();

    if (!c.renderer.isOpen) {
      setState(() {
        _slots = [];
        _canvasSize = Size.zero;
      });
      _building = false;
      return;
    }

    final seq = c.effectiveSequence;
    if (seq.isEmpty) {
      setState(() {
        _slots = [];
        _canvasSize = Size.zero;
      });
      _building = false;
      return;
    }

    final pos = c.seqPos.clamp(0, seq.length - 1);
    final current = seq[pos];

    // Spécifications de bandes : vue simple ou double (moitiés).
    final List<(int, double, double)> specs;
    if (c.spreadView && pos + 1 < seq.length) {
      specs = [
        (current, 0.5, 1.0),
        (seq[pos + 1], 0.0, 0.5),
      ];
    } else {
      specs = [(current, 0.0, 1.0)];
    }

    final slots = <PageSlot>[];
    double yOffset = 0;
    double maxW = 0;
    for (final (page, y0, y1) in specs) {
      final ui.Image image = await c.renderer.renderPage(page);
      final W = image.width.toDouble();
      final H = image.height.toDouble();
      final bandH = (y1 - y0) * H;
      final rect = Rect.fromLTWH(0, yOffset, W, bandH);
      slots.add(PageSlot(page: page, y0: y0, y1: y1, rect: rect, image: image));
      yOffset += bandH + _kSpreadGap;
      if (W > maxW) maxW = W;
    }

    if (!mounted) {
      _building = false;
      return;
    }
    setState(() {
      _slots = slots;
      _canvasSize = Size(maxW, yOffset - _kSpreadGap);
    });
    _building = false;
    if (fit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
    }
  }

  // ---- Zoom / fit ----------------------------------------------------

  void _fit() {
    if (_canvasSize.isEmpty || _viewport.isEmpty) return;
    final cw = _canvasSize.width;
    final ch = _canvasSize.height;
    final scale = ((_viewport.width) / (cw + 2 * _kFitMargin))
        .clamp(_kZoomMin, _kZoomMax)
        .toDouble();
    final scaleH = ((_viewport.height) / (ch + 2 * _kFitMargin))
        .clamp(_kZoomMin, _kZoomMax)
        .toDouble();
    final s = scale < scaleH ? scale : scaleH;
    final tx = (_viewport.width - cw * s) / 2;
    final ty = (_viewport.height - ch * s) / 2;
    c.viewTransform.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(s);
  }

  void _zoomBy(double factor) {
    if (_viewport.isEmpty) return;
    final current = c.viewTransform.value.getMaxScaleOnAxis();
    final target = current * factor;
    if (target < _kZoomMin || target > _kZoomMax) return;
    final focal = Offset(_viewport.width / 2, _viewport.height / 2);
    final s = Matrix4.identity()
      ..translate(focal.dx, focal.dy)
      ..scale(factor)
      ..translate(-focal.dx, -focal.dy);
    c.viewTransform.value = s.multiplied(c.viewTransform.value);
  }

  // ---- Conversion pointeur ------------------------------------------

  PageSlot? _slotAt(Offset canvasPos) {
    for (final slot in _slots) {
      if (slot.contains(canvasPos)) return slot;
    }
    return null;
  }

  Offset _clampToSlot(PageSlot slot, Offset p) => Offset(
        p.dx.clamp(slot.rect.left, slot.rect.right),
        p.dy.clamp(slot.rect.top, slot.rect.bottom),
      );

  // ---- Gestes : placement ponctuel ----------------------------------

  Future<void> _onCanvasTap(TapUpDetails d) async {
    final slot = _slotAt(d.localPosition);
    if (slot == null) return;
    final rel = slot.canvasToRel(d.localPosition);
    switch (c.activeTool) {
      case Tool.sharp:
        c.placeSharp(slot.page, rel.dx, rel.dy);
        break;
      case Tool.flat:
        c.placeFlat(slot.page, rel.dx, rel.dy);
        break;
      case Tool.eraser:
        c.eraseAt(slot.page, rel.dx, rel.dy);
        break;
      case Tool.indication:
        final text = await _promptIndication();
        if (text != null && text.trim().isNotEmpty) {
          c.placeIndication(slot.page, rel.dx, rel.dy, text);
        }
        break;
      default:
        break;
    }
  }

  Future<String?> _promptIndication() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Indication musicale'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Texte de l\'indication'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Annuler')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text),
              child: const Text('Ajouter')),
        ],
      ),
    );
  }

  // ---- Gestes : dessin / effacement au glisser ----------------------

  void _onPanStart(DragStartDetails d) {
    final slot = _slotAt(d.localPosition);
    if (slot == null) return;
    _activeSlot = slot;
    final rel = slot.canvasToRel(d.localPosition);
    if (c.activeTool == Tool.crayon) {
      c.beginStroke(slot.page, rel.dx, rel.dy);
    } else if (c.activeTool == Tool.eraser) {
      c.eraseAt(slot.page, rel.dx, rel.dy);
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final slot = _activeSlot;
    if (slot == null) return;
    final clamped = _clampToSlot(slot, d.localPosition);
    final rel = slot.canvasToRel(clamped);
    if (c.activeTool == Tool.crayon) {
      c.extendStroke(rel.dx, rel.dy);
    } else if (c.activeTool == Tool.eraser) {
      c.eraseAt(slot.page, rel.dx, rel.dy);
    }
  }

  void _onPanEnd(DragEndDetails d) {
    if (c.activeTool == Tool.crayon) c.endStroke();
    _activeSlot = null;
  }

  // ---- Tap plein écran : tourner la page ----------------------------

  void _onViewportTap(TapUpDetails d) {
    if (_viewport.isEmpty) return;
    if (d.localPosition.dx >= _viewport.width / 2) {
      c.nextPage();
    } else {
      c.prevPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<EditorController>(); // rebuild sur changement d'outil, etc.
    final tool = c.activeTool;
    final hasContent = _slots.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = Size(constraints.maxWidth, constraints.maxHeight);

        if (!c.renderer.isOpen) return const _Placeholder();
        if (!hasContent) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.blue),
          );
        }

        final canvas = SizedBox(
          width: _canvasSize.width,
          height: _canvasSize.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: tool != null ? _onCanvasTap : null,
            onPanStart:
                (tool == Tool.crayon || tool == Tool.eraser) ? _onPanStart : null,
            onPanUpdate:
                (tool == Tool.crayon || tool == Tool.eraser) ? _onPanUpdate : null,
            onPanEnd:
                (tool == Tool.crayon || tool == Tool.eraser) ? _onPanEnd : null,
            child: CustomPaint(
              size: _canvasSize,
              painter: AnnotationPainter(
                slots: _slots,
                notations: c.doc.notations,
                drawings: c.doc.drawings,
                activeStrokePoints: c.activeStrokePoints,
                activeStrokePage: c.activeStrokePage,
                crayonColor: c.crayonColor,
                crayonSize: c.crayonSize.toDouble(),
                showLabels: _slots.length > 1,
                repaint: c.strokeTick,
              ),
            ),
          ),
        );

        final viewer = InteractiveViewer(
          transformationController: c.viewTransform,
          panEnabled: tool == null,
          scaleEnabled: true,
          minScale: _kZoomMin,
          maxScale: _kZoomMax,
          boundaryMargin: const EdgeInsets.all(2000),
          constrained: false,
          child: canvas,
        );

        return Container(
          color: AppColors.crust,
          child: GestureDetector(
            onTapUp: tool == null ? _onViewportTap : null,
            child: viewer,
          ),
        );
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.crust,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/Logo.png', width: 160, height: 160),
            const SizedBox(height: 24),
            const Text(
              'Aucune partition ouverte — Ctrl+O pour ouvrir un PDF',
              style: TextStyle(color: AppColors.subtext, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
