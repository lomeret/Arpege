/// A point of a pencil stroke, in coordinates relative (0-1) to the page.
class StrokePoint {
  double relativeX;
  double relativeY;

  StrokePoint(this.relativeX, this.relativeY);

  factory StrokePoint.fromJson(Map<String, dynamic> j) => StrokePoint(
        (j['relative_x'] as num).toDouble(),
        (j['relative_y'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'relative_x': relativeX,
        'relative_y': relativeY,
      };

  StrokePoint copy() => StrokePoint(relativeX, relativeY);
}

/// A single-point musical notation: sharp, flat, or text indication.
/// Coordinates relative (0-1) to the page, like the old `music_notation.py`.
class Notation {
  String type; // 'sharp' | 'flat' | 'indication'
  int page;
  double relativeX;
  double relativeY;
  String? text;

  /// Scale factor of the symbol (1.0 = default size). Adjustable by the
  /// user to match the staff size of each score.
  double size;

  Notation({
    required this.type,
    required this.page,
    required this.relativeX,
    required this.relativeY,
    this.text,
    this.size = 1.0,
  });

  factory Notation.fromJson(Map<String, dynamic> j) => Notation(
        type: j['type'] as String,
        page: (j['page'] as num).toInt(),
        relativeX: (j['relative_x'] as num).toDouble(),
        relativeY: (j['relative_y'] as num).toDouble(),
        text: j['text'] as String?,
        size: (j['size'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'type': type,
      'page': page,
      'relative_x': relativeX,
      'relative_y': relativeY,
      'size': size,
      'canvas_id': null,
    };
    if (type == 'sharp') {
      map['symbol'] = '♯'; // ♯
    } else if (type == 'flat') {
      map['symbol'] = '♭'; // ♭
    } else if (type == 'indication') {
      map['text'] = text ?? '';
    }
    return map;
  }

  Notation copy() => Notation(
        type: type,
        page: page,
        relativeX: relativeX,
        relativeY: relativeY,
        text: text,
        size: size,
      );
}

/// A pencil stroke: a sequence of points + color + width (in PDF points).
class DrawingPath {
  List<StrokePoint> points;
  String color; // '#rrggbb'
  double size;

  DrawingPath({required this.points, this.color = '#000000', this.size = 3});

  /// Handles both the old format (a plain point list) and the new one (a dict).
  factory DrawingPath.fromJson(dynamic data) {
    if (data is List) {
      // Legacy format: a plain list of points.
      return DrawingPath(
        points: data
            .map((p) => StrokePoint.fromJson(Map<String, dynamic>.from(p as Map)))
            .toList(),
        color: '#000000',
        size: 3,
      );
    }
    final map = Map<String, dynamic>.from(data as Map);
    final rawPoints = (map['points'] as List?) ?? const [];
    return DrawingPath(
      points: rawPoints
          .map((p) => StrokePoint.fromJson(Map<String, dynamic>.from(p as Map)))
          .toList(),
      color: (map['color'] as String?) ?? '#000000',
      size: (map['size'] as num?)?.toDouble() ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'color': color,
        'size': size,
      };

  DrawingPath copy() => DrawingPath(
        points: points.map((p) => p.copy()).toList(),
        color: color,
        size: size,
      );
}
