class Contact {
  final int? id;
  final int? visitCardId;
  String phoneNumber;

  Contact({this.id, this.visitCardId, required this.phoneNumber});

  Map<String, dynamic> toMap() => {
    'id': id,
    'visitCardId': visitCardId,
    'phoneNumber': phoneNumber,
  };

  factory Contact.fromMap(Map<String, dynamic> map) => Contact(
    id: map['id'],
    visitCardId: map['visitCardId'],
    phoneNumber: map['phoneNumber'],
  );
}
