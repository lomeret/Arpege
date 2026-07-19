/// Une partition référencée dans la bibliothèque, avec ses métadonnées.
/// Schéma identique à l'ancien `library.py` (`_new_score`).
class Score {
  final String id;
  String path;
  String added;
  String lastOpened;

  String title;
  String composer;
  String arranger;
  String key;
  String tempo;
  String genre;
  String notes;

  Score({
    required this.id,
    required this.path,
    required this.added,
    required this.lastOpened,
    this.title = '',
    this.composer = '',
    this.arranger = '',
    this.key = '',
    this.tempo = '',
    this.genre = '',
    this.notes = '',
  });

  /// Champs de métadonnées éditables (ordre d'affichage).
  static const metadataFields = [
    'title',
    'composer',
    'arranger',
    'key',
    'tempo',
    'genre',
    'notes',
  ];

  factory Score.fromJson(Map<String, dynamic> j) => Score(
        id: j['id'] as String,
        path: (j['path'] as String?) ?? '',
        added: (j['added'] as String?) ?? '',
        lastOpened: (j['last_opened'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        composer: (j['composer'] as String?) ?? '',
        arranger: (j['arranger'] as String?) ?? '',
        key: (j['key'] as String?) ?? '',
        tempo: (j['tempo'] as String?) ?? '',
        genre: (j['genre'] as String?) ?? '',
        notes: (j['notes'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'added': added,
        'last_opened': lastOpened,
        'title': title,
        'composer': composer,
        'arranger': arranger,
        'key': key,
        'tempo': tempo,
        'genre': genre,
        'notes': notes,
      };

  String get(String field) {
    switch (field) {
      case 'title':
        return title;
      case 'composer':
        return composer;
      case 'arranger':
        return arranger;
      case 'key':
        return key;
      case 'tempo':
        return tempo;
      case 'genre':
        return genre;
      case 'notes':
        return notes;
      default:
        return '';
    }
  }

  void set(String field, String value) {
    switch (field) {
      case 'title':
        title = value;
        break;
      case 'composer':
        composer = value;
        break;
      case 'arranger':
        arranger = value;
        break;
      case 'key':
        key = value;
        break;
      case 'tempo':
        tempo = value;
        break;
      case 'genre':
        genre = value;
        break;
      case 'notes':
        notes = value;
        break;
    }
  }
}
