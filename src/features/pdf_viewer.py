import fitz  # PyMuPDF
from PIL import Image
import io

class PDFViewer:
    def __init__(self):
        self.pdf_document = None
        self.current_page = 0
        self.zoom_level = 1.0
        self.page_count = 0
        self.pdf_path = None

    def load_pdf(self, file_path):
        self.pdf_path = file_path
        self.pdf_document = fitz.open(file_path)
        self.current_page = 0
        self.page_count = len(self.pdf_document)

    def render_page(self, page_number=None, dpi=200):
        # Utilise PyMuPDF pour convertir PDF en image avec haute qualité (pas besoin de poppler)
        if self.pdf_document is None:
            return None
        if page_number is None:
            page_number = self.current_page
        
        if page_number >= self.page_count:
            return None
            
        # Obtenir la page
        page = self.pdf_document[page_number]
        
        # Calculer la matrice de transformation pour le DPI (plus élevé pour meilleure qualité)
        zoom_factor = dpi / 72.0  # 72 DPI est la résolution par défaut
        matrix = fitz.Matrix(zoom_factor, zoom_factor)
        
        # Rendre la page en image avec anti-aliasing
        pix = page.get_pixmap(matrix=matrix, alpha=False)
        img_data = pix.tobytes("ppm")
        
        # Convertir en PIL Image
        pil_image = Image.open(io.BytesIO(img_data))
        return pil_image

    def zoom(self, zoom_factor):
        self.zoom_level *= zoom_factor

    def next_page(self):
        if self.pdf_document and self.current_page < self.page_count - 1:
            self.current_page += 1

    def previous_page(self):
        if self.pdf_document and self.current_page > 0:
            self.current_page -= 1