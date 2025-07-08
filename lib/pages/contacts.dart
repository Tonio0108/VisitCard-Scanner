import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:visit_card_scanner/main.dart' show routeObserver;
import 'package:visit_card_scanner/models/contact.dart';
import 'package:visit_card_scanner/models/social_network.dart';
import 'package:visit_card_scanner/models/website.dart';
import 'package:visit_card_scanner/pages/ConfirmContactPage.dart';
import 'package:visit_card_scanner/services/database_service.dart';
import 'package:visit_card_scanner/services/ocr_service.dart';
import 'contact_detail_page.dart';
import 'dart:io'; // Import dart:io

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> with RouteAware {
  List<Map<String, dynamic>> contacts = [];
  bool isLoading = true;
  String searchText = '';

  @override
  void initState() {
    super.initState();
    _loadContactsFromDb();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPush() {
    _loadContactsFromDb();
  }

  @override
  void didPopNext() {
    _loadContactsFromDb();
  }

  Future<void> _loadContactsFromDb() async {
    final cards = await DatabaseService.instance.getAllVisitCards();
    contacts = cards
        .map(
          (card) => {
            'name': card.fullName,
            'org': card.organisationName,
            'role': card.profession,
            'email': card.email,
            'phones': card.contacts,
            'websites': card.websites,
            'socials': card.socialNetworks,
            'id': card.id,
            'image': card.imageUrl, // Use the stored local image path
          },
        )
        .toList();
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredContacts = searchText.isEmpty
        ? contacts
        : contacts.where((c) {
            final query = searchText.toLowerCase();
            return c['name'].toLowerCase().contains(query) ||
                c['org'].toLowerCase().contains(query) ||
                c['role'].toLowerCase().contains(query);
          }).toList();

    final groupedContacts = groupBy(
      filteredContacts,
      (contact) => contact['name'][0].toUpperCase(),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: SizedBox(
          height: 40,
          child: TextField(
            onChanged: (value) => setState(() => searchText = value),
            decoration: InputDecoration(
              hintText: 'Rechercher un contact ...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD7D7D7)),
              ),
              suffixIcon: const Icon(Icons.search),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : contacts.isEmpty
          ? Column(
              children: [
                _buildHeader(),
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.contact_page_outlined,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Aucun contact enregistré',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ...groupedContacts.entries.expand(
                        (entry) => [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          ...entry.value.map(
                            (contact) => buildContactCard(
                              name: contact['name'] as String,
                              org: contact['org'] as String,
                              role: contact['role'] as String,
                              email: contact['email'] as String,
                              phones: contact['phones'] as List<Contact>,
                              websites: contact['websites'] as List<Website>,
                              socials:
                                  contact['socials'] as List<SocialNetwork>,
                              image: contact['image'],
                              id: contact['id'] as int,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Vos contacts',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () async {
              final ocrService = OCRService();
              final result = await ocrService.scanAndParseVisitCardFromCamera(
                context,
              );
              ocrService.dispose();

              if (result != null) {
                print('Name: ${result.name}');
                print('Company: ${result.company}');
                print('Profession: ${result.profession}');
                print('Phones: ${result.phones}');
                print('Emails: ${result.emails}');
                print('Websites: ${result.websites}');
                for (final social in result.socialNetworks) {
                  print('${social.platform}: ${social.username}');
                }

                int visitCardId = 1;

                List<Contact> contacts = result.phones
                    .map(
                      (phone) =>
                          Contact(visitCardId: visitCardId, phoneNumber: phone),
                    )
                    .toList();

                List<Website> websites = result.websites
                    .map(
                      (website) =>
                          Website(visitCardId: visitCardId, link: website),
                    )
                    .toList();

                List<SocialNetwork> socialProfiles = result.socialNetworks
                    .map(
                      (social) => SocialNetwork(
                        visitCardId: visitCardId,
                        title: social.platform,
                        userName: social.username,
                      ),
                    )
                    .toList();

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConfirmFormPage(
                      name: result.name,
                      org: result.company,
                      role: result.profession, // Pass the local image path
                      email: result.emails.isNotEmpty
                          ? result.emails.first
                          : null,
                      phones: contacts,
                      websites: websites,
                      socials: socialProfiles,
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.qr_code_scanner_rounded),
          ),
        ],
      ),
    );
  }

  Widget buildContactCard({
    required String name,
    required String org,
    required String role,
    required String email,
    required List<Contact> phones,
    List<Website>? websites,
    List<SocialNetwork>? socials,
    required int id,
    String? image, // This is now the local path
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final updatedCard = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContactDetailPage(
              name: name,
              org: org,
              role: role,
              image: image, // Pass the local image path
              email: email,
              phones: phones,
              websites: websites,
              socials: socials,
              id: id,
            ),
          ),
        );

        if (updatedCard != null && mounted) {
          await _loadContactsFromDb();
        }
      },
      child: Card(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFD7D7D7)),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color.fromARGB(255, 231, 231, 231),
                backgroundImage: image != null && image.isNotEmpty
                    ? FileImage(File(image)) // Use FileImage for local path
                    : null,
                child: (image == null || image.isEmpty)
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$org - $role',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
