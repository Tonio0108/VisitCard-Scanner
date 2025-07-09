import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:visit_card_scanner/main.dart' show routeObserver;
import 'package:visit_card_scanner/models/contact.dart';
import 'package:visit_card_scanner/models/social_network.dart';
import 'package:visit_card_scanner/models/visit_card.dart';
import 'package:visit_card_scanner/models/website.dart';
import 'package:visit_card_scanner/pages/ConfirmContactPage.dart';
import 'package:visit_card_scanner/services/database_service.dart';
import 'package:visit_card_scanner/services/ocr_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as native;
import 'contact_detail_page.dart';
import 'dart:io';

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

  Future<void> importContactsFromNative() async {
    final granted = await native.FlutterContacts.requestPermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permission denied to access contacts')),
      );
      return;
    }

    final nativeContacts = await native.FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    // Load all existing VisitCards once to check duplicates
    final existingCards = await DatabaseService.instance.getAllVisitCards();

    int importedCount = 0;

    for (var nativeContact in nativeContacts) {
      final firstName = nativeContact.name.first;
      if (firstName == null || firstName.trim().isEmpty) continue;
      if (nativeContact.phones.isEmpty) continue;

      String email = nativeContact.emails.isNotEmpty
          ? nativeContact.emails.first.address
          : '';

      // Check if a VisitCard already exists matching by name + (email or phone)
      bool exists = existingCards.any((card) {
        if (card.fullName.toLowerCase() != firstName.toLowerCase())
          return false;

        bool emailMatches =
            email.isNotEmpty && card.email.toLowerCase() == email.toLowerCase();
        bool phoneMatches = nativeContact.phones.any(
          (p) => card.contacts.any((local) => local.phoneNumber == p.number),
        );

        return emailMatches || phoneMatches;
      });

      if (exists) {
        // Skip duplicate
        continue;
      }

      // Build Contact list
      List<Contact> contacts = nativeContact.phones
          .map((p) => Contact(phoneNumber: p.number))
          .toList();

      final card = VisitCard(
        fullName: firstName,
        organisationName: '',
        email: email,
        profession: '',
        imageUrl: null,
        contacts: contacts,
        websites: [],
        socialNetworks: [],
      );

      await DatabaseService.instance.insertVisitCard(card);
      importedCount++;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$importedCount contacts importés')));

    await _loadContactsFromDb();
  }

  Future<void> _loadContactsFromDb() async {
    final cards = await DatabaseService.instance.getAllVisitCards();

    final nativeGranted = await native.FlutterContacts.requestPermission();
    List<native.Contact> nativeContacts = [];
    if (nativeGranted) {
      nativeContacts = await native.FlutterContacts.getContacts(
        withProperties: true,
      );
    }

    contacts = cards.map((card) {
      final isNative = card.nativeId != null
          ? nativeContacts.any((c) => c.id == card.nativeId)
          : nativeContacts.any(
              (c) =>
                  c.name.first.toLowerCase() == card.fullName.toLowerCase() &&
                  (c.emails.any((e) => e.address == card.email) ||
                      c.phones.any(
                        (p) => card.contacts.any(
                          (local) => local.phoneNumber == p.number,
                        ),
                      )),
            );

      return {
        'name': card.fullName,
        'org': card.organisationName,
        'role': card.profession,
        'email': card.email,
        'phones': card.contacts,
        'websites': card.websites,
        'socials': card.socialNetworks,
        'id': card.id,
        'image': card.imageUrl,
        'isNative': isNative,
        'nativeId': card.nativeId,
      };
    }).toList();

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
                    children: groupedContacts.entries
                        .expand(
                          (entry) => [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
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
                                name: contact['name'],
                                org: contact['org'],
                                role: contact['role'],
                                email: contact['email'],
                                phones: contact['phones'],
                                websites: contact['websites'],
                                socials: contact['socials'],
                                image: contact['image'],
                                id: contact['id'],
                                isNative: contact['isNative'],
                                nativeId: contact['nativeId'],
                              ),
                            ),
                          ],
                        )
                        .toList(),
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
          Row(
            children: [
              IconButton(
                onPressed: importContactsFromNative,
                icon: const Icon(Icons.download),
                tooltip: 'Importer depuis les contacts natifs',
              ),
              IconButton(
                onPressed: () async {
                  final ocrService = OCRService();
                  final result = await ocrService
                      .scanAndParseVisitCardFromCamera(context);
                  ocrService.dispose();

                  if (result != null) {
                    int visitCardId = 1;
                    List<Contact> contacts = result.phones
                        .map(
                          (phone) => Contact(
                            visitCardId: visitCardId,
                            phoneNumber: phone,
                          ),
                        )
                        .toList();

                    List<Website> websites = result.websites
                        .map(
                          (website) =>
                              Website(visitCardId: visitCardId, link: website),
                        )
                        .toList();

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ConfirmFormPage(
                          name: result.name,
                          org: result.company,
                          role: result.profession,
                          email: result.emails.isNotEmpty
                              ? result.emails.first
                              : null,
                          phones: contacts,
                          websites: websites,
                        ),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
              ),
            ],
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
    String? image,
    required bool isNative,

    String? nativeId,
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
              image: image,
              email: email,
              phones: phones,
              websites: websites,
              socials: socials,
              id: id,
              nativeId: nativeId,
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
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color.fromARGB(255, 231, 231, 231),
                    backgroundImage: image != null && image.isNotEmpty
                        ? FileImage(File(image))
                        : null,
                    child: (image == null || image.isEmpty)
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                  if (isNative)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
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
