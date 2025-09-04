from tkinter import Tk, Frame, Button, filedialog, Canvas, LEFT, RIGHT, TOP, BOTTOM
from PIL import ImageTk
from features.pdf_viewer import PDFViewer
from features.annotation import AnnotationManager
from features.music_notation import MusicNotation

class MusicSheetEditor:
    def __init__(self, master):
        self.master = master
        self.master.title("Music Sheet Editor")
        
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
        
        # Configurer les poids des lignes et colonnes pour la responsivité
        self.master.grid_rowconfigure(1, weight=1)
        self.master.grid_columnconfigure(0, weight=1)

        # Top frame for buttons avec padding réduit
        self.top_frame = Frame(self.master, height=50)
        self.top_frame.grid(row=0, column=0, sticky="ew", padx=5, pady=2)
        self.top_frame.grid_propagate(False)

        # Boutons plus compacts
        btn_options = {'padx': 8, 'pady': 2}
        
        self.load_button = Button(self.top_frame, text="Charger PDF", command=self.load_pdf, **btn_options)
        self.load_button.pack(side=LEFT, padx=2)

        self.prev_button = Button(self.top_frame, text="◄ Page", command=self.prev_page, **btn_options)
        self.prev_button.pack(side=LEFT, padx=2)
        self.next_button = Button(self.top_frame, text="Page ►", command=self.next_page, **btn_options)
        self.next_button.pack(side=LEFT, padx=2)

        self.crayon_button = Button(self.top_frame, text="✏️ Crayon", command=self.activate_crayon, **btn_options)
        self.crayon_button.pack(side=LEFT, padx=2)
        self.diese_button = Button(self.top_frame, text="♯ Dièse", command=self.add_sharp, **btn_options)
        self.diese_button.pack(side=LEFT, padx=2)
        self.bemol_button = Button(self.top_frame, text="♭ Bémol", command=self.add_flat, **btn_options)
        self.bemol_button.pack(side=LEFT, padx=2)
        self.indication_button = Button(self.top_frame, text="📝 Indication", command=self.add_indication, **btn_options)
        self.indication_button.pack(side=LEFT, padx=2)
        
        self.clear_button = Button(self.top_frame, text="🗑️ Effacer Page", command=self.clear_current_page, **btn_options)
        self.clear_button.pack(side=LEFT, padx=2)

        self.save_button = Button(self.top_frame, text="� Sauver", command=self.save_annotations, **btn_options)
        self.save_button.pack(side=LEFT, padx=2)
        
        self.load_annotations_button = Button(self.top_frame, text="� Charger Annot.", command=self.load_annotations_manually, **btn_options)
        self.load_annotations_button.pack(side=LEFT, padx=2)

        # Canvas pour PDF et dessins - prend tout l'espace restant
        self.canvas = Canvas(self.master, bg="white", highlightthickness=0)
        self.canvas.grid(row=1, column=0, sticky="nsew", padx=5, pady=5)
        
        # Lier les événements
        self.canvas.bind("<ButtonPress-1>", self.on_canvas_press)
        self.canvas.bind("<B1-Motion>", self.on_canvas_drag)
        self.canvas.bind("<ButtonRelease-1>", self.on_canvas_release)
        self.master.bind('<Configure>', self.on_window_resize)

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
                                   text="Impossible d'afficher le PDF", 
                                   font=("Arial", 20), fill="red")
            return
        
        pil_image, x, y, canvas_width, canvas_height = result
        
        # Afficher l'image du PDF
        self.current_tk_image = ImageTk.PhotoImage(pil_image)
        self.canvas.create_image(x, y, anchor="nw", image=self.current_tk_image)
        
        # Afficher le numéro de page
        self.canvas.create_text(canvas_width - 50, 20, 
                               text=f"Page {self.pdf_viewer.current_page+1}/{self.pdf_viewer.page_count}", 
                               font=("Arial", 14), fill="black", anchor="ne")
        
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
                canvas_id = self.canvas.create_text(abs_x, abs_y, text="♯", font=("Arial", 20, "bold"), fill="blue")
            elif notation['type'] == 'flat':
                canvas_id = self.canvas.create_text(abs_x, abs_y, text="♭", font=("Arial", 20, "bold"), fill="blue")
            elif notation['type'] == 'indication':
                canvas_id = self.canvas.create_text(abs_x, abs_y, text=notation['text'], font=("Arial", 16, "italic"), fill="green")
            
            notation['canvas_id'] = canvas_id
        
        # Redessiner les tracés (maintenant organisés en tracés séparés)
        drawing_paths = self.music_notation.get_page_drawings(current_page)
        for path in drawing_paths:
            if len(path) > 1:
                # Dessiner chaque tracé séparément
                for i in range(len(path) - 1):
                    point1 = path[i]
                    point2 = path[i + 1]
                    
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
                    
                    self.canvas.create_line(abs_x1, abs_y1, abs_x2, abs_y2, fill="red", width=2)

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

    def activate_crayon(self):
        self.active_tool = "crayon"

    def add_sharp(self):
        self.active_tool = "sharp"

    def add_flat(self):
        self.active_tool = "flat"

    def add_indication(self):
        self.active_tool = "indication"

    def on_canvas_press(self, event):
        if not self.is_click_on_pdf(event.x, event.y):
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
            
            # Démarrer un nouveau tracé
            current_page = self.pdf_viewer.current_page
            self.current_drawing_path_index = self.music_notation.start_new_drawing(current_page)
            
            # Ajouter le premier point
            self.music_notation.add_drawing_point(current_page, rel_x, rel_y, self.current_drawing_path_index)
            
        elif self.active_tool == "sharp":
            notation = self.music_notation.add_sharp(current_page, rel_x, rel_y)
            canvas_id = self.canvas.create_text(event.x, event.y, text="♯", font=("Arial", 20, "bold"), fill="blue")
            notation['canvas_id'] = canvas_id
            
        elif self.active_tool == "flat":
            notation = self.music_notation.add_flat(current_page, rel_x, rel_y)
            canvas_id = self.canvas.create_text(event.x, event.y, text="♭", font=("Arial", 20, "bold"), fill="blue")
            notation['canvas_id'] = canvas_id
            
        elif self.active_tool == "indication":
            notation = self.music_notation.draw_indication("Ind.", current_page, rel_x, rel_y)
            canvas_id = self.canvas.create_text(event.x, event.y, text="Ind.", font=("Arial", 16, "italic"), fill="green")
            notation['canvas_id'] = canvas_id

    def on_canvas_drag(self, event):
        if self.active_tool == "crayon" and self.drawing and self.is_click_on_pdf(event.x, event.y):
            # Dessiner la ligne
            self.canvas.create_line(self.last_x, self.last_y, event.x, event.y, fill="red", width=2)
            
            # Convertir en coordonnées relatives et ajouter le point
            rel_x, rel_y = self.annotation_manager.absolute_to_relative(
                event.x, event.y,
                self.pdf_display_x, self.pdf_display_y,
                self.pdf_display_width, self.pdf_display_height
            )
            
            current_page = self.pdf_viewer.current_page
            self.music_notation.add_drawing_point(current_page, rel_x, rel_y, self.current_drawing_path_index)
            
            self.last_x = event.x
            self.last_y = event.y

    def on_canvas_release(self, event):
        if self.active_tool == "crayon":
            self.drawing = False
            self.last_x = None
            self.last_y = None
            self.current_drawing_path_index = None  # Réinitialiser l'index du tracé
            self.current_drawing_path = []

if __name__ == "__main__":
    root = Tk()
    app = MusicSheetEditor(root)
    root.mainloop()