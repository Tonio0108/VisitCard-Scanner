import 'dart:io';

import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:visit_card_scanner/main.dart' show routeObserver;
import 'package:visit_card_scanner/models/contact.dart';
import 'package:visit_card_scanner/models/social_network.dart';
import 'package:visit_card_scanner/models/website.dart';
import 'package:visit_card_scanner/pages/ConfirmContactPage.dart';
import 'package:visit_card_scanner/services/database_service.dart';
import 'package:visit_card_scanner/services/contact_sync_service.dart';
import 'package:visit_card_scanner/services/ocr_service.dart';

import 'contact_detail_page.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

enum ContactFilter { all, personal, professional }

class _ContactPageState extends State<ContactPage> with RouteAware {
  List<Map<String, dynamic>> contacts = [];
  bool isLoading = true;
  bool isSyncing = false;
  String syncStatus = '';
  String searchText = '';
  ContactFilter filterType = ContactFilter.all;

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
    setState(() => isLoading = true);

    final cards = await DatabaseService.instance.getAllVisitCards();

    final List<Map<String, dynamic>> loadedContacts = cards.map((card) {
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
        'synced': card.isSyncedToNative,
      };
    }).toList();

    setState(() {
      contacts = loadedContacts;
      isLoading = false;
    });
  }

  Future<bool> _ensurePermission() async {
    final hasPermission = await ContactSyncService.instance
        .hasContactsPermission();
    if (!hasPermission) {
      final granted = await ContactSyncService.instance
          .requestContactsPermission();
      if (!granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission des contacts non accordée.'),
          ),
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _syncToNative() async {
    if (!await _ensurePermission()) return;

    setState(() {
      isSyncing = true;
      syncStatus = 'Synchronisation vers contacts natifs en cours...';
    });

    try {
      final count = await ContactSyncService.instance.syncAllToNativeContacts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contacts synchronisés vers natifs: $count')),
      );
      await _loadContactsFromDb();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur synchronisation: $e')));
    } finally {
      setState(() {
        isSyncing = false;
        syncStatus = '';
      });
    }
  }

  Future<void> _importFromNative() async {
    if (!await _ensurePermission()) return;

    setState(() {
      isSyncing = true;
      syncStatus = 'Import depuis contacts natifs en cours...';
    });

    try {
      final count = await ContactSyncService.instance
          .importAndSaveNativeContacts();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contacts importés/mis à jour: $count')),
      );
      await _loadContactsFromDb();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur import: $e')));
    } finally {
      setState(() {
        isSyncing = false;
        syncStatus = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredContacts = contacts.where((c) {
      switch (filterType) {
        case ContactFilter.personal:
          return (c['org'] as String).isEmpty && (c['role'] as String).isEmpty;
        case ContactFilter.professional:
          return (c['org'] as String).isNotEmpty ||
              (c['role'] as String).isNotEmpty;
        case ContactFilter.all:
          return true;
      }
    }).toList();

    if (searchText.isNotEmpty) {
      final query = searchText.toLowerCase();
      filteredContacts = filteredContacts.where((c) {
        return c['name'].toLowerCase().contains(query) ||
            c['org'].toLowerCase().contains(query) ||
            c['role'].toLowerCase().contains(query);
      }).toList();
    }

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
        bottom: isSyncing
            ? PreferredSize(
                preferredSize: const Size.fromHeight(24),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(syncStatus, style: const TextStyle(fontSize: 14)),
                ),
              )
            : null,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ContactFilter.values.map((filter) {
                      final label = {
                        ContactFilter.all: 'Tous',
                        ContactFilter.personal: 'Personnel',
                        ContactFilter.professional: 'Professionnel',
                      }[filter]!;

                      return ChoiceChip(
                        label: Text(label),
                        selected: filterType == filter,
                        onSelected: (_) => setState(() => filterType = filter),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Vos contacts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: isSyncing ? null : _syncToNative,
                            icon: const Icon(Icons.upload, color: Colors.blue),
                            tooltip: 'Exporter vers contacts natifs',
                          ),
                          IconButton(
                            onPressed: isSyncing ? null : _importFromNative,
                            icon: const Icon(
                              Icons.download,
                              color: Colors.green,
                            ),
                            tooltip: 'Importer depuis contacts natifs',
                          ),
                          IconButton(
                            onPressed: isSyncing
                                ? null
                                : () async {
                                    final ocrService = OCRService();
                                    final result = await ocrService
                                        .scanAndParseVisitCardFromCamera(
                                          context,
                                        );
                                    ocrService.dispose();

                                    if (result != null) {
                                      List<Contact> contacts = result.phones
                                          .map(
                                            (phone) => Contact(
                                              visitCardId: 1,
                                              phoneNumber: phone,
                                            ),
                                          )
                                          .toList();
                                      List<Website> websites = result.websites
                                          .map(
                                            (site) => Website(
                                              visitCardId: 1,
                                              link: site,
                                            ),
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
                            tooltip: 'Scanner une carte',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: contacts.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.contact_page_outlined,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Aucun contact enregistré',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            ...groupedContacts.entries.expand(
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
                                    name: contact['name'] as String,
                                    org: contact['org'] as String,
                                    role: contact['role'] as String,
                                    email: contact['email'] as String,
                                    phones: contact['phones'] as List<Contact>,
                                    websites:
                                        contact['websites'] as List<Website>,
                                    socials:
                                        contact['socials']
                                            as List<SocialNetwork>,
                                    image: contact['image'],
                                    id: contact['id'] as int,
                                    synced: contact['synced'] as bool,
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
    required bool synced,
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
                    ? FileImage(File(image))
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
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
