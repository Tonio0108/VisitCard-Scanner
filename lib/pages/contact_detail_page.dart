import 'package:flutter/material.dart';
import 'package:visit_card_scanner/models/contact.dart';
import 'package:visit_card_scanner/models/social_network.dart';
import 'package:visit_card_scanner/models/website.dart';
// Import de la page de confirmation
import 'ConfirmContactPage.dart';

class ContactDetailPage extends StatelessWidget {
  final String name;
  final String org;
  final String role;
  final String? image;
  final String? email;
  final List<Contact> phones;
  final List<Website> websites;
  final List<SocialNetwork> socials;
  final int id;

  const ContactDetailPage({
    super.key,
    required this.name,
    required this.org,
    required this.role,
    this.image,
    this.email,
    required this.phones,
    required this.websites,
    required this.socials,
    required this.id,
  });

  Widget _buildListCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> items,
    required String seeAllText,
    bool showTrailing = false,
  }) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFD7D7D7)),
      ),
      child: Column(
        children: [
          ...items.map(
            (item) => ListTile(
              leading: Icon(icon, color: iconColor),
              title: Text(
                item,
                style: icon == Icons.language
                    ? const TextStyle(color: Colors.blue)
                    : null,
              ),
              trailing: showTrailing
                  ? Icon(Icons.call, color: iconColor)
                  : null,
            ),
          ),
          if (items.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  seeAllText,
                  style: TextStyle(
                    color: Colors.purple[400],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ConfirmFormPage(
                    name: name,
                    org: org,
                    role: role,
                    image: image,
                    email: email,
                    phones: phones,
                    websites: websites,
                    socials: socials,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color.fromARGB(255, 231, 231, 231),
              backgroundImage: image != null && image!.isNotEmpty
                  ? NetworkImage(image!)
                  : null,
              child: (image == null || image!.isEmpty)
                  ? const Icon(Icons.person, size: 48)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
              textAlign: TextAlign.center,
            ),
            Text(
              '$org - $role',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (email != null && email!.isNotEmpty)
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFD7D7D7)),
                ),
                child: ListTile(
                  leading: const Icon(Icons.email, color: Colors.deepOrange),
                  title: Text(email!),
                  trailing: const Icon(
                    Icons.mail_outline,
                    color: Colors.deepOrange,
                  ),
                ),
              ),

            if (phones.isNotEmpty)
              _buildListCard(
                icon: Icons.phone,
                iconColor: Colors.green,
                title: 'Téléphone(s)',
                items: phones.map((c) => c.phoneNumber).toList(),
                seeAllText: 'Voir tous les numéros',
              ),

            if (websites.isNotEmpty)
              _buildListCard(
                icon: Icons.language,
                iconColor: Colors.blue,
                title: 'Sites web',
                items: websites.map((w) => w.link).toList(),
                seeAllText: 'Voir tous les sites',
              ),

            if (socials.isNotEmpty)
              _buildListCard(
                icon: Icons.alternate_email,
                iconColor: Colors.purple,
                title: 'Réseaux sociaux',
                items: socials
                    .map((s) => '${s.title} - ${s.userName}')
                    .toList(),
                seeAllText: 'Voir tous les réseaux',
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
