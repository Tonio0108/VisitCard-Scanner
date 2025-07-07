import 'contact.dart';
import 'website.dart';
import 'social_network.dart';

class VisitCard {
  final int? id;
  final String fullName;
  final String organisationName;
  final String email;
  final String profession;

  List<Contact> contacts;
  List<Website> websites;
  List<SocialNetwork> socialNetworks;

  VisitCard({
    this.id,
    required this.fullName,
    required this.organisationName,
    required this.email,
    required this.profession,
    this.contacts = const [],
    this.websites = const [],
    this.socialNetworks = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organisationName': organisationName,
      'email': email,
      'profession': profession,
      'contacts': contacts.map((c) => c.toMap()).toList(),
      'websites': websites.map((w) => w.toMap()).toList(),
      'socialNetworks': socialNetworks.map((s) => s.toMap()).toList(),
    };
  }

  factory VisitCard.fromMap(Map<String, dynamic> map) {
    return VisitCard(
      id: map['id'],
      fullName: map['fullName'],
      organisationName: map['organisationName'],
      email: map['email'],
      profession: map['profession'],
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
    );
  }
}
