import 'package:arpege/models/annotation_document.dart';
import 'package:arpege/pdf/pdf_renderer.dart';
import 'package:arpege/services/annotation_repository.dart';
import 'package:arpege/services/json_file.dart';
import 'package:arpege/services/library_repository.dart';
import 'package:arpege/services/recent_files_repository.dart';
import 'package:arpege/state/editor_controller.dart';
import 'package:arpege/state/library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for pdfrx: the lifecycle of the annotation document does not
/// depend on how pages are rendered.
class _FakeRenderer extends PdfRenderer {
  bool _open = false;

  @override
  Future<void> open(String path) async {
    _open = true;
  }

  @override
  Future<void> close() async {
    _open = false;
  }

  @override
  bool get isOpen => _open;

  @override
  int get pageCount => 3;
}

class _RecordingAnnotationRepository implements AnnotationRepository {
  final List<String> savedPaths = [];
  final Map<String, AnnotationDocument> stored = {};
  bool failSaves = false;

  @override
  Future<StoredAnnotations?> load(String pdfPath) async {
    final doc = stored[pdfPath];
    return doc == null ? null : StoredAnnotations(doc: doc);
  }

  @override
  Future<AnnotationDocument> import(String jsonPath) async =>
      AnnotationDocument();

  @override
  Future<String> save({
    required String pdfPath,
    required AnnotationDocument doc,
    required int totalPages,
    String? createdIso,
  }) async {
    if (failSaves) throw StorageException('Disk is full', path: pdfPath);
    savedPaths.add(pdfPath);
    stored[pdfPath] = doc;
    return '$pdfPath.json';
  }
}

class _InMemoryLibraryRepository implements LibraryRepository {
  LibraryData data = LibraryData.empty();

  @override
  Future<LibraryData> load() async => data;

  @override
  Future<void> save(LibraryData data) async => this.data = data;
}

class _InMemoryRecentFiles implements RecentFilesRepository {
  final List<String> paths = [];

  @override
  Future<List<String>> load() async => List.of(paths);

  @override
  Future<void> add(String filePath) async {
    paths
      ..remove(filePath)
      ..insert(0, filePath);
  }

  @override
  Future<void> remove(String filePath) async => paths.remove(filePath);
}

void main() {
  late _RecordingAnnotationRepository annotations;
  late EditorController editor;

  setUp(() {
    annotations = _RecordingAnnotationRepository();
    editor = EditorController(
      LibraryController(
        repository: _InMemoryLibraryRepository(),
        recentFiles: _InMemoryRecentFiles(),
      ),
      annotations: annotations,
      recentFiles: _InMemoryRecentFiles(),
      renderer: _FakeRenderer(),
      // The lifecycle hooks need a WidgetsBinding; they do nothing but call
      // flushPendingChanges(), which is exercised directly below.
      observeLifecycle: false,
    );
  });

  tearDown(() => editor.dispose());

  group('unsaved-changes tracking', () {
    test('a freshly opened score is clean', () async {
      await editor.openPdf('/scores/a.pdf');
      expect(editor.hasUnsavedChanges, isFalse);
    });

    test('nothing is dirty while no score is open', () {
      expect(editor.hasUnsavedChanges, isFalse);
    });

    test('placing a notation marks the document dirty', () async {
      await editor.openPdf('/scores/a.pdf');
      editor.placeSharp(0, 0.5, 0.5);
      expect(editor.hasUnsavedChanges, isTrue);
    });

    test('drawing a stroke marks the document dirty', () async {
      await editor.openPdf('/scores/a.pdf');
      editor.beginStroke(0, 0.1, 0.1);
      editor.extendStroke(0.2, 0.2);
      editor.endStroke();
      expect(editor.hasUnsavedChanges, isTrue);
    });

    test('reordering pages marks the document dirty', () async {
      await editor.openPdf('/scores/a.pdf');
      editor.applyPageSequence([2, 0, 1]);
      expect(editor.hasUnsavedChanges, isTrue);
    });

    test('undo and redo mark the document dirty', () async {
      await editor.openPdf('/scores/a.pdf');
      editor.placeSharp(0, 0.5, 0.5);
      await editor.saveAnnotations();
      expect(editor.hasUnsavedChanges, isFalse);

      editor.undo();
      expect(editor.hasUnsavedChanges, isTrue);

      await editor.saveAnnotations();
      editor.redo();
      expect(editor.hasUnsavedChanges, isTrue);
    });

    test('saving clears the dirty state', () async {
      await editor.openPdf('/scores/a.pdf');
      editor.placeSharp(0, 0.5, 0.5);
      await editor.saveAnnotations();
      expect(editor.hasUnsavedChanges, isFalse);
    });
  });

  group('flushing before the document is replaced', () {
    test('opening another score saves the pending annotations first',
        () async {
      await editor.openPdf('/scores/a.pdf');
      editor.placeSharp(0, 0.5, 0.5);

      await editor.openPdf('/scores/b.pdf');

      expect(annotations.savedPaths, ['/scores/a.pdf']);
      expect(annotations.stored['/scores/a.pdf']!.notations.length, 1);
      expect(editor.currentPdfPath, '/scores/b.pdf');
      expect(editor.hasUnsavedChanges, isFalse);
    });

    test('opening another score writes nothing when nothing changed',
        () async {
      await editor.openPdf('/scores/a.pdf');
      await editor.openPdf('/scores/b.pdf');
      expect(annotations.savedPaths, isEmpty);
    });

    test('flushPendingChanges is a no-op on a clean document', () async {
      await editor.openPdf('/scores/a.pdf');
      await editor.flushPendingChanges();
      expect(annotations.savedPaths, isEmpty);
    });

    test('importing an annotations file saves the current one first',
        () async {
      await editor.openPdf('/scores/a.pdf');
      editor.placeSharp(0, 0.5, 0.5);
      await editor.loadAnnotationsFromPath('/elsewhere/other.json');
      expect(annotations.savedPaths, ['/scores/a.pdf']);
    });

    test('annotations written earlier are found again on reopen', () async {
      await editor.openPdf('/scores/a.pdf');
      editor.placeSharp(0, 0.25, 0.75);
      await editor.openPdf('/scores/b.pdf');
      await editor.openPdf('/scores/a.pdf');

      expect(editor.doc.notations.single.relativeX, 0.25);
      expect(editor.hasUnsavedChanges, isFalse);
    });
  });

  group('storage failures', () {
    test('a failed save is reported and keeps the document dirty', () async {
      await editor.openPdf('/scores/a.pdf');
      editor.placeSharp(0, 0.5, 0.5);
      annotations.failSaves = true;

      final path = await editor.saveAnnotations();

      expect(path, isNull);
      expect(editor.lastError, contains('Disk is full'));
      expect(editor.hasUnsavedChanges, isTrue,
          reason: 'a failed save must not look like a successful one');
    });

    test('a failed flush does not silently drop the annotations', () async {
      await editor.openPdf('/scores/a.pdf');
      editor.placeSharp(0, 0.5, 0.5);
      annotations.failSaves = true;

      await editor.flushPendingChanges();

      expect(editor.hasUnsavedChanges, isTrue);
      expect(editor.lastError, isNotNull);
    });
  });
}
