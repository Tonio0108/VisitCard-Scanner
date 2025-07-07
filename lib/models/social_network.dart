class SocialNetwork {
  final int? id;
  final int? visitCardId;
  String title;
  String userName;

  SocialNetwork({
    this.id,
    this.visitCardId,
    required this.title,
    required this.userName,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'visitCardId': visitCardId,
    'title': title,
    'userName': userName,
  };

  factory SocialNetwork.fromMap(Map<String, dynamic> map) => SocialNetwork(
    id: map['id'],
    visitCardId: map['visitCardId'],
    title: map['title'],
    userName: map['userName'],
  );
}
