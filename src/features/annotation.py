class AnnotationManager:
    def __init__(self):
        self.annotations = []
        self.page_annotations = {}  # Stockage par page

    def add_annotation(self, page_number, annotation_type, relative_x, relative_y, text="", **kwargs):
        """
        Ajoute une annotation avec des coordonnées relatives (0.0 à 1.0)
        relative_x, relative_y: position relative sur la page (0.0 = haut/gauche, 1.0 = bas/droite)
        """
        annotation = {
            'page': page_number,
            'type': annotation_type,  # 'sharp', 'flat', 'indication', 'drawing'
            'relative_x': relative_x,
            'relative_y': relative_y,
            'text': text,
            'canvas_id': None,  # ID de l'élément sur le canvas
            **kwargs
        }
        
        if page_number not in self.page_annotations:
            self.page_annotations[page_number] = []
        
        self.page_annotations[page_number].append(annotation)
        self.annotations.append(annotation)
        
        return annotation

    def remove_annotation(self, annotation):
        """Supprime une annotation"""
        if annotation in self.annotations:
            self.annotations.remove(annotation)
            page_num = annotation['page']
            if page_num in self.page_annotations and annotation in self.page_annotations[page_num]:
                self.page_annotations[page_num].remove(annotation)

    def get_page_annotations(self, page_number):
        """Récupère toutes les annotations d'une page"""
        return self.page_annotations.get(page_number, [])

    def clear_page_annotations(self, page_number):
        """Efface toutes les annotations d'une page"""
        if page_number in self.page_annotations:
            # Supprime également du tableau principal
            page_annots = self.page_annotations[page_number][:]
            for annotation in page_annots:
                if annotation in self.annotations:
                    self.annotations.remove(annotation)
            self.page_annotations[page_number] = []

    def list_annotations(self):
        return self.annotations

    def absolute_to_relative(self, abs_x, abs_y, pdf_x, pdf_y, pdf_width, pdf_height):
        """Convertit les coordonnées absolues en relatives par rapport à la partition"""
        relative_x = (abs_x - pdf_x) / pdf_width if pdf_width > 0 else 0
        relative_y = (abs_y - pdf_y) / pdf_height if pdf_height > 0 else 0
        return max(0, min(1, relative_x)), max(0, min(1, relative_y))

    def relative_to_absolute(self, relative_x, relative_y, pdf_x, pdf_y, pdf_width, pdf_height):
        """Convertit les coordonnées relatives en absolues"""
        abs_x = pdf_x + (relative_x * pdf_width)
        abs_y = pdf_y + (relative_y * pdf_height)
        return abs_x, abs_y