/// Un signet dans une partition : un libellé pointant vers une page source.
/// Chaque signet a un [id] unique, ce qui permet plusieurs signets sur une
/// même page, chacun supprimable indépendamment.
class Bookmark {
  final String id;
  String label;
  int page;

  Bookmark({String? id, required this.label, required this.page})
      : id = id ?? _genId();

  static int _counter = 0;
  static String _genId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        id: j['id'] as String?, // ancien format sans id → généré au chargement
        label: (j['label'] as String?) ?? '',
        page: (j['page'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'page': page};
}
