import 'package:flutter/material.dart';
import 'package:visit_card_scanner/models/contact.dart';
import 'package:visit_card_scanner/models/social_network.dart';
import 'package:visit_card_scanner/models/website.dart';
import 'package:visit_card_scanner/pages/confirmContactPage.dart';
import 'package:visit_card_scanner/services/ocr_service.dart';

class AddContactScreen extends StatelessWidget {
  const AddContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Ajouter un contact',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                onPressed: () async {
                  final ocrService = OCRService();
                  final result = await ocrService
                      .scanAndParseVisitCardFromCamera(context);
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
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Scanner une carte'),
                backgroundColor: const Color(0xFF7D49FF),
                foregroundColor: Colors.white,
                elevation: 1,
              ),

              const SizedBox(height: 20),
              const Text(
                'ou',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ConfirmFormPage()),
                  );
                },
                icon: const Icon(Icons.add, color: Color(0xFF7D49FF)),
                label: const Text(
                  'Ajouter manuellement',
                  style: TextStyle(
                    color: Color(0xFF7D49FF),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
