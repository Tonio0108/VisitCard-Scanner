import 'contact.dart';
import 'website.dart';
import 'social_network.dart';

class VisitCard {
  final int? id;
  final String fullName;
  final String organisationName;
  final String email;
  final String profession;
  String? nativeId; // ✅ Native contact ID
  List<Contact> contacts;
  List<Website> websites;
  List<SocialNetwork> socialNetworks;
  final String? imageUrl;

  VisitCard({
    this.id,
    required this.fullName,
    required this.organisationName,
    required this.email,
    required this.profession,
    this.nativeId, // ✅ Constructor param
    this.contacts = const [],
    this.websites = const [],
    this.socialNetworks = const [],
    this.imageUrl = "assets/images/placeholder.webp",
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'organisationName': organisationName,
      'email': email,
      'profession': profession,
      'nativeId': nativeId, // ✅ Save native ID
      'contacts': contacts.map((c) => c.toMap()).toList(),
      'websites': websites.map((w) => w.toMap()).toList(),
      'socialNetworks': socialNetworks.map((s) => s.toMap()).toList(),
      'imageUrl': imageUrl,
    };
  }

  factory VisitCard.fromMap(Map<String, dynamic> map) {
    return VisitCard(
      id: map['id'],
      fullName: map['fullName'],
      organisationName: map['organisationName'],
      email: map['email'],
      profession: map['profession'],
      nativeId: map['nativeId'], // ✅ Load native ID
      contacts:
          (map['contacts'] as List<dynamic>?)
              ?.map((item) => Contact.fromMap(item))
              .toList() ??
          [],
      websites:
          (map['websites'] as List<dynamic>?)
              ?.map((item) => Website.fromMap(item))
              .toList() ??
          [],
      socialNetworks:
          (map['socialNetworks'] as List<dynamic>?)
              ?.map((item) => SocialNetwork.fromMap(item))
              .toList() ??
          [],
      imageUrl: map['imageUrl'],
    );
  }
}
