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
from PySide6.QtWidgets import (QAbstractItemView, QApplication, QButtonGroup, QColorDialog,
                               QDialog, QDialogButtonBox, QDockWidget, QFileDialog,
                               QFormLayout, QFrame, QGraphicsDropShadowEffect, QGraphicsItem,
                               QGraphicsPathItem, QGraphicsRectItem, QGraphicsScene,
                               QGraphicsSimpleTextItem, QGraphicsView, QHBoxLayout,
                               QInputDialog, QLabel, QLineEdit, QListWidget, QListWidgetItem,
                               QMainWindow, QMenu, QMessageBox, QPlainTextEdit, QPushButton,
                               QSizePolicy, QToolBar, QToolButton, QVBoxLayout, QWidget)

from features.pdf_viewer import PDFViewer
from features.annotation import AnnotationManager
from features.music_notation import MusicNotation
from features.history import HistoryManager
from features.pdf_export import export_annotated_pdf
from features.library import Library, METADATA_FIELDS
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

QDockWidget {{
    color: {C['text']};
    titlebar-close-icon: none;
    titlebar-normal-icon: none;
}}
QDockWidget::title {{
    background-color: {C['crust']};
    padding: 8px 12px;
    font-weight: 700;
    border-bottom: 1px solid {C['surface0']};
}}
QDockWidget > QWidget {{ background-color: {C['mantle']}; }}

QListWidget {{
    background-color: {C['mantle']};
    color: {C['text']};
    border: none;
    outline: none;
    padding: 4px;
}}
QListWidget::item {{
    padding: 8px 10px;
    border-radius: 8px;
    margin: 1px 2px;
}}
QListWidget::item:hover {{ background-color: {C['surface0']}; }}
QListWidget::item:selected {{
    background-color: {C['blue']};
    color: {C['crust']};
}}

QLineEdit, QPlainTextEdit {{
    background-color: {C['surface0']};
    color: {C['text']};
    border: 1px solid {C['surface1']};
    border-radius: 8px;
    padding: 6px 10px;
    selection-background-color: {C['blue']};
    selection-color: {C['crust']};
}}
QLineEdit:focus, QPlainTextEdit:focus {{ border: 1px solid {C['blue']}; }}

QLabel#panelHint {{ color: {C['subtext']}; padding: 4px 6px; }}
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


class MetadataDialog(QDialog):
    """Éditeur des métadonnées d'une partition."""

    LABELS = {
        'title': 'Titre',
        'composer': 'Compositeur',
        'arranger': 'Arrangeur',
        'key': 'Tonalité',
        'tempo': 'Tempo',
        'genre': 'Genre',
    }

    def __init__(self, parent, score):
        super().__init__(parent)
        self.setWindowTitle("Métadonnées de la partition")
        self.setMinimumWidth(420)
        layout = QVBoxLayout(self)

        form = QFormLayout()
        form.setSpacing(8)
        self.edits = {}
        for field in ['title', 'composer', 'arranger', 'key', 'tempo', 'genre']:
            edit = QLineEdit(str(score.get(field, '')))
            self.edits[field] = edit
            form.addRow(self.LABELS[field], edit)
        self.notes_edit = QPlainTextEdit(str(score.get('notes', '')))
        self.notes_edit.setFixedHeight(90)
        form.addRow('Notes', self.notes_edit)
        layout.addLayout(form)

        path_label = QLabel(score.get('path', ''))
        path_label.setObjectName("panelHint")
        path_label.setWordWrap(True)
        layout.addWidget(path_label)

        buttons = QDialogButtonBox(QDialogButtonBox.Save | QDialogButtonBox.Cancel)
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addWidget(buttons)

    def values(self):
        data = {field: edit.text() for field, edit in self.edits.items()}
        data['notes'] = self.notes_edit.toPlainText()
        return data


class PageOrderDialog(QDialog):
    """Réordonner / masquer / dupliquer les pages en une séquence personnalisée.

    N'affecte jamais le PDF d'origine : la séquence est une liste d'indices source.
    """

    def __init__(self, parent, page_count, sequence, thumb_provider):
        super().__init__(parent)
        self.setWindowTitle("Gérer les pages")
        self.setMinimumSize(340, 520)
        self.page_count = page_count

        layout = QVBoxLayout(self)
        hint = QLabel("Glissez pour réordonner. La séquence n'altère pas le PDF d'origine.")
        hint.setObjectName("panelHint")
        hint.setWordWrap(True)
        layout.addWidget(hint)

        self.list = QListWidget()
        self.list.setDragDropMode(QAbstractItemView.InternalMove)
        self.list.setDefaultDropAction(Qt.MoveAction)
        self.list.setSelectionMode(QAbstractItemView.ExtendedSelection)
        self.list.setIconSize(QSize(70, 99))
        self.list.setSpacing(2)
        layout.addWidget(self.list)

        for src in sequence:
            self._add_row(src, thumb_provider(src))

        btns = QHBoxLayout()
        for text, slot in [("Masquer", self._hide_selected),
                           ("Dupliquer", self._duplicate_selected),
                           ("Réinitialiser", self._reset)]:
            b = QPushButton(text)
            b.clicked.connect(slot)
            btns.addWidget(b)
        layout.addLayout(btns)
        self._thumb_provider = thumb_provider

        box = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        box.accepted.connect(self.accept)
        box.rejected.connect(self.reject)
        layout.addWidget(box)

    def _add_row(self, src, icon, at=None):
        item = QListWidgetItem(f"  Page {src + 1}")
        item.setData(Qt.UserRole, src)
        if icon is not None:
            item.setIcon(icon)
        if at is None:
            self.list.addItem(item)
        else:
            self.list.insertItem(at, item)

    def _hide_selected(self):
        for item in self.list.selectedItems():
            self.list.takeItem(self.list.row(item))

    def _duplicate_selected(self):
        rows = sorted(self.list.row(i) for i in self.list.selectedItems())
        for offset, row in enumerate(rows):
            src = self.list.item(row + offset).data(Qt.UserRole)
            self._add_row(src, self._thumb_provider(src), at=row + offset + 1)

    def _reset(self):
        self.list.clear()
        for src in range(self.page_count):
            self._add_row(src, self._thumb_provider(src))

    def sequence(self):
        return [self.list.item(i).data(Qt.UserRole) for i in range(self.list.count())]


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
        self.library = Library()
        # Migration : importer les anciens fichiers récents dans la bibliothèque
        self.library.import_paths(recent_files.load_recent_files())

        self.current_pdf_path = None
        self.current_score_id = None
        self.bookmarks = []          # signets de la partition courante : [{label, page}]
        self.page_sequence = None    # séquence de pages personnalisée (indices source) ou None
        self.seq_pos = 0             # position courante dans la séquence
        self.active_setlist_id = None
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
        self.build_panels()
        self.build_statusbar()
        self.build_shortcuts()

        self.refresh_library()
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

    def _dock_body(self):
        """Widget + layout vertical standard pour le contenu d'un dock."""
        widget = QWidget()
        layout = QVBoxLayout(widget)
        layout.setContentsMargins(8, 8, 8, 8)
        layout.setSpacing(6)
        return widget, layout

    def build_panels(self):
        # --- Bibliothèque -------------------------------------------------
        self.library_dock = QDockWidget("Bibliothèque", self)
        self.library_dock.setObjectName("library_dock")
        body, lay = self._dock_body()
        self.library_search = QLineEdit()
        self.library_search.setPlaceholderText("Rechercher (titre, compositeur…)")
        self.library_search.setClearButtonEnabled(True)
        self.library_search.textChanged.connect(self.refresh_library)
        lay.addWidget(self.library_search)
        self.library_list = QListWidget()
        self.library_list.itemActivated.connect(
            lambda item: self.open_score_id(item.data(Qt.UserRole)))
        self.library_list.setContextMenuPolicy(Qt.CustomContextMenu)
        self.library_list.customContextMenuRequested.connect(self.library_context_menu)
        lay.addWidget(self.library_list)
        row = QHBoxLayout()
        add_btn = QPushButton("＋ Ajouter…")
        add_btn.clicked.connect(self.open_pdf_dialog)
        info_btn = QPushButton("Infos")
        info_btn.clicked.connect(self.edit_selected_metadata)
        row.addWidget(add_btn)
        row.addWidget(info_btn)
        lay.addLayout(row)
        self.library_dock.setWidget(body)
        self.addDockWidget(Qt.LeftDockWidgetArea, self.library_dock)

        # --- Signets ------------------------------------------------------
        self.bookmarks_dock = QDockWidget("Signets", self)
        self.bookmarks_dock.setObjectName("bookmarks_dock")
        body, lay = self._dock_body()
        self.bookmarks_list = QListWidget()
        self.bookmarks_list.itemActivated.connect(
            lambda item: self.go_to_page(item.data(Qt.UserRole)))
        self.bookmarks_list.setContextMenuPolicy(Qt.CustomContextMenu)
        self.bookmarks_list.customContextMenuRequested.connect(self.bookmark_context_menu)
        lay.addWidget(self.bookmarks_list)
        add_bm = QPushButton("＋ Signet à la page courante")
        add_bm.clicked.connect(self.add_bookmark)
        lay.addWidget(add_bm)
        self.bookmarks_dock.setWidget(body)
        self.addDockWidget(Qt.LeftDockWidgetArea, self.bookmarks_dock)

        # --- Setlists -----------------------------------------------------
        self.setlist_dock = QDockWidget("Setlists", self)
        self.setlist_dock.setObjectName("setlist_dock")
        body, lay = self._dock_body()
        self.setlist_combo_list = QListWidget()
        self.setlist_combo_list.setFixedHeight(96)
        self.setlist_combo_list.itemClicked.connect(
            lambda item: self.select_setlist(item.data(Qt.UserRole)))
        self.setlist_combo_list.setContextMenuPolicy(Qt.CustomContextMenu)
        self.setlist_combo_list.customContextMenuRequested.connect(self.setlist_context_menu)
        lay.addWidget(QLabel("Setlists", objectName="panelHint"))
        lay.addWidget(self.setlist_combo_list)
        new_sl = QPushButton("＋ Nouvelle setlist")
        new_sl.clicked.connect(self.create_setlist)
        lay.addWidget(new_sl)
        lay.addWidget(QLabel("Morceaux", objectName="panelHint"))
        self.setlist_songs = QListWidget()
        self.setlist_songs.itemActivated.connect(
            lambda item: self.open_setlist_song(self.setlist_songs.row(item)))
        self.setlist_songs.setContextMenuPolicy(Qt.CustomContextMenu)
        self.setlist_songs.customContextMenuRequested.connect(self.setlist_song_context_menu)
        lay.addWidget(self.setlist_songs)
        self.setlist_dock.setWidget(body)
        self.addDockWidget(Qt.LeftDockWidgetArea, self.setlist_dock)

        # Empiler les trois panneaux en onglets
        self.tabifyDockWidget(self.library_dock, self.bookmarks_dock)
        self.tabifyDockWidget(self.library_dock, self.setlist_dock)
        self.library_dock.raise_()
        self.resizeDocks([self.library_dock], [260], Qt.Horizontal)

        # Entrées de menu pour afficher/masquer les panneaux
        panels_menu = self.menuBar().addMenu("Panneaux")
        panels_menu.addAction(self.library_dock.toggleViewAction())
        panels_menu.addAction(self.bookmarks_dock.toggleViewAction())
        panels_menu.addAction(self.setlist_dock.toggleViewAction())

        self.refresh_setlists()

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
        QShortcut(QKeySequence("Ctrl+B"), self, activated=self.add_bookmark)
        QShortcut(QKeySequence("Ctrl+L"), self, activated=lambda: self.library_dock.raise_())
        QShortcut(QKeySequence("Alt+Right"), self, activated=self.next_song)
        QShortcut(QKeySequence("Alt+Left"), self, activated=self.prev_song)

    # ------------------------------------------------------------------
    # Bibliothèque
    # ------------------------------------------------------------------

    def refresh_library(self):
        if not hasattr(self, 'library_list'):
            return
        query = self.library_search.text()
        self.library_list.clear()
        for score in self.library.search(query):
            title = score.get('title') or os.path.basename(score.get('path', ''))
            composer = score.get('composer')
            label = f"{title}   ·   {composer}" if composer else title
            item = QListWidgetItem(label)
            item.setData(Qt.UserRole, score['id'])
            if os.path.exists(score.get('path', '')):
                item.setToolTip(score['path'])
            else:
                item.setForeground(QColor(C['surface1']))
                item.setToolTip("Fichier introuvable :\n" + score.get('path', ''))
            if score['id'] == self.current_score_id:
                item.setSelected(True)
            self.library_list.addItem(item)

    def open_score_id(self, score_id):
        score = self.library.get_score(score_id)
        if not score:
            return
        if not os.path.exists(score.get('path', '')):
            QMessageBox.warning(self, "Fichier introuvable",
                                f"Le fichier n'existe plus :\n{score.get('path', '')}")
            return
        self.open_pdf(score['path'])

    def library_context_menu(self, pos):
        item = self.library_list.itemAt(pos)
        if not item:
            return
        score_id = item.data(Qt.UserRole)
        menu = QMenu(self)
        menu.addAction("Ouvrir", lambda: self.open_score_id(score_id))
        menu.addAction("Métadonnées…", lambda: self._edit_metadata(score_id))
        if self.library.setlists:
            sub = menu.addMenu("Ajouter à la setlist")
            for setlist in self.library.setlists:
                sub.addAction(setlist['name'],
                              lambda checked=False, sid=setlist['id']:
                              self._add_to_setlist(sid, score_id))
        menu.addSeparator()
        menu.addAction("Retirer de la bibliothèque",
                       lambda: self._remove_from_library(score_id))
        menu.exec(self.library_list.mapToGlobal(pos))

    def edit_selected_metadata(self):
        item = self.library_list.currentItem()
        if item:
            self._edit_metadata(item.data(Qt.UserRole))
        elif self.current_score_id:
            self._edit_metadata(self.current_score_id)
        else:
            QMessageBox.information(self, "Métadonnées",
                                    "Sélectionnez une partition dans la bibliothèque.")

    def _edit_metadata(self, score_id):
        score = self.library.get_score(score_id)
        if not score:
            return
        dialog = MetadataDialog(self, score)
        if dialog.exec() == QDialog.Accepted:
            self.library.update_metadata(score_id, **dialog.values())
            self.refresh_library()
            if score_id == self.current_score_id:
                self._update_title_from_library()

    def _remove_from_library(self, score_id):
        score = self.library.get_score(score_id)
        title = score.get('title', '') if score else ''
        confirm = QMessageBox.question(
            self, "Retirer de la bibliothèque",
            f"Retirer « {title} » de la bibliothèque ?\n"
            "(Le fichier PDF et ses annotations ne sont pas supprimés.)")
        if confirm == QMessageBox.Yes:
            self.library.remove_score(score_id)
            if score_id == self.current_score_id:
                self.current_score_id = None
            self.refresh_library()
            self.refresh_setlists()

    def _update_title_from_library(self):
        score = self.library.get_score(self.current_score_id) if self.current_score_id else None
        title = score.get('title') if score else None
        if not title and self.current_pdf_path:
            title = os.path.basename(self.current_pdf_path)
        self.setWindowTitle(f"Arpège — {title}" if title else "Arpège")

    # ------------------------------------------------------------------
    # Signets (bookmarks)
    # ------------------------------------------------------------------

    def refresh_bookmarks(self):
        if not hasattr(self, 'bookmarks_list'):
            return
        self.bookmarks_list.clear()
        for bm in sorted(self.bookmarks, key=lambda b: b['page']):
            item = QListWidgetItem(f"p.{bm['page'] + 1}   {bm['label']}")
            item.setData(Qt.UserRole, bm['page'])
            self.bookmarks_list.addItem(item)

    def add_bookmark(self):
        if not self.current_pdf_path:
            return
        page = self.pdf_viewer.current_page
        label, ok = QInputDialog.getText(self, "Nouveau signet",
                                         f"Nom du signet (page {page + 1}) :")
        if ok:
            self.bookmarks.append({'label': label.strip() or f"Page {page + 1}",
                                   'page': page})
            self.save_annotations(silent=True)
            self.refresh_bookmarks()

    def bookmark_context_menu(self, pos):
        item = self.bookmarks_list.itemAt(pos)
        if not item:
            return
        page = item.data(Qt.UserRole)
        menu = QMenu(self)
        menu.addAction("Aller à la page", lambda: self.go_to_page(page))
        menu.addAction("Supprimer", lambda: self._remove_bookmark(page))
        menu.exec(self.bookmarks_list.mapToGlobal(pos))

    def _remove_bookmark(self, page):
        self.bookmarks = [b for b in self.bookmarks if b['page'] != page]
        self.save_annotations(silent=True)
        self.refresh_bookmarks()

    def go_to_page(self, page):
        """Va à une page source donnée (via sa première position dans la séquence)."""
        if not (self.pdf_viewer.pdf_document and 0 <= page < self.pdf_viewer.page_count):
            return
        seq = self.effective_sequence()
        pos = seq.index(page) if page in seq else 0
        self._goto_seq_pos(pos)

    # ------------------------------------------------------------------
    # Setlists
    # ------------------------------------------------------------------

    def refresh_setlists(self):
        if not hasattr(self, 'setlist_combo_list'):
            return
        self.setlist_combo_list.clear()
        for setlist in self.library.setlists:
            item = QListWidgetItem(f"{setlist['name']}  ({len(setlist['score_ids'])})")
            item.setData(Qt.UserRole, setlist['id'])
            if setlist['id'] == self.active_setlist_id:
                item.setSelected(True)
            self.setlist_combo_list.addItem(item)
        self.refresh_setlist_songs()

    def create_setlist(self):
        name, ok = QInputDialog.getText(self, "Nouvelle setlist", "Nom de la setlist :")
        if ok and name.strip():
            setlist = self.library.add_setlist(name.strip())
            self.active_setlist_id = setlist['id']
            self.refresh_setlists()

    def select_setlist(self, setlist_id):
        self.active_setlist_id = setlist_id
        self.refresh_setlist_songs()

    def setlist_context_menu(self, pos):
        item = self.setlist_combo_list.itemAt(pos)
        if not item:
            return
        setlist_id = item.data(Qt.UserRole)
        menu = QMenu(self)
        menu.addAction("Renommer…", lambda: self._rename_setlist(setlist_id))
        menu.addAction("Supprimer", lambda: self._delete_setlist(setlist_id))
        menu.exec(self.setlist_combo_list.mapToGlobal(pos))

    def _rename_setlist(self, setlist_id):
        setlist = self.library.get_setlist(setlist_id)
        if not setlist:
            return
        name, ok = QInputDialog.getText(self, "Renommer la setlist",
                                        "Nom :", text=setlist['name'])
        if ok and name.strip():
            self.library.rename_setlist(setlist_id, name.strip())
            self.refresh_setlists()

    def _delete_setlist(self, setlist_id):
        if self.active_setlist_id == setlist_id:
            self.active_setlist_id = None
        self.library.remove_setlist(setlist_id)
        self.refresh_setlists()

    def _add_to_setlist(self, setlist_id, score_id):
        self.library.add_to_setlist(setlist_id, score_id)
        self.active_setlist_id = setlist_id
        self.refresh_setlists()

    def refresh_setlist_songs(self):
        if not hasattr(self, 'setlist_songs'):
            return
        self.setlist_songs.clear()
        if not self.active_setlist_id:
            return
        for score in self.library.setlist_scores(self.active_setlist_id):
            title = score.get('title') or os.path.basename(score.get('path', ''))
            item = QListWidgetItem(title)
            item.setData(Qt.UserRole, score['id'])
            if score['id'] == self.current_score_id:
                item.setSelected(True)
            self.setlist_songs.addItem(item)

    def open_setlist_song(self, row):
        scores = self.library.setlist_scores(self.active_setlist_id)
        if 0 <= row < len(scores):
            self.open_score_id(scores[row]['id'])

    def setlist_song_context_menu(self, pos):
        item = self.setlist_songs.itemAt(pos)
        if not item:
            return
        score_id = item.data(Qt.UserRole)
        row = self.setlist_songs.row(item)
        menu = QMenu(self)
        menu.addAction("Ouvrir", lambda: self.open_setlist_song(row))
        menu.addAction("Monter", lambda: self._move_setlist_song(row, -1))
        menu.addAction("Descendre", lambda: self._move_setlist_song(row, 1))
        menu.addSeparator()
        menu.addAction("Retirer de la setlist",
                       lambda: self._remove_setlist_song(score_id))
        menu.exec(self.setlist_songs.mapToGlobal(pos))

    def _move_setlist_song(self, row, delta):
        setlist = self.library.get_setlist(self.active_setlist_id)
        if not setlist:
            return
        ids = setlist['score_ids']
        new = row + delta
        if 0 <= new < len(ids):
            ids[row], ids[new] = ids[new], ids[row]
            self.library.set_setlist_order(self.active_setlist_id, ids)
            self.refresh_setlist_songs()

    def _remove_setlist_song(self, score_id):
        self.library.remove_from_setlist(self.active_setlist_id, score_id)
        self.refresh_setlists()

    def next_song(self):
        self._step_song(1)

    def prev_song(self):
        self._step_song(-1)

    def _step_song(self, delta):
        if not self.active_setlist_id:
            return
        scores = self.library.setlist_scores(self.active_setlist_id)
        ids = [s['id'] for s in scores]
        if self.current_score_id in ids:
            idx = ids.index(self.current_score_id) + delta
            if 0 <= idx < len(ids):
                self.open_score_id(ids[idx])

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
        self.bookmarks = []
        self.page_sequence = None
        self.seq_pos = 0

        self.current_pdf_path = path
        self.pdf_viewer.load_pdf(path)
        self.load_existing_annotations()
        recent_files.add_recent_file(path)
        score = self.library.add_or_touch(path)
        self.current_score_id = score['id']

        self.rebuild_scene()
        self.fit_view()
        self.set_tool(None)
        self.refresh_library()
        self.refresh_bookmarks()
        self.refresh_setlist_songs()
        self._update_title_from_library()
        name = os.path.basename(path)
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

        # Signets et séquence de pages personnalisée
        self.bookmarks = save_data.get('bookmarks', [])
        seq = save_data.get('page_sequence')
        self.page_sequence = list(seq) if seq else None
        self.seq_pos = 0

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

    def save_annotations(self, silent=False):
        if not self.current_pdf_path:
            if not silent:
                QMessageBox.warning(self, "Attention", "Aucun PDF chargé.")
            return
        pdf_name = os.path.splitext(os.path.basename(self.current_pdf_path))[0]
        save_data = {
            'pdf_file': self.current_pdf_path,
            'pdf_name': pdf_name,
            'created_date': datetime.now().isoformat(),
            'last_modified': datetime.now().isoformat(),
            'total_pages': self.pdf_viewer.page_count,
            'bookmarks': self.bookmarks,
            'page_sequence': self.page_sequence,
            'annotations': {
                'music_notations': self.music_notation.get_notations(),
                'drawings': dict(self.music_notation.drawing_paths),
                'general_annotations': self.annotation_manager.annotations,
            },
        }
        try:
            with open(self._annotations_file(), 'w', encoding='utf-8') as f:
                json.dump(save_data, f, indent=2, ensure_ascii=False)
            if not silent:
                self.hint_label.setText(f"Annotations sauvegardées  •  {self._annotations_file()}")
        except Exception as e:
            if not silent:
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

    def effective_sequence(self):
        """Séquence des pages à afficher (indices source), ordre naturel par défaut."""
        if self.page_sequence is not None:
            return self.page_sequence
        if self.pdf_viewer.pdf_document:
            return list(range(self.pdf_viewer.page_count))
        return []

    def _goto_seq_pos(self, pos):
        seq = self.effective_sequence()
        if not seq:
            return
        pos = max(0, min(pos, len(seq) - 1))
        self.seq_pos = pos
        self.pdf_viewer.current_page = seq[pos]
        self.rebuild_scene()
        self.fit_view()

    def prev_page(self):
        if self.pdf_viewer.pdf_document:
            self._goto_seq_pos(self.seq_pos - 1)

    def next_page(self):
        if self.pdf_viewer.pdf_document:
            self._goto_seq_pos(self.seq_pos + 1)

    def go_first(self):
        if self.pdf_viewer.pdf_document:
            self._goto_seq_pos(0)

    def go_last(self):
        if self.pdf_viewer.pdf_document:
            self._goto_seq_pos(len(self.effective_sequence()) - 1)

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

        seq = self.effective_sequence()
        self.seq_pos = max(0, min(self.seq_pos, len(seq) - 1))
        self.pdf_viewer.current_page = seq[self.seq_pos]
        current = seq[self.seq_pos]
        # Vue double : moitié basse de la page courante au-dessus,
        # moitié haute de la page suivante (dans la séquence) juste en dessous.
        if self.spread_view and self.seq_pos + 1 < len(seq):
            specs = [
                {'page': current, 'y0': 0.5, 'y1': 1.0},
                {'page': seq[self.seq_pos + 1], 'y0': 0.0, 'y1': 0.5},
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

        total = len(seq)
        if len(specs) > 1:
            self.page_chip.setText(f"{self.seq_pos + 1}-{self.seq_pos + 2} / {total}")
        else:
            self.page_chip.setText(f"{self.seq_pos + 1} / {total}")

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
