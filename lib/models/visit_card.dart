import 'contact.dart';
import 'website.dart';
import 'social_network.dart';

class VisitCard {
  final int? id;
  final String fullName;
  final String organisationName;
  final String email;
  final String profession;
  final String? imageUrl;
  final List<Contact> contacts;
  final List<Website> websites;
  final List<SocialNetwork> socialNetworks;
  final bool isSyncedToNative;

  VisitCard({
    this.id,
    required this.fullName,
    this.organisationName = '',
    this.email = '',
    this.profession = '',
    this.imageUrl,
    this.contacts = const [],
    this.websites = const [],
    this.socialNetworks = const [],
    this.isSyncedToNative = false,
  });

  VisitCard copyWith({
    int? id,
    String? fullName,
    String? organisationName,
    String? email,
    String? profession,
    String? imageUrl,
    List<Contact>? contacts,
    List<Website>? websites,
    List<SocialNetwork>? socialNetworks,
    bool? isSyncedToNative,
  }) {
    return VisitCard(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      organisationName: organisationName ?? this.organisationName,
      email: email ?? this.email,
      profession: profession ?? this.profession,
      imageUrl: imageUrl ?? this.imageUrl,
      contacts: contacts ?? this.contacts,
      websites: websites ?? this.websites,
      socialNetworks: socialNetworks ?? this.socialNetworks,
      isSyncedToNative: isSyncedToNative ?? this.isSyncedToNative,
    );
  }

  factory VisitCard.fromMap(Map<String, dynamic> map) {
    return VisitCard(
      id: map['id'] as int?,
      fullName: map['fullName'] as String,
      organisationName: map['organisationName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      profession: map['profession'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      contacts: [], // Load separately in DB service
      websites: [],
      socialNetworks: [],
      isSyncedToNative: (map['isSyncedToNative'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'organisationName': organisationName,
      'email': email,
      'profession': profession,
      'imageUrl': imageUrl,
      'isSyncedToNative': isSyncedToNative ? 1 : 0,
    };
  }
}
