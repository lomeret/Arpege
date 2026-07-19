/// Un signet dans une partition : un libellé pointant vers une page source.
class Bookmark {
  String label;
  int page;

  Bookmark({required this.label, required this.page});

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        label: (j['label'] as String?) ?? '',
        page: (j['page'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {'label': label, 'page': page};
}
