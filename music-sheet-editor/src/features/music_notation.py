class MusicNotation:
    def __init__(self):
        self.annotations = []
        self.drawing_paths = {}  # Stockage des tracés par page : {page: [tracé1, tracé2, ...]}
        # Chaque tracé est une liste de points : [{relative_x, relative_y}, ...]

    def add_sharp(self, page_number, relative_x, relative_y):
        """Ajoute un dièse à une position relative sur la partition"""
        notation = {
            'type': 'sharp',
            'page': page_number,
            'relative_x': relative_x,
            'relative_y': relative_y,
            'symbol': '♯',
            'canvas_id': None
        }
        self.annotations.append(notation)
        return notation

    def add_flat(self, page_number, relative_x, relative_y):
        """Ajoute un bémol à une position relative sur la partition"""
        notation = {
            'type': 'flat',
            'page': page_number,
            'relative_x': relative_x,
            'relative_y': relative_y,
            'symbol': '♭',
            'canvas_id': None
        }
        self.annotations.append(notation)
        return notation

    def start_new_drawing(self, page_number, color="#000000", size=2):
        """Démarre un nouveau tracé sur une page avec couleur et taille"""
        if page_number not in self.drawing_paths:
            self.drawing_paths[page_number] = []
        
        # Ajouter un nouveau tracé avec métadonnées
        new_path = {
            'points': [],
            'color': color,
            'size': size
        }
        self.drawing_paths[page_number].append(new_path)
        return len(self.drawing_paths[page_number]) - 1  # Retourne l'index du nouveau tracé

    def add_drawing_point(self, page_number, relative_x, relative_y, path_index=None):
        """Ajoute un point de tracé à une position relative"""
        if page_number not in self.drawing_paths:
            self.drawing_paths[page_number] = []
        
        # Si pas d'index spécifié, utiliser le dernier tracé ou en créer un nouveau
        if path_index is None:
            if not self.drawing_paths[page_number]:
                path_index = self.start_new_drawing(page_number)
            else:
                path_index = len(self.drawing_paths[page_number]) - 1
        
        point = {
            'relative_x': relative_x,
            'relative_y': relative_y
        }
        
        # S'assurer que l'index existe
        while len(self.drawing_paths[page_number]) <= path_index:
            self.drawing_paths[page_number].append({'points': [], 'color': '#000000', 'size': 2})
        
        # Vérifier si c'est l'ancien format (liste simple) ou nouveau format (dict avec points)
        current_path = self.drawing_paths[page_number][path_index]
        if isinstance(current_path, list):
            # Ancien format : convertir en nouveau format
            self.drawing_paths[page_number][path_index] = {
                'points': current_path,
                'color': '#000000',
                'size': 2
            }
        
        self.drawing_paths[page_number][path_index]['points'].append(point)
        return point

    def draw_indication(self, indication, page_number, relative_x, relative_y):
        """Ajoute une indication musicale à une position relative"""
        notation = {
            'type': 'indication',
            'page': page_number,
            'relative_x': relative_x,
            'relative_y': relative_y,
            'text': indication,
            'canvas_id': None
        }
        self.annotations.append(notation)
        return notation

    def get_page_notations(self, page_number):
        """Récupère toutes les notations d'une page"""
        return [notation for notation in self.annotations if notation['page'] == page_number]

    def get_page_drawings(self, page_number):
        """Récupère tous les tracés d'une page"""
        return self.drawing_paths.get(page_number, [])

    def clear_notation(self):
        """Efface toutes les notations"""
        self.annotations.clear()
        self.drawing_paths.clear()

    def clear_page_notation(self, page_number):
        """Efface toutes les notations d'une page"""
        self.annotations = [notation for notation in self.annotations if notation['page'] != page_number]
        if page_number in self.drawing_paths:
            del self.drawing_paths[page_number]

    def get_notations(self):
        """Récupère toutes les notations"""
        return self.annotations