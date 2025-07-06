import 'package:flutter/material.dart';
// Import de la page de confirmation
import 'ConfirmContactPage.dart';

class ContactDetailPage extends StatelessWidget {
  final String name;
  final String org;
  final String role;
  final String? image;
  final String? email;
  final String? phone;
  final String? website;
  final String? social;

  const ContactDetailPage({
    super.key,
    required this.name,
    required this.org,
    required this.role,
    this.image,
    this.email,
    this.phone,
    this.website,
    this.social,
  });

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
                    phone: phone,
                    website: website,
                    social: social,
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
              backgroundImage: image != null && image!.isNotEmpty ? NetworkImage(image!) : null,
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
                  trailing: const Icon(Icons.mail_outline, color: Colors.deepOrange),
                ),
              ),
            if (phone != null && phone!.isNotEmpty)
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFD7D7D7)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.phone, color: Colors.green),
                      title: Text(phone!),
                      trailing: const Icon(Icons.call, color: Colors.green),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Voir tous les numéros', style: TextStyle(color: Colors.purple[400], fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ),
            if (website != null && website!.isNotEmpty)
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFD7D7D7)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.language, color: Colors.blue),
                      title: Text(website!, style: const TextStyle(color: Colors.blue)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Voir tous les sites', style: TextStyle(color: Colors.purple[400], fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ),
            if (social != null && social!.isNotEmpty)
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Color(0xFFD7D7D7)),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.alternate_email, color: Colors.purple),
                      title: Text(social!, style: const TextStyle(color: Colors.blue)),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Voir tous les réseaux', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

