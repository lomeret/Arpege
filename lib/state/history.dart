import '../models/annotation_document.dart';

/// Pile d'annulation/rétablissement par instantanés — port de `features/history.py`.
class HistoryManager {
  final int maxDepth;
  final List<AnnotationSnapshot> _undo = [];
  final List<AnnotationSnapshot> _redo = [];

  HistoryManager({this.maxDepth = 50});

  void push(AnnotationSnapshot current) {
    _undo.add(current.copy());
    if (_undo.length > maxDepth) _undo.removeAt(0);
    _redo.clear();
  }

  AnnotationSnapshot? undo(AnnotationSnapshot current) {
    if (_undo.isEmpty) return null;
    _redo.add(current.copy());
    return _undo.removeLast();
  }

  AnnotationSnapshot? redo(AnnotationSnapshot current) {
    if (_redo.isEmpty) return null;
    _undo.add(current.copy());
    return _redo.removeLast();
  }

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void clear() {
    _undo.clear();
    _redo.clear();
  }

  /// Retire le dernier instantané empilé (ex. tracé au crayon vide).
  void popUndo() {
    if (_undo.isNotEmpty) _undo.removeLast();
  }
}
