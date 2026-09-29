import 'dart:ui' as ui;

import 'package:arpege/main.dart';
import 'package:arpege/models/annotation_document.dart';
import 'package:arpege/pdf/pdf_renderer.dart';
import 'package:arpege/services/annotation_repository.dart';
import 'package:arpege/services/library_repository.dart';
import 'package:arpege/services/recent_files_repository.dart';
import 'package:arpege/state/editor_controller.dart';
import 'package:arpege/state/library_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// In-memory stand-ins for pdfrx and the storage, to pump the real window.
class FakeRenderer extends PdfRenderer {
  bool _open = false;
  ui.Image? page;

  @override
  Future<void> open(String path) async => _open = true;

  @override
  Future<void> close() async => _open = false;

  @override
  bool get isOpen => _open;

  @override
  int get pageCount => 3;

  @override
  Future<ui.Image> renderPage(int index) async => page!;
}

class NoAnnotations implements AnnotationRepository {
  @override
  Future<StoredAnnotations?> load(String pdfPath) async => null;

  @override
  Future<AnnotationDocument> import(String jsonPath) async =>
      AnnotationDocument();

  @override
  Future<String> save({
    required String pdfPath,
    required AnnotationDocument doc,
    required int totalPages,
    String? createdIso,
  }) async =>
      '$pdfPath.json';
}

class InMemoryLibraryRepository implements LibraryRepository {
  LibraryData data = LibraryData.empty();

  @override
  Future<LibraryData> load() async => data;

  @override
  Future<void> save(LibraryData data) async => this.data = data;
}

class NoRecentFiles implements RecentFilesRepository {
  @override
  Future<List<String>> load() async => [];

  @override
  Future<void> add(String filePath) async {}

  @override
  Future<void> remove(String filePath) async {}
}

/// Pumps [ArpegeHome] on a 1400×900 window with a 3-page score open.
Future<EditorController> pumpArpegeWithScore(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final renderer = FakeRenderer();
  renderer.page = await tester.runAsync(
      () => createTestImage(width: 600, height: 800, cache: false));
  final library = LibraryController(
    repository: InMemoryLibraryRepository(),
    recentFiles: NoRecentFiles(),
  );
  final editor = EditorController(
    library,
    annotations: NoAnnotations(),
    recentFiles: NoRecentFiles(),
    renderer: renderer,
    observeLifecycle: false,
  );
  await editor.openPdf('/scores/a.pdf');

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<LibraryController>.value(value: library),
      ChangeNotifierProvider<EditorController>.value(value: editor),
    ],
    child: const MaterialApp(home: ArpegeHome()),
  ));
  await tester.pumpAndSettle();
  return editor;
}
