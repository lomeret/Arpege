/// Une setlist : une liste ordonnée d'identifiants de partitions.
class Setlist {
  final String id;
  String name;
  List<String> scoreIds;

  Setlist({required this.id, required this.name, required this.scoreIds});

  factory Setlist.fromJson(Map<String, dynamic> j) => Setlist(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        scoreIds: ((j['score_ids'] as List?) ?? const [])
            .map((e) => e as String)
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'score_ids': scoreIds,
      };
}
