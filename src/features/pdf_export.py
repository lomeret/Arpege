import fitz


def _hex_to_rgb01(hex_color):
    """Convertit '#rrggbb' en tuple (r, g, b) normalisé entre 0 et 1."""
    hex_color = hex_color.lstrip('#')
    if len(hex_color) != 6:
        return (0, 0, 0)
    r = int(hex_color[0:2], 16) / 255
    g = int(hex_color[2:4], 16) / 255
    b = int(hex_color[4:6], 16) / 255
    return (r, g, b)


def _draw_sharp(page, x, y, size, color):
    """Dessine un dièse vectoriel (grille en '#') centré en (x, y)."""
    half = size / 2
    slant = size * 0.12
    # Deux barres verticales légèrement inclinées
    page.draw_line((x - half * 0.5 - slant, y - half), (x - half * 0.5 + slant, y + half), color=color, width=1.4)
    page.draw_line((x + half * 0.5 - slant, y - half), (x + half * 0.5 + slant, y + half), color=color, width=1.4)
    # Deux barres horizontales
    page.draw_line((x - half, y - half * 0.35), (x + half, y - half * 0.55), color=color, width=1.4)
    page.draw_line((x - half, y + half * 0.55), (x + half, y + half * 0.35), color=color, width=1.4)


def _draw_flat(page, x, y, size, color):
    """Dessine un bémol vectoriel (hampe + panse) centré en (x, y)."""
    half = size / 2
    # Hampe verticale
    page.draw_line((x - half * 0.4, y - half), (x - half * 0.4, y + half * 0.7), color=color, width=1.4)
    # Panse arrondie
    bowl_rect = fitz.Rect(x - half * 0.4, y, x + half * 0.6, y + half * 0.9)
    page.draw_oval(bowl_rect, color=color, fill=color)


def export_annotated_pdf(source_pdf_path, dest_path, music_notation, annotation_manager, default_color="#e74c3c"):
    """
    Fusionne les annotations (dièses, bémols, indications, tracés au crayon) dans une
    copie du PDF source et l'enregistre dans dest_path.
    """
    doc = fitz.open(source_pdf_path)
    try:
        default_rgb = _hex_to_rgb01(default_color)

        for page_index, page in enumerate(doc):
            page_width = page.rect.width
            page_height = page.rect.height

            # Notations musicales (dièse, bémol, indication)
            for notation in music_notation.get_page_notations(page_index):
                abs_x = notation['relative_x'] * page_width
                abs_y = notation['relative_y'] * page_height
                symbol_size = max(page_width, page_height) * 0.02

                if notation['type'] == 'sharp':
                    _draw_sharp(page, abs_x, abs_y, symbol_size, default_rgb)
                elif notation['type'] == 'flat':
                    _draw_flat(page, abs_x, abs_y, symbol_size, default_rgb)
                elif notation['type'] == 'indication':
                    text = notation.get('text', '')
                    if text:
                        page.insert_text(
                            (abs_x, abs_y),
                            text,
                            fontsize=max(10, symbol_size * 1.2),
                            color=_hex_to_rgb01('#27ae60'),
                            fontname="helv",
                        )

            # Tracés au crayon
            for path_data in music_notation.get_page_drawings(page_index):
                if isinstance(path_data, list):
                    points = path_data
                    color = default_color
                    width = 2
                else:
                    points = path_data.get('points', [])
                    color = path_data.get('color', default_color)
                    width = path_data.get('size', 2)

                rgb = _hex_to_rgb01(color)
                for i in range(len(points) - 1):
                    p1 = points[i]
                    p2 = points[i + 1]
                    x1 = p1['relative_x'] * page_width
                    y1 = p1['relative_y'] * page_height
                    x2 = p2['relative_x'] * page_width
                    y2 = p2['relative_y'] * page_height
                    page.draw_line((x1, y1), (x2, y2), color=rgb, width=width)

        doc.save(dest_path)
    finally:
        doc.close()
