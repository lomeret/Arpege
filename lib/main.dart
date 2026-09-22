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

  /// Panneaux de droite (Bibliothèque / Signets / Setlists) en mode large.
  /// En mode étroit ils vivent dans l'endDrawer, qui a sa propre fermeture.
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

/// Panneaux latéraux en onglets (Bibliothèque / Signets / Setlists).
class PanelsView extends StatelessWidget {
  /// Ferme le panneau (repli latéral en mode large, fermeture du drawer sinon).
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
              // Libellés compactés : la croix prend de la place sur 320 px et
              // « Bibliothèque » est le plus long des trois onglets.
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
                    Tab(text: 'Bibliothèque'),
                    Tab(text: 'Signets'),
                    Tab(text: 'Setlists'),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Fermer le panneau (F9)',
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
