import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:collection/collection.dart';
import 'contact_detail_page.dart';
class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  // Données statiques simulant une récupération depuis une BD
  final List<Map<String, String>> contacts = [
    {
      'name': 'Angel Robertson',
      'org': 'YAS',
      'role': 'Directeur technique',
      'image': ''
    },
    {
      'name': 'Alberto Di Castillo John Doe Lopez',
      'org': 'SMMEC',
      'role': 'Comptable',
      'image': 'https://i.pravatar.cc/100?img=1'
    },
    {
      'name': 'ARISOA Bozy',
      'org': 'JIRAMA',
      'role': 'Responsable de communication',
      'image': 'https://i.pravatar.cc/100?img=2'
    },
    {
      'name': 'Bertine Rasoa',
      'org': 'ONU',
      'role': 'Directeur technique',
      'image': 'https://i.pravatar.cc/100?img=3'
    },
  ];

  String searchText = '';

  @override
  Widget build(BuildContext context) {
    // Trie les contacts par ordre alphabétique
    contacts.sort((a, b) => a['name']!.compareTo(b['name']!));
    // Filtrage selon la recherche
    final filteredContacts = searchText.isEmpty
        ? contacts
        : contacts.where((c) {
            final query = searchText.toLowerCase();
            return c['name']!.toLowerCase().contains(query)
                || c['org']!.toLowerCase().contains(query)
                || c['role']!.toLowerCase().contains(query);
          }).toList();
    final groupedContacts = groupBy(filteredContacts, (contact) => contact['name']![0].toUpperCase());

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
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD7D7D7), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD7D7D7), width: 1),
              ),
              suffixIcon: Icon(Icons.search),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('Vos contacts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Icon(Icons.qr_code_scanner_rounded),
            ],
          ),
          const SizedBox(height: 16),

          // Liste groupée par lettre
          ...groupedContacts.entries.expand((entry) => [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(entry.key,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ...entry.value.map((contact) => buildContactCard(
              name: contact['name']!,
              org: contact['org']!,
              role: contact['role']!,
              image: contact['image']!,
            ))
          ])
        ],
      ),
    );
  }

  Widget buildContactCard({
    required String name,
    required String org,
    required String role,
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
              email: 'rakotojean@gmail.com', // exemple, à remplacer par la vraie donnée
              phone: '0340012345', // exemple, à remplacer par la vraie donnée
              website: 'www.johndoe.com', // exemple, à remplacer par la vraie donnée
              social: 'Instagram', // exemple, à remplacer par la vraie donnée
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
                backgroundImage:
                    image != null && image.isNotEmpty ? NetworkImage(image) : null,
                child: (image == null || image.isEmpty)
                    ? const Icon(Icons.person, size: 30)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('$org - $role', style: const TextStyle(color: Colors.grey)),
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


