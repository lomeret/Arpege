/// A bookmark within a score: a label pointing to a source page.
/// Each bookmark has a unique [id], which allows several bookmarks on the
/// same page, each removable independently.
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
        id: j['id'] as String?, // legacy format without an id -> generated on load
        label: (j['label'] as String?) ?? '',
        page: (j['page'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'page': page};
}
