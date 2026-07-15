from tkinter import Tk, Frame, Button, filedialog, Canvas, LEFT, RIGHT, TOP, BOTTOM, ttk
from tkinter import font as tkFont
from PIL import ImageTk
from features.pdf_viewer import PDFViewer
from features.annotation import AnnotationManager
from features.music_notation import MusicNotation

class MusicSheetEditor:
    def __init__(self, master):
        self.master = master
        self.master.title("🎼 Music Sheet Editor - Arpège")
        self.master.configure(bg='#f0f0f0')
        
        # Définir le thème de couleurs moderne
        self.colors = {
            'primary': '#2c3e50',      # Bleu foncé élégant
            'secondary': '#3498db',     # Bleu moderne
            'accent': '#e74c3c',        # Rouge/coral pour les actions importantes
            'success': '#27ae60',       # Vert pour les actions positives
            'warning': '#f39c12',       # Orange pour les avertissements
            'surface': '#ecf0f1',       # Gris très clair pour les surfaces
            'background': '#ffffff',    # Blanc pur
            'text': '#2c3e50',         # Texte foncé
            'text_light': '#7f8c8d',   # Texte secondaire
            'border': '#bdc3c7'        # Bordures subtiles
        }
        
        # Polices modernes
        self.fonts = {
            'button': ('Segoe UI', 9, 'normal'),
            'title': ('Segoe UI', 12, 'bold'),
            'text': ('Segoe UI', 10, 'normal'),
            'annotation': ('Segoe UI', 14, 'bold')
        }
        
        # Configuration de la grille principale
        self.master.grid_rowconfigure(1, weight=1)
        self.master.grid_columnconfigure(0, weight=1)

        # Variables pour le crayon (définir avant l'interface)
        self.crayon_color = "#000000"  # Noir par défaut
        self.crayon_size = 2  # Taille fine par défaut

        # Frame supérieur pour les boutons avec style moderne
        self.top_frame = Frame(self.master, bg=self.colors['surface'], relief='flat', bd=0)
        self.top_frame.grid(row=0, column=0, sticky="ew", padx=10, pady=(10, 5))
        
        # Style moderne pour les boutons
        self.button_style = {
            'font': self.fonts['button'],
            'relief': 'flat',
            'bd': 0,
            'padx': 15,
            'pady': 8,
            'cursor': 'hand2',
            'activebackground': self.colors['secondary'],
            'activeforeground': 'white'
        }
        
        # Styles spécifiques pour différents types de boutons
        self.primary_btn = {**self.button_style, 'bg': self.colors['primary'], 'fg': 'white'}
        self.secondary_btn = {**self.button_style, 'bg': self.colors['secondary'], 'fg': 'white'}
        self.accent_btn = {**self.button_style, 'bg': self.colors['accent'], 'fg': 'white'}
        self.success_btn = {**self.button_style, 'bg': self.colors['success'], 'fg': 'white'}
        self.warning_btn = {**self.button_style, 'bg': self.colors['warning'], 'fg': 'white'}
        self.tool_btn = {**self.button_style, 'bg': self.colors['surface'], 'fg': self.colors['text'], 'relief': 'solid', 'bd': 1}

        # Boutons avec nouveau style
        self.load_button = Button(self.top_frame, text="📁 Charger PDF", command=self.load_pdf, **self.primary_btn)
        self.load_button.pack(side=LEFT, padx=(0, 5))

        # Séparateur visuel
        separator1 = Frame(self.top_frame, width=2, bg=self.colors['text_light'])
        separator1.pack(side=LEFT, fill='y', padx=5)

        self.prev_button = Button(self.top_frame, text="◀ Page", command=self.prev_page, **self.secondary_btn)
        self.prev_button.pack(side=LEFT, padx=2)
        self.next_button = Button(self.top_frame, text="Page ▶", command=self.next_page, **self.secondary_btn)
        self.next_button.pack(side=LEFT, padx=2)

        # Séparateur visuel
        separator2 = Frame(self.top_frame, width=2, bg=self.colors['text_light'])
        separator2.pack(side=LEFT, fill='y', padx=5)

        self.crayon_button = Button(self.top_frame, text="✏️ Crayon", command=self.activate_crayon, **self.tool_btn)
        self.crayon_button.pack(side=LEFT, padx=2)
        self.diese_button = Button(self.top_frame, text="♯ Dièse", command=self.add_sharp, **self.tool_btn)
        self.diese_button.pack(side=LEFT, padx=2)
        self.bemol_button = Button(self.top_frame, text="♭ Bémol", command=self.add_flat, **self.tool_btn)
        self.bemol_button.pack(side=LEFT, padx=2)
        self.indication_button = Button(self.top_frame, text="📝 Indication", command=self.add_indication, **self.tool_btn)
        self.indication_button.pack(side=LEFT, padx=2)
        
        # Séparateur visuel pour les options de crayon
        separator_crayon = Frame(self.top_frame, width=2, bg=self.colors['text_light'])
        separator_crayon.pack(side=LEFT, fill='y', padx=5)
        
        # Contrôles pour le crayon
        crayon_frame = Frame(self.top_frame, bg=self.colors['surface'])
        crayon_frame.pack(side=LEFT, padx=2)
        
        # Bouton de couleur
        self.color_button = Button(crayon_frame, text="🎨", width=3, height=1,
                                  command=self.choose_crayon_color, **self.tool_btn)
        self.color_button.pack(side=LEFT, padx=1)
        
        # Indicateur de couleur actuelle
        self.color_indicator = Frame(crayon_frame, width=20, height=20, 
                                   bg=self.crayon_color, relief='solid', bd=1)
        self.color_indicator.pack(side=LEFT, padx=2)
        
        # Contrôle de taille
        size_frame = Frame(crayon_frame, bg=self.colors['surface'])
        size_frame.pack(side=LEFT, padx=2)
        
        # Boutons de taille
        self.size_small_btn = Button(size_frame, text="●", width=2,
                                   command=lambda: self.set_crayon_size(2), **self.tool_btn)
        self.size_small_btn.pack(side=LEFT, padx=1)
        
        self.size_medium_btn = Button(size_frame, text="●●", width=2,
                                    command=lambda: self.set_crayon_size(4), **self.tool_btn)
        self.size_medium_btn.pack(side=LEFT, padx=1)
        
        self.size_large_btn = Button(size_frame, text="●●●", width=2,
                                   command=lambda: self.set_crayon_size(6), **self.tool_btn)
        self.size_large_btn.pack(side=LEFT, padx=1)
        
        # Séparateur visuel
        separator3 = Frame(self.top_frame, width=2, bg=self.colors['text_light'])
        separator3.pack(side=LEFT, fill='y', padx=5)
        
        self.clear_button = Button(self.top_frame, text="🗑️ Effacer", command=self.clear_current_page, **self.warning_btn)
        self.clear_button.pack(side=LEFT, padx=2)

        self.save_button = Button(self.top_frame, text="💾 Sauver", command=self.save_annotations, **self.success_btn)
        self.save_button.pack(side=LEFT, padx=2)
        
        self.load_annotations_button = Button(self.top_frame, text="📂 Charger", command=self.load_annotations_manually, **self.tool_btn)
        self.load_annotations_button.pack(side=LEFT, padx=2)
        
        self.master.configure(bg=self.colors['background'])
        
        # Configurer la fenêtre en plein écran ou maximisée
        self.master.state('zoomed')  # Pour Windows, équivalent à maximiser
        self.master.geometry("1200x900")
        
        self.pdf_viewer = PDFViewer()
        self.annotation_manager = AnnotationManager()
        self.music_notation = MusicNotation()
        self.current_pdf_path = None
        
        # Variables pour les dimensions de la partition affichée
        self.pdf_display_x = 0
        self.pdf_display_y = 0
        self.pdf_display_width = 0
        self.pdf_display_height = 0
        self.current_tk_image = None
        
        # Variables pour les outils de dessin
        self.drawing = False
        self.last_x = None
        self.last_y = None
        self.active_tool = None
        self.current_drawing_path_index = None  # Index du tracé en cours
        
        # Buffer pour optimiser le dessin du crayon
        self.drawing_buffer = []  # Buffer pour les points en attente
        self.buffer_timer = None  # Timer pour vider le buffer

        # Canvas pour PDF et dessins - style moderne
        canvas_frame = Frame(self.master, bg=self.colors['surface'], relief='solid', bd=1)
        canvas_frame.grid(row=1, column=0, sticky="nsew", padx=10, pady=(5, 10))
        canvas_frame.grid_rowconfigure(0, weight=1)
        canvas_frame.grid_columnconfigure(0, weight=1)
        
        self.canvas = Canvas(
            canvas_frame, 
            bg=self.colors['surface'], 
            highlightthickness=0,
            relief='flat',
            bd=0
        )
        self.canvas.grid(row=0, column=0, sticky="nsew", padx=5, pady=5)
        
        # Variables pour l'état de l'outil actif
        self.active_tool = None
        self.tool_buttons = [
            self.crayon_button, self.diese_button, 
            self.bemol_button, self.indication_button
        ]
        
        # Lier les événements
        self.canvas.bind("<ButtonPress-1>", self.on_canvas_press)
        self.canvas.bind("<B1-Motion>", self.on_canvas_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_canvas_release)
        self.canvas.bind("<Motion>", self.on_mouse_motion)
        self.master.bind('<Configure>', self.on_window_resize)
        
        # Optimisation pour le crayon - réduire la fréquence des événements
        self.last_motion_time = 0
        
        # Initialiser l'état des boutons de taille
        self.update_size_buttons()

    def load_pdf(self):
        file_path = filedialog.askopenfilename(filetypes=[("PDF files", "*.pdf")])
        if file_path:
            # D'abord effacer toutes les annotations existantes
            self.clear_all_annotations()
            
            # Ensuite charger le nouveau PDF
            self.current_pdf_path = file_path
            self.pdf_viewer.load_pdf(file_path)
            
            # Puis chercher et charger les annotations correspondantes
            self.load_existing_annotations()
            self.render_pdf_with_annotations()

    def clear_all_annotations(self):
        """Efface toutes les annotations de toutes les pages"""
        # Effacer les notations musicales
        self.music_notation.clear_notation()
        
        # Effacer les annotations générales
        self.annotation_manager.annotations.clear()
        self.annotation_manager.page_annotations.clear()
        
        print("Toutes les annotations ont été effacées.")

    def load_existing_annotations(self):
        """Charge les annotations existantes si elles existent"""
        if not self.current_pdf_path:
            return
        
        import json
        import os
        
        # Dossier central pour toutes les annotations
        annotations_dir = os.path.join(os.path.expanduser("~"), "Documents", "Arpège", "annotations")
        
        # Rechercher le fichier d'annotations
        pdf_name = os.path.splitext(os.path.basename(self.current_pdf_path))[0]
        annotations_file = os.path.join(annotations_dir, f"{pdf_name}_annotations.json")
        
        if not os.path.exists(annotations_file):
            print(f"Aucune annotation existante trouvée pour {pdf_name}.")
            return
        
        try:
            with open(annotations_file, 'r', encoding='utf-8') as f:
                save_data = json.load(f)
            
            # Charger les annotations même si le chemin du PDF a changé
            # (on se base sur le nom du fichier plutôt que sur le chemin complet)
            saved_pdf_name = save_data.get('pdf_name', os.path.splitext(os.path.basename(save_data.get('pdf_file', '')))[0])
            if saved_pdf_name != pdf_name:
                print("Le fichier d'annotations ne correspond pas au PDF chargé.")
                return
            
            # Charger les annotations
            annotations_data = save_data.get('annotations', {})
            
            # Restaurer les notations musicales
            music_notations = annotations_data.get('music_notations', [])
            self.music_notation.annotations = music_notations
            
            # Restaurer les tracés
            drawings = annotations_data.get('drawings', {})
            # Convertir les clés de chaînes en entiers pour les numéros de page
            # Et s'assurer que le format est correct (liste de tracés)
            self.music_notation.drawing_paths = {}
            for page_str, drawing_data in drawings.items():
                page_num = int(page_str)
                # Vérifier le format des données de dessin
                if isinstance(drawing_data, list):
                    # Si c'est une liste simple de points (ancien format), la convertir
                    if drawing_data and isinstance(drawing_data[0], dict) and 'relative_x' in drawing_data[0]:
                        # Ancien format : liste de points
                        self.music_notation.drawing_paths[page_num] = [drawing_data] if drawing_data else []
                    else:
                        # Nouveau format : liste de tracés
                        self.music_notation.drawing_paths[page_num] = drawing_data
                else:
                    self.music_notation.drawing_paths[page_num] = []
            
            # Restaurer les annotations générales
            general_annotations = annotations_data.get('general_annotations', [])
            self.annotation_manager.annotations = general_annotations
            
            # Reconstruire le dictionnaire par page pour AnnotationManager
            self.annotation_manager.page_annotations = {}
            for annotation in general_annotations:
                page_num = annotation.get('page', 0)
                if page_num not in self.annotation_manager.page_annotations:
                    self.annotation_manager.page_annotations[page_num] = []
                self.annotation_manager.page_annotations[page_num].append(annotation)
            
            print(f"Annotations chargées depuis : {annotations_file}")
            
        except Exception as e:
            print(f"Erreur lors du chargement des annotations : {e}")
            from tkinter import messagebox
            messagebox.showwarning("Avertissement", f"Impossible de charger les annotations :\n{e}")

    def load_annotations_manually(self):
        """Permet de charger manuellement un fichier d'annotations"""
        if not self.current_pdf_path:
            from tkinter import messagebox
            messagebox.showwarning("Attention", "Veuillez d'abord charger un PDF.")
            return
        
        # Dossier central pour les annotations
        import os
        annotations_dir = os.path.join(os.path.expanduser("~"), "Documents", "Arpège", "annotations")
        
        # Créer le dossier s'il n'existe pas
        if not os.path.exists(annotations_dir):
            os.makedirs(annotations_dir)
        
        annotations_file = filedialog.askopenfilename(
            title="Charger les annotations",
            initialdir=annotations_dir,
            filetypes=[("Fichiers JSON", "*.json"), ("Tous les fichiers", "*.*")]
        )
        
        if not annotations_file:
            return
        
        import json
        try:
            with open(annotations_file, 'r', encoding='utf-8') as f:
                save_data = json.load(f)
            
            # Charger les annotations
            annotations_data = save_data.get('annotations', {})
            
            # Restaurer les notations musicales
            music_notations = annotations_data.get('music_notations', [])
            self.music_notation.annotations = music_notations
            
            # Restaurer les tracés
            drawings = annotations_data.get('drawings', {})
            # Convertir et s'assurer du bon format
            self.music_notation.drawing_paths = {}
            for page_str, drawing_data in drawings.items():
                page_num = int(page_str)
                if isinstance(drawing_data, list):
                    # Si c'est une liste simple de points (ancien format), la convertir
                    if drawing_data and isinstance(drawing_data[0], dict) and 'relative_x' in drawing_data[0]:
                        # Ancien format : liste de points
                        self.music_notation.drawing_paths[page_num] = [drawing_data] if drawing_data else []
                    else:
                        # Nouveau format : liste de tracés
                        self.music_notation.drawing_paths[page_num] = drawing_data
                else:
                    self.music_notation.drawing_paths[page_num] = []
            
            # Restaurer les annotations générales
            general_annotations = annotations_data.get('general_annotations', [])
            self.annotation_manager.annotations = general_annotations
            
            # Reconstruire le dictionnaire par page
            self.annotation_manager.page_annotations = {}
            for annotation in general_annotations:
                page_num = annotation.get('page', 0)
                if page_num not in self.annotation_manager.page_annotations:
                    self.annotation_manager.page_annotations[page_num] = []
                self.annotation_manager.page_annotations[page_num].append(annotation)
            
            # Redessiner la page avec les nouvelles annotations
            self.render_pdf_with_annotations()
            
            from tkinter import messagebox
            messagebox.showinfo("Succès", f"Annotations chargées depuis :\n{annotations_file}")
            
        except Exception as e:
            from tkinter import messagebox
            messagebox.showerror("Erreur", f"Impossible de charger le fichier d'annotations :\n{e}")

    def calculate_pdf_dimensions(self):
        """Calcule et met à jour les dimensions d'affichage de la partition"""
        pil_image = self.pdf_viewer.render_page()
        if not pil_image:
            return None
            
        # Obtenir les dimensions du canvas
        canvas_width = self.canvas.winfo_width()
        canvas_height = self.canvas.winfo_height()
        
        # Si les dimensions ne sont pas encore disponibles, utiliser les dimensions par défaut
        if canvas_width <= 1 or canvas_height <= 1:
            self.master.update_idletasks()
            canvas_width = self.canvas.winfo_width()
            canvas_height = self.canvas.winfo_height()
        
        # Dimensions par défaut si toujours pas disponibles
        if canvas_width <= 1 or canvas_height <= 1:
            canvas_width = 1100
            canvas_height = 800
        
        # Calculer le ratio pour maintenir les proportions
        img_width, img_height = pil_image.size
        
        # Marges pour laisser un peu d'espace
        margin = 20
        max_width = canvas_width - (margin * 2)
        max_height = canvas_height - (margin * 2)
        
        # Calculer le facteur d'échelle pour que l'image tienne dans le canvas
        scale_width = max_width / img_width
        scale_height = max_height / img_height
        scale = min(scale_width, scale_height)
        
        # Nouvelles dimensions
        new_width = int(img_width * scale)
        new_height = int(img_height * scale)
        
        # Centrer l'image dans le canvas
        x = (canvas_width - new_width) // 2
        y = (canvas_height - new_height) // 2
        
        # Mettre à jour les variables de dimensions
        self.pdf_display_x = x
        self.pdf_display_y = y
        self.pdf_display_width = new_width
        self.pdf_display_height = new_height
        
        # Redimensionner l'image
        pil_image = pil_image.resize((new_width, new_height), resample=3)
        return pil_image, x, y, canvas_width, canvas_height

    def render_pdf_with_annotations(self):
        """Rend le PDF avec toutes les annotations en coordonnées relatives"""
        self.canvas.delete("all")
        
        result = self.calculate_pdf_dimensions()
        if not result:
            canvas_width = self.canvas.winfo_width() or 1100
            canvas_height = self.canvas.winfo_height() or 800
            self.canvas.create_text(canvas_width//2, canvas_height//2, 
                                   text="📄 Aucun PDF chargé\n\nCliquez sur 'Charger PDF' pour commencer", 
                                   font=self.fonts['title'], 
                                   fill=self.colors['text_light'],
                                   justify='center')
            return
        
        pil_image, x, y, canvas_width, canvas_height = result
        
        # Afficher l'image du PDF
        self.current_tk_image = ImageTk.PhotoImage(pil_image)
        self.canvas.create_image(x, y, anchor="nw", image=self.current_tk_image)
        
        # Affichage moderne du numéro de page avec fond
        page_text = f"Page {self.pdf_viewer.current_page+1}/{self.pdf_viewer.page_count}"
        
        # Créer un fond pour le texte de la page
        text_bg = self.canvas.create_rectangle(
            canvas_width - 120, 10, 
            canvas_width - 10, 35,
            fill=self.colors['primary'], 
            outline="", 
            width=0
        )
        
        self.canvas.create_text(canvas_width - 65, 22.5, 
                               text=page_text, 
                               font=self.fonts['button'], 
                               fill="white", 
                               anchor="center")
        
        # Ajouter des flèches de navigation inclinées sur les côtés
        arrow_size = 40
        arrow_y = canvas_height // 2
        
        # Flèche gauche (page précédente) - triangle incliné vers la gauche
        if self.pdf_viewer.current_page > 0:
            # Triangle pointant vers la gauche ◤
            left_arrow_points = [
                30, arrow_y - arrow_size//2,  # Point haut
                30, arrow_y + arrow_size//2,  # Point bas
                30 - arrow_size//2, arrow_y   # Point gauche
            ]
            self.left_arrow_id = self.canvas.create_polygon(
                left_arrow_points, 
                fill=self.colors['secondary'], 
                outline=self.colors['primary'],
                width=2,
                tags="nav_arrow"
            )
            # Texte "◄" au centre
            self.canvas.create_text(30 - arrow_size//4, arrow_y, 
                                   text="◄", 
                                   font=("Arial", 20, "bold"), 
                                   fill="white",
                                   tags="nav_arrow")
        
        # Flèche droite (page suivante) - triangle incliné vers la droite
        if self.pdf_viewer.current_page < self.pdf_viewer.page_count - 1:
            # Triangle pointant vers la droite ◥
            right_arrow_points = [
                canvas_width - 30, arrow_y - arrow_size//2,  # Point haut
                canvas_width - 30, arrow_y + arrow_size//2,  # Point bas
                canvas_width - 30 + arrow_size//2, arrow_y   # Point droit
            ]
            self.right_arrow_id = self.canvas.create_polygon(
                right_arrow_points, 
                fill=self.colors['secondary'], 
                outline=self.colors['primary'],
                width=2,
                tags="nav_arrow"
            )
            # Texte "►" au centre
            self.canvas.create_text(canvas_width - 30 + arrow_size//4, arrow_y, 
                                   text="►", 
                                   font=("Arial", 20, "bold"), 
                                   fill="white",
                                   tags="nav_arrow")
        
        # Redessiner toutes les annotations de la page courante
        self.redraw_annotations()

    def redraw_annotations(self):
        """Redessine toutes les annotations de la page courante avec les coordonnées relatives"""
        current_page = self.pdf_viewer.current_page
        
        # Redessiner les notations musicales
        notations = self.music_notation.get_page_notations(current_page)
        for notation in notations:
            abs_x, abs_y = self.annotation_manager.relative_to_absolute(
                notation['relative_x'], notation['relative_y'],
                self.pdf_display_x, self.pdf_display_y,
                self.pdf_display_width, self.pdf_display_height
            )
            
            if notation['type'] == 'sharp':
                canvas_id = self.canvas.create_text(abs_x, abs_y, text="♯", 
                                                   font=(self.fonts['button'][0], 24, "bold"), 
                                                   fill=self.colors['accent'])
            elif notation['type'] == 'flat':
                canvas_id = self.canvas.create_text(abs_x, abs_y, text="♭", 
                                                   font=(self.fonts['button'][0], 24, "bold"), 
                                                   fill=self.colors['accent'])
            elif notation['type'] == 'indication':
                canvas_id = self.canvas.create_text(abs_x, abs_y, text=notation['text'], 
                                                   font=(self.fonts['button'][0], 16, "italic"), 
                                                   fill=self.colors['success'])
            
            notation['canvas_id'] = canvas_id
        
        # Redessiner les tracés avec leurs couleurs et tailles
        drawing_paths = self.music_notation.get_page_drawings(current_page)
        for path_data in drawing_paths:
            # Gérer l'ancien format (liste simple) et le nouveau format (dict avec métadonnées)
            if isinstance(path_data, list):
                # Ancien format : liste de points
                path_points = path_data
                path_color = self.colors['primary']  # Couleur par défaut
                path_size = 3  # Taille par défaut
            else:
                # Nouveau format : dict avec points, couleur et taille
                path_points = path_data.get('points', [])
                path_color = path_data.get('color', self.colors['primary'])
                path_size = path_data.get('size', 3)
            
            if len(path_points) > 1:
                # Dessiner chaque segment du tracé
                for i in range(len(path_points) - 1):
                    point1 = path_points[i]
                    point2 = path_points[i + 1]
                    
                    abs_x1, abs_y1 = self.annotation_manager.relative_to_absolute(
                        point1['relative_x'], point1['relative_y'],
                        self.pdf_display_x, self.pdf_display_y,
                        self.pdf_display_width, self.pdf_display_height
                    )
                    
                    abs_x2, abs_y2 = self.annotation_manager.relative_to_absolute(
                        point2['relative_x'], point2['relative_y'],
                        self.pdf_display_x, self.pdf_display_y,
                        self.pdf_display_width, self.pdf_display_height
                    )
                    
                    self.canvas.create_line(
                        abs_x1, abs_y1, abs_x2, abs_y2, 
                        fill=path_color,  # Utiliser la couleur sauvegardée
                        width=path_size,  # Utiliser la taille sauvegardée
                        capstyle='round', 
                        smooth=True
                    )

    def is_click_on_pdf(self, x, y):
        """Vérifie si le clic est sur la partition"""
        return (self.pdf_display_x <= x <= self.pdf_display_x + self.pdf_display_width and
                self.pdf_display_y <= y <= self.pdf_display_y + self.pdf_display_height)

    def on_window_resize(self, event=None):
        """Redessiner le PDF quand la fenêtre est redimensionnée"""
        if hasattr(self, 'current_pdf_path') and self.current_pdf_path and event.widget == self.master:
            # Délai pour éviter trop de redimensionnements
            self.master.after(100, self.render_pdf_with_annotations)

    def save_annotations(self):
        """Sauvegarde toutes les annotations dans un fichier JSON"""
        if not self.current_pdf_path:
            print("Aucun PDF chargé pour sauvegarder les annotations.")
            return
        
        import json
        import os
        from datetime import datetime
        
        # Dossier central pour toutes les annotations
        annotations_dir = os.path.join(os.path.expanduser("~"), "Documents", "Arpège", "annotations")
        
        # Créer le dossier annotations s'il n'existe pas
        if not os.path.exists(annotations_dir):
            os.makedirs(annotations_dir)
        
        # Créer le nom du fichier d'annotations basé sur le PDF
        pdf_name = os.path.splitext(os.path.basename(self.current_pdf_path))[0]
        annotations_file = os.path.join(annotations_dir, f"{pdf_name}_annotations.json")
        
        # Préparer les données à sauvegarder
        save_data = {
            'pdf_file': self.current_pdf_path,
            'pdf_name': pdf_name,
            'created_date': datetime.now().isoformat(),
            'last_modified': datetime.now().isoformat(),
            'total_pages': self.pdf_viewer.page_count,
            'annotations': {
                'music_notations': self.music_notation.get_notations(),
                'drawings': dict(self.music_notation.drawing_paths),
                'general_annotations': self.annotation_manager.annotations
            }
        }
        
        try:
            with open(annotations_file, 'w', encoding='utf-8') as f:
                json.dump(save_data, f, indent=2, ensure_ascii=False)
            print(f"Annotations sauvegardées dans : {annotations_file}")
            # Optionnel : afficher un message à l'utilisateur
            from tkinter import messagebox
            messagebox.showinfo("Sauvegarde", f"Annotations sauvegardées !\n{annotations_file}")
        except Exception as e:
            print(f"Erreur lors de la sauvegarde : {e}")
            from tkinter import messagebox
            messagebox.showerror("Erreur", f"Impossible de sauvegarder les annotations :\n{e}")

    def prev_page(self):
        self.pdf_viewer.previous_page()
        self.render_pdf_with_annotations()

    def next_page(self):
        self.pdf_viewer.next_page()
        self.render_pdf_with_annotations()

    def clear_current_page(self):
        """Efface toutes les annotations de la page courante"""
        current_page = self.pdf_viewer.current_page
        self.music_notation.clear_page_notation(current_page)
        self.annotation_manager.clear_page_annotations(current_page)
        self.render_pdf_with_annotations()

    def update_tool_buttons(self):
        """Met à jour l'apparence des boutons d'outils pour montrer lequel est actif"""
        active_style = {**self.tool_btn, 'bg': self.colors['secondary'], 'fg': 'white'}
        inactive_style = self.tool_btn
        
        for button in self.tool_buttons:
            button.configure(**inactive_style)
        
        # Mettre en surbrillance le bouton actif
        if self.active_tool == "crayon":
            self.crayon_button.configure(**active_style)
        elif self.active_tool == "sharp":
            self.diese_button.configure(**active_style)
        elif self.active_tool == "flat":
            self.bemol_button.configure(**active_style)
        elif self.active_tool == "indication":
            self.indication_button.configure(**active_style)

    def deactivate_tools(self):
        """Désactive tous les outils et remet le curseur par défaut"""
        self.active_tool = None
        self.update_tool_buttons()
        self.canvas.configure(cursor="arrow")
        print("🔧 Tous les outils désactivés")

    def activate_crayon(self):
        if self.active_tool == "crayon":
            # Si le crayon est déjà actif, le désactiver
            self.deactivate_tools()
        else:
            self.active_tool = "crayon"
            self.update_tool_buttons()
            self.canvas.configure(cursor="pencil")
            print("🔧 Outil crayon activé")

    def add_sharp(self):
        if self.active_tool == "sharp":
            # Si le dièse est déjà actif, le désactiver
            self.deactivate_tools()
        else:
            self.active_tool = "sharp"
            self.update_tool_buttons()
            self.canvas.configure(cursor="crosshair")
            print("🔧 Outil dièse activé")

    def add_flat(self):
        if self.active_tool == "flat":
            # Si le bémol est déjà actif, le désactiver
            self.deactivate_tools()
        else:
            self.active_tool = "flat"
            self.update_tool_buttons()
            self.canvas.configure(cursor="crosshair")
            print("🔧 Outil bémol activé")

    def add_indication(self):
        if self.active_tool == "indication":
            # Si l'indication est déjà active, la désactiver
            self.deactivate_tools()
        else:
            self.active_tool = "indication"
            self.update_tool_buttons()
            self.canvas.configure(cursor="crosshair")
            print("🔧 Outil indication activé")

    def choose_crayon_color(self):
        """Ouvre un sélecteur de couleur pour le crayon"""
        from tkinter import colorchooser
        color = colorchooser.askcolor(title="Choisir la couleur du crayon", 
                                     color=self.crayon_color)
        if color[1]:  # Si une couleur a été sélectionnée
            self.crayon_color = color[1]
            self.color_indicator.configure(bg=self.crayon_color)
            print(f"🎨 Couleur du crayon changée: {self.crayon_color}")

    def set_crayon_size(self, size):
        """Définit la taille du crayon"""
        self.crayon_size = size
        self.update_size_buttons()
        print(f"📏 Taille du crayon changée: {size}px")

    def update_size_buttons(self):
        """Met à jour l'apparence des boutons de taille pour montrer lequel est actif"""
        active_size_style = {**self.tool_btn, 'bg': self.colors['accent'], 'fg': 'white'}
        inactive_size_style = self.tool_btn
        
        # Réinitialiser tous les boutons
        self.size_small_btn.configure(**inactive_size_style)
        self.size_medium_btn.configure(**inactive_size_style)
        self.size_large_btn.configure(**inactive_size_style)
        
        # Mettre en surbrillance le bouton actif
        if self.crayon_size == 2:
            self.size_small_btn.configure(**active_size_style)
        elif self.crayon_size == 4:
            self.size_medium_btn.configure(**active_size_style)
        elif self.crayon_size == 6:
            self.size_large_btn.configure(**active_size_style)

    def check_navigation_click(self, x, y):
        """Vérifie si le clic est sur une flèche de navigation et effectue l'action"""
        canvas_width = self.canvas.winfo_width() or 1100
        canvas_height = self.canvas.winfo_height() or 800
        arrow_size = 40
        arrow_y = canvas_height // 2
        
        # Zone de la flèche gauche
        left_arrow_zone = {
            'x_min': 10,
            'x_max': 50,
            'y_min': arrow_y - arrow_size//2 - 10,
            'y_max': arrow_y + arrow_size//2 + 10
        }
        
        # Zone de la flèche droite
        right_arrow_zone = {
            'x_min': canvas_width - 50,
            'x_max': canvas_width - 10,
            'y_min': arrow_y - arrow_size//2 - 10,
            'y_max': arrow_y + arrow_size//2 + 10
        }
        
        # Vérifier clic sur flèche gauche (page précédente)
        if (left_arrow_zone['x_min'] <= x <= left_arrow_zone['x_max'] and 
            left_arrow_zone['y_min'] <= y <= left_arrow_zone['y_max'] and
            self.pdf_viewer.current_page > 0):
            self.prev_page()
            return True
        
        # Vérifier clic sur flèche droite (page suivante)
        if (right_arrow_zone['x_min'] <= x <= right_arrow_zone['x_max'] and 
            right_arrow_zone['y_min'] <= y <= right_arrow_zone['y_max'] and
            self.pdf_viewer.current_page < self.pdf_viewer.page_count - 1):
            self.next_page()
            return True
        
        return False

    def on_canvas_press(self, event):
        # Vérifier d'abord si le clic est sur une flèche de navigation
        if self.check_navigation_click(event.x, event.y):
            return
        
        if not self.is_click_on_pdf(event.x, event.y):
            print("❌ Clic en dehors de la zone PDF")
            return
        
        # Convertir en coordonnées relatives
        rel_x, rel_y = self.annotation_manager.absolute_to_relative(
            event.x, event.y,
            self.pdf_display_x, self.pdf_display_y,
            self.pdf_display_width, self.pdf_display_height
        )
        
        current_page = self.pdf_viewer.current_page
        
        if self.active_tool == "crayon":
            self.drawing = True
            self.last_x = event.x
            self.last_y = event.y
            
            # Vider le buffer au début d'un nouveau tracé
            self.drawing_buffer.clear()
            if self.buffer_timer:
                self.master.after_cancel(self.buffer_timer)
                self.buffer_timer = None
            
            # Démarrer un nouveau tracé avec couleur et taille actuelles
            current_page = self.pdf_viewer.current_page
            self.current_drawing_path_index = self.music_notation.start_new_drawing(
                current_page, self.crayon_color, self.crayon_size)
            
            # Ajouter le premier point immédiatement (pas de buffer pour le premier point)
            self.music_notation.add_drawing_point(current_page, rel_x, rel_y, self.current_drawing_path_index)
            
        elif self.active_tool == "sharp":
            notation = self.music_notation.add_sharp(current_page, rel_x, rel_y)
            canvas_id = self.canvas.create_text(event.x, event.y, text="♯", 
                                               font=(self.fonts['button'][0], 24, "bold"), 
                                               fill=self.colors['accent'])
            notation['canvas_id'] = canvas_id
            
        elif self.active_tool == "flat":
            notation = self.music_notation.add_flat(current_page, rel_x, rel_y)
            canvas_id = self.canvas.create_text(event.x, event.y, text="♭", 
                                               font=(self.fonts['button'][0], 24, "bold"), 
                                               fill=self.colors['accent'])
            notation['canvas_id'] = canvas_id
            
        elif self.active_tool == "indication":
            # Demander à l'utilisateur de saisir le texte de l'indication
            from tkinter import simpledialog
            indication_text = simpledialog.askstring(
                "Indication musicale", 
                "Entrez le texte de l'indication :",
                initialvalue="",
                parent=self.master
            )
            
            # Si l'utilisateur a saisi quelque chose
            if indication_text and indication_text.strip():
                notation = self.music_notation.draw_indication(indication_text.strip(), current_page, rel_x, rel_y)
                canvas_id = self.canvas.create_text(event.x, event.y, text=indication_text.strip(), 
                                                   font=(self.fonts['button'][0], 16, "italic"), 
                                                   fill=self.colors['success'])
                notation['canvas_id'] = canvas_id
            else:
                print("❌ Aucune indication ajoutée - texte vide ou annulé")

    def on_canvas_drag(self, event):
        if self.active_tool == "crayon" and self.drawing and self.is_click_on_pdf(event.x, event.y):
            # Vérifier la distance minimale pour éviter trop de points
            import time
            current_time = time.time() * 1000  # millisecondes
            
            # Limiter à environ 60 FPS pour le crayon
            if current_time - self.last_motion_time < 16:  # ~16ms = 60 FPS
                # Juste dessiner sans sauvegarder le point
                self.canvas.create_line(
                    self.last_x, self.last_y, event.x, event.y, 
                    fill=self.crayon_color,
                    width=self.crayon_size,
                    capstyle='round', 
                    smooth=True
                )
                self.last_x = event.x
                self.last_y = event.y
                return
            
            self.last_motion_time = current_time
            
            # Dessiner immédiatement sur le canvas pour la réactivité
            self.canvas.create_line(
                self.last_x, self.last_y, event.x, event.y, 
                fill=self.crayon_color,
                width=self.crayon_size,
                capstyle='round', 
                smooth=True
            )
            
            # Ajouter les coordonnées au buffer pour traitement ultérieur
            rel_x, rel_y = self.annotation_manager.absolute_to_relative(
                event.x, event.y,
                self.pdf_display_x, self.pdf_display_y,
                self.pdf_display_width, self.pdf_display_height
            )
            
            self.drawing_buffer.append({
                'page': self.pdf_viewer.current_page,
                'rel_x': rel_x,
                'rel_y': rel_y,
                'path_index': self.current_drawing_path_index
            })
            
            # Traiter le buffer de façon asynchrone pour ne pas bloquer l'interface
            if self.buffer_timer:
                self.master.after_cancel(self.buffer_timer)
            self.buffer_timer = self.master.after(5, self.process_drawing_buffer)  # Réduit à 5ms
            
            self.last_x = event.x
            self.last_y = event.y

    def process_drawing_buffer(self):
        """Traite le buffer de points de dessin de façon asynchrone"""
        if not self.drawing_buffer:
            return
        
        # Traiter tous les points du buffer
        for point_data in self.drawing_buffer:
            self.music_notation.add_drawing_point(
                point_data['page'], 
                point_data['rel_x'], 
                point_data['rel_y'], 
                point_data['path_index']
            )
        
        # Vider le buffer
        self.drawing_buffer.clear()
        self.buffer_timer = None

    def on_canvas_release(self, event):
        if self.active_tool == "crayon":
            self.drawing = False
            
            # S'assurer que le buffer est vidé immédiatement
            if self.buffer_timer:
                self.master.after_cancel(self.buffer_timer)
                self.buffer_timer = None
            self.process_drawing_buffer()
            
            self.last_x = None
            self.last_y = None
            self.current_drawing_path_index = None
            self.current_drawing_path = []

    def on_mouse_motion(self, event):
        """Gère le mouvement de la souris pour changer le curseur sur les flèches"""
        canvas_width = self.canvas.winfo_width() or 1100
        canvas_height = self.canvas.winfo_height() or 800
        arrow_size = 40
        arrow_y = canvas_height // 2
        
        # Zone de la flèche gauche
        left_arrow_zone = {
            'x_min': 10,
            'x_max': 50,
            'y_min': arrow_y - arrow_size//2 - 10,
            'y_max': arrow_y + arrow_size//2 + 10
        }
        
        # Zone de la flèche droite
        right_arrow_zone = {
            'x_min': canvas_width - 50,
            'x_max': canvas_width - 10,
            'y_min': arrow_y - arrow_size//2 - 10,
            'y_max': arrow_y + arrow_size//2 + 10
        }
        
        # Vérifier si on survole une flèche
        over_left_arrow = (left_arrow_zone['x_min'] <= event.x <= left_arrow_zone['x_max'] and 
                          left_arrow_zone['y_min'] <= event.y <= left_arrow_zone['y_max'] and
                          self.pdf_viewer.current_page > 0)
        
        over_right_arrow = (right_arrow_zone['x_min'] <= event.x <= right_arrow_zone['x_max'] and 
                           right_arrow_zone['y_min'] <= event.y <= right_arrow_zone['y_max'] and
                           self.pdf_viewer.current_page < self.pdf_viewer.page_count - 1)
        
        # Changer le curseur selon la position
        if over_left_arrow or over_right_arrow:
            self.canvas.configure(cursor="hand2")
        else:
            # Restaurer le curseur selon l'outil actif
            if self.active_tool == "crayon":
                self.canvas.configure(cursor="pencil")
            elif self.active_tool in ["sharp", "flat", "indication"]:
                self.canvas.configure(cursor="crosshair")
            else:
                self.canvas.configure(cursor="arrow")

if __name__ == "__main__":
    root = Tk()
    app = MusicSheetEditor(root)
    root.mainloop()
