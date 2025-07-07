class Website {
  final int? id;
  final int? visitCardId;
  String link;

  Website({this.id, this.visitCardId, required this.link});

  Map<String, dynamic> toMap() => {
    'id': id,
    'visitCardId': visitCardId,
    'link': link,
  };

  factory Website.fromMap(Map<String, dynamic> map) => Website(
    id: map['id'],
    visitCardId: map['visitCardId'],
    link: map['link'],
  );
}
