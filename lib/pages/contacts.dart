import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:visit_card_scanner/models/contact.dart';
import 'package:visit_card_scanner/models/social_network.dart';
import 'package:visit_card_scanner/models/website.dart';
import 'package:visit_card_scanner/services/database_service.dart';
import 'contact_detail_page.dart';

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  // Données statiques simulant une récupération depuis une BD
  List<Map<String, dynamic>> contacts = [];
  bool isLoading = true;

  String searchText = '';

  @override
  void initState() {
    super.initState();
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
            'image': 'https://i.pravatar.cc/100?u=${card.id}',
          },
        )
        .toList();
    print('Contacts loaded: *********** ${contacts.length} **************');
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Trie les contacts par ordre alphabétique
    // contacts.sort((a, b) => a['name']!.compareTo(b['name']!));
    // Filtrage selon la recherche
    final filteredContacts = searchText.isEmpty
        ? contacts
        : contacts.where((c) {
            final query = searchText.toLowerCase();
            return c['name']!.toLowerCase().contains(query) ||
                c['org']!.toLowerCase().contains(query) ||
                c['role']!.toLowerCase().contains(query);
          }).toList();
    final groupedContacts = groupBy(
      filteredContacts,
      (contact) => contact['name']![0].toUpperCase(),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: SizedBox(
          height: 40,
          child: TextField(
            onChanged: (value) {
              setState(() {
                searchText = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Rechercher un contact ...',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 0,
                horizontal: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFD7D7D7),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFFD7D7D7),
                  width: 1,
                ),
              ),
              suffixIcon: Icon(Icons.search),
            ),
          ),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Vos contacts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final image = await picker.pickImage(
                          source: ImageSource.camera,
                        );
                        if (image != null) {
                          // Traiter l'image scannée
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Image capturée !')),
                          );
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Liste groupée par lettre
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
                        name: contact['name']! as String,
                        org: contact['org']! as String,
                        role: contact['role']! as String,
                        email: contact['email']! as String,
                        phones: contact['phones'] as List<Contact>,
                        websites: contact['websites'] as List<Website>,
                        socials: contact['socials'] as List<SocialNetwork>,
                        image: contact['image']!,
                        id: contact['id'] as int,
                      ),
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
    required List<Website> websites,
    required List<SocialNetwork> socials,
    required int id,
    String? image,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContactDetailPage(
              name: name,
              org: org,
              role: role,
              image: image,
              email: email,
              phones: phones, // exemple, à remplacer par la vraie donnée
              websites: websites, // exemple, à remplacer par la vraie donnée
              socials: socials,
              id: id, // exemple, à remplacer par la vraie donnée
            ),
          ),
        );
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
                    ? NetworkImage(image)
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
