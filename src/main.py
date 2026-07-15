"""
Arpège — éditeur de partitions PDF (interface Qt / PySide6).
"""

import json
import os
import sys
from datetime import datetime

import fitz

from PySide6.QtCore import Qt, QPointF, QRectF, QSize
from PySide6.QtGui import (QAction, QColor, QFont, QIcon, QImage, QKeySequence,
                           QPainter, QPainterPath, QPen, QPixmap, QPolygonF, QShortcut)
from PySide6.QtWidgets import (QApplication, QButtonGroup, QColorDialog, QFileDialog,
                               QFrame, QGraphicsDropShadowEffect, QGraphicsItem,
                               QGraphicsPathItem, QGraphicsRectItem, QGraphicsScene,
                               QGraphicsSimpleTextItem, QGraphicsView, QHBoxLayout,
                               QInputDialog, QLabel, QMainWindow, QMessageBox,
                               QSizePolicy, QToolBar, QToolButton, QVBoxLayout, QWidget)

from features.pdf_viewer import PDFViewer
from features.annotation import AnnotationManager
from features.music_notation import MusicNotation
from features.history import HistoryManager
from features.pdf_export import export_annotated_pdf
from utils import recent_files

ASSETS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets')

RENDER_DPI = 200
ZOOM_MIN = 0.15
ZOOM_MAX = 8.0
ZOOM_STEP = 1.15
ERASER_TOLERANCE = 0.03  # tolérance de clic en coordonnées relatives
SPREAD_GAP = 60          # espace vertical entre les deux bandes en vue double

# Palette sombre (Catppuccin Mocha)
C = {
    'crust':    '#11111b',
    'mantle':   '#181825',
    'base':     '#1e1e2e',
    'surface0': '#313244',
    'surface1': '#45475a',
    'text':     '#cdd6f4',
    'subtext':  '#a6adc8',
    'blue':     '#89b4fa',
    'lavender': '#b4befe',
    'red':      '#f38ba8',
    'green':    '#a6e3a1',
    'yellow':   '#f9e2af',
    'peach':    '#fab387',
}

QSS = f"""
QMainWindow, QWidget {{
    background-color: {C['base']};
    color: {C['text']};
    font-family: 'Segoe UI', 'Noto Sans', 'DejaVu Sans', sans-serif;
    font-size: 13px;
}}

QMenuBar {{
    background-color: {C['mantle']};
    color: {C['text']};
    padding: 2px 8px;
    border: none;
}}
QMenuBar::item {{
    padding: 6px 12px;
    border-radius: 6px;
    background: transparent;
}}
QMenuBar::item:selected {{ background-color: {C['surface0']}; }}

QMenu {{
    background-color: {C['mantle']};
    color: {C['text']};
    border: 1px solid {C['surface0']};
    border-radius: 10px;
    padding: 6px;
}}
QMenu::item {{
    padding: 7px 28px 7px 16px;
    border-radius: 6px;
}}
QMenu::item:selected {{ background-color: {C['surface0']}; }}
QMenu::item:disabled {{ color: {C['surface1']}; }}
QMenu::separator {{
    height: 1px;
    background: {C['surface0']};
    margin: 6px 10px;
}}

QToolBar {{
    background-color: {C['mantle']};
    border: none;
    padding: 8px 12px;
    spacing: 6px;
}}
QToolBar::separator {{
    background: {C['surface0']};
    width: 1px;
    margin: 6px 8px;
}}

QToolButton {{
    background-color: transparent;
    color: {C['text']};
    border: none;
    border-radius: 9px;
    padding: 7px 12px;
    font-weight: 600;
}}
QToolButton:hover {{ background-color: {C['surface0']}; }}
QToolButton:pressed {{ background-color: {C['surface1']}; }}
QToolButton:checked {{
    background-color: {C['blue']};
    color: {C['crust']};
}}
QToolButton:disabled {{ color: {C['surface1']}; }}

QToolButton#primary {{
    background-color: {C['blue']};
    color: {C['crust']};
}}
QToolButton#primary:hover {{ background-color: {C['lavender']}; }}

QToolButton#success {{
    background-color: {C['green']};
    color: {C['crust']};
}}
QToolButton#success:hover {{ background-color: #b9ecb4; }}

QLabel#chip {{
    background-color: {C['surface0']};
    color: {C['text']};
    border-radius: 9px;
    padding: 7px 14px;
    font-weight: 600;
}}

QFrame#sidebar {{
    background-color: {C['mantle']};
    border: none;
    border-right: 1px solid {C['surface0']};
}}
QFrame#sidebar QToolButton {{
    padding: 0px;
    min-width: 42px;
    max-width: 42px;
    min-height: 42px;
    max-height: 42px;
    font-size: 19px;
    border-radius: 11px;
}}

QStatusBar {{
    background-color: {C['mantle']};
    color: {C['subtext']};
    border-top: 1px solid {C['surface0']};
}}
QStatusBar::item {{ border: none; }}

QGraphicsView {{
    background-color: {C['crust']};
    border: none;
}}

QMessageBox, QInputDialog, QColorDialog, QFileDialog {{
    background-color: {C['base']};
}}
QPushButton {{
    background-color: {C['surface0']};
    color: {C['text']};
    border: none;
    border-radius: 8px;
    padding: 7px 18px;
    font-weight: 600;
}}
QPushButton:hover {{ background-color: {C['surface1']}; }}
QPushButton:default {{
    background-color: {C['blue']};
    color: {C['crust']};
}}
QLineEdit, QSpinBox {{
    background-color: {C['surface0']};
    color: {C['text']};
    border: 1px solid {C['surface1']};
    border-radius: 8px;
    padding: 6px 10px;
    selection-background-color: {C['blue']};
    selection-color: {C['crust']};
}}
QScrollBar:vertical {{
    background: transparent;
    width: 10px;
    margin: 2px;
}}
QScrollBar:horizontal {{
    background: transparent;
    height: 10px;
    margin: 2px;
}}
QScrollBar::handle {{
    background: {C['surface1']};
    border-radius: 4px;
    min-height: 30px;
    min-width: 30px;
}}
QScrollBar::handle:hover {{ background: {C['blue']}; }}
QScrollBar::add-line, QScrollBar::sub-line {{ height: 0; width: 0; }}
QScrollBar::add-page, QScrollBar::sub-page {{ background: transparent; }}
"""


def circle_icon(diameter, color="#cdd6f4", canvas=22):
    """Crée une icône ronde pleine (pour les boutons de taille de crayon)."""
    pm = QPixmap(canvas, canvas)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing)
    p.setBrush(QColor(color))
    p.setPen(Qt.NoPen)
    r = diameter / 2
    p.drawEllipse(QPointF(canvas / 2, canvas / 2), r, r)
    p.end()
    return QIcon(pm)


def asset_icon(white_name, dark_name=None):
    """Icône depuis assets/ : version blanche au repos, foncée à l'état coché.

    Retourne None si le fichier est absent (repli sur les glyphes/icônes peintes).
    """
    white_path = os.path.join(ASSETS_DIR, white_name)
    if not os.path.exists(white_path):
        return None
    icon = QIcon()
    modes = (QIcon.Normal, QIcon.Active, QIcon.Selected)
    for mode in modes:
        icon.addFile(white_path, mode=mode, state=QIcon.Off)
    if dark_name:
        dark_path = os.path.join(ASSETS_DIR, dark_name)
        if os.path.exists(dark_path):
            for mode in modes:
                icon.addFile(dark_path, mode=mode, state=QIcon.On)
    return icon


def painted_pixmap(kind, color=None, size=36):
    """Pixmaps vectoriels dessinés au QPainter (indépendants des polices emoji)."""
    color = QColor(color or C['text'])
    pm = QPixmap(size, size)
    pm.fill(Qt.transparent)
    p = QPainter(pm)
    p.setRenderHint(QPainter.Antialiasing)
    pen = QPen(color, size * 0.09)
    pen.setCapStyle(Qt.RoundCap)
    pen.setJoinStyle(Qt.RoundJoin)
    p.setPen(pen)
    s = size

    if kind == 'folder':
        p.drawRoundedRect(QRectF(s*0.14, s*0.3, s*0.72, s*0.48), s*0.08, s*0.08)
        p.drawLine(QPointF(s*0.14, s*0.3), QPointF(s*0.22, s*0.2))
        p.drawLine(QPointF(s*0.22, s*0.2), QPointF(s*0.42, s*0.2))
        p.drawLine(QPointF(s*0.42, s*0.2), QPointF(s*0.5, s*0.3))
    elif kind == 'save':
        # Flèche vers le bas dans un bac
        p.drawLine(QPointF(s*0.5, s*0.16), QPointF(s*0.5, s*0.58))
        p.drawLine(QPointF(s*0.32, s*0.42), QPointF(s*0.5, s*0.6))
        p.drawLine(QPointF(s*0.68, s*0.42), QPointF(s*0.5, s*0.6))
        p.drawPolyline([QPointF(s*0.16, s*0.62), QPointF(s*0.16, s*0.82),
                        QPointF(s*0.84, s*0.82), QPointF(s*0.84, s*0.62)])
    elif kind == 'export':
        # Flèche vers le haut hors d'un bac
        p.drawLine(QPointF(s*0.5, s*0.6), QPointF(s*0.5, s*0.16))
        p.drawLine(QPointF(s*0.32, s*0.34), QPointF(s*0.5, s*0.15))
        p.drawLine(QPointF(s*0.68, s*0.34), QPointF(s*0.5, s*0.15))
        p.drawPolyline([QPointF(s*0.16, s*0.62), QPointF(s*0.16, s*0.82),
                        QPointF(s*0.84, s*0.82), QPointF(s*0.84, s*0.62)])
    elif kind == 'pages':
        p.drawRoundedRect(QRectF(s*0.12, s*0.2, s*0.34, s*0.6), s*0.05, s*0.05)
        p.drawRoundedRect(QRectF(s*0.54, s*0.2, s*0.34, s*0.6), s*0.05, s*0.05)
    elif kind == 'trash':
        p.drawLine(QPointF(s*0.2, s*0.28), QPointF(s*0.8, s*0.28))
        p.drawLine(QPointF(s*0.4, s*0.28), QPointF(s*0.42, s*0.18))
        p.drawLine(QPointF(s*0.42, s*0.18), QPointF(s*0.58, s*0.18))
        p.drawLine(QPointF(s*0.58, s*0.18), QPointF(s*0.6, s*0.28))
        p.drawPolyline([QPointF(s*0.26, s*0.28), QPointF(s*0.32, s*0.84),
                        QPointF(s*0.68, s*0.84), QPointF(s*0.74, s*0.28)])
        p.drawLine(QPointF(s*0.44, s*0.4), QPointF(s*0.46, s*0.72))
        p.drawLine(QPointF(s*0.56, s*0.4), QPointF(s*0.54, s*0.72))
    elif kind == 'fit':
        # Quatre coins vers l'extérieur
        for (cx, cy, dx, dy) in [(0.2, 0.2, 1, 1), (0.8, 0.2, -1, 1),
                                  (0.2, 0.8, 1, -1), (0.8, 0.8, -1, -1)]:
            p.drawLine(QPointF(s*cx, s*cy), QPointF(s*(cx + dx*0.14), s*cy))
            p.drawLine(QPointF(s*cx, s*cy), QPointF(s*cx, s*(cy + dy*0.14)))
    elif kind == 'pencil':
        p.setPen(Qt.NoPen)
        p.setBrush(color)
        # Corps du crayon (diagonale)
        p.drawPolygon(QPolygonF([
            QPointF(s*0.64, s*0.12), QPointF(s*0.84, s*0.32),
            QPointF(s*0.42, s*0.74), QPointF(s*0.22, s*0.54),
        ]))
        # Pointe
        p.drawPolygon(QPolygonF([
            QPointF(s*0.19, s*0.60), QPointF(s*0.36, s*0.77),
            QPointF(s*0.10, s*0.86),
        ]))
        # Rainure de la gomme (creusée dans le corps)
        p.setCompositionMode(QPainter.CompositionMode_Clear)
        groove = QPen(Qt.black, s*0.05)
        p.setPen(groove)
        p.drawLine(QPointF(s*0.56, s*0.16), QPointF(s*0.78, s*0.38))
        p.setCompositionMode(QPainter.CompositionMode_SourceOver)
    elif kind == 'sharp':
        thin = QPen(color, s*0.07, Qt.SolidLine, Qt.RoundCap)
        thick = QPen(color, s*0.11, Qt.SolidLine, Qt.RoundCap)
        # Deux verticales
        p.setPen(thin)
        p.drawLine(QPointF(s*0.40, s*0.14), QPointF(s*0.40, s*0.86))
        p.drawLine(QPointF(s*0.60, s*0.10), QPointF(s*0.60, s*0.82))
        # Deux barres inclinées (plus épaisses)
        p.setPen(thick)
        p.drawLine(QPointF(s*0.22, s*0.42), QPointF(s*0.78, s*0.30))
        p.drawLine(QPointF(s*0.22, s*0.68), QPointF(s*0.78, s*0.56))
    elif kind == 'flat':
        stem = QPen(color, s*0.08, Qt.SolidLine, Qt.RoundCap)
        p.setPen(stem)
        # Hampe verticale
        p.drawLine(QPointF(s*0.38, s*0.10), QPointF(s*0.38, s*0.84))
        # Panse arrondie
        bowl = QPainterPath()
        bowl.moveTo(s*0.38, s*0.48)
        bowl.cubicTo(QPointF(s*0.74, s*0.42), QPointF(s*0.76, s*0.72),
                     QPointF(s*0.38, s*0.84))
        p.setBrush(Qt.NoBrush)
        p.drawPath(bowl)
    elif kind == 'eraser':
        p.save()
        p.translate(s*0.5, s*0.42)
        p.rotate(-45)
        p.setPen(Qt.NoPen)
        p.setBrush(color)
        p.drawRoundedRect(QRectF(-s*0.28, -s*0.17, s*0.56, s*0.34), s*0.07, s*0.07)
        # Séparation biseau/gomme
        p.setCompositionMode(QPainter.CompositionMode_Clear)
        p.setPen(QPen(Qt.black, s*0.05))
        p.drawLine(QPointF(-s*0.02, -s*0.19), QPointF(-s*0.02, s*0.19))
        p.restore()
        # Ligne de base « effacée »
        p.setCompositionMode(QPainter.CompositionMode_SourceOver)
        p.setPen(QPen(color, s*0.07, Qt.SolidLine, Qt.RoundCap))
        p.drawLine(QPointF(s*0.18, s*0.88), QPointF(s*0.74, s*0.88))

    p.end()
    return pm


def painted_icon(kind, color=None, size=36):
    return QIcon(painted_pixmap(kind, color, size))


def two_state_icon(kind, size=36):
    """Icône claire au repos, foncée à l'état coché (fond bleu clair)."""
    icon = QIcon()
    icon.addPixmap(painted_pixmap(kind, C['text'], size), QIcon.Normal, QIcon.Off)
    icon.addPixmap(painted_pixmap(kind, C['crust'], size), QIcon.Normal, QIcon.On)
    return icon


class SheetView(QGraphicsView):
    """Vue de la partition : zoom à la molette, panoramique, délégation des outils."""

    def __init__(self, window):
        super().__init__()
        self.window = window
        self.setRenderHints(QPainter.Antialiasing | QPainter.SmoothPixmapTransform)
        self.setTransformationAnchor(QGraphicsView.AnchorUnderMouse)
        self.setResizeAnchor(QGraphicsView.AnchorViewCenter)
        self.setDragMode(QGraphicsView.NoDrag)
        self.setHorizontalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self._panning = False
        self._pan_last = QPointF()
        self._press_pos = None       # position du clic gauche, pour distinguer clic et glisser

    def wheelEvent(self, event):
        if not self.window.current_pdf_path:
            return
        factor = ZOOM_STEP if event.angleDelta().y() > 0 else 1 / ZOOM_STEP
        current = self.transform().m11()
        target = current * factor
        if target < ZOOM_MIN or target > ZOOM_MAX:
            return
        self.scale(factor, factor)
        self.window.update_zoom_chip()

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton and self.window.active_tool:
            self.window.on_canvas_press(self.mapToScene(event.position().toPoint()))
            event.accept()
            return
        if event.button() == Qt.LeftButton:
            # Aucun outil actif : mémoriser la position pour distinguer un simple
            # clic (tourner la page) d'un glisser (déplacer la vue).
            self._press_pos = event.position()
            self.setDragMode(QGraphicsView.ScrollHandDrag)
            super().mousePressEvent(event)
            return
        if event.button() == Qt.RightButton:
            self._panning = True
            self._pan_last = event.position()
            self.setCursor(Qt.ClosedHandCursor)
            event.accept()
            return
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if self.window.stroke_active:
            self.window.on_canvas_move(self.mapToScene(event.position().toPoint()))
            event.accept()
            return
        if self._panning:
            delta = event.position() - self._pan_last
            self._pan_last = event.position()
            self.horizontalScrollBar().setValue(self.horizontalScrollBar().value() - int(delta.x()))
            self.verticalScrollBar().setValue(self.verticalScrollBar().value() - int(delta.y()))
            event.accept()
            return
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.LeftButton and self.window.stroke_active:
            self.window.on_canvas_release()
            event.accept()
            return
        if event.button() == Qt.RightButton and self._panning:
            self._panning = False
            self.window.apply_tool_cursor()
            event.accept()
            return
        super().mouseReleaseEvent(event)
        if event.button() == Qt.LeftButton:
            self.setDragMode(QGraphicsView.NoDrag)
            self.window.apply_tool_cursor()
            # Clic simple (sans glisser notable) sans outil actif : tourner la page.
            # Moitié droite → page suivante, moitié gauche → page précédente.
            if self._press_pos is not None and not self.window.active_tool:
                moved = (event.position() - self._press_pos).manhattanLength()
                if moved < 6:
                    if event.position().x() >= self.viewport().width() / 2:
                        self.window.next_page()
                    else:
                        self.window.prev_page()
            self._press_pos = None


class ArpegeWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Arpège — Éditeur de partitions")
        logo_path = os.path.join(ASSETS_DIR, "Logo.png")
        if os.path.exists(logo_path):
            self.setWindowIcon(QIcon(logo_path))
        self.resize(1320, 900)

        self.pdf_viewer = PDFViewer()
        self.annotation_manager = AnnotationManager()
        self.music_notation = MusicNotation()
        self.history_manager = HistoryManager()

        self.current_pdf_path = None
        self.active_tool = None      # None | 'crayon' | 'sharp' | 'flat' | 'indication' | 'eraser'
        self.crayon_color = '#e74c3c'
        self.crayon_size = 4
        self.spread_view = False

        self._pixmap_cache = {}      # page -> QPixmap
        # Bandes affichées : {'page', 'rect' (QRectF scène), 'y0', 'y1'}
        # y0/y1 = portion verticale de la page couverte par la bande (0.0–1.0)
        self.page_slots = []

        # État du tracé en cours
        self.stroke_active = False
        self._stroke_points = []
        self._stroke_slot = None
        self._stroke_item = None
        self._stroke_path = None

        self.scene = QGraphicsScene()
        self.scene.setBackgroundBrush(QColor(C['crust']))
        self.view = SheetView(self)
        self.view.setScene(self.scene)

        central = QWidget()
        layout = QVBoxLayout(central)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        layout.addWidget(self.view)
        self.setCentralWidget(central)

        self.build_menu()
        self.build_toolbar()
        self.build_sidebar()
        self.build_statusbar()
        self.build_shortcuts()

        self.show_placeholder()

    # ------------------------------------------------------------------
    # Construction de l'interface
    # ------------------------------------------------------------------

    def build_menu(self):
        bar = self.menuBar()

        m_file = bar.addMenu("Fichier")
        open_action = self._act("Ouvrir un PDF…", self.open_pdf_dialog, "Ctrl+O")
        w_open = os.path.join(ASSETS_DIR, "w_open.png")
        if os.path.exists(w_open):
            open_action.setIcon(QIcon(w_open))
        m_file.addAction(open_action)
        self.recent_menu = m_file.addMenu("Fichiers récents")
        self.recent_menu.aboutToShow.connect(self.populate_recent_menu)
        m_file.addSeparator()
        m_file.addAction(self._act("Sauvegarder les annotations", self.save_annotations, "Ctrl+S"))
        m_file.addAction(self._act("Charger des annotations…", self.load_annotations_manually))
        m_file.addSeparator()
        m_file.addAction(self._act("Exporter le PDF annoté…", self.export_pdf, "Ctrl+E"))
        m_file.addSeparator()
        m_file.addAction(self._act("Quitter", self.close, "Ctrl+Q"))

        m_edit = bar.addMenu("Édition")
        m_edit.addAction(self._act("Annuler", self.undo, "Ctrl+Z"))
        m_edit.addAction(self._act("Rétablir", self.redo, "Ctrl+Y"))
        m_edit.addSeparator()
        m_edit.addAction(self._act("Effacer la page courante", self.clear_current_page))

        m_view = bar.addMenu("Affichage")
        m_view.addAction(self._act("Zoom avant", self.zoom_in, "Ctrl++"))
        m_view.addAction(self._act("Zoom arrière", self.zoom_out, "Ctrl+-"))
        m_view.addAction(self._act("Ajuster à la fenêtre", self.fit_view, "Ctrl+0"))
        m_view.addSeparator()
        self.spread_action = QAction("Vue double page", self, checkable=True)
        self.spread_action.setShortcut("Ctrl+D")
        self.spread_action.toggled.connect(self.toggle_spread_view)
        m_view.addAction(self.spread_action)

    def _act(self, text, slot, shortcut=None):
        action = QAction(text, self)
        if shortcut:
            action.setShortcut(QKeySequence(shortcut))
        action.triggered.connect(slot)
        return action

    def build_toolbar(self):
        tb = QToolBar()
        tb.setMovable(False)
        tb.setIconSize(QSize(18, 18))
        self.addToolBar(Qt.TopToolBarArea, tb)

        open_btn = QToolButton(text="Ouvrir", objectName="primary")
        open_asset = os.path.join(ASSETS_DIR, "open.png")
        open_btn.setIcon(QIcon(open_asset) if os.path.exists(open_asset)
                         else painted_icon('folder', C['crust']))
        open_btn.setToolButtonStyle(Qt.ToolButtonTextBesideIcon)
        open_btn.clicked.connect(self.open_pdf_dialog)
        tb.addWidget(open_btn)

        tb.addSeparator()

        self.prev_btn = QToolButton(text="‹")
        self.prev_btn.setToolTip("Page précédente (←)")
        self.prev_btn.clicked.connect(self.prev_page)
        tb.addWidget(self.prev_btn)

        self.page_chip = QLabel("— / —", objectName="chip")
        self.page_chip.setAlignment(Qt.AlignCenter)
        self.page_chip.setMinimumWidth(86)
        tb.addWidget(self.page_chip)

        self.next_btn = QToolButton(text="›")
        self.next_btn.setToolTip("Page suivante (→)")
        self.next_btn.clicked.connect(self.next_page)
        tb.addWidget(self.next_btn)

        tb.addSeparator()

        zo = QToolButton(text="−")
        zo.setToolTip("Zoom arrière (Ctrl+-)")
        zo.clicked.connect(self.zoom_out)
        tb.addWidget(zo)

        self.zoom_chip = QLabel("100 %", objectName="chip")
        self.zoom_chip.setAlignment(Qt.AlignCenter)
        self.zoom_chip.setMinimumWidth(70)
        tb.addWidget(self.zoom_chip)

        zi = QToolButton(text="+")
        zi.setToolTip("Zoom avant (Ctrl++)")
        zi.clicked.connect(self.zoom_in)
        tb.addWidget(zi)

        fit = QToolButton(text="Ajuster")
        fit.setIcon(painted_icon('fit'))
        fit.setToolButtonStyle(Qt.ToolButtonTextBesideIcon)
        fit.setToolTip("Ajuster à la fenêtre (Ctrl+0)")
        fit.clicked.connect(self.fit_view)
        tb.addWidget(fit)

        self.spread_btn = QToolButton(text="Double page")
        self.spread_btn.setIcon(painted_icon('pages'))
        self.spread_btn.setToolButtonStyle(Qt.ToolButtonTextBesideIcon)
        self.spread_btn.setCheckable(True)
        self.spread_btn.setToolTip("Afficher deux pages côte à côte (Ctrl+D)")
        self.spread_btn.toggled.connect(self.spread_action.setChecked)
        tb.addWidget(self.spread_btn)

        spacer = QWidget()
        spacer.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        spacer.setStyleSheet("background: transparent;")
        tb.addWidget(spacer)

        save_btn = QToolButton(text="Sauver", objectName="success")
        save_btn.setIcon(painted_icon('save', C['crust']))
        save_btn.setToolButtonStyle(Qt.ToolButtonTextBesideIcon)
        save_btn.setToolTip("Sauvegarder les annotations (Ctrl+S)")
        save_btn.clicked.connect(self.save_annotations)
        tb.addWidget(save_btn)

        export_btn = QToolButton(text="Exporter")
        export_btn.setIcon(painted_icon('export'))
        export_btn.setToolButtonStyle(Qt.ToolButtonTextBesideIcon)
        export_btn.setToolTip("Exporter le PDF annoté (Ctrl+E)")
        export_btn.clicked.connect(self.export_pdf)
        tb.addWidget(export_btn)

    def build_sidebar(self):
        sidebar = QFrame(objectName="sidebar")
        sidebar.setFixedWidth(62)
        lay = QVBoxLayout(sidebar)
        lay.setContentsMargins(10, 14, 10, 14)
        lay.setSpacing(8)
        lay.setAlignment(Qt.AlignTop | Qt.AlignHCenter)

        self.tool_group = QButtonGroup(self)
        self.tool_group.setExclusive(False)  # géré manuellement pour permettre la désélection

        self.tool_buttons = {}
        tools = [
            ('crayon', "✎", asset_icon("w_pen.png", "pen.png") or two_state_icon('pencil'),
             "Crayon — dessin libre"),
            ('sharp', "♯", two_state_icon('sharp'), "Ajouter un dièse"),
            ('flat', "♭", two_state_icon('flat'), "Ajouter un bémol"),
            ('indication', "T", asset_icon("w_text.png", "text.png"),
             "Ajouter une indication texte"),
            ('eraser', "⌫", asset_icon("w_eraser.png", "eraser.png") or two_state_icon('eraser'),
             "Gomme — supprimer un élément"),
        ]
        for name, glyph, icon, tip in tools:
            if icon is not None:
                btn = QToolButton()
                btn.setIcon(icon)
                btn.setIconSize(QSize(24, 24))
            else:
                btn = QToolButton(text=glyph)
            btn.setCheckable(True)
            btn.setToolTip(tip)
            if name == 'indication' and icon is None:
                font = btn.font()
                font.setItalic(True)
                font.setBold(True)
                btn.setFont(font)
            btn.clicked.connect(lambda checked, n=name: self.set_tool(n if checked else None))
            lay.addWidget(btn)
            self.tool_buttons[name] = btn

        sep = QFrame()
        sep.setFixedHeight(1)
        sep.setStyleSheet(f"background: {C['surface0']};")
        lay.addSpacing(4)
        lay.addWidget(sep)
        lay.addSpacing(4)

        self.color_btn = QToolButton()
        self.color_btn.setToolTip("Couleur du crayon")
        self.color_btn.clicked.connect(self.choose_color)
        self._refresh_color_button()
        lay.addWidget(self.color_btn)

        self.size_buttons = {}
        for size, diameter in [(2, 5), (4, 9), (6, 13)]:
            btn = QToolButton()
            btn.setCheckable(True)
            btn.setIcon(circle_icon(diameter))
            btn.setToolTip(f"Épaisseur du trait : {size} pt")
            btn.clicked.connect(lambda checked, s=size: self.set_crayon_size(s))
            lay.addWidget(btn)
            self.size_buttons[size] = btn
        self.size_buttons[self.crayon_size].setChecked(True)

        lay.addStretch()

        clear_btn = QToolButton()
        clear_btn.setIcon(painted_icon('trash', C['red']))
        clear_btn.setIconSize(QSize(22, 22))
        clear_btn.setToolTip("Effacer toutes les annotations de la page")
        clear_btn.clicked.connect(self.clear_current_page)
        lay.addWidget(clear_btn)

        central = self.centralWidget()
        wrapper = QWidget()
        hbox = QHBoxLayout(wrapper)
        hbox.setContentsMargins(0, 0, 0, 0)
        hbox.setSpacing(0)
        hbox.addWidget(sidebar)
        hbox.addWidget(central)
        self.setCentralWidget(wrapper)

    def build_statusbar(self):
        sb = self.statusBar()
        self.hint_label = QLabel("Ouvrez une partition pour commencer  •  Ctrl+O")
        sb.addWidget(self.hint_label)
        shortcut_label = QLabel("molette : zoom   •   clic droit : déplacer   •   Échap : désélectionner l'outil")
        sb.addPermanentWidget(shortcut_label)

    def build_shortcuts(self):
        QShortcut(QKeySequence(Qt.Key_Left), self, activated=self.prev_page)
        QShortcut(QKeySequence(Qt.Key_Right), self, activated=self.next_page)
        QShortcut(QKeySequence(Qt.Key_PageUp), self, activated=self.prev_page)
        QShortcut(QKeySequence(Qt.Key_PageDown), self, activated=self.next_page)
        QShortcut(QKeySequence(Qt.Key_Home), self, activated=self.go_first)
        QShortcut(QKeySequence(Qt.Key_End), self, activated=self.go_last)
        QShortcut(QKeySequence(Qt.Key_Escape), self, activated=lambda: self.set_tool(None))
        QShortcut(QKeySequence("Ctrl+Shift+Z"), self, activated=self.redo)

    # ------------------------------------------------------------------
    # Outils
    # ------------------------------------------------------------------

    def set_tool(self, tool):
        self.active_tool = tool
        for name, btn in self.tool_buttons.items():
            btn.setChecked(name == tool)
        hints = {
            None: "Aucun outil  •  cliquer-glisser pour déplacer la vue",
            'crayon': "Crayon  •  dessinez directement sur la partition",
            'sharp': "Dièse  •  cliquez à l'endroit voulu",
            'flat': "Bémol  •  cliquez à l'endroit voulu",
            'indication': "Indication  •  cliquez puis saisissez le texte",
            'eraser': "Gomme  •  cliquez sur un élément pour le supprimer",
        }
        self.hint_label.setText(hints.get(tool, ""))
        self.apply_tool_cursor()

    def apply_tool_cursor(self):
        cursors = {
            None: Qt.OpenHandCursor if self.current_pdf_path else Qt.ArrowCursor,
            'crayon': Qt.CrossCursor,
            'sharp': Qt.CrossCursor,
            'flat': Qt.CrossCursor,
            'indication': Qt.IBeamCursor,
            'eraser': Qt.PointingHandCursor,
        }
        self.view.setCursor(cursors.get(self.active_tool, Qt.ArrowCursor))

    def choose_color(self):
        color = QColorDialog.getColor(QColor(self.crayon_color), self, "Couleur du crayon")
        if color.isValid():
            self.crayon_color = color.name()
            self._refresh_color_button()

    def _refresh_color_button(self):
        self.color_btn.setStyleSheet(
            f"QToolButton {{ background-color: {self.crayon_color}; border-radius: 11px; }}"
            f"QToolButton:hover {{ border: 2px solid {C['text']}; }}"
        )

    def set_crayon_size(self, size):
        self.crayon_size = size
        for s, btn in self.size_buttons.items():
            btn.setChecked(s == size)

    # ------------------------------------------------------------------
    # Historique
    # ------------------------------------------------------------------

    def _get_state_refs(self):
        return {
            'music_notations': self.music_notation.annotations,
            'drawing_paths': self.music_notation.drawing_paths,
            'general_annotations': self.annotation_manager.annotations,
            'page_annotations': self.annotation_manager.page_annotations,
        }

    def _apply_state(self, state):
        self.music_notation.annotations = state['music_notations']
        self.music_notation.drawing_paths = state['drawing_paths']
        self.annotation_manager.annotations = state['general_annotations']
        self.annotation_manager.page_annotations = state['page_annotations']

    def push_history(self):
        self.history_manager.push(self._get_state_refs())

    def undo(self):
        if not self.history_manager.can_undo():
            return
        state = self.history_manager.undo(self._get_state_refs())
        if state is not None:
            self._apply_state(state)
            self.rebuild_scene(preserve_view=True)

    def redo(self):
        if not self.history_manager.can_redo():
            return
        state = self.history_manager.redo(self._get_state_refs())
        if state is not None:
            self._apply_state(state)
            self.rebuild_scene(preserve_view=True)

    # ------------------------------------------------------------------
    # Chargement / sauvegarde
    # ------------------------------------------------------------------

    def open_pdf_dialog(self):
        path, _ = QFileDialog.getOpenFileName(self, "Ouvrir une partition", "",
                                              "Fichiers PDF (*.pdf)")
        if path:
            self.open_pdf(path)

    def open_pdf(self, path):
        self.music_notation.clear_notation()
        self.annotation_manager.annotations.clear()
        self.annotation_manager.page_annotations.clear()
        self.history_manager.clear()
        self._pixmap_cache.clear()

        self.current_pdf_path = path
        self.pdf_viewer.load_pdf(path)
        self.load_existing_annotations()
        recent_files.add_recent_file(path)

        self.rebuild_scene()
        self.fit_view()
        self.set_tool(None)
        name = os.path.basename(path)
        self.setWindowTitle(f"Arpège — {name}")
        self.hint_label.setText(f"{name}  •  {self.pdf_viewer.page_count} pages")

    def populate_recent_menu(self):
        self.recent_menu.clear()
        recents = recent_files.load_recent_files()
        if not recents:
            action = self.recent_menu.addAction("(aucun fichier récent)")
            action.setEnabled(False)
            return
        for path in recents:
            action = self.recent_menu.addAction(os.path.basename(path))
            action.triggered.connect(lambda checked=False, p=path: self.open_pdf(p))

    def _annotations_dir(self):
        path = os.path.join(os.path.expanduser("~"), "Documents", "Arpège", "annotations")
        os.makedirs(path, exist_ok=True)
        return path

    def _annotations_file(self):
        pdf_name = os.path.splitext(os.path.basename(self.current_pdf_path))[0]
        return os.path.join(self._annotations_dir(), f"{pdf_name}_annotations.json")

    def load_existing_annotations(self):
        if not self.current_pdf_path:
            return
        annotations_file = self._annotations_file()
        if not os.path.exists(annotations_file):
            return
        try:
            with open(annotations_file, 'r', encoding='utf-8') as f:
                save_data = json.load(f)
            self._restore_annotations(save_data)
        except Exception as e:
            QMessageBox.warning(self, "Avertissement",
                                f"Impossible de charger les annotations :\n{e}")

    def _restore_annotations(self, save_data):
        annotations_data = save_data.get('annotations', {})
        self.music_notation.annotations = annotations_data.get('music_notations', [])

        drawings = annotations_data.get('drawings', {})
        self.music_notation.drawing_paths = {}
        for page_str, drawing_data in drawings.items():
            page_num = int(page_str)
            if isinstance(drawing_data, list):
                if drawing_data and isinstance(drawing_data[0], dict) and 'relative_x' in drawing_data[0]:
                    # Ancien format : liste simple de points
                    self.music_notation.drawing_paths[page_num] = [drawing_data]
                else:
                    self.music_notation.drawing_paths[page_num] = drawing_data
            else:
                self.music_notation.drawing_paths[page_num] = []

        general = annotations_data.get('general_annotations', [])
        self.annotation_manager.annotations = general
        self.annotation_manager.page_annotations = {}
        for annotation in general:
            page_num = annotation.get('page', 0)
            self.annotation_manager.page_annotations.setdefault(page_num, []).append(annotation)

    def load_annotations_manually(self):
        if not self.current_pdf_path:
            QMessageBox.warning(self, "Attention", "Veuillez d'abord charger un PDF.")
            return
        path, _ = QFileDialog.getOpenFileName(self, "Charger des annotations",
                                              self._annotations_dir(),
                                              "Fichiers JSON (*.json)")
        if not path:
            return
        try:
            with open(path, 'r', encoding='utf-8') as f:
                save_data = json.load(f)
            self.push_history()
            self._restore_annotations(save_data)
            self.rebuild_scene(preserve_view=True)
        except Exception as e:
            QMessageBox.critical(self, "Erreur",
                                 f"Impossible de charger le fichier d'annotations :\n{e}")

    def save_annotations(self):
        if not self.current_pdf_path:
            QMessageBox.warning(self, "Attention", "Aucun PDF chargé.")
            return
        pdf_name = os.path.splitext(os.path.basename(self.current_pdf_path))[0]
        save_data = {
            'pdf_file': self.current_pdf_path,
            'pdf_name': pdf_name,
            'created_date': datetime.now().isoformat(),
            'last_modified': datetime.now().isoformat(),
            'total_pages': self.pdf_viewer.page_count,
            'annotations': {
                'music_notations': self.music_notation.get_notations(),
                'drawings': dict(self.music_notation.drawing_paths),
                'general_annotations': self.annotation_manager.annotations,
            },
        }
        try:
            with open(self._annotations_file(), 'w', encoding='utf-8') as f:
                json.dump(save_data, f, indent=2, ensure_ascii=False)
            self.hint_label.setText(f"Annotations sauvegardées  •  {self._annotations_file()}")
        except Exception as e:
            QMessageBox.critical(self, "Erreur", f"Impossible de sauvegarder :\n{e}")

    def export_pdf(self):
        if not self.current_pdf_path:
            QMessageBox.warning(self, "Attention", "Veuillez d'abord charger un PDF.")
            return
        default_name = os.path.splitext(os.path.basename(self.current_pdf_path))[0] + "_annote.pdf"
        path, _ = QFileDialog.getSaveFileName(self, "Exporter le PDF annoté",
                                              default_name, "Fichiers PDF (*.pdf)")
        if not path:
            return
        try:
            export_annotated_pdf(self.current_pdf_path, path,
                                 self.music_notation, self.annotation_manager)
            self.hint_label.setText(f"PDF annoté exporté  •  {path}")
        except Exception as e:
            QMessageBox.critical(self, "Erreur d'export", f"Impossible d'exporter :\n{e}")

    # ------------------------------------------------------------------
    # Navigation / zoom
    # ------------------------------------------------------------------

    def prev_page(self):
        if self.pdf_viewer.pdf_document and self.pdf_viewer.current_page > 0:
            self.pdf_viewer.current_page -= 1
            self.rebuild_scene()
            self.fit_view()

    def next_page(self):
        if self.pdf_viewer.pdf_document and self.pdf_viewer.current_page < self.pdf_viewer.page_count - 1:
            self.pdf_viewer.current_page += 1
            self.rebuild_scene()
            self.fit_view()

    def go_first(self):
        if self.pdf_viewer.pdf_document:
            self.pdf_viewer.current_page = 0
            self.rebuild_scene()
            self.fit_view()

    def go_last(self):
        if self.pdf_viewer.pdf_document:
            self.pdf_viewer.current_page = self.pdf_viewer.page_count - 1
            self.rebuild_scene()
            self.fit_view()

    def zoom_in(self):
        if self.current_pdf_path and self.view.transform().m11() * ZOOM_STEP <= ZOOM_MAX:
            self.view.scale(ZOOM_STEP, ZOOM_STEP)
            self.update_zoom_chip()

    def zoom_out(self):
        if self.current_pdf_path and self.view.transform().m11() / ZOOM_STEP >= ZOOM_MIN:
            self.view.scale(1 / ZOOM_STEP, 1 / ZOOM_STEP)
            self.update_zoom_chip()

    def fit_view(self):
        if not self.scene.items():
            return
        rect = self.scene.itemsBoundingRect().adjusted(-30, -30, 30, 30)
        self.view.fitInView(rect, Qt.KeepAspectRatio)
        self.update_zoom_chip()

    def update_zoom_chip(self):
        # Zoom affiché relatif à la résolution native du PDF (72 dpi)
        scale = self.view.transform().m11() * RENDER_DPI / 72.0
        self.zoom_chip.setText(f"{scale * 100:.0f} %")

    def toggle_spread_view(self, enabled):
        self.spread_view = enabled
        self.spread_btn.setChecked(enabled)
        if self.current_pdf_path:
            self.rebuild_scene()
            self.fit_view()

    # ------------------------------------------------------------------
    # Rendu de la scène
    # ------------------------------------------------------------------

    def show_placeholder(self):
        self.scene.clear()
        self.page_slots = []
        y = 0.0
        logo_path = os.path.join(ASSETS_DIR, "Logo.png")
        if os.path.exists(logo_path):
            logo = QPixmap(logo_path).scaled(200, 200, Qt.KeepAspectRatio,
                                             Qt.SmoothTransformation)
            logo_item = self.scene.addPixmap(logo)
            logo_item.setPos(-logo.width() / 2, y)
            y += logo.height() + 30
        text = self.scene.addSimpleText("Aucune partition ouverte — Ctrl+O pour ouvrir un PDF",
                                        QFont("Segoe UI", 14))
        text.setBrush(QColor(C['subtext']))
        br = text.boundingRect()
        text.setPos(-br.width() / 2, y)
        self.scene.setSceneRect(self.scene.itemsBoundingRect().adjusted(-60, -60, 60, 60))
        self.view.resetTransform()
        self.view.centerOn(0, y / 2)
        self.page_chip.setText("— / —")

    def _page_pixmap(self, page_num):
        if page_num in self._pixmap_cache:
            return self._pixmap_cache[page_num]
        page = self.pdf_viewer.pdf_document[page_num]
        zoom = RENDER_DPI / 72.0
        pix = page.get_pixmap(matrix=fitz.Matrix(zoom, zoom), alpha=False)
        image = QImage(pix.samples, pix.width, pix.height, pix.stride, QImage.Format_RGB888)
        pixmap = QPixmap.fromImage(image.copy())
        self._pixmap_cache[page_num] = pixmap
        return pixmap

    def rebuild_scene(self, preserve_view=False):
        if not self.pdf_viewer.pdf_document:
            self.show_placeholder()
            return

        if preserve_view:
            saved_transform = self.view.transform()
            saved_h = self.view.horizontalScrollBar().value()
            saved_v = self.view.verticalScrollBar().value()

        self.scene.clear()
        self.page_slots = []

        current = self.pdf_viewer.current_page
        # Vue double : moitié basse de la page courante au-dessus,
        # moitié haute de la page suivante juste en dessous.
        if self.spread_view and current + 1 < self.pdf_viewer.page_count:
            specs = [
                {'page': current, 'y0': 0.5, 'y1': 1.0},
                {'page': current + 1, 'y0': 0.0, 'y1': 0.5},
            ]
        else:
            specs = [{'page': current, 'y0': 0.0, 'y1': 1.0}]

        y_offset = 0.0
        for spec in specs:
            full = self._page_pixmap(spec['page'])
            if spec['y0'] == 0.0 and spec['y1'] == 1.0:
                pixmap = full
            else:
                top = int(spec['y0'] * full.height())
                bottom = int(spec['y1'] * full.height())
                pixmap = full.copy(0, top, full.width(), bottom - top)

            item = self.scene.addPixmap(pixmap)
            item.setPos(0, y_offset)
            shadow = QGraphicsDropShadowEffect()
            shadow.setBlurRadius(48)
            shadow.setOffset(0, 10)
            shadow.setColor(QColor(0, 0, 0, 200))
            item.setGraphicsEffect(shadow)

            rect = QRectF(0, y_offset, pixmap.width(), pixmap.height())
            slot = {'page': spec['page'], 'rect': rect,
                    'y0': spec['y0'], 'y1': spec['y1']}
            self.page_slots.append(slot)

            # Étiquette de page au-dessus de chaque bande (vue double uniquement)
            if len(specs) > 1:
                label = QGraphicsSimpleTextItem(f"page {spec['page'] + 1}")
                label_font = QFont("Segoe UI")
                label_font.setPixelSize(int(full.height() * 0.016))
                label.setFont(label_font)
                label.setBrush(QColor(C['subtext']))
                label.setPos(rect.x(), rect.y() - full.height() * 0.024)
                self.scene.addItem(label)

            self._draw_page_annotations(slot)
            y_offset += pixmap.height() + SPREAD_GAP

        self.scene.setSceneRect(self.scene.itemsBoundingRect().adjusted(-80, -80, 80, 80))

        if len(specs) > 1:
            self.page_chip.setText(f"{current + 1}-{current + 2} / {self.pdf_viewer.page_count}")
        else:
            self.page_chip.setText(f"{current + 1} / {self.pdf_viewer.page_count}")

        if preserve_view:
            self.view.setTransform(saved_transform)
            self.view.horizontalScrollBar().setValue(saved_h)
            self.view.verticalScrollBar().setValue(saved_v)

    def _rel_to_scene(self, slot, rel_x, rel_y):
        """Coordonnées relatives page (0–1) → coordonnées scène dans la bande."""
        rect = slot['rect']
        band = slot['y1'] - slot['y0']
        x = rect.x() + rel_x * rect.width()
        y = rect.y() + (rel_y - slot['y0']) / band * rect.height()
        return x, y

    def _slot_rel(self, slot, scene_pos):
        """Coordonnées scène → coordonnées relatives page (0–1)."""
        rect = slot['rect']
        band = slot['y1'] - slot['y0']
        rel_x = (scene_pos.x() - rect.x()) / rect.width()
        rel_y = slot['y0'] + (scene_pos.y() - rect.y()) / rect.height() * band
        return rel_x, rel_y

    def _draw_page_annotations(self, slot):
        page_num = slot['page']
        rect = slot['rect']
        # Hauteur de la page complète en unités scène (la bande peut être partielle)
        page_height = rect.height() / (slot['y1'] - slot['y0'])

        # Conteneur de découpe : les annotations débordant de la bande sont rognées
        container = QGraphicsRectItem(rect)
        container.setPen(QPen(Qt.NoPen))
        container.setFlag(QGraphicsItem.ItemClipsChildrenToShape, True)
        self.scene.addItem(container)

        # Notations musicales (dièse, bémol, indication)
        # Couleurs saturées identiques à l'export PDF (lisibles sur papier blanc)
        symbol_color = QColor('#e74c3c')
        indication_color = QColor('#27ae60')
        symbol_font = QFont("DejaVu Sans")
        symbol_font.setPixelSize(int(page_height * 0.034))
        symbol_font.setBold(True)
        text_font = QFont("Segoe UI")
        text_font.setPixelSize(int(page_height * 0.022))
        text_font.setItalic(True)

        for notation in self.music_notation.get_page_notations(page_num):
            x, y = self._rel_to_scene(slot, notation['relative_x'], notation['relative_y'])
            if notation['type'] == 'sharp':
                item = QGraphicsSimpleTextItem("♯")
                item.setFont(symbol_font)
                item.setBrush(symbol_color)
            elif notation['type'] == 'flat':
                item = QGraphicsSimpleTextItem("♭")
                item.setFont(symbol_font)
                item.setBrush(symbol_color)
            elif notation['type'] == 'indication':
                item = QGraphicsSimpleTextItem(notation.get('text', ''))
                item.setFont(text_font)
                item.setBrush(indication_color)
            else:
                continue
            br = item.boundingRect()
            item.setPos(x - br.width() / 2, y - br.height() / 2)
            item.setParentItem(container)

        # Tracés au crayon
        for path_data in self.music_notation.get_page_drawings(page_num):
            if isinstance(path_data, list):
                points, color, size = path_data, '#000000', 3
            else:
                points = path_data.get('points', [])
                color = path_data.get('color', '#000000')
                size = path_data.get('size', 3)
            if len(points) < 2:
                continue
            path = QPainterPath()
            first = points[0]
            path.moveTo(*self._rel_to_scene(slot, first['relative_x'], first['relative_y']))
            for pt in points[1:]:
                path.lineTo(*self._rel_to_scene(slot, pt['relative_x'], pt['relative_y']))
            item = QGraphicsPathItem(path)
            item.setPen(self._stroke_pen(color, size, rect))
            item.setParentItem(container)

    def _stroke_pen(self, color, size, rect):
        """Épaisseur en points PDF convertie à l'échelle de la page rendue."""
        width = size * rect.width() / 595.0
        pen = QPen(QColor(color), width)
        pen.setCapStyle(Qt.RoundCap)
        pen.setJoinStyle(Qt.RoundJoin)
        return pen

    # ------------------------------------------------------------------
    # Événements canvas (délégués par SheetView)
    # ------------------------------------------------------------------

    def _locate(self, scene_pos):
        """Retourne la bande sous le curseur, ou None si hors partition."""
        for slot in self.page_slots:
            if slot['rect'].contains(scene_pos):
                return slot
        return None

    def on_canvas_press(self, scene_pos):
        slot = self._locate(scene_pos)
        if slot is None:
            return
        page_num = slot['page']
        rel_x, rel_y = self._slot_rel(slot, scene_pos)

        if self.active_tool == 'crayon':
            self.push_history()
            self.stroke_active = True
            self._stroke_slot = slot
            self._stroke_points = [{'relative_x': rel_x, 'relative_y': rel_y}]
            self._stroke_path = QPainterPath(scene_pos)
            self._stroke_item = QGraphicsPathItem(self._stroke_path)
            self._stroke_item.setPen(
                self._stroke_pen(self.crayon_color, self.crayon_size, slot['rect']))
            self.scene.addItem(self._stroke_item)

        elif self.active_tool in ('sharp', 'flat'):
            self.push_history()
            if self.active_tool == 'sharp':
                self.music_notation.add_sharp(page_num, rel_x, rel_y)
            else:
                self.music_notation.add_flat(page_num, rel_x, rel_y)
            self.rebuild_scene(preserve_view=True)

        elif self.active_tool == 'indication':
            text, ok = QInputDialog.getText(self, "Indication musicale",
                                            "Texte de l'indication :")
            if ok and text.strip():
                self.push_history()
                self.music_notation.draw_indication(text.strip(), page_num, rel_x, rel_y)
                self.rebuild_scene(preserve_view=True)

        elif self.active_tool == 'eraser':
            self.erase_at(page_num, rel_x, rel_y)

    def on_canvas_move(self, scene_pos):
        if not self.stroke_active or self._stroke_slot is None:
            return
        rect = self._stroke_slot['rect']
        # Limiter le tracé à la bande où il a commencé
        x = min(max(scene_pos.x(), rect.left()), rect.right())
        y = min(max(scene_pos.y(), rect.top()), rect.bottom())
        self._stroke_path.lineTo(x, y)
        self._stroke_item.setPath(self._stroke_path)
        rel_x, rel_y = self._slot_rel(self._stroke_slot, QPointF(x, y))
        self._stroke_points.append({'relative_x': rel_x, 'relative_y': rel_y})

    def on_canvas_release(self):
        if not self.stroke_active:
            return
        self.stroke_active = False
        if len(self._stroke_points) > 1:
            page_num = self._stroke_slot['page']
            index = self.music_notation.start_new_drawing(
                page_num, self.crayon_color, self.crayon_size)
            for pt in self._stroke_points:
                self.music_notation.add_drawing_point(
                    page_num, pt['relative_x'], pt['relative_y'], index)
        else:
            # Tracé vide : annuler l'entrée d'historique superflue
            self.history_manager.undo_stack.pop()
            if self._stroke_item is not None:
                self.scene.removeItem(self._stroke_item)
        self._stroke_points = []
        self._stroke_item = None
        self._stroke_path = None
        self._stroke_slot = None

    def erase_at(self, page_num, rel_x, rel_y):
        best_dist = ERASER_TOLERANCE
        best_kind = None
        best_notation = None
        best_path_index = None

        for notation in self.music_notation.get_page_notations(page_num):
            dx = notation['relative_x'] - rel_x
            dy = notation['relative_y'] - rel_y
            dist = (dx * dx + dy * dy) ** 0.5
            if dist < best_dist:
                best_dist = dist
                best_kind = 'notation'
                best_notation = notation

        drawings = self.music_notation.get_page_drawings(page_num)
        for path_index, path_data in enumerate(drawings):
            points = path_data.get('points', []) if isinstance(path_data, dict) else path_data
            for point in points:
                dx = point['relative_x'] - rel_x
                dy = point['relative_y'] - rel_y
                dist = (dx * dx + dy * dy) ** 0.5
                if dist < best_dist:
                    best_dist = dist
                    best_kind = 'drawing'
                    best_path_index = path_index

        if best_kind is None:
            return

        self.push_history()
        if best_kind == 'notation':
            self.music_notation.annotations.remove(best_notation)
        else:
            drawings.pop(best_path_index)
        self.rebuild_scene(preserve_view=True)

    def clear_current_page(self):
        if not self.current_pdf_path:
            return
        self.push_history()
        page = self.pdf_viewer.current_page
        self.music_notation.clear_page_notation(page)
        self.annotation_manager.clear_page_annotations(page)
        self.rebuild_scene(preserve_view=True)


def main():
    app = QApplication(sys.argv)
    app.setApplicationName("Arpège")
    logo_path = os.path.join(ASSETS_DIR, "Logo.png")
    if os.path.exists(logo_path):
        app.setWindowIcon(QIcon(logo_path))
    app.setStyleSheet(QSS)
    window = ArpegeWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
