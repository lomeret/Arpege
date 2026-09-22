import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import 'app_actions.dart';
import 'services/annotation_repository.dart';
import 'services/library_repository.dart';
import 'services/paths.dart';
import 'services/recent_files_repository.dart';
import 'state/editor_controller.dart';
import 'state/library_controller.dart';
import 'theme.dart';
import 'widgets/bookmarks_panel.dart';
import 'widgets/dialogs.dart';
import 'widgets/library_panel.dart';
import 'widgets/setlists_panel.dart';
import 'widgets/sheet_view.dart';
import 'widgets/toolbar.dart';
import 'widgets/tool_sidebar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android: draw under the system bars (edge-to-edge) and make them
  // transparent with light icons, to avoid the white Xiaomi bands that
  // cover the toolbar and status bar.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  pdfrxFlutterInitialize(); // required by pdfrx 2.x before any use

  // Storage is wired here and nowhere else: the controllers only ever see
  // the repository interfaces, which is what makes them testable.
  final locations = AppPaths();
  final recentFiles = FileRecentFilesRepository(locations: locations);
  final annotations = FileAnnotationRepository(locations: locations);
  final library = LibraryController(
    repository: FileLibraryRepository(locations: locations),
    recentFiles: recentFiles,
  );
  await library.load();
  // Migration: import the old recent files into the library.
  await library.importRecentFiles();

  runApp(ArpegeApp(
    library: library,
    annotations: annotations,
    recentFiles: recentFiles,
  ));
}

class ArpegeApp extends StatelessWidget {
  final LibraryController library;
  final AnnotationRepository annotations;
  final RecentFilesRepository recentFiles;

  const ArpegeApp({
    super.key,
    required this.library,
    required this.annotations,
    required this.recentFiles,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LibraryController>.value(value: library),
        ChangeNotifierProvider<EditorController>(
          create: (_) => EditorController(
            library,
            annotations: annotations,
            recentFiles: recentFiles,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Arpège',
        debugShowCheckedModeBanner: false,
        theme: buildArpegeTheme(),
        home: const ArpegeHome(),
      ),
    );
  }
}

class ArpegeHome extends StatefulWidget {
  const ArpegeHome({super.key});

  @override
  State<ArpegeHome> createState() => _ArpegeHomeState();
}

class _ArpegeHomeState extends State<ArpegeHome> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  LibraryController? _library;
  EditorController? _editor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_library != null) return;
    // Storage failures used to be swallowed; they are now reported by the
    // controllers and shown here, once each.
    _library = context.read<LibraryController>()..addListener(_showErrors);
    _editor = context.read<EditorController>()..addListener(_showErrors);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showErrors());
  }

  @override
  void dispose() {
    _library?.removeListener(_showErrors);
    _editor?.removeListener(_showErrors);
    super.dispose();
  }

  void _showErrors() {
    if (!mounted) return;
    final library = _library;
    if (library != null && library.lastError != null) {
      final message = library.lastError!;
      library.clearError();
      _showError(message);
    }
    final editor = _editor;
    if (editor != null && editor.lastError != null) {
      final message = editor.lastError!;
      editor.clearError();
      _showError(message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.red,
      duration: const Duration(seconds: 6),
    ));
  }

  /// Right-hand panels (Library / Bookmarks / Setlists) in wide mode.
  /// In narrow mode they live in the endDrawer, which has its own close action.
  bool _panelsOpen = true;

  void _togglePanels(bool wide) {
    if (wide) {
      setState(() => _panelsOpen = !_panelsOpen);
    } else {
      final scaffold = _scaffoldKey.currentState;
      if (scaffold == null) return;
      if (scaffold.isEndDrawerOpen) {
        Navigator.of(context).maybePop();
      } else {
        scaffold.openEndDrawer();
      }
    }
  }

  Map<ShortcutActivator, VoidCallback> _shortcuts(EditorController editor) => {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
            pickAndOpenPdf(context, editor),
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
            saveAnnotationsWithFeedback(context, editor),
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
            exportCurrentPdf(context, editor),
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
            editor.undo,
        const SingleActivator(LogicalKeyboardKey.keyY, control: true):
            editor.redo,
        const SingleActivator(LogicalKeyboardKey.keyZ,
            control: true, shift: true): editor.redo,
        const SingleActivator(LogicalKeyboardKey.keyD, control: true): () =>
            editor.toggleSpread(!editor.spreadView),
        const SingleActivator(LogicalKeyboardKey.keyB, control: true): () =>
            _addBookmark(editor),
        const SingleActivator(LogicalKeyboardKey.equal, control: true):
            editor.zoomIn,
        const SingleActivator(LogicalKeyboardKey.minus, control: true):
            editor.zoomOut,
        const SingleActivator(LogicalKeyboardKey.digit0, control: true):
            editor.fitView,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): editor.prevPage,
        const SingleActivator(LogicalKeyboardKey.arrowRight): editor.nextPage,
        const SingleActivator(LogicalKeyboardKey.pageUp): editor.prevPage,
        const SingleActivator(LogicalKeyboardKey.pageDown): editor.nextPage,
        // Bluetooth/USB page-turn pedals (AirTurn, PageFlip, iRig BlueTurn,
        // Donner…): they announce themselves as an HID keyboard, but their
        // default mapping varies by model — cover the most common
        // configurations in addition to the left/right arrows and
        // Page Up/Down already handled above.
        const SingleActivator(LogicalKeyboardKey.arrowUp): editor.prevPage,
        const SingleActivator(LogicalKeyboardKey.arrowDown): editor.nextPage,
        const SingleActivator(LogicalKeyboardKey.space): editor.nextPage,
        const SingleActivator(LogicalKeyboardKey.space, shift: true):
            editor.prevPage,
        const SingleActivator(LogicalKeyboardKey.backspace): editor.prevPage,
        const SingleActivator(LogicalKeyboardKey.home): editor.goFirst,
        const SingleActivator(LogicalKeyboardKey.end): editor.goLast,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            editor.setTool(null),
        const SingleActivator(LogicalKeyboardKey.f9): () =>
            _togglePanels(MediaQuery.sizeOf(context).width >= 900),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () =>
            editor.stepSong(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
            editor.stepSong(-1),
      };

  Future<void> _addBookmark(EditorController editor) async {
    if (editor.currentPdfPath == null) return;
    final page = editor.currentSourcePage;
    final label = await promptText(context,
        title: 'New bookmark', label: 'Bookmark name (page ${page + 1})');
    if (label != null) editor.addBookmark(label);
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorController>();

    return CallbackShortcuts(
      bindings: _shortcuts(editor),
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return Scaffold(
              key: _scaffoldKey,
              endDrawer: wide
                  ? null
                  : Drawer(
                      child: SafeArea(
                        child: PanelsView(
                          onClose: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
              body: SafeArea(
                child: Row(
                children: [
                  const ToolSidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        ArpegeToolbar(
                          onTogglePanels: () => _togglePanels(wide),
                          panelsOpen: !wide || _panelsOpen,
                        ),
                        const Expanded(child: SheetView()),
                        const _StatusBar(),
                      ],
                    ),
                  ),
                  if (wide && _panelsOpen)
                    Container(
                      width: 320,
                      decoration: const BoxDecoration(
                        color: AppColors.mantle,
                        border: Border(
                            left: BorderSide(color: AppColors.surface0)),
                      ),
                      child: PanelsView(
                        onClose: () => setState(() => _panelsOpen = false),
                      ),
                    ),
                ],
              ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Tabbed side panels (Library / Bookmarks / Setlists).
class PanelsView extends StatelessWidget {
  /// Closes the panel (collapses it in wide mode, closes the drawer otherwise).
  final VoidCallback? onClose;
  const PanelsView({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              // Compact labels: the close button takes up room at 320 px and
              // "Bookmarks" is the longest of the three tab names.
              const Expanded(
                child: TabBar(
                  labelColor: AppColors.blue,
                  unselectedLabelColor: AppColors.subtext,
                  indicatorColor: AppColors.blue,
                  labelPadding: EdgeInsets.symmetric(horizontal: 4),
                  labelStyle:
                      TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: TextStyle(fontSize: 13),
                  tabs: [
                    Tab(text: 'Library'),
                    Tab(text: 'Bookmarks'),
                    Tab(text: 'Setlists'),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Close panel (F9)',
                  visualDensity: VisualDensity.compact,
                  color: AppColors.subtext,
                  onPressed: onClose,
                ),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                LibraryPanel(),
                BookmarksPanel(),
                SetlistsPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<EditorController>();
    return Container(
      height: 30,
      color: AppColors.mantle,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (editor.hasUnsavedChanges)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Text(
                '● unsaved',
                style: TextStyle(color: AppColors.peach, fontSize: 12),
              ),
            ),
          Expanded(
            child: Text(
              editor.statusHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.subtext, fontSize: 12),
            ),
          ),
          const Text(
            'scroll: zoom   •   drag: pan   •   Esc: deselect',
            style: TextStyle(color: AppColors.subtext, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
