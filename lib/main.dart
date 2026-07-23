import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import 'app_actions.dart';
import 'services/recent_files.dart';
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
  // Android : dessine sous les barres système (edge-to-edge) et rend-les
  // transparentes avec des icônes claires, pour éviter les bandeaux blancs
  // Xiaomi qui recouvrent la toolbar et la barre de statut.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  pdfrxFlutterInitialize(); // requis par pdfrx 2.x avant toute utilisation
  final library = LibraryController();
  await library.load();
  // Migration : importe les anciens fichiers récents dans la bibliothèque.
  await library.importPaths(await RecentFiles.load());
  runApp(ArpegeApp(library: library));
}

class ArpegeApp extends StatelessWidget {
  final LibraryController library;
  const ArpegeApp({super.key, required this.library});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LibraryController>.value(value: library),
        ChangeNotifierProvider<EditorController>(
          create: (_) => EditorController(library),
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
        const SingleActivator(LogicalKeyboardKey.home): editor.goFirst,
        const SingleActivator(LogicalKeyboardKey.end): editor.goLast,
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            editor.setTool(null),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): () =>
            editor.stepSong(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): () =>
            editor.stepSong(-1),
      };

  Future<void> _addBookmark(EditorController editor) async {
    if (editor.currentPdfPath == null) return;
    final page = editor.currentSourcePage;
    final label = await promptText(context,
        title: 'Nouveau signet', label: 'Nom du signet (page ${page + 1})');
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
              endDrawer:
                  wide ? null : const Drawer(child: PanelsView()),
              body: SafeArea(
                child: Row(
                children: [
                  const ToolSidebar(),
                  Expanded(
                    child: Column(
                      children: [
                        ArpegeToolbar(
                          onTogglePanels: wide
                              ? null
                              : () =>
                                  _scaffoldKey.currentState?.openEndDrawer(),
                        ),
                        const Expanded(child: SheetView()),
                        const _StatusBar(),
                      ],
                    ),
                  ),
                  if (wide)
                    Container(
                      width: 320,
                      decoration: const BoxDecoration(
                        color: AppColors.mantle,
                        border: Border(
                            left: BorderSide(color: AppColors.surface0)),
                      ),
                      child: const PanelsView(),
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

/// Panneaux latéraux en onglets (Bibliothèque / Signets / Setlists).
class PanelsView extends StatelessWidget {
  const PanelsView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: const [
          SizedBox(height: 8),
          TabBar(
            labelColor: AppColors.blue,
            unselectedLabelColor: AppColors.subtext,
            indicatorColor: AppColors.blue,
            tabs: [
              Tab(text: 'Bibliothèque'),
              Tab(text: 'Signets'),
              Tab(text: 'Setlists'),
            ],
          ),
          Expanded(
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
          Expanded(
            child: Text(
              editor.statusHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.subtext, fontSize: 12),
            ),
          ),
          const Text(
            'molette : zoom   •   glisser : déplacer   •   Échap : désélectionner',
            style: TextStyle(color: AppColors.subtext, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
